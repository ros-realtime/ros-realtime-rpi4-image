.PHONY: focal-rt-ros2 jammy-rt-ros2 clean

# TODO: eventually the build.py should be a command line script that takes
#       arguments
focal-rt-ros2:
	sudo ./ros-rt-img build

focal-rt-ruediger:
	sudo ./ros-rt-img build focal-rt focal-rt-noetic

jammy-rt-ros2:
	sudo ./ros-rt-img build jammy-rt jammy-rt-rolling

jammy-rt-ruediger2:
	sudo ./ros-rt-img build jammy-rt-humble-ruediger

clean:
	sudo ./ros-rt-img teardown
	sudo rm -rf out cache
