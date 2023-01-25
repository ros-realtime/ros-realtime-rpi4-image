## To release a file 

Change the size of the image in config.ini
```
[build]
image_size = 12G
```

Generate the image from the master
```
make jammy-rt-ros2
```

Mount the image and connect to the image
```
sudo ./ros-rt-img mount out/ubuntu-22.04.1-rt-ros2-arm64+raspi.img
sudo ros-rt-img chroot
```

install other stuff
```
export ROS_DISTRO=humble

apt-get update && apt-get install -y ros-$ROS_DISTRO-joint-state-publisher ros-$ROS_DISTRO-xacro ros-$ROS_DISTRO-robot-localization ros-$ROS_DISTRO-joy ros-$ROS_DISTRO-teleop-twist-joy ros-$ROS_DISTRO-ros2-control ros-$ROS_DISTRO-ros2-controllers ros-$ROS_DISTRO-nav2-map-server ros-$ROS_DISTRO-nav2-amcl ros-$ROS_DISTRO-navigation2 ros-$ROS_DISTRO-nav2-bringup ros-$ROS_DISTRO-v4l2-camera ros-$ROS_DISTRO-image-transport-plugins ros-$ROS_DISTRO-image-tools ros-$ROS_DISTRO-image-common build-essential python3-colcon-common-extensions git libwiringpi-dev && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

cd /usr/local/lib
ln -fs /home/ruediger/deployement/serial_megapi/lib/serial_megapi/libserial_megapi.so libserial_megapi.so
ldconfig
```

Change config.txt
```
rm /boot/firmware/config.txt
touch /boot/firmware/config.txt
nano /boot/firmware/config.txt
```
```
[all]
kernel=vmlinuz
cmdline=cmdline.txt
initramfs initrd.img followkernel

[pi4]
max_framebuffers=2
arm_boost=1

[all]
# Enable the audio output, I2C and SPI interfaces on the GPIO header. As these
# parameters related to the base device-tree they must appear *before* any
# other dtoverlay= specification
dtparam=audio=on
dtparam=i2c_arm=on,i2c_arm_baudrate=400000
dtparam=spi=on

# Comment out the following line if the edges of the desktop appear outside
# the edges of your display
disable_overscan=1

# If you have issues with audio, you may try uncommenting the following line
# which forces the HDMI output into HDMI mode instead of DVI (which doesn't
# support audio output)
#hdmi_drive=2

# Enable the serial pins
enable_uart=1

# Autoload overlays for any recognized cameras or displays that are attached
# to the CSI/DSI ports. Please note this is for libcamera support, *not* for
# the legacy camera stack
camera_auto_detect=1
display_auto_detect=1

# Config settings specific to arm64
arm_64bit=1
dtoverlay=dwc2

[cm4]
# Enable the USB2 outputs on the IO board (assuming your CM4 is plugged into
# such a board)
dtoverlay=dwc2,dr_mode=host

[pi3]
dtoverlay=pi3-disable-bt

[all]
start_x=1
gpu_mem=256
dtoverlay=disable-bt
```

In cmdline delete serial0, 115200 
```
nano /boot/firmware/cmdline.txt
```

Change user-data to add the user ruediger and delete ubuntu
```
nano /boot/firmware/user-data
```
```
#cloud-config

# On first boot, set the (default) ruediger user's password to "ruediger" and
# expire user passwords
chpasswd:
  expire: true
  list:
  - ruediger:ruediger

## Set the system's hostname. Please note that, unless you have a local DNS
## setup where the hostname is derived from DHCP requests (as with dnsmasq),
## setting the hostname here will not make the machine reachable by this name.
## You may also wish to install avahi-daemon (see the "packages:" key below)
## to make your machine reachable by the .local domain
hostname: ruediger2

# Enable password authentication with the SSH daemon
ssh_pwauth: true

users:
- default
- name: ruediger
  plain_text_passwd: 'ruediger'
  homedir: /home/ruediger
  shell: /bin/bash
  groups: [ adm, audio, cdrom, dialout, floppy, video, plugdev, dip, netdev, sudo, lxd ]
  sudo: ['ALL=(ALL) NOPASSWD:ALL']


## Run arbitrary commands at rc.local like time
runcmd:
-  [deluser, --remove-home, ubuntu]
```

Exit container
```
exit
```

Close and umount everything
```
sudo ./ros-rt-img teardown
```

Make a copy of the output into release
```
mkdir release
cp out/ubuntu-22.04.1-rt-ros2-arm64+raspi.img release/ubuntu-22.04.1-rt-ruediger2-offline-v1.0-arm64+raspi.img
```

Use PiShrimp
```
sudo bash pishrink.sh release/ubuntu-22.04.1-rt-ruediger2-offline-v1.0-arm64+raspi.img
```

Compress Image
```
xz -9 release/ubuntu-22.04.1-rt-ruediger2-offline-v1.0-arm64+raspi.img
```




