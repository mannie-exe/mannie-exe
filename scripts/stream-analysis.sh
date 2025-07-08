#!/usr/bin/env bash

# Script to test and analyze the performance of different shell command pipelines
# for extracting and modifying a version string.

# --- Configuration ---
NUM_PRIMING_RUNS=10
NUM_SEQUENTIAL_SETS=5
NUM_RANDOM_RUNS=100
EXPECTED_VERSION="0.0.0-20250119231123-241f24b550f6" # For verification

# --- Mock Function ---
# Simulates the output of 'go version -m $(which packwiz)'
mock_go_version() {
  # This output is designed to be processed by the methods below.
  # The key line is the 'mod' line. It contains tabs and spaces.
  cat <<EOF
go: finding module for path /some/path/to/packwiz-binary
go: found PWD in go.mod: github.com/packwiz/packwiz
	mod	github.com/packwiz/packwiz	v0.0.0-20250119231123-241f24b550f6	h1:someRandomHashValueHereIndeed
	dep	github.com/some/dependency	v1.2.3	h1:anotherHash
	dep	example.com/another/module	v0.5.0	go.mod
EOF
}

# --- Version Extraction Methods ---

# Method 1: grep | awk (substr)
method_grep_awk_substr() {
  mock_go_version | grep -E "^[[:space:]]*mod[[:space:]]+" | awk '{print substr($3, 2)}'
}

# Method 2: grep | awk (gsub)
method_grep_awk_gsub() {
  mock_go_version | grep -E "^[[:space:]]*mod[[:space:]]+" | awk '{sub(/^v/, "", $3); print $3}'
}

# Method 3: grep | awk | sed
method_grep_awk_sed() {
  mock_go_version | grep -E "^[[:space:]]*mod[[:space:]]+" | awk '{print $3}' | sed 's/^v//'
}

# Method 4: grep | sed
# Corrected to use POSIX character classes for better portability.
# The grep command ensures we only process the relevant line.
method_grep_sed() {
  mock_go_version | grep -E "^[[:space:]]*mod[[:space:]]+" | sed -E 's/^[[:space:]]*mod[[:space:]]+[^[:space:]]+[[:space:]]+v?([^[:space:]]+).*/\1/'
}

# Method 5: sed
# Corrected to use POSIX character classes and newline for command separation within {}
# for better portability, especially for the 'p' command.
method_sed_standalone() {
  mock_go_version | sed -nE '
    /^[[:space:]]*mod[[:space:]]+/ {
        s/^[[:space:]]*mod[[:space:]]+[^[:space:]]+[[:space:]]+v?([^[:space:]]+).*/\1/
        p
    }
    '
}

# Array of method names (must match function names)
METHODS=("method_grep_awk_substr" "method_grep_awk_gsub" "method_grep_awk_sed" "method_grep_sed" "method_sed_standalone")
METHOD_DESCRIPTIONS=(
  "grep | awk (substr)"
  "grep | awk (gsub)"
  "grep | awk | sed"
  "grep | sed"
  "sed"
)

# --- Helper Function for Timing ---
# Takes a command as argument, executes it, and echoes its duration in nanoseconds.
# Output of the command is sent to /dev/null.
time_execution() {
  local cmd_to_run="$1"
  local start_time end_time duration

  start_time=$(date +%s%N)
  "$cmd_to_run" >/dev/null # Execute the command, discard its stdout
  end_time=$(date +%s%N)

  duration=$((end_time - start_time))
  echo "$duration"
}

# --- Verification Step (Optional but Recommended) ---
echo "--- Verifying methods produce expected output: $EXPECTED_VERSION ---"
for i in "${!METHODS[@]}"; do
  method_name="${METHODS[$i]}"
  description="${METHOD_DESCRIPTIONS[$i]}"
  output=$($method_name)
  if [[ $output == "$EXPECTED_VERSION" ]]; then
    printf "Method %d (%s): OK\n" "$((i + 1))" "$description"
  else
    printf "Method %d (%s): FAILED (Output: '%s', Expected: '%s')\n" "$((i + 1))" "$description" "$output" "$EXPECTED_VERSION"
  fi
done
echo "----------------------------------------------------"
echo

# --- Cache Priming ---
echo "--- 1. Cache Priming (${NUM_PRIMING_RUNS} runs per method) ---"
for i in "${!METHODS[@]}"; do
  method_name="${METHODS[$i]}"
  description="${METHOD_DESCRIPTIONS[$i]}"
  echo "Priming ${description}..."
  for ((j = 0; j < NUM_PRIMING_RUNS; j++)); do
    "$method_name" >/dev/null
  done
done
echo "Cache priming complete."
echo "----------------------------------------------------"
echo

# --- Sequential Testing ---
echo "--- 2. Sequential Testing (${NUM_SEQUENTIAL_SETS} sets) ---"
# This part is mostly for observation; detailed stats are from randomized tests.
for set_num in $(seq 1 "$NUM_SEQUENTIAL_SETS"); do
  echo "Sequential Set $set_num:"
  for i in "${!METHODS[@]}"; do
    method_name="${METHODS[$i]}"
    description="${METHOD_DESCRIPTIONS[$i]}"
    duration_ns=$(time_execution "$method_name")
    duration_ms=$(echo "scale=3; $duration_ns / 1000000" | bc)
    printf "  Method %d (%s): %s ms\n" "$((i + 1))" "$description" "$duration_ms"
  done
