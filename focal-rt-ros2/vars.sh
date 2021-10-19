###################
# Build Variables #
###################
#
# All the build variables are supposed to be set in this section.

# Do not set -x if VERBOSE is not set or set to no.
VERBOSE=${VERBOSE:-no}

# The image url to download and customize.
IMAGE_URL="https://cdimage.ubuntu.com/releases/20.04.3/release/ubuntu-20.04.3-preinstalled-server-arm64+raspi.img.xz"

# The partition number of the rootfs. Partition number starts at 0.
# TODO: This should always be the last partition, otherwise resize won't work.
# Need the resize because the default image has a very small paritition whereas
# ROS is big and we need to add some temporary files.
IMAGE_ROOTFS_PARTITION_NUM=2

# Mount location for the partitions in the image file downloaded from canonical.
IMAGE_PARTITION_MOUNTS=(
  "/boot/firmware"
  "/"
)

# This is passed to truncate --size=$IMAGE_SIZE when operating against the .img file.
# TODO: Note that always the last partition will be expanded as I just call truncate for now.
IMAGE_SIZE=4G

# Absolute path of the output image on the host.
OUTPUT_FILENAME=$(pwd)/out/ubuntu-20.04.3-rt-ros2-galactic-arm64+raspi.img

# Absolute to the location of the rootfs on the host that will be copied into
# the chroot and therefore the final image.
#
# Note: This is in rsync format, so must have a trailing slash if you want to
# actually merge the content into the rootfs and not create another subdirectory.
ROOTFS_OVERLAY=$(pwd)/focal-rt-ros2/rootfs/

#################
# Setup scripts #
#################

# There are four setup scripts:

# Absolute paths to the scripts that runs in phase1 and phase 2 on the host
# that runs on the host.
# SETUP_PHASE1_OUTSIDE_CHROOT=$(pwd)/phase1-outside.sh
# SETUP_PHASE2_OUTSIDE_CHROOT=$(pwd)/phase2-outside.sh # don't need it

# Absolute path to the scripts that runs in phase1 and phase2 in the chroot
# that runs inside the chroot.
#
# Note: Put these scripts in the ROOTFS_OVERLAY as the copy of the overlay
# happens before these scripts fires.
SETUP_PHASE1_INSIDE_CHROOT=/setup/phase1.sh
SETUP_PHASE2_INSIDE_CHROOT=/setup/phase2.sh

# Path to qemu-user-static on the host, which will be copied into the chroot to
# the same path.
QEMU_USER_STATIC_PATH=/usr/bin/qemu-aarch64-static

# Uncomment this if you want the builder to pause to debug things.
# PAUSE_AFTER=setup_script_phase2_outside_chroot

####################
# Custom variables #
####################

# These variables will be forwarded to all the phase1 phase2 scripts if they
# are exported.

# export CMAKE_TOOLCHAIN_FILE=$(pwd)/aarch64.cmake

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

  e2fsck -f ${loop_device}p2
  resize2fs ${loop_device}p2
}

