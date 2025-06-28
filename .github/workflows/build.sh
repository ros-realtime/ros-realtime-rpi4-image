#!/bin/bash

set -xe

make $1
sudo chown -R $(id -u):$(id -g) out

echo "Before compression:"
ls -lh out/
cd out

echo "After compression:"
time zstd -12 *.img
ls -lh .
