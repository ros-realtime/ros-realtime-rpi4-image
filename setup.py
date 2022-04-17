from setuptools import setup

setup(
  name="ros-realtime-rpi4-image-builder",
  version="0.1",
  description="ROS real-time image builder",
  author="Shuhao Wu",
  author_email="shuhao@shuhaowu.com",
  url="https://github.com/ros-realtime/ros-realtime-rpi4-image",
  packages=["image_builder"],
  scripts=["./build-ros-rt-img"],
)
