#!/bin/bash

filename="data/$(lsb_release -r | awk '{print $2}')_$(uname -r).log"

set -xe

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get install -y python3-pip fonts-stix
pip3 install -r requirements.txt --user
python3 cyclictest_latency_plotter.py $filename
