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
#   3. It loads the inputs of a first market as a Python dictionary,
#      here from 01_Input/example_building_first_call.json.
#   4. It turns the dictionary into an R list, calls optimize_market()
#      and turns the result back into a dictionary with
#      format_market_output().
#   5. It builds a chained call. The output of the first market has a
#      "system" block (the net energy of the plan and of its
#      flexibility itineraries) and an "assets" block (the itineraries
#      of every asset). Both are copied into the input of a later
#      market with the "O+F" aim, over the intervals of that market,
#      and the prices of the later market are added. The later market
#      keeps the plan and only searches flexibility over it.
#   6. It calls the chained market the same way.
# -------------------------------------------------------------
# Inputs
#   01_Input/example_building_first_call.json
#   01_Input/example_building_chained_call.json: the market, the
#   weather, the prices and the use of the building of the chained
#   market. Its own "system" and "assets" itineraries are replaced
#   by the ones taken from the output of the first market.
# -------------------------------------------------------------
# Outputs
#   A printed summary of the operations of each market.
# -------------------------------------------------------------
# Code outline
# 1. R session
# 2. Conversion between Python and R
# 3. Call function
# 4. First market
# 5. Chained market
# -------------------------------------------------------------
# Usage instructions
#   python3 31_Standalone_code/call_script_from_Python_rpy2.py
# rpy2 uses the R installation given by the R_HOME environment
# variable, or the one it finds on its own. setup.R installs the
# packages for that same R.
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
first_example   = os.path.join(
    standalone_path, "01_Input", "example_building_first_call.json"
)
chained_example = os.path.join(
    standalone_path, "01_Input", "example_building_chained_call.json"
)

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
# 3. Call function
# -------------------------------------------------------------
# run_market calls optimize_market() on the inputs of a market, a
# dictionary, and returns the output as a dictionary.
# -------------------------------------------------------------
def run_market(inputs):
    result = ro.r["optimize_market"](to_r(inputs), paths)
    return to_python(ro.r["format_market_output"](result))


def print_operations(output):
    operations = output["operations"]
    print("Committed intervals:", len(operations["time"]))
    for name, values in operations.items():
        if name != "time":
            print(f"  {name:20s} {sum(values):10.3f} kWh")

# -------------------------------------------------------------
# 4. First market
# -------------------------------------------------------------
# The inputs are a dictionary with the blocks market, context, prices,
# system and assets. The first market is a day-ahead market that
# starts from scratch.
# -------------------------------------------------------------
with open(first_example) as handle:
    first_inputs = json.load(handle)

first_output = run_market(first_inputs)
print_operations(first_output)

# -------------------------------------------------------------
# 5. Chained market
# -------------------------------------------------------------
# The chained market takes its market, weather, prices and building
# use from its own file. The system and the assets come from the
# output of the first market: take_block cuts a block of that output
# to the intervals of the chained market, and leaves None where the
# first market did not reach.
# -------------------------------------------------------------
def take_block(block, times):
    position = {time: index for index, time in enumerate(block["time"])}
    taken = {"time": list(times)}
    for name, values in block.items():
        if name != "time":
            taken[name] = [values[position[time]] if time in position else None
                           for time in times]
    return taken


def take_itineraries(itineraries, times):
    return {name: take_block(block, times) for name, block in itineraries.items()}


with open(chained_example) as handle:
    chained_inputs = json.load(handle)

chained_times = chained_inputs["context"]["time"]

chained_inputs["system"] = {
    "itineraries": take_itineraries(first_output["system"]["itineraries"], chained_times)
}
for asset_id, asset in first_output["assets"].items():
    chained_inputs["assets"].setdefault(asset_id, {})["itineraries"] = \
        take_itineraries(asset["itineraries"], chained_times)

chained_output = run_market(chained_inputs)
print_operations(chained_output)

# close_standalone stops the worker cluster of the R session, when
# the optimizer runs in parallel.
ro.r["close_standalone"](paths)
