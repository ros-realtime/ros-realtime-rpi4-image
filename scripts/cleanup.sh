#!/bin/bash

# TODO: keep in sync with main.sh or refactor
CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CACHE_DIR=$(readlink -f "$CURDIR/../cache")

# This is a path where we mount the loop device on the host.
# TODO: keep this in sync with utils.sh or refactor
# TODO: make this easily changable
CHROOT_PATH=/tmp/rpi4-image-build

set -x

sudo umount -R $CHROOT_PATH

if [ -f "${CACHE_DIR}/session-loop-device.txt" ]; then
  sudo losetup -d $(cat "${CACHE_DIR}/session-loop-device.txt")
fi

sudo rm ${CACHE_DIR}/session.txt
sudo rm ${CACHE_DIR}/session-loop-device.txt
