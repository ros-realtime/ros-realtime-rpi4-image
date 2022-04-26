.PHONY: focal-rt-ros2 clean

# TODO: eventually the build.py should be a command line script that takes
#       arguments
focal-rt-ros2:
	sudo ./ros-rt-img build

clean:
	sudo rm -rf out cache
