#!/bin/bash

set -xe

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y parted pv rsync wget systemd-container qemu-user-static make zip zstd xz-utils
