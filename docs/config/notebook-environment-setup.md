# Local Notebook Environment Setup (Conda + Jupyter)

Purpose: this repo is documentation-only (see `CLAUDE.md`) but analysis work increasingly involves querying PROD/UAT and reviewing results exported as CSV into `tmp/` (gitignored). A local Jupyter notebook environment makes that analysis repeatable instead of one-off. This doc is written as a from-scratch setup guide — follow it top to bottom on a machine with no conda installed.

## 1. Check whether conda is already installed

Before installing anything, check for an existing conda install — a machine can easily end up with two redundant ones (Miniconda vs. Miniforge vs. Anaconda) if this step is skipped.

```powershell
Get-Command conda -ErrorAction SilentlyContinue
Get-ChildItem -Path $env:USERPROFILE -Directory -Filter "*conda*" -ErrorAction SilentlyContinue
& "$env:USERPROFILE\miniforge3\Scripts\conda.exe" info --envs   # if miniforge3 exists
& "$env:USERPROFILE\miniconda3\Scripts\conda.exe" info --envs   # if miniconda3 exists
```

`conda` often isn't on `PATH` even when installed, so check the common install directories directly (`~/miniconda3`, `~/miniforge3`, `~/anaconda3`, `C:\ProgramData\miniconda3`, `C:\ProgramData\Anaconda3`) rather than relying on `Get-Command` alone. If any of these exist, **reuse that install** — go to step 3.

## 2. Install conda (only if step 1 found nothing)

Using `winget` (already available on Windows 11):

```powershell
winget install -e --id Anaconda.Miniconda3 --accept-package-agreements --accept-source-agreements
```

This installs to `%USERPROFILE%\miniconda3`. If `winget uninstall -e --id Anaconda.Miniconda3` is ever needed, note that the uninstaller can leave the directory behind (long-path deletion errors on nested `site-packages`); `Remove-Item -Recurse -Force` against that path cleans it up even if PowerShell reports errors mid-run — `Test-Path` afterward to confirm it's actually gone.

## 3. Create a dedicated environment for this repo

Don't reuse an unrelated/ambiguously-named existing environment — create one scoped to this project:

```powershell
& "<conda-root>\Scripts\conda.exe" create -n cw-learning python=3.11 jupyter ipykernel pandas -y
```

Replace `<conda-root>` with wherever step 1/2 found conda (e.g. `$env:USERPROFILE\miniforge3` or `$env:USERPROFILE\miniconda3`). `pandas` is included because the primary use case is loading/analyzing the CSV query exports in `tmp/`; add other packages as needed later with `conda install -n cw-learning <package>`.

Verify it:

```powershell
& "<conda-root>\Scripts\conda.exe" run -n cw-learning python -c "import sys, pandas; print(sys.version); print(pandas.__version__)"
```

## 4. Register the environment as a Jupyter kernel

```powershell
& "<conda-root>\Scripts\conda.exe" run -n cw-learning python -m ipykernel install --user --name cw-learning --display-name "Python (cw-learning)"
```

This makes the env selectable by name in both VS Code and JupyterLab, independent of whichever env `jupyter` itself was launched from.

## 5. Notebook location and `.gitignore`

Notebooks live in `notebooks/` at the repo root. `.gitignore` already excludes `.ipynb_checkpoints/` (it's a full Python `.gitignore`), so no changes were needed there. As with everything else in this repo, **never commit real credentials, IPs, or query output containing sensitive data inside a notebook cell/output** — keep raw data loads pointed at gitignored paths (`tmp/`), and only commit notebooks whose saved outputs are safe to publish (or clear outputs before committing).

## 6. Running a notebook

**VS Code:** open a `.ipynb` file → kernel picker (top-right) → select **"Python (cw-learning)"**.

**CLI (no VS Code):**

```powershell
& "<conda-root>\Scripts\conda.exe" activate cw-learning
jupyter lab   # or: jupyter notebook
```

**Headless execution (e.g. to smoke-test the env, or run a notebook as a script):**

```powershell
& "<conda-root>\Scripts\conda.exe" run -n cw-learning jupyter nbconvert --to notebook --execute --inplace "notebooks\<name>.ipynb"
```

## What was actually done in this repo (2026-08-29)

- Found an existing `miniforge3` install with an unrelated empty env (`po_xuan`) — reused the install, did not create a redundant one.
- Initially installed a second, redundant Miniconda3 via `winget` before discovering `miniforge3`; uninstalled it and cleaned up the leftover directory once discovered.
- Created env `cw-learning` (Python 3.11, `jupyter`, `ipykernel`, `pandas`) under the existing `miniforge3` install.
- Registered it as Jupyter kernel `"Python (cw-learning)"`.
- Created `notebooks/smoke-test.ipynb` and executed it via `nbconvert --execute --inplace` to confirm the kernel runs end-to-end (Python version + pandas version + a rendered DataFrame all captured in the saved outputs).

## Related files

- `CLAUDE.md` — repo overview; still accurate that there's no build/lint/test tooling for the docs themselves, but this notebook environment now exists for ad-hoc data analysis of `tmp/` exports.
- `structure.md` — target folder layout; doesn't yet list `notebooks/` (add it here if the layout doc is revisited).
