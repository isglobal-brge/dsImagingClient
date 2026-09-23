# dsImagingClient 0.6.0 model bundle validation

Task: `DSIMAGING_MODELS_2026-09-23`. Recorded 2026-09-23.

Tested source: `7df0e011b12f9a8daa13bd3805ed6473305aa126` on
`feat/model-bundles`, descended from v0.5.0 (`3be41ff`). The complete suite,
source-package build and package check ran in the clean detached checkout
`.validation/models/checkout`. `status-before.txt` and `status-after.txt`
are empty. These receipts are added in a subsequent commit; a receipt does
not claim its commit contains its own hash.

The complete suite passed **78 test cases and 493 expectations**, with
**0 failures, 0 errors, 0 warnings and 0 skips**. `R CMD build` succeeded.
`R CMD check --no-multiarch` returned **Status: OK**, with **0 errors,
0 warnings and 0 notes**. Its installed-package suite independently reported
493 passes, 0 failures, 0 warnings and 0 skips. Repeated runs are not summed.

## Evidence

- `results.csv` records source identity and totals.
- `test-cases.csv` records each local test case and its outcomes.
- `test-suite.txt`, `build.txt`, `check.txt`, `check-tests.txt` contain logs.
- `commit.txt`, `status-before.txt`, `status-after.txt` prove checkout identity.
- `run-suite.R` is the exact suite runner, copied unchanged from v0.5.0.
- `environment.txt` records R, platform and dependency versions.

Log copies normalize line endings and trailing whitespace only. Existing
validation receipts are unchanged.

## Commands

From `dsImagingClient/.validation/models`, after creating the detached checkout:

```sh
set -e
. /Users/david/Documents/GitHub/dsimaging-fix/dsImaging/.validation/env.sh
git -C checkout status --porcelain > logs/status-before.txt
git -C checkout rev-parse HEAD > logs/commit.txt
Rscript checkout/inst/validation/v0.5.0/run-suite.R dsImagingClient "$PWD/checkout" logs/test-cases.csv > logs/test-suite.txt 2>&1
R CMD build checkout > logs/build.txt 2>&1
R CMD check --no-multiarch dsImagingClient_0.6.0.tar.gz > logs/check.txt 2>&1
git -C checkout status --porcelain > logs/status-after.txt
```

The shared environment points `R_LIBS_USER`, `TMPDIR`, `DSHPC_HOME`,
`DSIMAGING_HOME`, `DSIMAGING_ASSET_DB` and Python's `PATH` into the server
clone's `.validation` area. It sets `DSHPC_DISABLE_AUTOSTART=1` and
`PYTHONDONTWRITEBYTECODE=1`.

## Scope

The added tests cover public bundle identity/readiness passthrough, manifest
digest reporting after authenticated administrator installation, encoded admin
key transport, and path-free learned-provider selectors. Existing workflow
and disclosure tests also pass. Client tests mock DSI transport; these receipts
do not claim live server/HPC execution or clinical accuracy. Server receipts
cover synthetic bundle installation and actual runner processes with fake
providers. Vignettes render existing static study evidence and do not rerun
historical model experiments.
