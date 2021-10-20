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
# TODO: create systemd startup service to pin the CPU to a configurable
# frequency (via /etc/default/cpu-frequency)

# TODO: If specified, create an image with isolcpus already setup.

# Install ROS2
