#!/bin/bash
#SBATCH --job-name=MPC_optim
#SBATCH --partition=general              # Overridden by Console_code.txt via SCC_QUEUE
#SBATCH --qos=serial                    # Overridden by Console_code.txt via SCC_QOS
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=2-00:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --mail-user=roberto.garay@deusto.es   # Overridden by Console_code.txt via SCC_USER
#SBATCH --mail-type=ALL

# Print job information
echo "==================================="
echo "Job started at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on cluster: $SLURM_CLUSTER_NAME"
echo "Running on host: $SLURM_NODELIST"
echo "Job name: $SLURM_JOB_NAME"
echo "Working directory: $SLURM_SUBMIT_DIR"
echo "Partition: $SLURM_JOB_PARTITION"
echo "Nodes: $SLURM_JOB_NUM_NODES"
echo "Tasks: $SLURM_NTASKS"
echo "CPUs per task: $SLURM_CPUS_PER_TASK"
echo "==================================="

# Ensure working from the directory where 'sbatch' was executed
cd "${SLURM_SUBMIT_DIR:-$PWD}"

# Load SCC settings for output format (SCC_OUTPUT_FORMATS).
# This variable is also exported by Console_code.txt, but sourcing
# the file here makes the script self-contained for manual runs.
SCC_SETTINGS="31_SCC_Simulation/scc_settings.sh"
if [[ -f "$SCC_SETTINGS" ]]; then
  source "$SCC_SETTINGS"
fi
: "${SCC_OUTPUT_FORMATS:=csv,rds}"
: "${SCC_KEEP_LOGS:=1}"
: "${SCC_MAX_REQUEUE:=2}"
export SCC_OUTPUT_FORMATS
export SCC_KEEP_LOGS
export SCC_MAX_REQUEUE

INPUT_FILE="31_SCC_Simulation/Optim_parameters.csv"
R_SCRIPT="31_SCC_Simulation/Main_SCC.R"

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

# Parse CSV columns (comma-separated)
# Columns: population_size, iteration_number, run_number,
#          pcrossover, pmutation,
#          control_optimization_horizon, control_implementation_horizon,
#          control_optimization_anticipation, control_type, optimization_aim,
#          flexibility_event_length_max, flexibility_recover_timespan,
#          thermal_stabilization_timespan, minimum_flexibility,
#          flexibility_splits, Alpha_Service_Min, month_subset
IFS=',' read -r popsize iter run pcross pmut opt_hor impl_hor anticip ctrl_type opt_aim \
               flex_len flex_rec therm_stab min_flex flex_splits alpha month <<< "$line"

# Trim whitespace
popsize=$(echo "$popsize"         | xargs)
iter=$(echo "$iter"               | xargs)
run=$(echo "$run"                 | xargs)
pcross=$(echo "$pcross"           | xargs)
pmut=$(echo "$pmut"               | xargs)
opt_hor=$(echo "$opt_hor"         | xargs)
impl_hor=$(echo "$impl_hor"       | xargs)
anticip=$(echo "$anticip"         | xargs)
ctrl_type=$(echo "$ctrl_type"     | xargs)
opt_aim=$(echo "$opt_aim"         | xargs)
flex_len=$(echo "$flex_len"       | xargs)
flex_rec=$(echo "$flex_rec"       | xargs)
therm_stab=$(echo "$therm_stab"   | xargs)
min_flex=$(echo "$min_flex"       | xargs)
flex_splits=$(echo "$flex_splits" | xargs)
alpha=$(echo "$alpha"             | xargs)
month=$(echo "$month"             | xargs)

