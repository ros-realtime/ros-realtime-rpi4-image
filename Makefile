.PHONY: focal-rt-ros2 clean

focal-rt-ros2:
	sudo builder/main.sh focal-rt-ros2/vars.sh

clean:
	./builder/cleanup.sh
	sudo rm -rf out cache
