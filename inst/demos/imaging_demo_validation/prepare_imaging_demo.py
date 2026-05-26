#!/usr/bin/env python3
"""Prepare a compact three-site dsImaging validation dataset.

The generated data are synthetic CT-like NIfTI volumes with matching binary
ROI masks. They are intentionally small enough to exercise the dsImaging
runner surface repeatedly in local Opal/Rock deployments while still behaving
like real image collections: each site has images, masks and sample metadata.
"""

from __future__ import annotations

import argparse
import csv
import shutil
from pathlib import Path

import numpy as np
import SimpleITK as sitk


SITE_DEFS = (
    ("site_a", "imaging_demo_a"),
    ("site_b", "imaging_demo_b"),
    ("site_c", "imaging_demo_c"),
)


def build_case(shape, site_idx, case_idx, rng):
    zz, yy, xx = np.indices(shape)
    center_y = (shape[1] - 1) / 2
    center_x = (shape[2] - 1) / 2
    center_z = (shape[0] - 1) / 2

    image = np.full(shape, 45.0 + 2.5 * site_idx, dtype=np.float32)
    body = (
        ((yy - center_y) / 22.0) ** 2
        + ((xx - center_x) / 21.0) ** 2
        + ((zz - center_z) / 23.0) ** 2
    ) <= 1.0
    image[~body] = -1024.0

    lung_radius_y = 8.2 + 0.12 * case_idx
    lung_radius_x = 5.4 + 0.08 * site_idx
    lung_radius_z = 13.0 + 0.15 * case_idx
    left_lung = (
        ((yy - (center_y - 6.2)) / lung_radius_y) ** 2
        + ((xx - (center_x - 5.8)) / lung_radius_x) ** 2
        + ((zz - center_z) / lung_radius_z) ** 2
    ) <= 1.0
    right_lung = (
        ((yy - (center_y + 6.2)) / lung_radius_y) ** 2
        + ((xx - (center_x + 5.8)) / lung_radius_x) ** 2
        + ((zz - center_z) / lung_radius_z) ** 2
    ) <= 1.0
    lungs = (left_lung | right_lung) & body
    image[lungs] = -760.0 + 8.0 * site_idx + 1.5 * case_idx

    lesion_center = (center_z + (case_idx % 3) - 1, center_y + 6.2, center_x + 5.8)
    lesion = (
        ((zz - lesion_center[0]) / (4.0 + 0.1 * site_idx)) ** 2
        + ((yy - lesion_center[1]) / (3.2 + 0.1 * case_idx)) ** 2
        + ((xx - lesion_center[2]) / 3.0) ** 2
    ) <= 1.0
    lesion = lesion & right_lung
    image[lesion] = 115.0 + 4.0 * site_idx + 2.0 * case_idx
    image += rng.normal(0, 4.0, size=shape).astype(np.float32)

    mask = lesion.astype(np.uint8)
    if int(mask.sum()) < 10:
        mask[18:23, 26:31, 26:31] = 1
    return image, mask, lungs


def write_image(array, path, spacing):
    image = sitk.GetImageFromArray(array)
    image.SetSpacing(spacing)
    image.SetOrigin((0.0, 0.0, 0.0))
    sitk.WriteImage(image, str(path))


def prepare(workdir: Path, cases_per_site: int, seed: int, replace: bool) -> None:
    if workdir.exists() and replace:
        shutil.rmtree(workdir)
    rng = np.random.default_rng(seed)
    shape = (40, 48, 48)

    for site_idx, (site, dataset_id) in enumerate(SITE_DEFS, start=1):
        site_dir = workdir / "sites" / site
        image_dir = site_dir / "images"
        mask_dir = site_dir / "masks"
        image_dir.mkdir(parents=True, exist_ok=True)
        mask_dir.mkdir(parents=True, exist_ok=True)

        rows = []
        for case_idx in range(1, cases_per_site + 1):
            sample_id = f"{site}_case_{case_idx:02d}"
            image, mask, lungs = build_case(shape, site_idx, case_idx, rng)
            spacing = (1.15 + 0.01 * site_idx, 1.15 + 0.01 * site_idx, 2.2)
            write_image(image, image_dir / f"{sample_id}.nii.gz", spacing)
            write_image(mask, mask_dir / f"{sample_id}.nii.gz", spacing)
            rows.append(
                {
                    "sample_id": sample_id,
                    "site": site,
                    "dataset_id": dataset_id,
                    "age": 55 + site_idx * 3 + case_idx,
                    "sex": "M" if (case_idx + site_idx) % 2 else "F",
                    "scanner_vendor": ("Siemens", "GE", "Philips")[site_idx - 1],
                    "synthetic_lesion_voxels": int(mask.sum()),
                    "synthetic_lung_mean_hu": round(float(image[lungs].mean()), 3),
                    "outcome": int((case_idx + site_idx) % 3 == 0),
                }
            )

        with (site_dir / "metadata.csv").open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workdir", default="/tmp/dsimaging_imaging_demo")
    parser.add_argument("--cases-per-site", type=int, default=10)
    parser.add_argument("--seed", type=int, default=26052026)
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    prepare(Path(args.workdir).expanduser().resolve(), args.cases_per_site,
            args.seed, args.replace)
    print(Path(args.workdir).expanduser().resolve())


if __name__ == "__main__":
    main()
