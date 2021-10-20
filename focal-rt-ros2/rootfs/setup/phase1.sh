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

# Remove some packages that are likely not needed:
# - snapd: no one packages their robot apps with snap, right?
# - fwupd: I don't think we need to update devices firmware like a logitech mouse, and it also uses like 20MB of RAM...
apt-get purge --autoremove -y snapd fwupd

# Install ROS2
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key  -o /usr/share/keyrings/ros-archive-keyring.gpg

sudo apt-get update
sudo apt-get install -y ros-galactic-ros-base

# Install some misc packages
apt-get install -y cpufrequtils libraspberrypi-bin