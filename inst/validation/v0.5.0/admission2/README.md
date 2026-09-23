# dsImagingClient 0.5.0 SEG and labelled-dose admission receipt

Task: `DSIMAGING_RAISE2_2026-09-23`. Recorded 2026-09-23.

The tested source commit is `764a0ad274c7c7f0e3e6486f49c3262228b43ce9`
on `feat/admit-rt-wsi-monai`. The full suite, source-package build and package
check used a detached checkout at `.validation/admission2/checkout` of that
exact commit. Captured `git status --porcelain` was empty before and after
validation; `status-before.txt` and `status-after.txt` are both empty files.
`commit.txt` records the checked-out source. This receipt is added later and
does not claim that a commit contains its own hash. Version remains 0.5.0.

## Results

The complete local test suite passed **75 test cases and 479 expectations**,
with **0 failed expectations, 0 errors, 0 warnings and 0 skips**.
`R CMD build` succeeded. `R CMD check --no-multiarch` reported **Status: OK**,
with **0 errors, 0 warnings and 0 notes**. The independent installed-package
test run reported **479 passes, 0 failures, 0 warnings and 0 skips**.
The repeated test runs are not added together.

- `results.csv`: this client's results and exact tested source commit.
- `test-cases.csv`: local testthat case counts, outcomes and timings.
- `test-suite.txt`, `build.txt`, `check.txt`, `check-tests.txt`: captured logs.
- `environment.txt`: shared validation R/Python and dependency versions.
- `run-suite.R`: exact local test runner, unchanged from the earlier receipt.
- `commit.txt`, `status-before.txt`, `status-after.txt`: checkout evidence.

Text log copies normalize line endings and trailing whitespace only.
Earlier admission receipts and results remain unchanged in the parent directory.

## Commands and environment

These commands ran from
`/Users/david/Documents/GitHub/dsimaging-fix/dsImagingClient/.validation/admission2`:

```sh
set -e
. /Users/david/Documents/GitHub/dsimaging-fix/dsImaging/.validation/env.sh
git -C checkout status --porcelain > logs/status-before.txt
git -C checkout rev-parse HEAD > logs/commit.txt
Rscript checkout/inst/validation/v0.5.0/run-suite.R dsImagingClient "$PWD/checkout" logs/test-cases.csv > logs/test-suite.txt 2>&1
R CMD build checkout > logs/build.txt 2>&1
R CMD check --no-multiarch dsImagingClient_0.5.0.tar.gz > logs/check.txt 2>&1
git -C checkout status --porcelain > logs/status-after.txt
```

R was 4.5.2 (2025-10-31), platform `aarch64-apple-darwin20`, running on macOS
15.4.1. The shared environment set `R_LIBS_USER`, `TMPDIR`, `DSHPC_HOME`,
`DSIMAGING_HOME` and `DSIMAGING_ASSET_DB` within the server clone's
`.validation` directory. `DSHPC_DISABLE_AUTOSTART=1` and
`PYTHONDONTWRITEBYTECODE=1` were set, and the local Python environment was
first on `PATH`. Dependency versions are captured in `environment.txt`.

## Scope

Client tests verify DICOM SEG segment selection, mutually exclusive selection
options, bounded public dose ROI schemas, paired mask assets and voxel labels,
ambiguous-input refusals, transport through the imaging domain ASSIGN method,
private table assignment and suppression of remote diagnostic content.
The new requests preserve repeated mask names or values when their pairs are
different, and retain the legacy request shape when no public ROI schema is
supplied. The full suite also checks the existing client workflows.

Client tests mock DSI transport and do not claim live server or remote HPC
execution. Synthetic image decoding and exact patient/source association
tests belong to the separate server receipt. Client vignettes render their
bundled static evidence; this validation does not rerun the historical LUNG1
study or establish clinical accuracy.
