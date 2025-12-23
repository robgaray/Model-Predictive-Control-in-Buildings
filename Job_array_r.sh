#!/bin/bash
#SBATCH --job-name=MPC_optim
#SBATCH --partition=general
#SBATCH --qos=serial
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=2-00:00:00
#SBATCH --output=logs/MPC_optim_%j.out
#SBATCH --error=logs/MPC_optim_%j.err
#SBATCH --mail-user=roberto.garay@deusto.es
#SBATCH --mail-type=ALL

# Print job information
echo "==================================="
echo "Job started at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on cluster: $SLURM_CLUSTER_NAME"
echo "Running on host: $SLURM_NODELIST"
echo "Job name: $SLURM_JOB_NAME"
echo "Working directory: $SLURM_SUBMITDIR"
echo "Partition: $SLURM_JOB_PARTITION"
echo "Nodes: $SLURM_JOB_NUM_NODES"
echo "Tasks: $SLURM_NTASKS"
echo "CPUs per task: $SLURM_CPUS_PER_TASK"
echo "==================================="

set -euo pipefail

# Ensure working from the directory where 'sbatch' was executed
cd "${SLURM_SUBMIT_DIR:-$PWD}"

INPUT_FILE="02_Parametric_table/Optim_parameters.csv"
R_SCRIPT="Main_SCC.R"

# Existence checks
[[ -f "$INPUT_FILE" ]] || { echo "Not found: $INPUT_FILE" >&2; exit 1; }
[[ -f "$R_SCRIPT"   ]] || { echo "Not found: $R_SCRIPT"   >&2; exit 1; }

# The header occupies the first row; data start on row 2
line_no=$(( SLURM_ARRAY_TASK_ID + 1 ))

# Line range validation
total_lines=$(wc -l < "$INPUT_FILE")
if (( line_no > total_lines )); then
echo "Line $line_no does not exist in $INPUT_FILE (total $total_lines). Aborting." >&2
exit 1
fi

# Extract exactly that line
line=$(sed -n "${line_no}p" "$INPUT_FILE")

# Parse using ';' as separator
IFS=';' read -r popsize iter run horizon frequency month <<< "$line"

# Trim whitespace
popsize=$(echo "$popsize" | xargs)
iter=$(echo "$iter" | xargs)
run=$(echo "$run" | xargs)
horizon=$(echo "$horizon" | xargs)
frequency=$(echo "$frequency" | xargs)
month=$(echo "$month" | xargs)

# Basic validation
if [[ -z "$popsize" || -z "$iter" || -z "$run" || -z "$horizon" || -z "$frequency" || -z "$month" ]]; then
echo "Task ${SLURM_ARRAY_TASK_ID}: empty row or missing columns. Aborting." >&2
exit 1
fi

echo "Task ${SLURM_ARRAY_TASK_ID}: p=$popsize it=$iter r=$run h=%$horizon f=$frequency m=$month" 

# Load R if the cluster uses modules
# module load R/4.3.1

# Run your R script with positional arguments
Rscript "$R_SCRIPT" "$popsize" "$iter" "$run" "$horizon" "$frequency" "$month"


# End of job
echo "==================================="
echo "Job finished at $(date)"
echo "==================================="


