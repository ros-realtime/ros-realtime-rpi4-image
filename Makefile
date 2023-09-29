.PHONY: focal-rt-ros2 jammy-rt-ros2 clean

jammy-rt-ros2:
	sudo ./ros-rt-img build jammy-rt jammy-rt-humble

# TODO: eventually the build.py should be a command line script that takes
#       arguments
focal-rt-ros2:
	sudo ./ros-rt-img build

focal-rt-ruediger:
	sudo ./ros-rt-img build focal-rt focal-rt-noetic

jammy-rt-ros2:
	sudo ./ros-rt-img build jammy-rt jammy-rt-rolling
	sudo chown -R $$(id -u):$$(id -g) out cache

jammy-rt-ruediger2:
	sudo ./ros-rt-img build jammy-rt-rolling-ruediger
	sudo chown -R $$(id -u):$$(id -g) out cache

jammy-rt-stanley2:
	sudo ./ros-rt-img build jammy-rt-rolling-stanley
	sudo chown -R $$(id -u):$$(id -g) out cache

clean:
	sudo ./ros-rt-img teardown
	sudo rm -rf out cache