# Basic validation
if [[ -z "$popsize"     || -z "$iter"       || -z "$run"       || \
      -z "$pcross"      || -z "$pmut"       || \
      -z "$opt_hor"     || -z "$impl_hor"   || -z "$anticip"   || \
      -z "$ctrl_type"   || -z "$opt_aim"    || -z "$flex_len"   || \
      -z "$flex_rec"    || -z "$therm_stab" || -z "$min_flex"   || \
      -z "$flex_splits" || -z "$alpha"      || -z "$month" ]]; then
  echo "Task ${SLURM_ARRAY_TASK_ID}: empty row or missing columns. Aborting." >&2
  exit 1
fi

echo "Task ${SLURM_ARRAY_TASK_ID}"
echo "population_size=$popsize"
echo "iteration_number=$iter"
echo "run_number=$run"
echo "pcrossover=$pcross"
echo "pmutation=$pmut"
echo "control_optimization_horizon=$opt_hor"
echo "control_implementation_horizon=$impl_hor"
echo "control_optimization_anticipation=$anticip"
echo "control_type=$ctrl_type"
echo "optimization_aim=$opt_aim"
echo "flexibility_event_length_max=$flex_len"
echo "flexibility_recover_timespan=$flex_rec"
echo "thermal_stabilization_timespan=$therm_stab"
echo "minimum_flexibility=$min_flex"
echo "flexibility_splits=$flex_splits"
echo "Alpha_Service_Min=$alpha"
echo "month_subset=$month"

# Run the R script with positional arguments
Rscript "$R_SCRIPT" "$popsize" "$iter" "$run" "$pcross" "$pmut" \
        "$opt_hor" "$impl_hor" "$anticip" \
        "$ctrl_type" "$opt_aim" "$flex_len" "$flex_rec" "$therm_stab" \
        "$min_flex" "$flex_splits" "$alpha" "$month"

R_EXIT=$?

# End of job
echo "==================================="
echo "Job finished at $(date)"
echo "Exit code: $R_EXIT"
echo "==================================="

# --- Verify output for this task -----------------------------------
# After the R script finishes, verify the output file(s) for this
# specific task's configuration. Adds the line to a failed-configs
# accumulator file if verification fails.
# ------------------------------------------------------------------
{
  : "${SCC_OUTPUT_FORMATS:=synth_rds}"
  # SUFFIX derived from the same CSV columns already parsed above.
  SUFFIX="${popsize}_${iter}_${run}_${pcross}_${pmut}_${opt_hor}_${impl_hor}_${anticip}_${ctrl_type}_${opt_aim}_${flex_len}_${flex_rec}_${therm_stab}_${min_flex}_${flex_splits}_${alpha}_${month}"
  TASK_PASS=1
  TASK_LINE="${popsize},${iter},${run},${pcross},${pmut},${opt_hor},${impl_hor},${anticip},${ctrl_type},${opt_aim},${flex_len},${flex_rec},${therm_stab},${min_flex},${flex_splits},${alpha},${month}"

  IFS=',' read -ra FORMATS <<< "$SCC_OUTPUT_FORMATS"
  for fmt in "${FORMATS[@]}"; do
    fmt=$(echo "$fmt" | xargs)
    case "$fmt" in
      synth_csv)
        f="30_Simulation/90_Output/Sinthetized_df_computed_${SUFFIX}.csv"
        [[ -f "$f" ]] || { echo "Missing output: $f" >&2; TASK_PASS=0; }
        ;;
      synth_rds)
        f="30_Simulation/90_Output/Sinthetized_df_computed_${SUFFIX}.rds"
        [[ -f "$f" ]] || { echo "Missing output: $f" >&2; TASK_PASS=0; }
        ;;
      main_csv)
        f="30_Simulation/90_Output/Main_df_computed_${SUFFIX}.csv"
        [[ -f "$f" ]] || { echo "Missing output: $f" >&2; TASK_PASS=0; }
        ;;
      main_rds)
        f="30_Simulation/90_Output/Main_df_computed_${SUFFIX}.rds"
        [[ -f "$f" ]] || { echo "Missing output: $f" >&2; TASK_PASS=0; }
        ;;
    esac
  done

  if [[ "$TASK_PASS" -eq 0 || "$R_EXIT" -ne 0 ]]; then
    FAILED_ACC="31_SCC_Simulation/failed_configs_acc.csv"
    if [[ ! -f "$FAILED_ACC" ]]; then
      echo "population_size,iteration_number,run_number,pcrossover,pmutation,control_optimization_horizon,control_implementation_horizon,control_optimization_anticipation,control_type,optimization_aim,flexibility_event_length_max,flexibility_recover_timespan,thermal_stabilization_timespan,minimum_flexibility,flexibility_splits,Alpha_Service_Min,month_subset" > "$FAILED_ACC"
    fi
    echo "$TASK_LINE" >> "$FAILED_ACC"
    echo "Task ${SLURM_ARRAY_TASK_ID}: output verification FAILED."
  else
    echo "Task ${SLURM_ARRAY_TASK_ID}: output verification PASSED."
  fi
}

