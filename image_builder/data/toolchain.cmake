set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# TODO: this hard code is not great, but solving it comprehensively is kind of
# difficult (maybe dockcross? but that has its own drawbacks..)
set(CMAKE_SYSROOT /tmp/rpi4-image-build)
set(CMAKE_STAGING_PREFIX /tmp/rpi4-image-build) # This allows phase2 to install directly to the image

# Assume host compiler, is that OK if host gcc version doesn't match target system gcc?
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
