#!/usr/bin/env python3
"""Prepare a reproducible LUNG1/NSCLC-Radiomics federated study.

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

    if args.dry_run:
        planned = plan_patient_split(clinical["sample_id"].sort_values(), args)
        print_plan(planned, label="Planned split")
        return 0

    selected: dict[str, list[str]] = {site: [] for site in SITE_NAMES}
    failures: dict[str, str] = {}

    for patient_id in clinical["sample_id"].sort_values():
        site = SITE_NAMES[stable_site_index(patient_id, len(SITE_NAMES))]
        if not args.all_patients and len(selected[site]) >= args.n_per_site:
            continue
        try:
            image_path, mask_path = prepare_patient(
                patient_id=patient_id,
                raw_dir=raw_dir,
                image_dir=nifti_images,
                mask_dir=nifti_masks,
                roi_name=args.roi,
                force=args.force,
                keep_raw=args.keep_raw,
            )
            if image_path.exists() and mask_path.exists():
                selected[site].append(patient_id)
                print(f"[ok] {patient_id} -> {site}")
        except Exception as exc:  # noqa: BLE001 - keep going through public data quirks.
            failures[patient_id] = str(exc)
            print(f"[skip] {patient_id}: {exc}", file=sys.stderr)

        if (not args.all_patients and
                all(len(ids) >= args.n_per_site for ids in selected.values())):
            break

    if args.all_patients:
        if failures:
            print(
                f"WARNING: {len(failures)} patient(s) could not be prepared; "
                "study uses the successfully converted cases.",
                file=sys.stderr,
            )
    else:
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
    parser.add_argument(
        "--n-per-site",
        type=int,
        default=12,
        help="Balanced validation cohort size per site when --all-patients is not set",
    )
    parser.add_argument(
        "--all-patients",
        action="store_true",
        help="Prepare every available LUNG1 patient instead of a balanced validation cohort",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Resolve the patient split and exit without downloading DICOM data",
    )
    parser.add_argument("--roi", default="GTV-1")
    parser.add_argument("--profile", default=str(default_profile_path()))
    parser.add_argument("--skip-central", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--keep-raw",
        action="store_true",
        help="Keep downloaded DICOM/zip files after NIfTI and mask conversion",
    )
    return parser.parse_args()


def plan_patient_split(patient_ids, args) -> dict[str, list[str]]:
    selected: dict[str, list[str]] = {site: [] for site in SITE_NAMES}
    for patient_id in patient_ids:
        site = SITE_NAMES[stable_site_index(str(patient_id), len(SITE_NAMES))]
        if args.all_patients or len(selected[site]) < args.n_per_site:
            selected[site].append(str(patient_id))
        if (not args.all_patients and
                all(len(ids) >= args.n_per_site for ids in selected.values())):
            break
    return selected


def print_plan(selected: dict[str, list[str]], label: str) -> None:
    print(label)
    for site, patient_ids in selected.items():
        if patient_ids:
            print(
                f"  {site}: {len(patient_ids)} patients "
                f"({patient_ids[0]} ... {patient_ids[-1]})"
            )
        else:
            print(f"  {site}: 0 patients")


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
                    mask_dir: Path, roi_name: str, force: bool,
                    keep_raw: bool) -> tuple[Path, Path]:
    image_path = image_dir / f"{patient_id}.nii.gz"
    mask_path = mask_dir / f"{patient_id}_{roi_name}.nii.gz"
    if image_path.exists() and mask_path.exists() and not force:
        return image_path, mask_path

    patient_raw = raw_dir / patient_id
    ct_dir = patient_raw / "CT"
    rt_dir = patient_raw / "RTSTRUCT"
    seg_dir = patient_raw / "SEG"

    try:
        series = fetch_series(patient_id)
        rt_series = choose_series(series, "RTSTRUCT")
        seg_series = choose_optional_series(series, "SEG")
        download_series(rt_series["SeriesInstanceUID"], rt_dir)
        rt_path = find_rtstruct(rt_dir)

        ct_series = choose_ct_series(series, rt_path)
        download_series(ct_series["SeriesInstanceUID"], ct_dir)
        try:
            write_ct_nifti_and_mask(ct_dir, rt_path, image_path, mask_path, roi_name)
        except Exception:
            if seg_series is None:
                raise
            image_path.unlink(missing_ok=True)
            mask_path.unlink(missing_ok=True)
            download_series(seg_series["SeriesInstanceUID"], seg_dir)
            seg_path = find_dicom_modality(seg_dir, "SEG")
            ct_series = choose_ct_series(series, seg_path)
            download_series(ct_series["SeriesInstanceUID"], ct_dir)
            write_ct_nifti_and_seg_mask(ct_dir, seg_path, image_path,
                                        mask_path, roi_name)
    except Exception:
        image_path.unlink(missing_ok=True)
        mask_path.unlink(missing_ok=True)
        raise
    finally:
        if not keep_raw:
            shutil.rmtree(patient_raw, ignore_errors=True)
            for zip_path in (patient_raw / "CT.zip", patient_raw / "RTSTRUCT.zip"):
                zip_path.unlink(missing_ok=True)
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


def choose_optional_series(series: list[dict], modality: str) -> dict | None:
    matches = [row for row in series if row.get("Modality") == modality]
    if not matches:
        return None
    return max(matches, key=lambda row: int(row.get("ImageCount", 0)))


def choose_ct_series(series: list[dict], rt_path: Path) -> dict:
    matches = [row for row in series if row.get("Modality") == "CT"]
    if not matches:
        raise ValueError("No CT series")

    referenced_uids = referenced_series_uids(rt_path)
    if referenced_uids:
        referenced_matches = [
            row for row in matches
            if row.get("SeriesInstanceUID") in referenced_uids
        ]
        if referenced_matches:
            return max(
                referenced_matches,
                key=lambda row: int(row.get("ImageCount", 0)),
            )

    return max(matches, key=lambda row: int(row.get("ImageCount", 0)))


def referenced_series_uids(reference_path: Path) -> set[str]:
    import pydicom

    ds = pydicom.dcmread(str(reference_path), stop_before_pixels=True)
    uids: set[str] = set()

    for ref_series in getattr(ds, "ReferencedSeriesSequence", []):
        uid = getattr(ref_series, "SeriesInstanceUID", None)
        if uid:
            uids.add(str(uid))

    for ref_frame in getattr(ds, "ReferencedFrameOfReferenceSequence", []):
        for ref_study in getattr(ref_frame, "RTReferencedStudySequence", []):
            for ref_series in getattr(ref_study, "RTReferencedSeriesSequence", []):
                uid = getattr(ref_series, "SeriesInstanceUID", None)
                if uid:
                    uids.add(str(uid))
    return uids


def download_series(series_uid: str, dest_dir: Path) -> None:
    dcm_files = list(dest_dir.glob("*.dcm"))
    if dcm_files and dicom_dir_matches_series(dest_dir, series_uid):
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


def dicom_dir_matches_series(dest_dir: Path, series_uid: str) -> bool:
    import pydicom

    for path in sorted(dest_dir.glob("*.dcm")):
        try:
            ds = pydicom.dcmread(str(path), stop_before_pixels=True)
        except Exception:  # noqa: BLE001 - stale or partial cache, redownload it.
            return False
        uid = getattr(ds, "SeriesInstanceUID", None)
        if uid:
            return str(uid) == str(series_uid)
    return False


def find_rtstruct(rt_dir: Path) -> Path:
    return find_dicom_modality(rt_dir, "RTSTRUCT")


def find_dicom_modality(dicom_dir: Path, modality: str) -> Path:
    import pydicom

    for path in sorted(dicom_dir.glob("*.dcm")):
        ds = pydicom.dcmread(str(path), stop_before_pixels=True)
        if getattr(ds, "Modality", "") == modality:
            return path
    raise ValueError(f"{modality} DICOM not found")


def write_ct_nifti_and_mask(ct_dir: Path, rt_path: Path, image_path: Path,
                            mask_path: Path, roi_name: str) -> None:
    image, _ = read_ct_image_and_uid_index(ct_dir)

    rtstruct = RTStructBuilder.create_from(
        dicom_series_path=str(ct_dir),
        rt_struct_path=str(rt_path),
    )
    roi_names = rtstruct.get_roi_names()
    mask = best_rtstruct_mask(rtstruct, roi_names, roi_name)
    mask_array = np.transpose(mask.astype(np.uint8), (2, 0, 1))
    mask_image = sitk.GetImageFromArray(mask_array)
    mask_image.CopyInformation(image)
    image_path.parent.mkdir(parents=True, exist_ok=True)
    mask_path.parent.mkdir(parents=True, exist_ok=True)
    sitk.WriteImage(image, str(image_path))
    sitk.WriteImage(mask_image, str(mask_path))


def best_rtstruct_mask(rtstruct, roi_names: list[str], roi_name: str):
    candidates = candidate_roi_names(roi_names, roi_name)
    best_mask = None
    best_name = None
    best_voxels = 0
    for candidate in candidates:
        mask = rtstruct.get_roi_mask_by_name(candidate)
        voxels = int(mask.sum())
        if voxels > best_voxels:
            best_mask = mask
            best_name = candidate
            best_voxels = voxels
    if best_mask is None or best_voxels <= 0:
        raise ValueError(
            f"ROI {roi_name!r} candidates are empty; "
            f"available: {roi_names}"
        )
    if best_name != roi_name:
        print(f"  ROI fallback: {roi_name!r} -> {best_name!r}")
    return best_mask


def write_ct_nifti_and_seg_mask(ct_dir: Path, seg_path: Path, image_path: Path,
                                mask_path: Path, roi_name: str) -> None:
    import pydicom

    image, uid_to_z = read_ct_image_and_uid_index(ct_dir)
    reference_array = sitk.GetArrayFromImage(image)
    mask_array = np.zeros(reference_array.shape, dtype=np.uint8)

    ds = pydicom.dcmread(str(seg_path), stop_before_pixels=False)
    segment_number = find_segment_number(ds, roi_name)
    pixels = ds.pixel_array
    if pixels.ndim == 2:
        pixels = pixels[np.newaxis, :, :]
    if pixels.shape[1:] != mask_array.shape[1:]:
        raise ValueError(
            "DICOM SEG frame size does not match CT image plane: "
            f"{pixels.shape[1:]} vs {mask_array.shape[1:]}"
        )

    for frame_index, frame in enumerate(getattr(ds, "PerFrameFunctionalGroupsSequence", [])):
        if frame_segment_number(frame) != segment_number:
            continue
        source_uid = frame_source_sop_instance_uid(frame)
        if not source_uid or source_uid not in uid_to_z:
            continue
        z_index = uid_to_z[source_uid]
        mask_array[z_index] = np.logical_or(
            mask_array[z_index],
            pixels[frame_index].astype(bool),
        ).astype(np.uint8)

    if int(mask_array.sum()) <= 0:
        raise ValueError(f"SEG segment for ROI {roi_name!r} is empty or unmapped")

    mask_image = sitk.GetImageFromArray(mask_array)
    mask_image.CopyInformation(image)
    image_path.parent.mkdir(parents=True, exist_ok=True)
    mask_path.parent.mkdir(parents=True, exist_ok=True)
    sitk.WriteImage(image, str(image_path))
    sitk.WriteImage(mask_image, str(mask_path))


def read_ct_image_and_uid_index(ct_dir: Path) -> tuple[sitk.Image, dict[str, int]]:
    import pydicom

    reader = sitk.ImageSeriesReader()
    files = reader.GetGDCMSeriesFileNames(str(ct_dir))
    if not files:
        raise ValueError("No readable CT DICOM series")
    reader.SetFileNames(files)
    image = reader.Execute()

    uid_to_z: dict[str, int] = {}
    for z_index, path in enumerate(files):
        ds = pydicom.dcmread(str(path), stop_before_pixels=True)
        sop_uid = getattr(ds, "SOPInstanceUID", None)
        if sop_uid:
            uid_to_z[str(sop_uid)] = z_index
    return image, uid_to_z


def find_segment_number(ds, roi_name: str) -> int:
    candidates = []
    target = normalize_roi_name(roi_name)
    for segment in getattr(ds, "SegmentSequence", []):
        number = int(getattr(segment, "SegmentNumber"))
        labels = [
            str(getattr(segment, "SegmentLabel", "")),
            str(getattr(segment, "SegmentDescription", "")),
        ]
        for label in labels:
            if normalize_roi_name(label) == target:
                return number
        candidates.append(f"{number}:{'/'.join(label for label in labels if label)}")

    for segment in getattr(ds, "SegmentSequence", []):
        number = int(getattr(segment, "SegmentNumber"))
        labels = [
            str(getattr(segment, "SegmentLabel", "")),
            str(getattr(segment, "SegmentDescription", "")),
        ]
        if any(is_roi_alias(label, target) for label in labels):
            return number

    raise ValueError(f"SEG ROI {roi_name!r} not found; available: {candidates}")


def candidate_roi_names(roi_names: list[str], roi_name: str) -> list[str]:
    target = normalize_roi_name(roi_name)
    exact = [name for name in roi_names if name == roi_name]
    if exact:
        return exact

    normalized = [name for name in roi_names if normalize_roi_name(name) == target]
    if normalized:
        return normalized

    aliases = [name for name in roi_names if is_roi_alias(name, target)]
    if aliases:
        return aliases

    raise ValueError(f"ROI {roi_name!r} not found; available: {roi_names}")


def is_roi_alias(value: str, normalized_target: str) -> bool:
    normalized_value = normalize_roi_name(value)
    if not normalized_value:
        return False
    if normalized_target in normalized_value:
        return True
    if normalized_target.startswith("gtv"):
        return ("gtv" in normalized_value or
                "gross" in normalized_value or
                "neoplasmprimary" in normalized_value)
    return False


def normalize_roi_name(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


def frame_segment_number(frame) -> int | None:
    sequence = getattr(frame, "SegmentIdentificationSequence", [])
    if not sequence:
        return None
    number = getattr(sequence[0], "ReferencedSegmentNumber", None)
    return int(number) if number is not None else None


def frame_source_sop_instance_uid(frame) -> str | None:
    for derivation in getattr(frame, "DerivationImageSequence", []):
        for source in getattr(derivation, "SourceImageSequence", []):
            uid = getattr(source, "ReferencedSOPInstanceUID", None)
            if uid:
                return str(uid)
    return None


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
    out_dir = image_dir.parents[1] / "central"
    cache_dir = out_dir / "per_sample"
    cache_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for site, patient_ids in selected.items():
        for patient_id in patient_ids:
            cache_path = cache_dir / f"{patient_id}.json"
            if cache_path.exists():
                with open(cache_path, encoding="utf-8") as handle:
                    row = json.load(handle)
                row["site"] = site
            else:
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
                with open(cache_path, "w", encoding="utf-8") as handle:
                    json.dump(row, handle, indent=2, sort_keys=True)
            rows.append(row)

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