# --- Job persistence: update tracker and launch next pending job ---
# The job tracker (job_tracker.csv) records every job's status.
# When this array task is the LAST task in its job (highest
# SLURM_ARRAY_TASK_ID in this array), mark the job as completed
# and submit the next pending job from the tracker.
# ------------------------------------------------------------------
TRACKER="31_SCC_Simulation/job_tracker.csv"

if [[ -f "$TRACKER" ]]; then

  # Determine if this is the last task in the array.
  # SLURM_ARRAY_TASK_MAX is set by Slurm to the highest task id.
  if [[ "${SLURM_ARRAY_TASK_ID}" -eq "${SLURM_ARRAY_TASK_MAX}" ]]; then

    PARENT_JOB="${SLURM_ARRAY_JOB_ID}"

    if [[ "$R_EXIT" -eq 0 ]]; then
      # Mark current job as completed
      if [[ -n "$PARENT_JOB" ]]; then
        sed -i "s/,launched,${PARENT_JOB}$/,completed,${PARENT_JOB}/" "$TRACKER"
        echo "Tracker: marked job ${PARENT_JOB} as completed."
      fi
    else
      # Mark current job as failed so it is visible in the tracker
      if [[ -n "$PARENT_JOB" ]]; then
        sed -i "s/,launched,${PARENT_JOB}$/,failed,${PARENT_JOB}/" "$TRACKER"
        echo "Tracker: marked job ${PARENT_JOB} as FAILED (exit $R_EXIT)."
      fi
    fi

    # Regardless of success/failure, launch the next pending job
    # so the pipeline keeps progressing.
    NEXT_LINE=$(grep ',pending,' "$TRACKER" | head -n 1)
    if [[ -n "$NEXT_LINE" ]]; then
      NEXT_IDX=$(echo "$NEXT_LINE"   | cut -d',' -f1)
      NEXT_START=$(echo "$NEXT_LINE" | cut -d',' -f2)
      NEXT_END=$(echo "$NEXT_LINE"   | cut -d',' -f3)

      # Re-read SCC settings for sbatch arguments
      SCC_SETTINGS="31_SCC_Simulation/scc_settings.sh"
      if [[ -f "$SCC_SETTINGS" ]]; then
        source "$SCC_SETTINGS"
      fi
      : "${JOB_NAME:=MPC_optim}"
      : "${SCC_QUEUE:=general}"
      : "${SCC_QOS:=serial}"
      : "${SCC_USER:=}"

      SBATCH_EXTRA=""
      [[ -n "$JOB_NAME"  ]] && SBATCH_EXTRA="$SBATCH_EXTRA --job-name=$JOB_NAME"
      [[ -n "$SCC_QUEUE"  ]] && SBATCH_EXTRA="$SBATCH_EXTRA --partition=$SCC_QUEUE"
      [[ -n "$SCC_QOS"    ]] && SBATCH_EXTRA="$SBATCH_EXTRA --qos=$SCC_QOS"
      [[ -n "$SCC_USER"   ]] && SBATCH_EXTRA="$SBATCH_EXTRA --mail-user=$SCC_USER"

      echo "Auto-launching pending job $NEXT_IDX (tasks ${NEXT_START}-${NEXT_END})"
      SBATCH_OUT=$(sbatch --array=${NEXT_START}-${NEXT_END} $SBATCH_EXTRA \
                          --export=ALL "31_SCC_Simulation/Job_array_r.sh" 2>&1)
      SBATCH_EXIT=$?
      echo "$SBATCH_OUT"

      # Verify the new job is actually present in the Slurm queue before
      # updating the tracker.  If sbatch failed or the job was rejected,
      # the entry stays "pending" so it can be retried by a later job.
      # Use [0-9]+ to require at least one digit and avoid empty matches.
      NEW_JID=$(echo "$SBATCH_OUT" | grep -oE '[0-9]+$' || true)
      if [[ "$SBATCH_EXIT" -ne 0 ]]; then
        echo "Warning: sbatch rejected job $NEXT_IDX (exit $SBATCH_EXIT). Keeping as pending."
      elif [[ -n "$NEW_JID" ]]; then
        # Slurm may take a brief moment to register the job in squeue after
        # sbatch returns; retry a few times before concluding it is absent.
        SLURM_QUEUED=0
        for _i in 1 2 3 4 5; do
          if squeue --noheader -j "$NEW_JID" 2>/dev/null | grep -q .; then
            SLURM_QUEUED=1
            break
          fi
          sleep 2
        done
        if [[ "$SLURM_QUEUED" -eq 1 ]]; then
          sed -i "s/^${NEXT_IDX},${NEXT_START},${NEXT_END},pending,/${NEXT_IDX},${NEXT_START},${NEXT_END},launched,${NEW_JID}/" "$TRACKER"
        else
          echo "Warning: job $NEXT_IDX (Slurm ID $NEW_JID) not found in Slurm queue. Keeping as pending."
        fi
      else
        echo "Warning: sbatch output for job $NEXT_IDX contained no job ID. Keeping as pending."
      fi
    else
      echo "Tracker: no pending jobs remain."
    fi

    # --- Copy outputs to /dipc (fast scratch -> persistent home) -------
    # Sync simulation results from scratch to /dipc so they are
    # available on the persistent filesystem after the job finishes.
    # ------------------------------------------------------------------
    {
      DIPC_USER="${SCC_USERNAME:-$USER}"
      SRC_OUTPUT="${SLURM_SUBMIT_DIR:-$PWD}/30_Simulation/90_Output"
      DST_OUTPUT="/dipc/${DIPC_USER}/${JOB_NAME}/30_Simulation/90_Output"
      if [[ -d "$SRC_OUTPUT" ]]; then
        mkdir -p "$DST_OUTPUT"
        rsync -a "${SRC_OUTPUT}/" "${DST_OUTPUT}/"
        echo "Outputs synced to: $DST_OUTPUT"
      fi
    }

    # --- Manage log files ----------------------------------------------
    # If SCC_KEEP_LOGS=0, delete the .err and .out files for this job
    # array after copying outputs, to save disk space.
    # ------------------------------------------------------------------
    {
      : "${SCC_KEEP_LOGS:=1}"
      if [[ "$SCC_KEEP_LOGS" -eq 0 ]]; then
        if [[ -n "$SLURM_ARRAY_JOB_ID" ]]; then
          rm -f "logs/"*"_${SLURM_ARRAY_JOB_ID}_"*.out "logs/"*"_${SLURM_ARRAY_JOB_ID}_"*.err 2>/dev/null
          echo "Log files for job ${SLURM_ARRAY_JOB_ID} deleted."
        fi
      fi
    }

    # --- Re-queue failed configs when all jobs are done ----------------
    # If no more pending or launched jobs remain in the tracker,
    # and there are accumulated failed configs, re-submit them
    # up to SCC_MAX_REQUEUE times.
    # ------------------------------------------------------------------
    {
      : "${SCC_MAX_REQUEUE:=2}"
      REQUEUE_COUNT_FILE="31_SCC_Simulation/requeue_count.txt"
      FAILED_ACC="31_SCC_Simulation/failed_configs_acc.csv"

      STILL_ACTIVE=$(grep -c ',\(pending\|launched\),' "$TRACKER" 2>/dev/null || echo 0)

      if [[ "$STILL_ACTIVE" -eq 0 ]] && \
         [[ -f "$FAILED_ACC" ]] && \
         [[ $(( $(wc -l < "$FAILED_ACC") - 1 )) -gt 0 ]]; then

        REQUEUE_ATTEMPT=0
        [[ -f "$REQUEUE_COUNT_FILE" ]] && REQUEUE_ATTEMPT=$(cat "$REQUEUE_COUNT_FILE" | xargs)

        if [[ "$REQUEUE_ATTEMPT" -lt "$SCC_MAX_REQUEUE" ]]; then
          REQUEUE_ATTEMPT=$(( REQUEUE_ATTEMPT + 1 ))
          echo "$REQUEUE_ATTEMPT" > "$REQUEUE_COUNT_FILE"

          BACKUP_TS=$(date +%Y%m%d_%H%M%S)
          cp "31_SCC_Simulation/Optim_parameters.csv" \
             "31_SCC_Simulation/Optim_parameters_backup_requeue_${BACKUP_TS}.csv"
          cp "$FAILED_ACC" "31_SCC_Simulation/Optim_parameters.csv"
          # Reset accumulator to header-only for next re-queue round
          head -n 1 "$FAILED_ACC" > "${FAILED_ACC}.tmp"
          HEAD_EXIT=$?
          if [[ "$HEAD_EXIT" -eq 0 ]]; then
            mv "${FAILED_ACC}.tmp" "$FAILED_ACC"
          else
            rm -f "${FAILED_ACC}.tmp"
            echo "Warning: could not reset $FAILED_ACC." >&2
          fi

          N_REQUEUE=$(( $(wc -l < "31_SCC_Simulation/Optim_parameters.csv") - 1 ))
          echo "Re-queue attempt ${REQUEUE_ATTEMPT}/${SCC_MAX_REQUEUE}: ${N_REQUEUE} failed configs."

          # TRACKER and TRACKER_NEW both point to job_tracker.csv.
          # Re-initialise the tracker file for the new re-queue round.
          TRACKER_NEW="$TRACKER"
          echo "job_index,start_task,end_task,status,slurm_job_id" > "$TRACKER_NEW"
          IDX_RQ=0
          S_RQ=1
          while [ $S_RQ -le $N_REQUEUE ]; do
            E_RQ=$(( S_RQ + TASKS_PER_JOB - 1 ))
            [ $E_RQ -gt $N_REQUEUE ] && E_RQ=$N_REQUEUE
            IDX_RQ=$(( IDX_RQ + 1 ))
            echo "${IDX_RQ},${S_RQ},${E_RQ},pending," >> "$TRACKER_NEW"
            S_RQ=$(( E_RQ + 1 ))
          done

          SBATCH_EXTRA_RQ=""
          [[ -n "$JOB_NAME"  ]] && SBATCH_EXTRA_RQ="$SBATCH_EXTRA_RQ --job-name=$JOB_NAME"
          [[ -n "$SCC_QUEUE"  ]] && SBATCH_EXTRA_RQ="$SBATCH_EXTRA_RQ --partition=$SCC_QUEUE"
          [[ -n "$SCC_QOS"    ]] && SBATCH_EXTRA_RQ="$SBATCH_EXTRA_RQ --qos=$SCC_QOS"
          [[ -n "$SCC_USER"   ]] && SBATCH_EXTRA_RQ="$SBATCH_EXTRA_RQ --mail-user=$SCC_USER"

          FIRST_END_RQ=$(( TASKS_PER_JOB < N_REQUEUE ? TASKS_PER_JOB : N_REQUEUE ))
          sbatch --array=1-${FIRST_END_RQ} $SBATCH_EXTRA_RQ \
                 --export=ALL "31_SCC_Simulation/Job_array_r.sh"
          # Update the active tracker (TRACKER_NEW == TRACKER) to mark
          # the first re-queue job as launched with a placeholder ID.
          sed -i "s/^1,1,${FIRST_END_RQ},pending,$/1,1,${FIRST_END_RQ},launched,auto/" "$TRACKER"
        else
          echo "Max re-queue attempts (${SCC_MAX_REQUEUE}) reached. No more re-queuing."
        fi
      fi
    }

    # --- Generate operation summary in /dipc ---------------------------
    # Write a summary of the SCC operation to the project's 31_SCC_Simulation
    # folder on /dipc for the user to review after jobs complete.
    # ------------------------------------------------------------------
    {
      DIPC_USER="${SCC_USERNAME:-$USER}"
      SUMMARY_DIR="/dipc/${DIPC_USER}/${JOB_NAME}/31_SCC_Simulation"
      mkdir -p "$SUMMARY_DIR"
      SUMMARY_FILE="${SUMMARY_DIR}/operation_summary_$(date +%Y%m%d_%H%M%S).txt"

      N_ORIGIN=$(( $(wc -l < "31_SCC_Simulation/Optim_parameters.csv") - 1 ))
      N_FAIL=0
      if [[ -f "31_SCC_Simulation/failed_configs_acc.csv" ]]; then
        N_FAIL=$(( $(wc -l < "31_SCC_Simulation/failed_configs_acc.csv") - 1 ))
      fi
      N_PASS=$(( N_ORIGIN - N_FAIL ))

      N_RUNNING=0
      N_QUEUED=0
      N_PENDING=0
      if [[ -f "31_SCC_Simulation/job_tracker.csv" ]]; then
        N_RUNNING=$(grep -c ',launched,' "31_SCC_Simulation/job_tracker.csv" 2>/dev/null || echo 0)
        N_PENDING=$(grep -c ',pending,'  "31_SCC_Simulation/job_tracker.csv" 2>/dev/null || echo 0)
      fi
      if [[ -n "${SCC_USERNAME:-}" ]]; then
        N_QUEUED=$(squeue -u "${SCC_USERNAME}" --noheader 2>/dev/null | wc -l || echo 0)
      fi

      REQUEUE_ATTEMPT=0
      [[ -f "31_SCC_Simulation/requeue_count.txt" ]] && \
        REQUEUE_ATTEMPT=$(cat "31_SCC_Simulation/requeue_count.txt" | xargs)

      {
        echo "==================================="
        echo "SCC Operation Summary"
        echo "==================================="
        echo "Date/Time:                     $(date)"
        echo "Job name:                      ${JOB_NAME}"
        echo "-----------------------------------"
        echo "Simulations queued at start:   ${N_ORIGIN}"
        echo "Simulations validated OK:      ${N_PASS}"
        echo "Simulations failed (re-queued): ${N_FAIL}"
        echo "Re-queue attempt:              ${REQUEUE_ATTEMPT} / ${SCC_MAX_REQUEUE:-2}"
        echo "-----------------------------------"
        echo "Tasks currently running:       ${N_RUNNING}"
        echo "Jobs in Slurm queue:           ${N_QUEUED}"
        echo "Pending job-tracker entries:   ${N_PENDING}"
        echo "==================================="
      } > "$SUMMARY_FILE"

      echo "Operation summary written to: $SUMMARY_FILE"

      # Trailing slash on source syncs contents into destination directory.
      rsync -a "31_SCC_Simulation/" "/dipc/${DIPC_USER}/${JOB_NAME}/31_SCC_Simulation/"
    }

  fi
fi
