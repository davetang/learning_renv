# Installing different versions of a Bioconductor package

Empirical check: can `renv::install()` pin a specific version of a **Bioconductor** package the way it can for a CRAN one?

**Short answer: yes.** Within the active Bioconductor release, the syntax `renv::install("bioc::Pkg@version")` works for both the current patch and archived earlier patches — renv consults `Archive/` after a transparent 404 retry on the live `src/contrib/` URL.

## Summary of findings

| Form | Works? | Notes |
|---|---|---|
| `bioc::Pkg` | ✅ | Resolves to latest patch in active Bioc release. |
| `bioc::Pkg@<current>` | ✅ | Trivial — same as plain `bioc::Pkg`, just cache hit. |
| `bioc::Pkg@<archived patch>` | ✅ | Downloads from `Archive/`; logs show one harmless `ERROR [error code 22]` before retry succeeds. |
| `bioc::Pkg@<version from other Bioc release>` | ❌ | 404. renv only searches the configured release's repo + Archive. |
| `bioc::release/Pkg` | ⚠️ | Downloads the latest in whatever BiocManager labels "release" (devel/3.23 in this env, giving 4.20.0). Build fails because the rest of the cached dep tree is pinned to 3.22 — API drift. Avoid unless you also switch the project's Bioc release. |
| Direct Archive tarball URL | ✅ | Always works as a manual fallback. |

What we proved by re-running with `clusterProfiler` 4.18.0 / 4.18.2 / 4.18.4 inside Bioc 3.22:

- `Installed clusterProfiler version:` genuinely moves 4.18.4 → 4.18.2 → 4.18.0.
- Each archived patch tarball was freshly downloaded (~613–617 KB), not a cache hit.
- The first attempt at each archived version 404s on the current `src/contrib/` path; renv automatically retries against `Archive/` and succeeds. So the `ERROR [error code 22]` line in the log is part of normal operation, not a failure.

## What the docs say vs what the source says

The published renv docs ([Using renv with Bioconductor](https://rstudio.github.io/renv/articles/bioconductor.html), [Install packages](https://rstudio.github.io/renv/reference/install.html)) show:

- `renv::install("bioc::Biobase")` — install latest from Bioconductor.
- `renv::install("digest@0.6.18")` — install a specific CRAN version.

They do **not** show `bioc::Pkg@version`. The renv source (`R/remotes.R`) does. The spec is first parsed as a generic "repository" remote; if the repository is `bioc` the type is flipped and dispatched to `renv_remotes_resolve_bioc()`. When a version is captured by the parser, it short-circuits to:

```r
renv_remotes_resolve_bioc_plain <- function(remote) {
  list(Package = remote$package, Version = remote$version, Source = "Bioconductor")
}
```

So the syntax is real. There's also a second form, `bioc::<release>/Pkg` (e.g. `bioc::3.18/Biobase`), handled by the same resolver via `BiocManager$.version_map()` — it pins to the *latest* patch inside a named Bioconductor release.

## Running the test

System dependencies first (`clusterProfiler` pulls in `systemfonts`, `gdtools`, etc.):

```sh
sudo apt install libcairo2-dev libfontconfig1-dev
```

Then from this directory:

```sh
make test    # Rscript test_bioc_version.R, tee output to test_bioc_version.log
make log     # reprint the last run's log
make clean   # remove the renv/ state and the log
```

Or, from an R session opened here:

```r
source("test_bioc_version.R")
```

The script:

1. Initialises an isolated renv project tied to Bioconductor 3.22.
2. Installs `clusterProfiler` four ways, all within Bioc 3.22:
   - `bioc::clusterProfiler` (current, 4.18.4),
   - `bioc::clusterProfiler@4.18.4` (current — sanity check),
   - `bioc::clusterProfiler@4.18.2` (archived patch),
   - `bioc::clusterProfiler@4.18.0` (earliest archived patch).
3. Installs 4.18.0 a second time directly from its Archive tarball URL as a manual fallback baseline.
4. Prints the installed version after each step and a final `renv::status()`.

## Practical guidance

- To pin to a **specific patch within the current Bioc release**, use `renv::install("bioc::Pkg@<version>")`. It works.
- To pin to a **version that lived in a different Bioc release**, don't try to cross over with `@version` — switch the project's Bioc release instead:
  ```r
  renv::init(bioconductor = "3.21", bare = TRUE)
  renv::install("bioc::clusterProfiler")   # gets 4.16.0
  ```
  This keeps the whole dep tree consistent with that release.
- Avoid `bioc::release/Pkg` unless you really mean "whatever Bioconductor currently calls release" *and* you control the dep tree. Mixing one release's package against another release's deps causes lazy-loading errors (we saw `object 'get_organism' is not exported by 'namespace:GOSemSim'` when 4.20.0 from 3.23 was dropped onto 3.22's `GOSemSim 2.36.0`).
- `renv::status()` reporting an empty library is expected here — the test uses `renv::init(bare = TRUE)` and never calls `renv::snapshot()`, so there's no lockfile to compare against.

## Project library vs cache

`renv/library/.../clusterProfiler/` only ever shows one version because an R library is flat — each package has exactly one installed copy, and `library(pkg)` has no version selector at load time. The library entry is a symlink into the global renv cache at `~/.cache/R/renv/cache/v5/.../clusterProfiler/<version>/<hash>/clusterProfiler`, and each `renv::install(...@<version>)` just re-points that symlink. All previously-installed versions (4.18.0, 4.18.2, 4.18.4) still live side-by-side in the cache; the project library only shows the most recently installed one (4.18.0 after our test). Different projects on the same machine can simultaneously link to different cached versions without duplicating anything on disk — that's renv's reproducibility model in one sentence.

## Bioc 3.22 Archive contents (as of 2026-05)

Verified via the OSN bucket index used by `archive.bioconductor.org`:

- `clusterProfiler_4.18.0.tar.gz`
- `clusterProfiler_4.18.1.tar.gz`
- `clusterProfiler_4.18.2.tar.gz`
- `clusterProfiler_4.18.3.tar.gz`

`clusterProfiler_4.18.4.tar.gz` is the current patch and lives at `.../src/contrib/clusterProfiler_4.18.4.tar.gz`, not under `Archive/`.

## Files in this directory

- `test_bioc_version.R` — the test script.
- `Makefile` — `make test` / `make log` / `make clean`.
- `test_bioc_version.log` — output of the last `make test` run.
- `renv/`, `.Rprofile` — created on first run; ignored by git.
