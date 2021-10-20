#!/bin/bash

set -e -o pipefail

CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VARS_SH=${1:-${CURDIR}/../vars.sh}
VARS_SH=$(readlink -f $VARS_SH)

if [ ! -f "$VARS_SH" ]; then
  echo "error: $VARS_SH is not a valid file!" >&2
  exit 1
fi

# CACHE_DIR is exported so the user-defined phase1/2 scripts can use it.
export CACHE_DIR=$(readlink -f "$CURDIR/../cache")
SESSION_FILE=${CACHE_DIR}/session.txt
SESSION_LOOP_DEVICE_FILE=${CACHE_DIR}/session-loop-device.txt

source ${CURDIR}/utils.sh
source ${CURDIR}/core.sh
source ${VARS_SH}

# CHROOT_PATH is exported so the user-defined phase1/2 scripts can use it.
export CHROOT_PATH=${CHROOT_PATH:-/tmp/rpi4-image-build} # TODO: change this path to something more generic
DOWNLOAD_CACHE_PATH="$CACHE_DIR/$(basename ${IMAGE_URL})"
NAMESERVER=${NAMESERVER:-1.1.1.1}

if [ "$VERBOSE" == "yes" ]; then
  set -x
fi

# TODO: trap exit to ensure we don't end up in a broken state

mkdir -p $CACHE_DIR
cd $CACHE_DIR

verify_build_can_proceed
print_build_information

if [ -n "$DRYRUN" ]; then
  exit 0
fi

start_session_file

run_step download_and_extract_image_if_necessary
run_step setup_loop_device_and_mount_partitions
run_step prepare_chroot
run_step copy_files_to_chroot

run_step setup_script_phase1_outside_chroot
run_step setup_script_phase1_inside_chroot
run_step setup_script_phase2_outside_chroot # To allow for cross compile
run_step setup_script_phase2_inside_chroot

run_step cleanup_chroot
run_step umount_everything

end_session_file

log "Built image at $OUTPUT_FILENAME"