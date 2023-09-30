.PHONY: focal-rt-ros2 jammy-rt-ros2 clean

# TODO: eventually the build.py should be a command line script that takes
#       arguments

jammy-rt-ros2:
	sudo -v ./ros-rt-img build jammy-rt jammy-rt-rolling
	sudo -v chown -R $$(id -u):$$(id -g) out cache

jammy-rt-ruediger2:
	sudo -v ./ros-rt-img build jammy-rt-rolling-ruediger
	sudo -v chown -R $$(id -u):$$(id -g) out cache

jammy-rt-stanley2:
	sudo -v ./ros-rt-img build jammy-rt-rolling-stanley
	sudo -v chown -R $$(id -u):$$(id -g) out cache

clean:
	sudo ./ros-rt-img teardown
	sudo rm -rf out cache
