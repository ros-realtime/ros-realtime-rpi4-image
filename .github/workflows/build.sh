#!/bin/bash

set -xe

make
sudo chown -R $(id -u):$(id -g) out
xz -T$(nproc) out/*.img
ls -l out/