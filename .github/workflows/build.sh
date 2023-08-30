#!/bin/bash

set -xe

make $1
sudo chown -R $(id -u):$(id -g) out

echo "Before compression:"
ls -lh out/

for img in out/*.img; do
  echo "  Shrimping $img"
  sudo pishrink $img
done

echo "After PiShrink:"
ls -lh out/

for img in out/*.img; do
  echo "  Compressing $img"
#   xz -9 $img
  xz --extreme --threads=0 -9 $img
done

echo "After compression:"
ls -lh out/
