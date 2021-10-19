.PHONY: focal-rt-ros2 clean

focal-rt-ros2:
	sudo builder/main.sh focal-rt-ros2/vars.sh

clean:
	sudo rm -rf out cache
