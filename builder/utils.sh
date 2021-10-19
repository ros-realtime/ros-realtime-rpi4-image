log() {
  echo "[$(date +'%H:%M:%S')] $1"
}

log_in_step() {
  log "  >> $1"
}

run_step() {
  local step=$1
  if [ "$2" != "idempotent" ]; then
    if step_in_session "$step"; then
      log "skipped $step as it already ran."
      return
    fi
  else
    extra_log="(idempotent step always run)"
  fi

  log "running $step $extra_log"
  $step

  if [ "$PAUSE_AFTER" == "$step" ]; then
    log "Pausing at $step as it is configured in PAUSE_AFTER"
    exit 1
  fi

  if [ "$2" != "idempotent" ]; then
    echo "$step" >> $SESSION_FILE
  fi
}

start_session_file() {
  if [ ! -f $SESSION_FILE ]; then
    touch $SESSION_FILE
    chmod 0666 $SESSION_FILE
  fi
}

end_session_file() {
  rm -f $SESSION_FILE
}

step_in_session() {
  grep -q $1 $SESSION_FILE
}

verify_build_can_proceed() {
  # Checking required functions
  for f in custom_extract_image; do
    if __function_does_not_exist $f; then
      echo "error: function $f does not exist, define it in $OVERRIDE_SH." >&2
      exit 1
    fi
  done

  local required_variables=(
    "IMAGE_PARTITION_MOUNTS"
    "IMAGE_ROOTFS_PARTITION_NUM"
    "IMAGE_URL"
    "QEMU_USER_STATIC_PATH"
    "ROOTFS_OVERLAY"
  )

  # Checking required parameters
  for v in "${required_variables[@]}"; do
    if [ -z "${!v}" ]; then
      echo "error: variable $v is not defined, define it in $OVERRIDE_SH." >&2
      exit 1
    fi
  done

  if [ ! -f $QEMU_USER_STATIC_PATH ]; then
    echo "error: cannot find $QEMU_USER_STATIC_PATH, please install it" >&2
    exit 1
  fi

  # Checking required commands
  local required_cmd=(
    "cut"
    "grep"
    "parted"
    "pv"
    "rsync"
    "truncate"
    "wget"
    "systemd-nspawn"
  )

  for cmd in "${required_cmd[@]}"; do
    if ! type $cmd >/dev/null 2>&1; then
      echo "error: $cmd is not found built is required for building." >&2
      exit 1
    fi
  done

  if [ -n "$SETUP_PHASE1_OUTSIDE_CHROOT" ]; then
    if [ ! -f "$SETUP_PHASE1_OUTSIDE_CHROOT" ]; then
      echo "error: $SETUP_PHASE1_OUTSIDE_CHROOT is not a valid file" >&2
      exit 1
    fi
  fi

  if [ -n "$SETUP_PHASE2_OUTSIDE_CHROOT" ]; then
    if [ ! -f "$SETUP_PHASE2_OUTSIDE_CHROOT" ]; then
      echo "error: $SETUP_PHASE2_OUTSIDE_CHROOT is not a valid file" >&2
      exit 1
    fi
  fi

  # Check root
  if [ "$(whoami)" != "root" ]; then
    echo "error: must build system image as root" >&2
    exit 1
  fi
}

set_default_values() {
  # Setting default values
  # CHROOT_PATH is exported
  export CHROOT_PATH=${CHROOT_PATH:-/tmp/rpi4-image-build} # TODO: change this path to something more generic
  DOWNLOAD_CACHE_PATH="$CACHE_DIR/$(basename ${IMAGE_URL})"
  NAMESERVER=${NAMESERVER:-1.1.1.1}
}

print_build_information() {
  local session_file_exists=""
  if [ -f $SESSION_FILE ]; then
    session_file_exists="resuming from previous"
  else
    session_file_exists="starting new session"
  fi

  local cached_download_exists=""
  if [ -f $DOWNLOAD_CACHE_PATH ]; then
    cached_download_exists="exists"
  else
    cached_download_exists="missing"
  fi

  log "================================================================"
  log "                      Build Information"
  log "================================================================"
  log "Image URL:         ${IMAGE_URL}"
  log "Cached Download:   ${cached_download_exists} at ${DOWNLOAD_CACHE_PATH}"
  log "Output file:       ${OUTPUT_FILENAME}"
  log "Chroot location:   ${CHROOT_PATH}"
  log "Image Final Size:  ${IMAGE_SIZE}"
  log "Image Rootfs Num:  ${IMAGE_ROOTFS_PARTITION_NUM}"
  log "Image Mounts:"

  for i in "${!IMAGE_PARTITION_MOUNTS[@]}"; do # loop with index
    log "  - Partition $((i+1)) => ${IMAGE_PARTITION_MOUNTS[$i]}"
  done

  log "Session:           ${session_file_exists}"
  if [ "$session_file_exists" == "resuming from previous" ]; then
    log "Steps already done:"
    while IFS= read -r step; do
      log "  - ${step}"
    done < $SESSION_FILE
  fi
  log "================================================================"
  log ""
}

######################
# Helpers start here #
######################

__function_does_not_exist() {
  [ "$(type -t $1)" != "function" ]
}
