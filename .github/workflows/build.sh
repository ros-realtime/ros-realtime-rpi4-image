#!/bin/bash

set -xe

make
sudo chown -R $(id -u):$(id -g) out

echo "Before compression:"
ls -lh out/
cd out

echo "After compression:"
pigz *.img
ls -lh .
