#!/usr/bin/env bash

set -euo pipefail

sudo apt update
sudo apt install pv systemd-container qemu-user-static -y