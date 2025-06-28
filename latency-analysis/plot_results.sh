#!/bin/bash

modelstring=$(cat /sys/firmware/devicetree/base/model)

if echo "$modelstring" | grep -q 'Raspberry Pi 4'; then
  model=rpi4
elif echo "$modelstring" | grep -q 'Raspberry Pi 5'; then
  model=rpi5
elif echo "$modelstring" | grep -q 'Raspberry Pi 3 Model B+'; then
  # https://github.com/raspberrypi/linux/blob/ef8e31bd0d660ef06e98fcf6337d3374c8884038/arch/arm/boot/dts/broadcom/bcm2837-rpi-3-b-plus.dts#L12
  # match B+ first!
  model=rpi3b+
elif echo "$modelstring" | grep -q 'Raspberry Pi 3 Model B'; then
  model=rpi3b
else
  model=unknown
fi

filename="data/$(lsb_release -r | awk '{print $2}')_$(uname -r)_${model}.log"

set -xe

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get install -y python3-venv fonts-stix
if [ ! -f $HOME/latencytestvenv/bin/activate ]; then
  python3 -m venv ~/latencytestvenv
  source ~/latencytestvenv/bin/activate
  pip3 install -r requirements.txt
else
  source ~/latencytestvenv/bin/activate
fi


python3 cyclictest_latency_plotter.py $filename
