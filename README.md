Custom Image Builder for the Raspberry Pi 4 for ROS2 + PREEMPT_RT
=================================================================

This is a custom image builder for the Raspberry Pi 4. Some features:

- Technically customizable to build any custom image, although by default this
  provides configuration for ROS 2 + PREEMPT_RT.
- If errors are made in the development of the setup scripts here, rebuilding
  doesn't take 20 minutes as the system will not repeat previous steps.
  - Obviously this doesn't work in all cases, so the system also offers a way
    to provide a clean rebuild.
- The ability to use cmake to cross compile code after an initial rootfs is
  created.

The way it works:

- Download the prebuilt Ubuntu server image.
- Mount it in a loop device.
- Chroot into it with qemu-user-static.
- Copy files to customize.
- Run scripts inside and outside the chroot.
- Cleanup
- Unmount everything

In the future, maybe it's better to figure out how Canonical generate their
official Ubuntu images. However, I can't find how they built their images when
I looked.
