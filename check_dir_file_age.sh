#!/usr/bin/env bash
#
# check_dir_file_age.sh - Icinga/Nagios check for newest/oldest file age in a directory
#
# Repository:
#   https://github.com/Nemester/check-dir-file-age
#
# Description:
#   Checks the newest or oldest file in a given directory and evaluates its age
#   against warning and critical thresholds.
#
# Usage:
#   ./check_dir_file_age.sh --directory <path> --warn <hours> --crit <hours> [--mode newest|oldest] [--perfdata]
#
# Return codes:
#   OK        (0) File age below warning threshold
#   WARNING   (1) File age exceeds warning threshold
#   CRITICAL  (2) Directory not found, no files found, or file age exceeds critical threshold
#   UNKNOWN   (3) Invalid input, parsing errors, or missing dependencies
#
# Changelog:
#   1.0 - Initial implementation
#   1.1 - Changed perfdata to opt-in (--perfdata)
#   1.2 - Added --mode newest|oldest

Author="Manuel Sonder"
Version="1.2"

set -o nounset
set -o pipefail

DIRECTORY=""
WARNING_AGE=""
CRITICAL_AGE=""
PERFDATA_ENABLED=0
MODE="newest"

usage() {
    cat <<EOF

Version $Version

Usage:
  $0 --directory <path> --warn <hours> --crit <hours> [--mode newest|oldest] [--perfdata]

Description:
  Checks the newest or oldest file in a directory and evaluates its age.

Modes:
  newest  (default) Alert if the newest file is too old — use to detect stale/missing writes
  oldest            Alert if the oldest file is too old — use to detect files not being cleaned up

Threshold semantics:
  --warn  alert if file age is >= threshold
  --crit  alert if file age is >= threshold

Options:
  --mode     newest or oldest (default: newest)
  --perfdata enable perfdata output (disabled by default)

Return codes:
  OK        (0) File age below warning threshold
  WARNING   (1) File age exceeds warning threshold
  CRITICAL  (2) Directory not found, no files found, or file age exceeds critical threshold
  UNKNOWN   (3) Invalid input, parsing errors, or missing dependencies

EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
    echo "$Version"
    exit 0
fi

die_unknown() {
    printf '[UNKNOWN]: %s\n' "$1"
    exit 3
}

die_critical() {
    printf '[CRITICAL]: %s\n' "$1"
    exit 2
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die_unknown "Required command not found: $1"
}

is_integer() {
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}

validate_threshold() {
    local name="$1"
    local value="$2"
    is_integer "$value" || die_unknown "Invalid value for $name: '$value'"
}

validate_threshold_pair_high_worse() {
    local warn="$1"
    local warn_val="$2"
    local crit="$3"
    local crit_val="$4"

    validate_threshold "$warn" "$warn_val"
    validate_threshold "$crit" "$crit_val"

    (( warn_val < crit_val )) || die_unknown "Invalid thresholds: $warn_val must be < $crit_val"
}

# --- Dependencies ---
require_cmd find
require_cmd sort
require_cmd head
require_cmd awk
require_cmd date
require_cmd stat
require_cmd basename

# --- Args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --directory|-d)
            DIRECTORY="$2"; shift 2 ;;
        --warn|-w)
            WARNING_AGE="$2"; shift 2 ;;
        --crit|-c)
            CRITICAL_AGE="$2"; shift 2 ;;
        --perfdata)
            PERFDATA_ENABLED=1; shift ;;
        --mode|-m)
            MODE="$2"; shift 2 ;;
        --help|-h)
            usage; exit 0 ;;
        --version|-v)
            echo "$Version"; exit 0 ;;
        *)
            die_unknown "Unknown parameter: $1" ;;
    esac
done

[[ -n "$DIRECTORY" ]] || die_unknown "Missing --directory"
[[ -n "$WARNING_AGE" ]] || die_unknown "Missing --warn"
[[ -n "$CRITICAL_AGE" ]] || die_unknown "Missing --crit"
[[ "$MODE" == "newest" || "$MODE" == "oldest" ]] || die_unknown "Invalid --mode: '$MODE' (expected: newest|oldest)"

validate_threshold_pair_high_worse "--warn" "$WARNING_AGE" "--crit" "$CRITICAL_AGE"

[[ -d "$DIRECTORY" ]] || die_critical "Directory not found: $DIRECTORY"

# newest = sort descending (head picks highest timestamp = most recent)
# oldest = sort ascending  (head picks lowest  timestamp = least recent)
SORT_FLAG="-nr"
[[ "$MODE" == "oldest" ]] && SORT_FLAG="-n"

TARGET_FILE="$(
    find "$DIRECTORY" -type f -printf '%T@ %p\n' 2>/dev/null | sort $SORT_FLAG | head -n1 | awk '{$1=""; sub(/^ /,""); print}'
)"

[[ -n "$TARGET_FILE" ]] || die_critical "No files found in $DIRECTORY"

CURRENT_TIME="$(date +%s)"
FILE_TIME="$(stat -c %Y "$TARGET_FILE")" || die_unknown "Failed to stat file"
AGE=$(( (CURRENT_TIME - FILE_TIME) / 3600 ))

FILE_NAME="$(basename "$TARGET_FILE")"

# --- Perfdata ---
PERFDATA=""
if (( PERFDATA_ENABLED )); then
    PERFDATA=" | file_age_hours=${AGE};${WARNING_AGE};${CRITICAL_AGE};0;"
fi

# --- Output ---
if (( AGE >= CRITICAL_AGE )); then
    printf '[CRITICAL]: %s file "%s" is %s hours old in %s%s\n' "$MODE" "$FILE_NAME" "$AGE" "$DIRECTORY" "$PERFDATA"
    exit 2
elif (( AGE >= WARNING_AGE )); then
    printf '[WARNING]: %s file "%s" is %s hours old in %s%s\n' "$MODE" "$FILE_NAME" "$AGE" "$DIRECTORY" "$PERFDATA"
    exit 1
else
    printf '[OK]: %s file "%s" is %s hours old in %s%s\n' "$MODE" "$FILE_NAME" "$AGE" "$DIRECTORY" "$PERFDATA"
    exit 0
fi
