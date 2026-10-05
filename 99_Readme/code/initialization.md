# initialization.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/initialization.R`

## Function

This function performs the initialization steps required before running the MPC simulation. It carries out two tasks:

1. Loads all required R packages listed in a plain-text library file (one package name per line, comment lines starting with '#' are ignored).
2. Sources all R function files found in the specified functions directory, making them available in the calling environment.

## Called by

- [01_initialization.R](01_initialization.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- library_file    : Character. Path to a plain-text file listing the names of required R packages, one per line. Lines beginning with '#' and empty lines are ignored.
- functions_path  : Character. Path to the directory containing the R function files (.R) to be sourced.
- lib_path        : Character or NULL. Optional path to a custom R library location passed to library() as 'lib.loc'. If NULL (default), the default library paths are used.

## Output data

- None (called for side effects). Prints "libraries loaded" and "functions loaded" to the console upon completion.

## Other notes from the file header

### Code outline

1. Load required libraries from file
2. Source all function files from the functions directory

### Usage instructions

```r
initialization(library_file, functions_path)
```

```r
initialization(library_file, functions_path, lib_path = "/path/to/libs")
```

### Exceptions and special cases

- If a package listed in library_file is not installed, library() will raise an error. No automatic installation is attempted.
- If lib_path is NULL, packages are loaded from the default R library paths.
- All .R files in functions_path are sourced unconditionally and in the order returned by list.files(); file ordering may matter if functions depend on each other.

## Diagram

![Block diagram of initialization.R](initialization.jpg)

Also available as [initialization.svg](initialization.svg).

---

[Back to the code structure index](../Code_Structure.md)
