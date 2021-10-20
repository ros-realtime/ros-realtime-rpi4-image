#!/bin/bash

set -xe

make
sudo chown -R $(id -u):$(id -g) out
# The following takes too long on CI (20+ minutes, only 3 min on my computer,
# although I have like 8 times as many cores), so it is disabled until I can get
# a self-hosted runner.
#
# xz -T$(nproc) out/*.img # I can get a compress ratio of something like 6:1.
ls -lh out/