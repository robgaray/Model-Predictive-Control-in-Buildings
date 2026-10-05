# -------------------------------------------------------------
# Script: call_script_from_Python_rpy2.py
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Example of how a Python program calls the standalone market script
# in memory, with rpy2, without writing any file. It needs the Python
# package rpy2 and an installation of R.
#   1. It starts R inside Python and runs setup.R, in a separate R
#      process, to install the R packages and the C++ compiler the
#      script needs. Only the first time is it really needed; later
#      runs find everything in place and end quickly.
#   2. It prepares the R session with initialize_standalone().
#   3. It loads the inputs of one market as a Python dictionary, here
#      from 01_Input/example_first_call.json.
#   4. It turns the dictionary into an R list, calls optimize_market()
#      and turns the result back into a dictionary with
#      format_market_output().
# -------------------------------------------------------------
# Inputs
#   01_Input/example_first_call.json
# -------------------------------------------------------------
# Outputs
#   A printed summary of the market operations.
# -------------------------------------------------------------
# Code outline
# 1. R session
# 2. Conversion between Python and R
# 3. Inputs, call and output
# -------------------------------------------------------------
# Usage instructions
#   python3 31_Standalone_code/call_script_from_Python_rpy2.py
# rpy2 uses the R installation given by the R_HOME environment
# variable, or the one it finds on its own. setup.R installs the
# packages for that same R.
# -------------------------------------------------------------
# Where this function/script is used
#   - Run by hand, as an example.
# -------------------------------------------------------------
# functions/scripts called
#   - setup.R: run with Rscript, through subprocess
#   - initialize_standalone(): prepares the R session
#   - optimize_market(): optimizes the market
#   - format_market_output(): prepares the result for Python
# -------------------------------------------------------------

import json
import os
import subprocess
import sys

import rpy2.robjects as ro

# -------------------------------------------------------------
# 1. R session
# -------------------------------------------------------------
standalone_path = os.path.dirname(os.path.abspath(__file__))
input_example   = os.path.join(standalone_path, "01_Input", "example_first_call.json")

# setup.R is run with the Rscript of the R that rpy2 started, so that
# the packages are installed where that R looks for them.
rscript = os.path.join(ro.r('R.home("bin")')[0], "Rscript")
if subprocess.run([rscript, os.path.join(standalone_path, "setup.R")]).returncode != 0:
    sys.exit("setup.R failed. Read its messages above.")

ro.r["source"](os.path.join(standalone_path, "03_Functions", "initialize_standalone.R"))
paths = ro.r["initialize_standalone"](standalone_path, ro.NULL)

# -------------------------------------------------------------
# 2. Conversion between Python and R
# -------------------------------------------------------------
# A dictionary becomes a named R list, a list of numbers a numeric
# vector (None becomes NA), a list of texts a character vector, and a
# single value a vector of length one. The way back follows the same
# rules.
# -------------------------------------------------------------
def to_r(value):
    if isinstance(value, dict):
        return ro.ListVector({key: to_r(item) for key, item in value.items()})
    items = value if isinstance(value, list) else [value]
    if any(isinstance(item, str) for item in items):
        return ro.StrVector([ro.NA_Character if item is None else item for item in items])
    return ro.FloatVector([ro.NA_Real if item is None else float(item) for item in items])


def to_python(value):
    if isinstance(value, ro.vectors.ListVector):
        return {key: to_python(item) for key, item in zip(value.names, value)}
    return [None if item is ro.NA_Real or item is ro.NA_Character or
            (isinstance(item, float) and item != item) else item
            for item in value]

# -------------------------------------------------------------
# 3. Inputs, call and output
# -------------------------------------------------------------
with open(input_example) as handle:
    inputs = json.load(handle)

result = ro.r["optimize_market"](to_r(inputs), paths)
output = to_python(ro.r["format_market_output"](result))

operations = output["operations"]
print("Committed intervals:", len(operations["time"]))
for name, values in operations.items():
    if name != "time":
        print(f"  {name:20s} {sum(values):10.3f} kWh")
