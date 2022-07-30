#!/bin/bash

set -e

sudo apt install -y htop tmux rt-tests stress-ng
mkdir -p data

duration=${1:-120m}

# We use tmux because this gives us a "free" no-hup, so benchmarking over SSH
# is easier.

session="rtbenchmark"
filename="data/$(lsb_release -r | awk '{print $2}')_$(uname -r).log"

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