done
echo "Sequential testing complete."
echo "----------------------------------------------------"
echo

# --- Randomized Testing ---
echo "--- 3. Randomized Testing (${NUM_RANDOM_RUNS} total runs) ---"
# Declare arrays to store timings for each method (in nanoseconds)
declare -a timings_method1 timings_method2 timings_method3 timings_method4 timings_method5
# Declare counters for runs of each method
declare -i counts_method1=0 counts_method2=0 counts_method3=0 counts_method4=0 counts_method5=0

echo "Running randomized tests..."
for ((k = 0; k < NUM_RANDOM_RUNS; k++)); do
  # Generate a random number between 1 and 5 (inclusive)
  # Using shuf if available, otherwise fallback to $RANDOM
  if command -v shuf &>/dev/null; then
    method_idx=$(($(shuf -i 1-${#METHODS[@]} -n 1) - 1))
  else
    method_idx=$((RANDOM % ${#METHODS[@]})) # RANDOM % N is 0 to N-1
  fi

  selected_method_name="${METHODS[$method_idx]}"

  duration_ns=$(time_execution "$selected_method_name")

  # Store the duration in the corresponding array
  case $method_idx in
    0)
      timings_method1+=("$duration_ns")
      counts_method1+=1
      ;;
    1)
      timings_method2+=("$duration_ns")
      counts_method2+=1
      ;;
    2)
      timings_method3+=("$duration_ns")
      counts_method3+=1
      ;;
    3)
      timings_method4+=("$duration_ns")
      counts_method4+=1
      ;;
    4)
      timings_method5+=("$duration_ns")
      counts_method5+=1
      ;;
  esac

  # Progress indicator (optional)
  if (((k + 1) % (NUM_RANDOM_RUNS / 10) == 0 && (NUM_RANDOM_RUNS / 10) > 0)); then
    printf "Completed %d/%d random runs.\n" "$((k + 1))" "$NUM_RANDOM_RUNS"
  fi
done
echo "Randomized testing complete."
echo "----------------------------------------------------"
echo

# --- Performance Analysis ---
echo "--- 4. Performance Analysis (from ${NUM_RANDOM_RUNS} randomized runs) ---"

# Helper function for array sum
sum_array() {
  local sum=0
  for val in "$@"; do
    sum=$((sum + val))
  done
  echo "$sum"
}

# Helper function for array min
min_array() {
  if [[ $# -eq 0 ]]; then
    echo 0
    return
  fi
  local min="$1"
  shift
  for val in "$@"; do
    if ((val < min)); then
      min="$val"
    fi
  done
  echo "$min"
}

# Helper function for array max
max_array() {
  if [[ $# -eq 0 ]]; then
    echo 0
    return
  fi
  local max="$1"
  shift
  for val in "$@"; do
    if ((val > max)); then
      max="$val"
    fi
  done
  echo "$max"
}

for i in "${!METHODS[@]}"; do
  method_name="${METHODS[$i]}"
  description="${METHOD_DESCRIPTIONS[$i]}"

  # Get the correct timings array and count variable dynamically
  timings_array_name="timings_method$((i + 1))[@]"
  timings=("${!timings_array_name}") # Indirect expansion

  count_var_name="counts_method$((i + 1))"
  count="${!count_var_name}" # Indirect expansion

  printf "Analysis for Method %d: %s\n" "$((i + 1))" "$description"

  if [[ $count -eq 0 ]]; then
    printf "  No runs recorded for this method in the randomized test.\n\n"
    continue
  fi

  total_time_ns=$(sum_array "${timings[@]}")
  min_time_ns=$(min_array "${timings[@]}")
  max_time_ns=$(max_array "${timings[@]}")
  # Ensure count is not zero before division for avg_time_ns
  avg_time_ns=0
  if ((count > 0)); then
    avg_time_ns=$(echo "scale=0; $total_time_ns / $count" | bc) # Integer division for average in ns
  fi

  # Convert to milliseconds for display
  total_time_ms=$(echo "scale=3; $total_time_ns / 1000000" | bc)
  min_time_ms=$(echo "scale=3; $min_time_ns / 1000000" | bc)
  max_time_ms=$(echo "scale=3; $max_time_ns / 1000000" | bc)
  avg_time_ms=$(echo "scale=3; $avg_time_ns / 1000000" | bc)

  printf "  Number of runs: %d\n" "$count"
  printf "  Total time    : %s ms\n" "$total_time_ms"
  printf "  Min time      : %s ms\n" "$min_time_ms"
  printf "  Max time      : %s ms\n" "$max_time_ms"
  printf "  Average time  : %s ms\n" "$avg_time_ms"
  echo
done

echo "--- Analysis Complete ---"
