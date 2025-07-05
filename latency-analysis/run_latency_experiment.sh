#!/bin/bash

set -e

sudo apt install -y htop tmux rt-tests stress-ng
mkdir -p data

duration=${1:-120m}

# We use tmux because this gives us a "free" no-hup, so benchmarking over SSH
# is easier.

session="rtbenchmark"

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

# Create new tmux session
tmux new-session -d -s $session
tmux send-keys -t $session:0 'clear' C-m
tmux send-keys -t $session:0 "sudo cyclictest --mlockall --smp --priority=80 --interval=200 -D $duration -H 400 --histfile=${filename}" C-m

# We want to create a layout like:
#
# +-----------+
# |     0     |
# +-----------+
# |  1  |  2  |
# +-----+-----+
#
# Panel 0 is cyclictest, panel 1 is stress, panel 2 is htop

tmux split-window -t $session:0 -v
tmux send-keys -t $session:0 'clear' C-m
tmux send-keys -t $session:0 'stress-ng -c $(nproc)' C-m
tmux split-window -t $session:0 -h
tmux send-keys -t $session:0 'clear' C-m
tmux send-keys -t $session:0 'htop' C-m

tmux attach -t $session
