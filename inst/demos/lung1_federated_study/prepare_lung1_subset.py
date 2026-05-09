#!/usr/bin/env python3
"""Prepare a reproducible LUNG1/NSCLC-Radiomics federated study subset.

The script downloads CT + RTSTRUCT series from TCIA/NBIA, converts the GTV-1
RTSTRUCT contour into NIfTI masks, partitions patients into simulated sites by
stable patient hash, writes dsimaging-admin-ready folders, and computes a local
central PyRadiomics baseline using the bundled dsImaging Aerts profile.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd
import requests
import SimpleITK as sitk
from radiomics import featureextractor
from rt_utils import RTStructBuilder


NBIA_BASE = "https://services.cancerimagingarchive.net/nbia-api/services/v1"
CLINICAL_URL = (
    "https://www.cancerimagingarchive.net/wp-content/uploads/"
    "NSCLC-Radiomics-Lung1.clinical-version3-Oct-2019.csv"
)
COLLECTION = "NSCLC-Radiomics"
SITE_NAMES = ("site_a", "site_b", "site_c")
SELECTED_FEATURES = (
    "original_firstorder_Energy",
    "original_shape_Compactness1",
    "original_glrlm_RunLengthNonUniformity",
    "wavelet-HLH_glrlm_RunLengthNonUniformity",
)


def main() -> int:
    args = parse_args()
    workdir = Path(args.workdir).resolve()
    workdir.mkdir(parents=True, exist_ok=True)

    profile_path = Path(args.profile).resolve()
    if not profile_path.exists():
        raise SystemExit(f"Profile not found: {profile_path}")

    clinical = load_clinical(workdir)
    available = set(fetch_patients())
    clinical = clinical[clinical["sample_id"].isin(available)].copy()

    raw_dir = workdir / "raw"
    nifti_images = workdir / "nifti" / "images"
    nifti_masks = workdir / "nifti" / "masks"
    for path in (raw_dir, nifti_images, nifti_masks):
        path.mkdir(parents=True, exist_ok=True)

    selected: dict[str, list[str]] = {site: [] for site in SITE_NAMES}
    failures: dict[str, str] = {}

    for patient_id in clinical["sample_id"].sort_values():
        site = SITE_NAMES[stable_site_index(patient_id, len(SITE_NAMES))]
        if len(selected[site]) >= args.n_per_site:
            continue
        try:
            image_path, mask_path = prepare_patient(
                patient_id=patient_id,
                raw_dir=raw_dir,
                image_dir=nifti_images,
                mask_dir=nifti_masks,
                roi_name=args.roi,
                force=args.force,
            )
            if image_path.exists() and mask_path.exists():
                selected[site].append(patient_id)
                print(f"[ok] {patient_id} -> {site}")
        except Exception as exc:  # noqa: BLE001 - keep going through public data quirks.
            failures[patient_id] = str(exc)
            print(f"[skip] {patient_id}: {exc}", file=sys.stderr)

        if all(len(ids) >= args.n_per_site for ids in selected.values()):
            break

    incomplete = {site: len(ids) for site, ids in selected.items()
                  if len(ids) < args.n_per_site}
    if incomplete:
        raise SystemExit(f"Could not fill requested sites: {incomplete}")

    write_site_folders(workdir, selected, clinical, nifti_images, nifti_masks,
                       roi_name=args.roi)

    central_features = run_central_radiomics(
        selected=selected,
        image_dir=nifti_images,
        mask_dir=nifti_masks,
        profile_path=profile_path,
        roi_name=args.roi,
        skip=args.skip_central,
    )

    manifest = {
        "collection": COLLECTION,
        "clinical_url": CLINICAL_URL,
        "nbia_base": NBIA_BASE,
        "roi": args.roi,
        "n_per_site": args.n_per_site,
        "sites": selected,
        "selected_features": list(SELECTED_FEATURES),
        "profile": str(profile_path),
        "central_features": str(central_features) if central_features else None,
        "failures": failures,
    }
    with open(workdir / "study_manifest.json", "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)

    print("")
    print(f"Prepared study at {workdir}")
    for site, ids in selected.items():
        print(f"  {site}: {len(ids)} patients ({ids[0]} ... {ids[-1]})")
    if central_features:
        print(f"  central baseline: {central_features}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workdir", default="/tmp/dsimaging_lung1_study")
    parser.add_argument("--n-per-site", type=int, default=12)
    parser.add_argument("--roi", default="GTV-1")
    parser.add_argument("--profile", default=str(default_profile_path()))
    parser.add_argument("--skip-central", action="store_true")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def default_profile_path() -> Path:
    env_profile = os.environ.get("DSIMAGING_AERTS_PROFILE", "")
    if env_profile:
        return Path(env_profile)
    here = Path(__file__).resolve()
    candidates = []
    for parent in here.parents:
        candidates.append(parent / "dsImaging/inst/profiles/aerts_signature_v1.yaml")
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return here.parents[0] / "aerts_signature_v1.yaml"


def load_clinical(workdir: Path) -> pd.DataFrame:
    path = workdir / "Lung1.clinical.csv"
    if not path.exists():
        download_file(CLINICAL_URL, path)
    df = pd.read_csv(path)
    clean = pd.DataFrame({
        "sample_id": df["PatientID"].astype(str),
        "patient_id": df["PatientID"].astype(str),
        "age": pd.to_numeric(df["age"], errors="coerce"),
        "clinical_t_stage": pd.to_numeric(df["clinical.T.Stage"], errors="coerce"),
        "clinical_n_stage": pd.to_numeric(df["Clinical.N.Stage"], errors="coerce"),
        "clinical_m_stage": pd.to_numeric(df["Clinical.M.Stage"], errors="coerce"),
        "overall_stage": df["Overall.Stage"].astype(str),
        "histology": df["Histology"].astype(str),
        "gender": df["gender"].astype(str),
        "gender_male": (df["gender"].astype(str).str.lower() == "male").astype(int),
        "survival_time_days": pd.to_numeric(df["Survival.time"], errors="coerce"),
        "deadstatus_event": pd.to_numeric(df["deadstatus.event"], errors="coerce"),
    })
    clean["os_2yr_alive"] = np.where(
        clean["survival_time_days"] >= 730,
        1,
        np.where(clean["deadstatus_event"] == 1, 0, np.nan),
    )
    return clean


def fetch_patients() -> list[str]:
    response = requests.get(
        f"{NBIA_BASE}/getPatient",
        params={"Collection": COLLECTION},
        timeout=60,
    )
    response.raise_for_status()
    return [row["PatientId"] for row in response.json()]


def stable_site_index(patient_id: str, n_sites: int) -> int:
    digest = hashlib.sha256(patient_id.encode("utf-8")).hexdigest()
    return int(digest, 16) % n_sites


def prepare_patient(patient_id: str, raw_dir: Path, image_dir: Path,
                    mask_dir: Path, roi_name: str, force: bool) -> tuple[Path, Path]:
    image_path = image_dir / f"{patient_id}.nii.gz"
    mask_path = mask_dir / f"{patient_id}_{roi_name}.nii.gz"
    if image_path.exists() and mask_path.exists() and not force:
        return image_path, mask_path

    series = fetch_series(patient_id)
    ct_series = choose_series(series, "CT")
    rt_series = choose_series(series, "RTSTRUCT")

    patient_raw = raw_dir / patient_id
    ct_dir = patient_raw / "CT"
    rt_dir = patient_raw / "RTSTRUCT"
    download_series(ct_series["SeriesInstanceUID"], ct_dir)
    download_series(rt_series["SeriesInstanceUID"], rt_dir)

    rt_path = find_rtstruct(rt_dir)
    write_ct_nifti_and_mask(ct_dir, rt_path, image_path, mask_path, roi_name)
    return image_path, mask_path


def fetch_series(patient_id: str) -> list[dict]:
    response = requests.get(
        f"{NBIA_BASE}/getSeries",
        params={"Collection": COLLECTION, "PatientID": patient_id},
        timeout=60,
    )
    response.raise_for_status()
    return response.json()


def choose_series(series: list[dict], modality: str) -> dict:
    matches = [row for row in series if row.get("Modality") == modality]
    if not matches:
        raise ValueError(f"No {modality} series")
    return max(matches, key=lambda row: int(row.get("ImageCount", 0)))


def download_series(series_uid: str, dest_dir: Path) -> None:
    dcm_files = list(dest_dir.glob("*.dcm"))
    if dcm_files:
        return
    if dest_dir.exists():
        shutil.rmtree(dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)
    zip_path = dest_dir.with_suffix(".zip")
    response = requests.get(
        f"{NBIA_BASE}/getImage",
        params={"SeriesInstanceUID": series_uid},
        timeout=600,
    )
    response.raise_for_status()
    zip_path.write_bytes(response.content)
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(dest_dir)


def find_rtstruct(rt_dir: Path) -> Path:
    import pydicom

    for path in sorted(rt_dir.glob("*.dcm")):
        ds = pydicom.dcmread(str(path), stop_before_pixels=True)
        if getattr(ds, "Modality", "") == "RTSTRUCT":
            return path
    raise ValueError("RTSTRUCT DICOM not found")


def write_ct_nifti_and_mask(ct_dir: Path, rt_path: Path, image_path: Path,
                            mask_path: Path, roi_name: str) -> None:
    reader = sitk.ImageSeriesReader()
    files = reader.GetGDCMSeriesFileNames(str(ct_dir))
    if not files:
        raise ValueError("No readable CT DICOM series")
    reader.SetFileNames(files)
    image = reader.Execute()
    image_path.parent.mkdir(parents=True, exist_ok=True)
    sitk.WriteImage(image, str(image_path))

    rtstruct = RTStructBuilder.create_from(
        dicom_series_path=str(ct_dir),
        rt_struct_path=str(rt_path),
    )
    roi_names = rtstruct.get_roi_names()
    if roi_name not in roi_names:
        raise ValueError(f"ROI {roi_name!r} not found; available: {roi_names}")
    mask = rtstruct.get_roi_mask_by_name(roi_name)
    if int(mask.sum()) <= 0:
        raise ValueError(f"ROI {roi_name!r} mask is empty")
    mask_array = np.transpose(mask.astype(np.uint8), (2, 0, 1))
    mask_image = sitk.GetImageFromArray(mask_array)
    mask_image.CopyInformation(image)
    mask_path.parent.mkdir(parents=True, exist_ok=True)
    sitk.WriteImage(mask_image, str(mask_path))


def write_site_folders(workdir: Path, selected: dict[str, list[str]],
                       clinical: pd.DataFrame, image_dir: Path,
                       mask_dir: Path, roi_name: str) -> None:
    clinical_by_id = clinical.set_index("sample_id", drop=False)
    for site, patient_ids in selected.items():
        site_dir = workdir / "sites" / site
        images = site_dir / "images"
        masks = site_dir / "masks"
        if site_dir.exists():
            shutil.rmtree(site_dir)
        images.mkdir(parents=True)
        masks.mkdir(parents=True)
        for patient_id in patient_ids:
            shutil.copy2(image_dir / f"{patient_id}.nii.gz", images / f"{patient_id}.nii.gz")
            shutil.copy2(
                mask_dir / f"{patient_id}_{roi_name}.nii.gz",
                masks / f"{patient_id}_{roi_name}.nii.gz",
            )
        metadata = clinical_by_id.loc[patient_ids].copy()
        metadata["site"] = site
        metadata.to_csv(site_dir / "metadata.csv", index=False)


def run_central_radiomics(selected: dict[str, list[str]], image_dir: Path,
                          mask_dir: Path, profile_path: Path,
                          roi_name: str,
                          skip: bool) -> Path | None:
    if skip:
        return None
    extractor = featureextractor.RadiomicsFeatureExtractor(str(profile_path))
    rows = []
    for site, patient_ids in selected.items():
        for patient_id in patient_ids:
            print(f"[central] extracting {patient_id}")
            result = extractor.execute(
                str(image_dir / f"{patient_id}.nii.gz"),
                str(mask_dir / f"{patient_id}_{roi_name}.nii.gz"),
            )
            row = {"sample_id": patient_id, "site": site}
            for feature in SELECTED_FEATURES:
                if feature not in result:
                    raise ValueError(f"Feature missing for {patient_id}: {feature}")
                row[feature] = float(result[feature])
            rows.append(row)

    out_dir = image_dir.parents[1] / "central"
    out_dir.mkdir(parents=True, exist_ok=True)
    df = pd.DataFrame(rows)
    parquet_path = out_dir / "aerts_features.parquet"
    csv_path = out_dir / "aerts_features.csv"
    df.to_parquet(parquet_path, index=False)
    df.to_csv(csv_path, index=False)
    return parquet_path


def download_file(url: str, dest: Path) -> None:
    response = requests.get(url, timeout=120)
    response.raise_for_status()
    dest.write_bytes(response.content)


if __name__ == "__main__":
    raise SystemExit(main())
