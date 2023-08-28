#!/bin/bash

set -xe

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y parted pv rsync wget systemd-container qemu-user-static make zip xz-utils

wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
chmod +x pishrink.sh
sudo mv pishrink.sh /usr/local/bin