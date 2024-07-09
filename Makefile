.PHONY: focal-rt-ros2 jammy-rt-ros2 focal-rt-ros clean

jammy-rt-ros2:
	sudo ./ros-rt-img build jammy-rt jammy-rt-humble

# TODO: eventually the build.py should be a command line script that takes
#       arguments
focal-rt-ros2:
	sudo ./ros-rt-img build focal-rt focal-rt-galactic

focal-rt-ros:
	sudo ./ros-rt-img build focal-rt focal-rt-noetic

clean:
	sudo ./ros-rt-img teardown
	sudo rm -rf out cache
