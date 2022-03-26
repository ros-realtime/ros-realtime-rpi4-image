.PHONY: focal-rt-ros2 clean

# TODO: eventually the build.py should be a command line script that takes
#       arguments
focal-rt-ros2:
	sudo python3 build.py

clean:
	sudo rm -rf out cache
