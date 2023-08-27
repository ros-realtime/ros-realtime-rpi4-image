#!/usr/bin/env bash

set -euo pipefail

# Terminal output colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NORM='\033[0m'

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly ROOT_DIR=$SCRIPT_DIR/..

# Defaults
result=1    # Default to failure
# unless a system variable is set 
ROBOT_BUILDER="stanley2"

# Loggers
log(){
  printf "%b%s%b\n" "$CYAN" "$1" "$NORM"
}

warning(){
  printf "%b%s%b\n" "$YELLOW" "$1" "$NORM"
}

error(){
  printf "%b%s%b\n" "$RED" "$1" "$NORM"
}

panic() {
  error "$1"
  result=1
  exit 1
}

success(){
  printf "%b%s%b\n" "$GREEN" "$1" "$NORM"
}

# Utilities
cleanup(){
  # Usage: cleanup RESULT
  if [[ "$1" -eq 0 ]]; then
    success PASS
  else
    error FAIL
  fi
}

usage="$(basename "$0") [-h|--help] [-b |--builder string] -- Generate Iso file pishrimp it and compress it

where:
  -h |--help        show this help text
  -b |--builder     set the rosdistro to use (default: "$ROBOT_BUILDER") - other possibilyties ruediger2"

# Argparser
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -h|--help)
    echo "$usage"
    shift 1
    exit
    ;;
    -b|--builder)
    ROBOT_BUILDER="$2"
    shift 2
    ;;
    *)
    panic "Unrecognized option $1"
    ;;
  esac
done

# Create trap to make sure all artifacts are removed on exit
trap 'cleanup $result' EXIT

echo 'Generating ISO for ' ${ROBOT_BUILDER}
echo 'You will be ask to enter your root password'

make jammy-rt-${ROBOT_BUILDER}

echo 'Shrimp ISO file with PiShrimp'
echo 'PiShrimp should already be installed'

for iso in out/*.img; do
  echo "  Shrimping $iso"
  sudo pishrink $iso
done

echo 'Compress ISO file with xz'
for iso in out/*.img; do
  echo "  Compressing $iso"
  xz -9 $iso
done

result=0
exit 0
