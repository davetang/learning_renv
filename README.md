# README

renv is an R package for dependency management that helps create reproducible R projects. It isolates project libraries so that each project has its own set of package versions, independent of other projects and the system library.

Each renv project has its own library stored in the `renv/library` directory. When you load R in a project with renv activated, R uses this project-specific library instead of the user or system library. This isolation means installing or updating packages in one project does not affect other projects. Without isolation, updating a package for one project could break another. renv eliminates this conflict by giving each project its own library.

## The Lockfile

The `renv.lock` file is a JSON file that records the exact versions of all packages used in your project, including:

* Package names and versions
* Package sources (CRAN, Bioconductor, GitHub, etc.)
* Repository URLs
* R version

This lockfile (theoretically) allows anyone to recreate your exact package environment. Sharing a lockfile through version control means collaborators should be able to run `renv::restore()` to get an identical environment without manual coordination about which packages to install.

## Global Package Cache

While each project has its own library, renv uses a global cache to avoid redundant downloads and installations. When you install a package, renv first checks if that exact version already exists in the cache. If so, it creates a link to the cached package rather than downloading and installing it again. This saves disk space and installation time, especially when multiple projects use the same packages.

By default, renv maintains a global cache at a platform-specific location. You can customise this with the `RENV_PATHS_CACHE` environment variable:

```r
# Check current cache path
renv::paths$cache()
```

The cache is particularly valuable in environments where multiple users share a system or when using containers, as packages only need to be compiled once.

## Automatic Dependency Discovery

When you run `renv::snapshot()`, renv scans your project files (R scripts, R Markdown documents, DESCRIPTION files) to discover which packages your project actually uses; only these packages and their dependencies are recorded in the lockfile.

## Stability

Package updates can introduce breaking changes. With {renv}, you control when packages are updated. Your project remains stable until you explicitly choose to update, test the changes, and snapshot the new state.

## Typical Usage

Starting a new project:

```r
# Initialize renv in a new project
renv::init()
```

This creates:

* `renv/` directory containing the project library and settings
* `renv.lock` file (initially recording currently used packages)
* `.Rprofile` that activates renv when the project is opened

Installing packages:

```r
# Install packages as usual
install.packages("dplyr")

# Or use renv's install function for more options
renv::install("dplyr")

# Install from GitHub
renv::install("tidyverse/dplyr")

# Install a specific version
renv::install("dplyr@1.1.0")
```

After installing packages **AND** writing code that uses them:

```r
# Update the lockfile with currently-used packages
renv::snapshot()
```

{renv} will scan your project, identify which packages are used, and record their versions in `renv.lock`.

Restoring An environment

```r
# Install packages as recorded in the lockfile
renv::restore()
```

This installs the exact package versions specified in `renv.lock`.

Checking status:

```r
# See if your library matches the lockfile
renv::status()
```

This reports packages that are:

* In the lockfile but not installed
* Installed but not in the lockfile
* Installed with a different version than the lockfile specifies

Updating packages

```r
# Update a specific package
renv::update("dplyr")

# Update all packages
renv::update()

# After updating, snapshot to record new versions
renv::snapshot()
```

## Using {renv} with Bioconductor

{renv} integrates with Bioconductor. When you install Bioconductor packages, renv records the Bioconductor version and repository URLs in the lockfile:

```r
# Install BiocManager first
renv::install("BiocManager")

# Then install Bioconductor packages
BiocManager::install("SingleCellExperiment")

# Snapshot will capture Bioconductor repositories
renv::snapshot()
```

The lockfile will include Bioconductor-specific repositories to ensure packages are restored from the correct source.

## Version Control Integration

These files should be committed to version control:

* `renv.lock` - The lockfile (essential for reproducibility)
* `.Rprofile` - Activates renv on project load
* `renv/activate.R` - Bootstrap script for renv
* `renv/settings.json` - Project settings (if present)

These should be ignored (renv's `.gitignore` handles this):

* `renv/library/` - The installed packages
* `renv/staging/` - Temporary installation directory

## Continuous Integration

{renv} works well with CI systems like GitHub Actions. A typical workflow:

1. Cache the renv library and global cache between runs
2. Run `renv::restore()` to install packages
3. Run your tests or build your project

This ensures CI uses the same package versions as development.

## Docker and Containers

When using renv in Docker:

1. Copy `renv.lock` into the container
2. Install renv and run `renv::restore()`
3. Optionally mount a cache volume to speed up builds

Setting `RENV_PATHS_CACHE` to a mounted volume allows cache sharing across container rebuilds.

## Handling Packages Not on CRAN

For packages from GitHub, GitLab, or other sources:

```r
# GitHub
renv::install("user/repo")

# Specific commit
renv::install("user/repo@abc123")

# Local package
renv::install("/path/to/package")
```

{renv} records the source information so these packages can be restored.

## Upgrading R Versions

When upgrading R, packages typically need to be reinstalled since they are compiled for specific R versions. With renv:

1. Install the new R version
2. Open your project (renv will detect the version change)
3. Run `renv::restore()` to reinstall packages for the new R version

The global cache may already have packages compiled for the new version from other projects, speeding up this process.

## Getting started

Start RStudio Server.

```console
./bin/run_rstudio.sh
```

After opening the project via `learning_renv.Rproj`, run `renv::init()` to restore the project from the lockfile.

```r
renv::init()
```
```
This project already has a lockfile. What would you like to do?

1: Restore the project from the lockfile.
2: Discard the lockfile and re-initialize the project.
3: Activate the project without snapshotting or installing any packages.
4: Abort project initialization.

Selection: 1
```

## Using renv on a Shared Server

On a shared server where R is installed system-wide (e.g., `/usr/bin/R`), you can use renv without needing administrator privileges. All packages are installed to your project's local library and your personal cache.

### Setting Up a New Project

Navigate to your project directory and start R:

```console
cd /path/to/your/project
/usr/bin/R
```

Then initialise renv:

```r
# Install renv to your user library if not already available
install.packages("renv")

# Initialise renv in the current directory
renv::init()
```
```
- renv activated -- please restart the R session.
```

### Working with an Existing renv Project

If you clone or receive a project that already has renv configured:

```console
cd /path/to/project
/usr/bin/R
```

The `.Rprofile` in the project directory automatically activates renv when R starts. Then restore the environment:

```r
renv::restore()
```

### Configuring the Cache Location

On shared servers, you may want to place your renv cache in a specific location (e.g., a directory with more disk quota). Set the `RENV_PATHS_CACHE` environment variable before starting R:

```console
export RENV_PATHS_CACHE=/path/to/your/renv/cache
/usr/bin/R
```

Or add it to your `~/.bashrc` or `~/.bash_profile`:

```bash
export RENV_PATHS_CACHE="$HOME/.local/share/renv/cache"
```

### Running R Scripts

When running R scripts non-interactively, ensure you run them from the project directory so the `.Rprofile` activates renv:

```console
cd /path/to/project
/usr/bin/Rscript analysis.R
```

Or specify the working directory explicitly:

```console
/usr/bin/Rscript --vanilla -e "setwd('/path/to/project'); source('.Rprofile'); source('analysis.R')"
```
