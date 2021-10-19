#!/bin/bash

set -e -o pipefail

CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OVERRIDE_SH=${1:-${CURDIR}/../overrides.sh}
OVERRIDE_SH=$(readlink -f $OVERRIDE_SH)
CACHE_DIR=$(readlink -f "$CURDIR/../build_cache")
SESSION_FILE=${CACHE_DIR}/session.txt
SESSION_LOOP_DEVICE_FILE=${CACHE_DIR}/session-loop-device.txt

source ${CURDIR}/utils.sh
source ${CURDIR}/core.sh
source ${OVERRIDE_SH}

if [ "$VERBOSE" == "yes" ]; then
  set -x
fi

# TODO: trap exit

mkdir -p $CACHE_DIR
cd $CACHE_DIR

verify_build_can_proceed
set_default_values
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
