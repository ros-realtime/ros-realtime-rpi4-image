Image builder design and usage guide
====================================

Before reading this, please make sure you read the README of the project.

Overview
--------

The image builder's main workflow consists of the following few steps (see
`Builder.build()` in the code for more up-to-date details):

- Download and extract the vendor image.
- Mount the image via loop devices locally.
- Setup a "container" via `systemd-nspawn`. For images with foreign
  architecture (such as aarch64), qemu-user-static is copied to the mounts.
- Copy configuration files to the image.
- Run any setup scripts both outside the container and inside the container to
  customize the image (such as installing packages, or cross compiling).
- Cleanup the temporary files copied into the container and unmount everything.

This process is generic for most single board computers (SBC) where a flashable
image is provided by the vendor. The image builder allows one to configure this
process with by writing a set of well-defined ["build profiles
files"](#build-profile-format) without having to worry about book-keeping
tasks like mounting the image. This in principle should allow the builder to
build images not just for the Raspberry Pi, but for other SBCs as well.
Further, the design allow the build profile files to be overlaid on top
of each other, allowing for a common base profile to be built into
multiple image types. For example, we can use a common real-time Ubuntu base to
build images with different ROS2 distros without having to duplicate too much
code.

The builder also has time-saving features such as the ability to [pause and
resume](#pause-and-resume) at each step. For example, if one of the custom
setup scripts being executed fails, the builder will not cleanup right away.
This allows the developer to go into the container and experiment. In my
experience, this drastically cuts down on the development time for this kind of
image-building work. See [here for tips and tricks on how to debug and work on
this setup in a time-efficient manner](#tips-and-tricks).

Build profile format
--------------------------

The build profile is defined as a directory in which contains the following
structure:

- `config.ini`: Specifies the [build config](#configini).
- `scripts/`
  - `extract-image`: This script extracts the image downloaded. It's not
    easy to generically infer how to extract an image, so this is parameterized
    as a script.
  - `loop-device-setup`: This script performs setup on the host against the
    loop device after it is setup by the builder. A common list of operations
    done here is to `fsck` the file system of the rootfs and resize it to the
    maximum allocated size as per config.ini via `resize2fs`.
  - `phase1-host`: Optional. This scripts runs on the host machine immediately
    after the image is mounted and ready to go.
  - `phase1-target`: Optional. This script runs in the image via
    `systemd-nspawn` after the `phase1-host`. For example, you can install
    packages in the image by calling `apt`.
  - `phase2-host`: Optional. This scripts runs on the host after
    `phase1-target`. An example usage of this would be to perform cross
    compilation.
  - `phase2-target`: Optional. This script runs in the image via
    `systemd-nspawn` after `phase2-host`.
- `rootfs/`: Any files and directory within this directory will be copied to
  the root of the image being built. The copy of files occur before any of the
  phase1/phase2 scripts are executed.

A full example of this directory can be seen in [`focal-rt`](../focal-rt).

### `config.ini`

This file specifies the build profile under the section `[build]`. This section
contains the following variables:

- `image_url`: string. The URL of the image to be downloaded by the builder.
- `image_mounts`: string. A comma separated list of the partition's mount
  point. Mounting occurs in the reverse order by the builder, because usually
  the / mount point is the last partition and it needs to be mounted first.
- `image_size`: string. This is passed to `truncate --size=<image_size>
  <path to .img file>` and is needed because sometimes the vendor image is too
  small.
- `output_filename`: string. The output image file name (not path, just the
  file name).

There's another section in this file, `[env]`, which are a list of environment
variables that will be passed to [all scripts](#phase-1-and-phase-2-scripts)
called during the build process.

### Phase 1 and Phase 2 scripts

As noted above, there are 4 scripts that are called. These scripts are called
with the environment variables specified in `config.ini` and a few additional
variables:

- `CHROOT_PATH`: the path of the mounted image seen from the host.
- `OUT_DIR`: the directory of the output file.
- `CACHE_DIR`: a place to put cached data.

Typically, the scripts may be structured as follows:

1. `phase1-host`: downloads additional dependencies from the internet and
   copies it to the image via `CHROOT_PATH`.
2. `phase1-target`: installs dependencies within the image.
3. `phase2-host`: Perform cross compilation with `$CHROOT_PATH` as the sysroot.
4. `phase2-target`: Perform any additional setup is needed after the cross
   compilation has been installed.

### Overlaying multiple build profiles

The builder is designed for the layering of build profiles. This works by
telling the builder to build with a list of profile directories. The builder
will then:

- Merge the variables inside `config.ini`, where variables from later profiles
  overrides the ones from earlier ones.
- Copy `rootfs` files from each build profile in sequential order. Later
  profiles can override files from earlier ones.
- Run the phase1/phase2 scripts in sequential order. For example, when running
  the phase1 host scripts, the builder will run the script from the first
  profile, then the second, then the third, and so on.

### Phase 2 cross-compilation

If you want a custom image with a custom library/application, you can
cross-compile it in phase2. This is done via a cross compilation toolchain
installed on the host machine. An example of this is given in
[`image_builder/data/example-cross-compile`](../image_builder/data/example-cross-compile).
This is an example profile that can be overlaid ontop of any image and will
cross-compile and install a C++ project. Please read this profile if you're
interested in creating your own profile. Most C++ projects will follow a
similar structure to it:

1. The [`phase1-target`](../image_builder/data/example-cross-compile/scripts/phase1-target)
   script installs the build and runtime dependency for the
   project you're trying to cross compile into the target image.
2. The [`phase2-host`](../image_builder/data/example-cross-compile/scripts/phase2-host)
   script downloads the C++ project and calls to cmake. The
   `CMAKE_TOOLCHAIN_FILE` is already passed to this script and points to
   [`image_builder/data/toolchain.cmake`](../image_builder/data/toolchain.cmake)
   so you shouldn't need to do anything special.

Note: to run this successfully, you need to install the package
`gcc-aarch64-linux-gnu g++-aarch64-linux-gnu` on your host system. This is
because the toolchain file assumes your cross-compiler is at
`/usr/bin/aarch64-linux-gnu-{gcc,g++}`.

To run the example profile, build an image via the command:

```
sudo ./ros-rt-img build jammy-rt jammy-rt-humble example-cross-compile
```

This will install a few executable to the target image that will run on the
Raspberry Pi.

- `/bin/rt_simple_example`
- `/bin/rt_message_passing_example`
- `/bin/rt_mutex_example`
- `/bin/rt_lttng_ust_example`

Pause and resume
----------------

The builder can pause after each step defined in the code (see
`Builder.build()` and `./ros-rt-img build --pause-after`). If a step fails, the
builder won't cleanup anything to give the developer a chance to debug and fix
things manually before continuing. The way this works is with two files:

- `cache/session.txt`: contains a list of steps executed, one per line. You can
  freely change this file if you know what you're doing to selectively
  execute/skip steps when working with this system. 
  - If this file is removed, then the builder will restart from scratch.
- `cache/session-loop-device.txt`: This saves the loop device the chroot is
  mounted to, since the loop devices may be different each time we run this.

Tips and tricks
---------------

If you ever used tools like Ansible, or Packer, you will know that a lot of the
times, to fix a simple typo, you will have to wait for the entire script to run
from the beginning, taking up valuable time. With the ability to pause and
resume, the workflow I take with this repo is as follows:

1. Edit the build scripts. Run them.
2. Encounter an error.
3. Manually go into the chroot via systemd-nspawn.
4. Figure out the right commands to run and change the script.
5. Change `cache/session.txt` to make sure I can resume from the right spot (by
   removing and adding steps into the file, see below).
6. Run the builder again.
7. When all the problems are worked out, run the builder from the beginning to
   ensure it works for a fresh build.

While this is not a perfect process, it can save a lot of time.

To get into the chroot to experiment, run the command:

```
$ sudo systemd-nspawn -D /tmp/rpi4-image-build/ bash # the path is whatever CHROOT_PATH is
```

At some point, we can refactor the command above into the builder directly.

### How to reset your host system if something horribly goes wrong

THIS IS OUTDATED and the functionality need to be restored.

- Try running `./scripts/cleanup.sh`
- Try running the commands in `umount_everything` manually (see
  `builder/core.sh`).
  - Can do this by adding every step in `builder/main.sh` into
  `cache/session.txt` except the umount everything step.
  - TODO: I should create simpler command to run this step only.
- If that doesn't work, try restarting your computer :(.
