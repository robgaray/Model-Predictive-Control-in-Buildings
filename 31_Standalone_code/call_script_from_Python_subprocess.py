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
#   3. It loads the inputs of one market, here from
#      01_Input/example_first_call.json. Any Python code can build the
#      same dictionary instead.
#   4. It writes them to a JSON file and runs call_script_console.R
#      with Rscript.
#   5. It reads the output JSON file and prints a summary.
# -------------------------------------------------------------
# Inputs
#   01_Input/example_first_call.json
#   Environment variable RSCRIPT (optional): path of the Rscript
#   executable. Without it, Rscript is looked up in the PATH and, on
#   Windows, in the usual installation folders of R.
# -------------------------------------------------------------
# Outputs
#   90_Output/call_script_from_Python_subprocess_output.json
#   A printed summary of the market operations.
# -------------------------------------------------------------
# Code outline
# 1. Paths
# 2. Rscript
# 3. Setup
# 4. Inputs
# 5. Call to call_script_console.R
# 6. Output
# -------------------------------------------------------------
# Usage instructions
#   python3 31_Standalone_code/call_script_from_Python_subprocess.py
# -------------------------------------------------------------
# Where this function/script is used
#   - Run by hand, as an example.
# -------------------------------------------------------------
# functions/scripts called
#   - setup.R: run with Rscript, through subprocess
#   - call_script_console.R: run with Rscript, through subprocess
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
input_example   = os.path.join(standalone_path, "01_Input", "example_first_call.json")
output_file     = os.path.join(standalone_path, "90_Output",
                               "call_script_from_Python_subprocess_output.json")

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
# 4. Inputs
# -------------------------------------------------------------
# The inputs are a dictionary with the blocks market, context, prices
# and itineraries. Missing values are written as None (JSON null).
# -------------------------------------------------------------
with open(input_example) as handle:
    inputs = json.load(handle)

with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
    json.dump(inputs, handle)
    input_file = handle.name

# -------------------------------------------------------------
# 5. Call to call_script_console.R
# -------------------------------------------------------------
# call_script_console.R ends with exit status 1 and prints the reason
# on any error, without writing the output file.
# -------------------------------------------------------------
completed = subprocess.run([rscript, console_script, input_file, output_file],
                           capture_output=True, text=True)
os.remove(input_file)

if completed.returncode != 0:
    print(completed.stdout)
    print(completed.stderr)
    sys.exit("The market script failed")

# -------------------------------------------------------------
# 6. Output
# -------------------------------------------------------------
with open(output_file) as handle:
    output = json.load(handle)

operations = output["operations"]
print("Committed intervals:", len(operations["time"]))
for name, values in operations.items():
    if name != "time":
        print(f"  {name:20s} {sum(values):10.3f} kWh")
