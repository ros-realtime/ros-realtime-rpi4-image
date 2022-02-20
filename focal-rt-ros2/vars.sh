#!/bin/bash

# pwd should always be the root of this repository when builder/main.sh is called.
curdir=$(pwd)/focal-rt-ros2

####################
# Custom variables #
####################

# These variables will be forwarded to all the phase1 phase2 scripts if they
# are exported.

export LINUX_RT_VERSION=5.4.106-rt54
export LINUX_RT_VERSION_ACTUALLY=5.4.140-rt64 # This is a bug, the release tag should match the content, but it doesn't
export STOCK_LINUX_VERSION=5.4.0-1042 # This is the linux version that stock ubuntu comes with that we can uninstall.

export PINNED_CPU_FREQUENCY=1500000
# export CMAKE_TOOLCHAIN_FILE=$(pwd)/aarch64.cmake

###################
# Build Variables #
###################
#
# All the build variables are supposed to be set in this section.

# Do not set -x if VERBOSE is not set or set to no.
VERBOSE=${VERBOSE:-no}

# The image url to download and customize.
# shellcheck disable=SC2034
IMAGE_URL="https://cdimage.ubuntu.com/releases/20.04.3/release/ubuntu-20.04.3-preinstalled-server-arm64+raspi.img.xz"

# The partition number of the rootfs. Partition number starts at 0.
# TODO: This should always be the last partition, otherwise resize won't work.
# Need the resize because the default image has a very small paritition whereas
# ROS is big and we need to add some temporary files.
# shellcheck disable=SC2034
IMAGE_ROOTFS_PARTITION_NUM=2

# Mount location for the partitions in the image file downloaded from canonical.
# shellcheck disable=SC2034
IMAGE_PARTITION_MOUNTS=(
  "/boot/firmware"
  "/"
)

# This is passed to truncate --size=$IMAGE_SIZE when operating against the .img file.
# TODO: Note that always the last partition will be expanded as I just call truncate for now.
# shellcheck disable=SC2034
IMAGE_SIZE=4G

# Absolute path of the output image on the host.
# shellcheck disable=SC2034
OUTPUT_FILENAME=$(pwd)/out/ubuntu-20.04.3-rt-ros2-galactic-arm64+raspi.img

# Absolute to the location of the rootfs on the host that will be copied into
# the chroot and therefore the final image.
#
# Note: This is in rsync format, so must have a trailing slash if you want to
# actually merge the content into the rootfs and not create another subdirectory.
# shellcheck disable=SC2034
ROOTFS_OVERLAY=${curdir}/rootfs/

#################
# Setup scripts #
#################

# Host side setup scripts #
# ----------------------- #

# Absolute paths to the scripts that runs in phase1 and phase 2 on the host
# that runs on the host.

# Phase 1 is generally for fetching prebuilt binaries and copying them into the
# chroot. Basically any files that cannot be put in the ROOTFS_OVERLAY should
# be generated and copied in this step.
# shellcheck disable=SC2034
SETUP_PHASE1_OUTSIDE_CHROOT=${curdir}/phase1-outside.sh

# Phase 2 is generally for cross compiling (such as via CMake), because the
# rootfs should already be setup with all the dependencies at this point.
# shellcheck disable=SC2034
# SETUP_PHASE2_OUTSIDE_CHROOT=$(pwd)/phase2-outside.sh # don't need it for this

# Chroot-side setup scripts #
# ------------------------- #

# Absolute path to the scripts that runs in phase1 and phase2 in the chroot
# that runs inside the chroot.
#
# Note: Put these scripts in the ROOTFS_OVERLAY as the copy of the overlay
# happens before these scripts fires.

# Phase 1 is generall for installing packages.
SETUP_PHASE1_INSIDE_CHROOT=/setup/phase1.sh

# Phase 2 is for removing files in the chroot that are placed to help with the
# setup of the image.
# shellcheck disable=SC2034
SETUP_PHASE2_INSIDE_CHROOT=/setup/phase2.sh

# Path to qemu-user-static on the host, which will be copied into the chroot to
# the same path.
# shellcheck disable=SC2034
QEMU_USER_STATIC_PATH=/usr/bin/qemu-aarch64-static

# Uncomment and change this if you want the builder to pause after a particular
# step to debug/experiment.
# PAUSE_AFTER=setup_script_phase1_inside_chroot

######################
# Override functions #
######################
#
# Some functions needs to be overwritten, such as how to extract and
# verify the images, custom verification before build starts, etc.

# A function that decompresses the image. The first argument given is
# the path to the image. This should decompress it into stdout.
#
# Verification can be optionally performed, such as with sha256sum.
custom_extract_image() {
  xzcat --decompress $1
}

# Each image may be slightly different, but maybe we can put this code directly in core.sh.
custom_loop_device_setup() {
  local loop_device=$1

  e2fsck -y -f ${loop_device}p2
  resize2fs ${loop_device}p2
}
