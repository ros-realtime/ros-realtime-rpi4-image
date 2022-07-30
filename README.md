Custom Image Builder for the Raspberry Pi 4 for ROS2 + PREEMPT_RT
=================================================================

[![Build image](https://github.com/ros-realtime/ros-realtime-rpi4-image/actions/workflows/build.yml/badge.svg)](https://github.com/ros-realtime/ros-realtime-rpi4-image/actions/workflows/build.yml)

This is a custom image builder for the Raspberry Pi 4. Some features:

- Customize the official Ubuntu server image for the Raspberry Pi by mounting
  it locally (via loop device) and chrooting into it (via systemd-nspawn and
  qemu-user-static).
  - I can't locate how Canonical generate the official Ubuntu images for the
    Raspberry Pi, so I had to resort to this method.
  - The default customization in this repo is made for ROS2 with `PREEMPT_RT`
    applied.
- With two stages of setup scripts, executing in lock step both inside and
  outside the chroot, we can cross compile code (via something like CMake
  toolchain) on the host and copy it into the chroot for making the final
  image.
- One thing we all hate while building images is to waste a lot of time. These
  scripts are designed to hopefully not waste your time. It has several
  features for this:
  - The build process is divided into resumable steps. This means there is no
    need (in most cases) to restart the build from scratch if you make a
    mistake. You can experiment with the image as it builds either by
    deliberately pausing the build process after a certain step or be forced to
    pause because there are some typos in the build scripts.
  - Nice logs that aids with debugging of the build, should things go wrong.
  - Use tools like `pv` to display progress when applicable.
- The features of the actual RT image is difficult to document without becoming
  out of date quickly. Please take a look at `focal-rt-ros2/ros2/rootfs/setup/phase1.sh`
  for the setup script that runs against the Ubuntu image and `focal-rt-ros2/rootfs`
  for files that gets overlaid on top of the Ubuntu image. That said, some basics are:
  - Installed [`PREEMPT_RT` kernel](https://github.com/ros-realtime/rt-kernel-docker-builder).
  - Pinned CPU frequency and performance governor.
  - Removed some unnecessary services like snapd and fwupd to save resources.
  - Installed ROS2 galactic from apt.
  - Installed some misc. tooling (like `vcgencmd`).

### Todos

- [ ] Optionally configure isolcpus and nohz_full for the kernel.
- [ ] Use a sha256 checksum to ensure downloaded image and kernel are "secure".
- [ ] Add overclocking support

How to use
----------

### System requirements

**Why not docker?** Unfortunately, the current setup doesn't work in Docker, as 
I used `systemd-nspawn` to make setting up and executing commands in a chroot easier
(mainly so I can save some time figuring out the various bind mounts I need, to
shutdown the container correctly if a command fails, and to force quit a
container if something goes really wrong by pressing ^] 3 times).  This tool
also rely on loop devices, which are not namespaced and thus not readily usable
in Docker without privileged access. It may be possible to use Docker later by
changing this code, but for now it's not possible (the code will also likely be
uglier as nspawn can't be easily used in docker?).

Thus, you'll need a Linux machine with root and the following tools installed:
`cut`, `grep`, `parted`, `pv`, `rsync`, `truncate`, `wget`, `systemd-nspawn`,
and `qemu-aarch64-static`.

You will also need `python3`.

To build the `focal-rt-ros2` image, you'll also need: `zip`.

For Ubuntu, you can simply run:

```
$ sudo apt install parted pv rsync wget systemd-container qemu-user-static make zip
```

### To run

```
$ make focal-rt-ros2
```

This will build the image to `build/ubuntu-20.04.3-rt-ros2-galactic-arm64+raspi.img`. 
You can then `dd` this to a SD card.

You can see a demo of this in [CI](https://github.com/shuhaowu/ros-realtime-rpi4-image/actions). CI builds quite slowly. On my computer this whole process only takes a few minutes.

Customization guide
-------------------

See [`docs/BuilderDesignAndUsageGuide.md`](docs/BuilderDesignAndUsageGuide.md).
