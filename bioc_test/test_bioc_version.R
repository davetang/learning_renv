#!/usr/bin/env Rscript
# Test whether renv can install an older PATCH version of a Bioconductor
# package — i.e. a version that once shipped in the *same* Bioc release we're
# pinned to, but has since been superseded.
#
# Why patch-level? An earlier run of this script asked for 4.16.0 (Bioc 3.21)
# and 4.20.0 ("release", = Bioc 3.23 devel) — both *cross-release* requests
# that don't really test version pinning, they test cross-release routing.
# To prove version pinning works *within* a single Bioc release, every target
# below is a patch of 4.18.x that once shipped in Bioc 3.22 before being
# replaced by 4.18.4 (the current patch).
#
# Bioc 3.22 Archive contents (as of 2026-05) — confirmed via
# https://mghp.osn.xsede.org/bir190004-bucket01/?prefix=archive.bioconductor.org/packages/3.22/bioc/src/contrib/Archive/clusterProfiler/
#   - clusterProfiler_4.18.0.tar.gz
#   - clusterProfiler_4.18.1.tar.gz
#   - clusterProfiler_4.18.2.tar.gz
#   - clusterProfiler_4.18.3.tar.gz
# (4.18.4 is "current" and lives at .../src/contrib/, not Archive/.)
#
# What we test:
#   1. bioc::clusterProfiler           — latest in Bioc 3.22 (sanity)
#   2. bioc::clusterProfiler@4.18.4    — pin to the current patch (trivial)
#   3. bioc::clusterProfiler@4.18.2    — pin to an archived patch (real test)
#   4. bioc::clusterProfiler@4.18.0    — pin to the earliest archived patch
#   5. direct tarball URL from Archive/ — a manual fallback if renv refuses
#
# Watch the `Installed clusterProfiler version:` line after each step. If
# steps 3 and 4 actually downgrade the installed version to 4.18.2 and 4.18.0
# respectively, renv consults Bioc's Archive/ and `bioc::pkg@version` is real
# version pinning. If they 404, renv only reaches the current patch and the
# @version suffix is decorative.

# Print a visible section banner to stdout/log so each test step is easy to find.
log_step <- function(msg) {
  # cat() with sep="" assembles the banner without inserting spaces between parts.
  cat("\n==== ", msg, " ====\n", sep = "")
}

# Wrap renv::install() so a failure (e.g. 404 download) is caught and logged
# instead of aborting the whole script — we want every step to run.
try_install <- function(spec) {
  # Echo the exact install spec being attempted so the log is self-describing.
  log_step(paste("renv::install('", spec, "')", sep = ""))
  # tryCatch returns the error object on failure, or whatever install() returned on success.
  res <- tryCatch(
    # prompt = FALSE keeps the call non-interactive so it works under Rscript.
    renv::install(spec, prompt = FALSE),
    # Capture the condition rather than letting it propagate.
    error = function(e) e
  )
  # Branch on whether we caught an error condition or a normal return value.
  if (inherits(res, "error")) {
    # Surface just the human-readable message; the full trace is in renv's own output above.
    cat("FAILED: ", conditionMessage(res), "\n", sep = "")
  } else {
    # Mark success explicitly so a quick scan of the log shows pass/fail per step.
    cat("OK\n")
  }
  # Return res invisibly — the caller doesn't use it, but this keeps the function composable.
  invisible(res)
}

# Print the currently-installed version of `pkg`, or NA if it isn't installed.
show_version <- function(pkg) {
  # utils::packageVersion() errors when the package isn't on the library path; we don't want that to halt the script.
  v <- tryCatch(
    # Coerce the package_version object to a plain character for stable printing.
    as.character(utils::packageVersion(pkg)),
    # On error (package not installed), report NA rather than crashing.
    error = function(e) NA_character_
  )
  # One-line summary, easy to grep for after the run ("Installed clusterProfiler version: 4.18.2").
  cat("Installed ", pkg, " version: ", v, "\n", sep = "")
}

# Make sure renv itself is available before we use it; install from CRAN if missing.
if (!requireNamespace("renv", quietly = TRUE)) {
  # Cloud CRAN mirror works without needing the user to pick a mirror interactively.
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# Announce the init step in the log.
log_step("Initialising isolated renv project tied to Bioconductor 3.22")
# bioconductor = "3.22" wires BiocManager's repo URLs for that release into the project.
# bare = TRUE skips the dependency discovery/snapshot step so we start with an empty library.
# restart = FALSE keeps the current Rscript session — restarting would kill the script.
renv::init(bioconductor = "3.22", bare = TRUE, restart = FALSE)

# Package under test — clusterProfiler has multiple archived patches in Bioc 3.22, perfect for this experiment.
target_pkg      <- "clusterProfiler"
# Current patch in Bioc 3.22 — used as the "trivial" version-pin sanity check.
version_current <- "4.18.4"
# A middle archived patch — should require renv to fetch from .../Archive/ rather than the live repo.
version_mid     <- "4.18.2"
# The earliest archived patch in Bioc 3.22 — same archive path, oldest target.
version_first   <- "4.18.0"

# Step 1: install latest from Bioconductor with no version pin — establishes the default behaviour.
try_install(paste0("bioc::", target_pkg))
# Confirm what actually landed in the library after step 1 (expected: 4.18.4).
show_version(target_pkg)

# Step 2: explicitly pin to the current patch — should be a cache hit and no-op.
try_install(paste0("bioc::", target_pkg, "@", version_current))
# Expected: still 4.18.4. Proves the @version syntax at least parses without breaking the existing install.
show_version(target_pkg)

# Step 3: the real test — ask for an older patch that lives only in Archive/.
try_install(paste0("bioc::", target_pkg, "@", version_mid))
# Expected: 4.18.2. If we see this, renv genuinely consults Bioc's Archive/.
show_version(target_pkg)

# Step 4: same idea, but for the earliest archived patch — guards against "maybe it only finds the most recent archive entry".
try_install(paste0("bioc::", target_pkg, "@", version_first))
# Expected: 4.18.0.
show_version(target_pkg)

# Manual fallback: install directly from the Archive tarball URL. This bypasses
# renv's bioc-resolver and proves the file itself is reachable — useful as a
# baseline if the bioc::pkg@version path fails.
# Build the canonical Archive URL via sprintf so the pkg name appears once and version once.
archive_url <- sprintf(
  "https://bioconductor.org/packages/3.22/bioc/src/contrib/Archive/%s/%s_%s.tar.gz",
  target_pkg, target_pkg, version_first
)
# Banner for the manual-URL step so it's distinguishable from the bioc:: steps above.
log_step(paste0("renv::install('", archive_url, "') [direct tarball fallback]"))
# renv::install() also accepts a bare URL and treats it as a remote tarball.
try_install(archive_url)
# Expected: 4.18.0 (same as step 4, reached via a different route).
show_version(target_pkg)

# Print the renv project status at the end for completeness. With bare = TRUE
# and no snapshot, both library and lockfile will read as empty — that's expected.
log_step("renv::status()")
print(renv::status())

# Closing banner so the end of the run is unambiguous in long logs.
log_step("Done")
