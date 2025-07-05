Release an image
================

To release an image:

1. Build the image locally on a clean branch with a clean build (`make clean`)
2. Flash the image to an SD card and boot it on a Raspberry Pi 4.
3. Clone this repository.
4. Run the latency experiment on the Raspberry Pi 4 with the built image:

```
$ git clone https://github.com/ros-realtime/ros-realtime-rpi4-image.git
$ cd ros-realtime-rpi4-image/latency-analysis
$ ./run_latency_experiment.sh
```

5. Wait for about 2 hours for the experiments to complete (the default
   `cyclictest` duration is 2 hours for now). This will save test results into
   the `data` folder as a `.log` file. You can detach the tmux session by
   pressing the key sequence: `CTRL+b`, then `d`. To get back into this
   session, run `tmux attach` once you connect back to the Raspberry Pi 4.
6. In the same directory as above, run `./plot_latency.sh`. This will generate
   a PNG file from the test results.
7. Copy these files back to your local machine and commit them in the git repo.
8. Create a PR with these files. Ping for reviews and merge the PR.
9. Create a tag based on this, named
   `{ubuntu_version}_v{kernel_version}_ros2_{ros_release}`. The kernel version is an example is:
   `22.04.1_v5.15.39-rt42-raspi_ros2_humble`. The `ubuntu_version` is based on
   the version string of the image we download, and the `kernel_version` is the
   output of `uname -r`.
10. Push the tag to the repo.
11. Take the image you built, `zstd` it via the command: `cd out; sudo zstd -k -12 ubuntu-22.04.1-rt-ros2-arm64+raspi.img`.
12. [Create a release based on the tag](https://github.com/ros-realtime/ros-realtime-rpi4-image/releases/new). Upload the compressed image. Follow the below template for the release notes:

```
ROS 2 {ros_release} image for the Raspberry Pi 3/4/4 with the real-time kernel (`PREEMPT_RT`).

### Settings

- ROS: {ros_release}
- Ubuntu: {ubuntu_version}
- Kernel version: {kernel_version}
- LTTNG version: {lttng_version}
- Kernel config: [config-fragment](https://github.com/ros-realtime/linux-real-time-kernel-builder/blob/{hash}/.config-fragment)

### Benchmarks

| Model | Result |
| ----- | ------ |
| Raspberry Pi 3 | <img src=https://github.com/ros-realtime/ros-realtime-rpi4-image/raw/master/latency-analysis/data/{file.png} width=600 /> |
| Raspberry Pi 4 | <img src=https://github.com/ros-realtime/ros-realtime-rpi4-image/raw/master/latency-analysis/data/{file.png} width=600 /> |
| Raspberry Pi 5 | <img src=https://github.com/ros-realtime/ros-realtime-rpi4-image/raw/master/latency-analysis/data/{file.png} width=600 /> |

### Checksum 

- ubuntu-24.04.2-rt-ros2-arm64+raspi.img.zst: 69799c9388c6be5b6703b5c7954ad2c926c466e53108873e3f2bc0593968939b  
```


And you're done!
