#!/bin/bash

set -e -o pipefail

# This is the vars.sh file copied into the container, so we can get some custom
# variables here (such as LINUX_RT_VERSION).
source /vars.sh

# Setting up PREEMPT_RT kernel
cd /setup
sudo dpkg -i linux-*.deb

ln -s -f /boot/vmlinuz-${LINUX_RT_VERSION_ACTUALLY} /boot/vmlinuz
ln -s -f /boot/initrd.img-${LINUX_RT_VERSION_ACTUALLY} /boot/initrd.img

cp /boot/vmlinuz /boot/firmware/vmlinuz
cp /boot/vmlinuz /boot/firmware/vmlinuz.bak
cp /boot/initrd.img /boot/firmware/initrd.img
cp /boot/initrd.img /boot/firmware/initrd.img.bak

# Disable ondemand govenor and set constant frequency
systemctl disable ondemand
systemctl enable cpu-frequency

# TODO: If specified, create an image with isolcpus already setup.

export DEBIAN_FRONTEND=noninteractive

# Remove snapd as it is not really needed most of the time
apt-get purge --autoremove -y snapd

# Install some misc packages
apt-get install -y cpufrequtils

# Install ROS2
