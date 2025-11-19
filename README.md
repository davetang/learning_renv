# README

Learning about the {renv} package.

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
