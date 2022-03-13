#!/usr/bin/env python3
import logging

from image_builder.builder import Builder

logging.basicConfig(format="[%(asctime)s][%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S", level=logging.DEBUG)

b = Builder(["focal-rt-ros2"])
b.build()

