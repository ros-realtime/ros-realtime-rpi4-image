download_and_extract_image_if_necessary() {
  if [ ! -f $DOWNLOAD_CACHE_PATH ]; then
    wget -O $DOWNLOAD_CACHE_PATH $IMAGE_URL
  fi

  mkdir -p $(dirname $OUTPUT_FILENAME)
  log_in_step "extracting $(basename $DOWNLOAD_CACHE_PATH) into $OUTPUT_FILENAME"
  custom_extract_image $DOWNLOAD_CACHE_PATH | pv > $OUTPUT_FILENAME
}

setup_loop_device_and_mount_partitions() {
  log_in_step "expanding image to $IMAGE_SIZE with truncate"
  truncate -s $IMAGE_SIZE $OUTPUT_FILENAME

  local partition_end_in_mb=$(parted $OUTPUT_FILENAME print | grep $(basename $OUTPUT_FILENAME) | cut -f 2 -d ":" | grep -o '[0-9]\+')
  log_in_step "growing partition ${IMAGE_ROOTFS_PARTITION_NUM} to end at ${partition_end_in_mb}MB"
  parted $OUTPUT_FILENAME resizepart ${IMAGE_ROOTFS_PARTITION_NUM} ${partition_end_in_mb}

  # global var
  g_loop_device=$(losetup -P --show -f $OUTPUT_FILENAME)
  echo $g_loop_device > $SESSION_LOOP_DEVICE_FILE

  if ! __function_does_not_exist "custom_loop_device_setup"; then
    log_in_step "calling custom_loop_device_setup $g_loop_device"
    custom_loop_device_setup $g_loop_device
  fi
}

prepare_chroot() {
  if [ -z "$g_loop_device" ]; then
    g_loop_device=$(cat $SESSION_LOOP_DEVICE_FILE)
  fi

  if [ -z "$g_loop_device" ]; then
    echo "error: g_loop_device not found in session file ($SESSION_LOOP_DEVICE_FILE)" >&2
    exit 1
  fi

  if [ -z "$CHROOT_PATH" ]; then
    echo "error: whoa, CHROOT_PATH is nothing" >&2
    exit 1
  fi

  if [ "$CHROOT_PATH" == "/" ]; then
    echo "error: whoa, CHROOT_PATH is /" >&2
    exit 1
  fi

  mkdir -p $CHROOT_PATH

  # mount rootfs first
  local partnum="${IMAGE_ROOTFS_PARTITION_NUM}"
  local partmount="${CHROOT_PATH}/"
  log_in_step "mounting partition ${partnum} to ${partmount}"

  mount ${g_loop_device}p${partnum} $partmount

  for i in "${!IMAGE_PARTITION_MOUNTS[@]}"; do # loop with index
    partnum=$((i+1))
    if [ "$partnum" == "$IMAGE_ROOTFS_PARTITION_NUM" ]; then
      continue
    fi

    partmount=${CHROOT_PATH}${IMAGE_PARTITION_MOUNTS[$i]}
    log_in_step "mounting partition ${partnum} to ${partmount}"

    mount ${g_loop_device}p${partnum} $partmount
  done

  log_in_step "copying resolv.conf and qemu-user-static"
  mv ${CHROOT_PATH}/etc/resolv.conf ${CHROOT_PATH}/etc/resolv.conf.bak
  echo "nameserver ${NAMESERVER}" >> ${CHROOT_PATH}/etc/resolv.conf

  cp ${QEMU_USER_STATIC_PATH} ${CHROOT_PATH}${QEMU_USER_STATIC_PATH}
}

copy_files_to_chroot() {
  rsync -ar --stats $ROOTFS_OVERLAY $CHROOT_PATH
}

setup_script_phase1_outside_chroot() {
  if [ -n "$SETUP_PHASE1_OUTSIDE_CHROOT" ]; then
    log "running $SETUP_PHASE1_OUTSIDE_CHROOT"
    $SETUP_PHASE1_OUTSIDE_CHROOT
  else
    log "no outside-chroot-phase1 script defined, skipping..."
  fi
}

setup_script_phase1_inside_chroot() {
  if [ -n "$SETUP_PHASE1_INSIDE_CHROOT" ]; then
    log "running $SETUP_PHASE1_INSIDE_CHROOT inside chroot"
    systemd-nspawn -D $CHROOT_PATH "$SETUP_PHASE1_INSIDE_CHROOT"
  else
    log "no inside-chroot-phase1 script defined, skipping..."
  fi
}

setup_script_phase2_outside_chroot() {
  if [ -n "$SETUP_PHASE2_OUTSIDE_CHROOT" ]; then
    log "running $SETUP_PHASE2_OUTSIDE_CHROOT"
    $SETUP_PHASE2_OUTSIDE_CHROOT
  else
    log "no outside-chroot-phase2 script defined, skipping..."
  fi
}

setup_script_phase2_inside_chroot() {
  if [ -n "$SETUP_PHASE2_INSIDE_CHROOT" ]; then
    log "running $SETUP_PHASE2_INSIDE_CHROOT inside chroot"
    systemd-nspawn -D $CHROOT_PATH "$SETUP_PHASE2_INSIDE_CHROOT"
  else
    log "no inside-chroot-phase2 script defined, skipping..."
  fi
}

cleanup_chroot() {
  log_in_step "cleaning up resolv.conf and qemu-user-static"
  rm ${CHROOT_PATH}/etc/resolv.conf
  mv ${CHROOT_PATH}/etc/resolv.conf.bak ${CHROOT_PATH}/etc/resolv.conf
  rm ${CHROOT_PATH}${QEMU_USER_STATIC_PATH}
}

umount_everything() {
  log_in_step "unmounting everything"
  if [ -z "$g_loop_device" ]; then
    g_loop_device=$(cat $SESSION_LOOP_DEVICE_FILE)
  fi

  umount -R $CHROOT_PATH
  losetup -d $g_loop_device
}

