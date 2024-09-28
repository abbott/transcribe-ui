#!/bin/bash
# Process control example with different limits for multiple processes

# Check if required environment variables are set
if [ -z "$MAX_CONCURRENT_TRANSFORMS" ] || [ -z "$MAX_CONCURRENT_SUMMARIES" ] || [ -z "$SCRIPTS_DIR" ] || [ -z "$DISABLE_OLLAMA" ]; then
  echo "Error: Required environment variables (MAX_CONCURRENT_TRANSFORMS, MAX_CONCURRENT_SUMMARIES, SCRIPTS_DIR, DISABLE_OLLAMA) not set."
  exit 1
fi

# Process names and their maximum concurrent runs
process1="transcribe_example.sh"
maxConcurrentRuns1=$MAX_CONCURRENT_TRANSFORMS  # Maximum concurrent runs for process1

process2="auto-summary.py"
maxConcurrentRuns2=$MAX_CONCURRENT_SUMMARIES  # Maximum concurrent runs for process2

# Delay between starting each script (in seconds)
delayBetweenStarts=10

# Function to start a process if it hasn't reached its limit
start_process_if_allowed() {
  local processName=$1
  local maxConcurrentRuns=$2
  local runningInstances

  # Count the number of running instances of the process
  runningInstances=$(pgrep -fc $processName)

  # Start additional instances if the maximum limit has not been reached
  if [ $runningInstances -lt $maxConcurrentRuns ]; then
    echo "Starting new instance of $processName. Current count: $runningInstances"

    # Check if the process is a Python script
    if [[ $processName == *.py ]]; then
      python3 ${SCRIPTS_DIR}/$processName &
    else
      bash ${SCRIPTS_DIR}/$processName &
    fi

    # Check if the process started successfully
    if [ $? -ne 0 ]; then
      echo "Error: Failed to start $processName"
    fi

    # Add a delay to avoid race conditions
    sleep 2
  fi
}

# Function to check if auto-summary.py should be skipped due to DISABLE_OLLAMA
should_run_auto_summary() {
  if [ "$DISABLE_OLLAMA" == "true" ]; then
    echo "DISABLE_OLLAMA is set to true. Skipping auto-summary.py."
    return 1  # Return non-zero (false)
  fi
  return 0  # Return zero (true)
}

while true
do
  # Check and start process1 if allowed
  start_process_if_allowed $process1 $maxConcurrentRuns1

  # Delay between starting process1 and process2
  sleep $delayBetweenStarts

  # Check if auto-summary.py should run based on DISABLE_OLLAMA
  if should_run_auto_summary; then
    # Check and start process2 if allowed
    start_process_if_allowed $process2 $maxConcurrentRuns2
  fi

  # Sleep for a short duration before checking again
  sleep 5
done
