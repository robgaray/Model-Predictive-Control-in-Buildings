# -------------------------------------------------------------
# Script: call_script_from_Python_subprocess.py
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Example of how a Python program uses the standalone market script
# through its command line interface. It only needs the Python
# standard library and an installation of R.
#   1. It finds Rscript.
#   2. It runs setup.R, which installs the R packages and the C++
#      compiler the script needs. Only the first time is it really
#      needed; later runs find everything in place and end quickly.
#   3. It loads the inputs of a first market, here from
#      01_Input/example_first_call.json. Any Python code can build the
#      same dictionary instead.
#   4. It writes them to a JSON file and runs call_script_console.R
#      with Rscript, then reads the output JSON file and prints a
#      summary.
#   5. It builds a chained call. The output of the first market has a
#      "system" block (the net energy of the plan and of its
#      flexibility itineraries) and an "assets" block (the itineraries
#      of every asset). Both are copied into the input of a later
#      market with the "O+F" aim, over the intervals of that market,
#      and the prices of the later market are added. The later market
#      keeps the plan and only searches flexibility over it.
#   6. It runs the chained call and prints its summary.
# -------------------------------------------------------------
# Inputs
#   01_Input/example_first_call.json
#   01_Input/example_chained_call.json: the market, the weather, the
#   prices and the use of the building of the chained market. Its own
#   "system" and "assets" itineraries are replaced by the ones taken
#   from the output of the first market.
#   Environment variable RSCRIPT (optional): path of the Rscript
#   executable. Without it, Rscript is looked up in the PATH and, on
#   Windows, in the usual installation folders of R.
# -------------------------------------------------------------
# Outputs
#   90_Output/call_script_from_Python_subprocess_output.json: the
#   output of the first market.
#   90_Output/call_script_from_Python_subprocess_chained_output.json:
#   the output of the chained market.
#   A printed summary of the operations of each market.
# -------------------------------------------------------------
# Code outline
# 1. Paths
# 2. Rscript
# 3. Setup
# 4. Call function
# 5. First market
# 6. Chained market
# -------------------------------------------------------------
# Usage instructions
#   python3 31_Standalone_code/call_script_from_Python_subprocess.py
# -------------------------------------------------------------

import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

# -------------------------------------------------------------
# 1. Paths
# -------------------------------------------------------------
standalone_path = os.path.dirname(os.path.abspath(__file__))
setup_script    = os.path.join(standalone_path, "setup.R")
console_script  = os.path.join(standalone_path, "call_script_console.R")
first_example   = os.path.join(standalone_path, "01_Input", "example_first_call.json")
chained_example = os.path.join(standalone_path, "01_Input", "example_chained_call.json")
first_output_file   = os.path.join(standalone_path, "90_Output",
                                   "call_script_from_Python_subprocess_output.json")
chained_output_file = os.path.join(standalone_path, "90_Output",
                                   "call_script_from_Python_subprocess_chained_output.json")

# -------------------------------------------------------------
# 2. Rscript
# -------------------------------------------------------------
# The installer of R for Windows does not add R to the PATH, so on
# Windows the newest R under the Program Files folders is taken when
# Rscript is not in the PATH.
# -------------------------------------------------------------
rscript = os.environ.get("RSCRIPT") or shutil.which("Rscript")
if rscript is None and os.name == "nt":
    candidates = []
    for program_files in {os.environ.get("ProgramFiles", r"C:\Program Files"),
                          os.environ.get("LOCALAPPDATA", "") + r"\Programs"}:
        candidates += glob.glob(os.path.join(program_files, "R", "R-*", "bin", "Rscript.exe"))
    if candidates:
        version_of = lambda path: [int(part) for part in
                                   os.path.basename(os.path.dirname(os.path.dirname(path)))[2:].split(".")
                                   if part.isdigit()]
        rscript = max(candidates, key=version_of)
if rscript is None:
    sys.exit("Rscript not found. Install R, or give its path in the RSCRIPT environment variable.")
print("Rscript:", rscript)

# -------------------------------------------------------------
# 3. Setup
# -------------------------------------------------------------
# setup.R ends with exit status 0 when every package is installed and
# a C++ file compiles, and with exit status 1 otherwise. Its messages
# are shown on the console as it runs, because installing a compiler
# can take several minutes.
# -------------------------------------------------------------
setup = subprocess.run([rscript, setup_script])
if setup.returncode != 0:
    sys.exit("setup.R failed. Read its messages above.")

# -------------------------------------------------------------
# 4. Call function
# -------------------------------------------------------------
# run_market writes the inputs of a market to a temporary JSON file
# and runs call_script_console.R on it. The script ends with exit
# status 1 and prints the reason on any error, without writing the
# output file. The function returns the output as a dictionary. Missing
# values are written as None (JSON null).
# -------------------------------------------------------------
def run_market(inputs, output_path):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(inputs, handle)
        input_file = handle.name

    completed = subprocess.run([rscript, console_script, input_file, output_path],
                               capture_output=True, text=True)
    os.remove(input_file)

    if completed.returncode != 0:
        print(completed.stdout)
        print(completed.stderr)
        sys.exit("The market script failed")

    with open(output_path) as handle:
        return json.load(handle)


def print_operations(output):
    operations = output["operations"]
    print("Committed intervals:", len(operations["time"]))
    for name, values in operations.items():
        if name != "time":
            print(f"  {name:20s} {sum(values):10.3f} kWh")

# -------------------------------------------------------------
# 5. First market
# -------------------------------------------------------------
# The inputs are a dictionary with the blocks market, context, prices,
# system and assets. The first market is a day-ahead market that
# starts from scratch.
# -------------------------------------------------------------
with open(first_example) as handle:
    first_inputs = json.load(handle)

first_output = run_market(first_inputs, first_output_file)
print_operations(first_output)

# -------------------------------------------------------------
# 6. Chained market
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

chained_output = run_market(chained_inputs, chained_output_file)
print_operations(chained_output)
