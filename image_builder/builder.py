from __future__ import annotations

from collections.abc import Sequence
import configparser
import logging
import os
import os.path
import shutil
import subprocess
from typing import Callable


class RequirementNotMetError(RuntimeError):
  pass


class Builder(object):
  def __init__(self,
               profile_dirs: Sequence[str],
               cache_dir: str = "cache",
               out_dir: str = "out",
               chroot_path: str = "/tmp/rpi4-image-build"):
    self.logger = logging.getLogger("builder")

    self.cache_dir = cache_dir
    self.out_dir = out_dir
    self.chroot_path = chroot_path
    self.session_file = os.path.join(self.cache_dir, "session.txt")
    self.session_loop_device_file = os.path.join(self.cache_dir, "loop-device.txt")

    self.build_vars = {}
    self.env_vars = {
      "CACHE_DIR": os.path.abspath(self.cache_dir),
      "OUT_DIR": os.path.abspath(self.out_dir),
      "CHROOT_PATH": os.path.abspath(self.chroot_path),
    }

    self.phase1_host_paths = []
    self.phase2_host_paths = []
    self.phase1_target_paths = []
    self.phase2_target_paths = []

    self.rootfs_paths = []
    self.extract_image_path = None
    self.loop_device_setup_path = None

    self.profile_dirs = profile_dirs

    for profile_dir in profile_dirs:
      if not os.path.isdir(profile_dir):
        builtin_profile_dir = os.path.join(os.path.abspath(os.path.dirname(__file__)), "data", profile_dir)
        if not os.path.isdir(builtin_profile_dir):
          raise RequirementNotMetError(f"Cannot find {profile_dir}")

        profile_dir = builtin_profile_dir

      self.logger.debug(f"Found profile {profile_dir}")

      # Merge configuration
      build_vars, env_vars = self._parse_config(os.path.join(profile_dir, "config.ini"))
      self.build_vars.update(build_vars)
      self.env_vars.update(env_vars)

      # Add files. Simple code for now
      phase1_host_path = os.path.join(profile_dir, "scripts", "phase1-host")
      if os.path.isfile(phase1_host_path):
        self.phase1_host_paths.append(phase1_host_path)

      phase2_host_path = os.path.join(profile_dir, "scripts", "phase2-host")
      if os.path.isfile(phase2_host_path):
        self.phase2_host_paths.append(phase2_host_path)

      phase1_target_path = os.path.join(profile_dir, "scripts", "phase1-target")
      if os.path.isfile(phase1_target_path):
        self.phase1_target_paths.append(phase1_target_path)

      phase2_target_path = os.path.join(profile_dir, "scripts", "phase2-target")
      if os.path.isfile(phase2_target_path):
        self.phase2_target_paths.append(phase2_target_path)

      rootfs_path = os.path.join(profile_dir, "rootfs")
      if os.path.isdir(rootfs_path):
        self.rootfs_paths.append(rootfs_path)

      extract_image_path = os.path.join(profile_dir, "scripts", "extract-image")
      if os.path.isfile(extract_image_path):
        self.extract_image_path = extract_image_path

      loop_device_setup_path = os.path.join(profile_dir, "scripts", "loop-device-setup")
      if os.path.isfile(loop_device_setup_path):
        self.loop_device_setup_path = loop_device_setup_path

    self.verify_build_can_proceed()

    self.cached_download_path = os.path.join(self.cache_dir, os.path.basename(self.build_vars["image_url"]))
    self.output_filename = os.path.join(self.out_dir, self.build_vars["output_filename"])

  def verify_build_can_proceed(self):
    if os.geteuid() != 0:
      raise RequirementNotMetError("must execute the builder as root on the host")

    if self.extract_image_path is None:
      raise RequirementNotMetError("the extract-image script must be defined for one of the profiles")

    if self.loop_device_setup_path is None:
      raise RequirementNotMetError("the loop-device-setup script must be defined for one of the profiles")

    required_variables = [
      "image_mounts",
      "image_size",
      "image_url",
      "output_filename",
      "qemu_user_static_path",
    ]

    for var in required_variables:
      if var not in self.build_vars:
        raise RequirementNotMetError(f"variable {var} is not defined in any profiles but is required")

    required_commands = [
      "cut",
      "grep",
      "parted",
      "partx",
      "pv",
      "rsync",
      "systemd-nspawn",
      "truncate",
      "wget",
    ]

    for command in required_commands:
      if shutil.which(command) is None:
        raise RequirementNotMetError(f"command {command} is not found on the host system but is required")

  @property
  def loop_device(self):
    if getattr(self, "_loop_device", None) is None:
      with open(self.session_loop_device_file) as f:
        self._loop_device = f.read().strip()

    return self._loop_device

  def build(self):
    self._log_builder_information()

    os.makedirs(self.cache_dir, exist_ok=True)
    os.chmod(self.cache_dir, 0o777)

    os.makedirs(self.chroot_path, exist_ok=True)

    self.start_session()
    self.run_step(self.download_and_extract_image_if_necessary)

    self.run_step(self.setup_loop_device_and_mount_partitions)
    self.run_step(self.prepare_chroot)
    self.run_step(self.copy_files_to_chroot)

    self.run_step(self.run_phase1_host_scripts)
    self.run_step(self.run_phase1_target_scripts)
    self.run_step(self.run_phase2_host_scripts) # To allow for cross compile
    self.run_step(self.run_phase2_target_scripts)

    self.run_step(self.cleanup_chroot)
    self.run_step(self.umount_everything)
    self.end_session()

    msg = f"image built at {self.output_filename}"
    self.logger.info("-" * len(msg))
    self.logger.info(msg)
    self.logger.info("-" * len(msg))

  def start_session(self):
    if not os.path.isfile(self.session_file):
      with open(self.session_file, "w"):
        pass

      os.chmod(self.session_file, 0o666)

  def download_and_extract_image_if_necessary(self):
    if not os.path.isfile(self.cached_download_path):
      # Writing the code with wget gives better progress information than using
      # something like urllib3.
      self._run_script_on_host([
        "wget", "--progress=dot", "-e", "dotbytes=10M",
        "-O", self.cached_download_path, self.build_vars["image_url"],
      ])
    else:
      self.logger.info("already downloaded image, so only re-extracting it")

    os.makedirs(self.out_dir, exist_ok=True)
    self.logger.info(f"extracting {os.path.basename(self.cached_download_path)} into {self.output_filename}")
    # Writing the code as a shell with pv allows us to get a better progress
    # bar than implementing this code directly in Python.
    self._run_script_on_host(f"{self.extract_image_path} {self.cached_download_path} | pv > {self.output_filename}", shell=True)

  def setup_loop_device_and_mount_partitions(self):
    self.logger.info(f"expanding image to {self.build_vars['image_size']} with truncate")
    self._run_script_on_host(["truncate", "-s", self.build_vars["image_size"], self.output_filename])

    partition_end_in_mb = int(round(os.path.getsize(self.output_filename) / 1000.0 / 1000.0))
    partition_num = len(subprocess.check_output(["partx", "-g", self.output_filename]).decode("utf-8").strip().splitlines())
    self.logger.info(f"growing the last partition (partition number={partition_num}) to {partition_end_in_mb}MB")

    self._run_script_on_host(["parted", self.output_filename, "resizepart", str(partition_num), str(partition_end_in_mb)])

    loop_device = subprocess.check_output(["losetup", "-P", "--show", "-f", self.output_filename]).decode("utf-8").strip()

    self._run_script_on_host([self.loop_device_setup_path, loop_device])
    self._cache_loop_device(loop_device)

  def prepare_chroot(self):
    loop_device = self.loop_device

    # Reverse order because the rootfs needs to be mounted first, and the
    # rootfs is assumed to be the last partition.
    for i, mount_point in reversed(list(enumerate(self.build_vars["image_mounts"].split(",")))):
      i += 1
      device_name = f"{loop_device}p{i}"
      mount_point = os.path.join(self.chroot_path, mount_point.lstrip("/"))

      self._run_script_on_host(["mount", device_name, mount_point])

    self.logger.info("copy resolv.conf and qemu-user-static")

    shutil.move(
      os.path.join(self.chroot_path, "etc", "resolv.conf"),
      os.path.join(self.chroot_path, "etc", "resolv.conf.bak")
    )

    shutil.copy(
      self.build_vars["qemu_user_static_path"],
      os.path.join(self.chroot_path, self.build_vars["qemu_user_static_path"].lstrip("/"))
    )

    shutil.copy(
      "/etc/resolv.conf",
      os.path.join(self.chroot_path, "etc", "resolv.conf")
    )

    # Used for temporary files
    os.makedirs(os.path.join(self.chroot_path, "setup"))

  def copy_files_to_chroot(self):
    for rootfs_path in self.rootfs_paths:
      # Use rsync instead of shutil.copytree as it is more easy to control permissions
      self._run_script_on_host([
        "rsync", "-r", "-og", "--chown", "root:root", "--stats",
        f"{rootfs_path}/",
        self.chroot_path,
      ])

  def run_phase1_host_scripts(self):
    for phase1_host_path in self.phase1_host_paths:
      self._run_script_on_host(phase1_host_path)

  def run_phase1_target_scripts(self):
    for phase1_target_path in self.phase1_target_paths:
      self._run_script_on_target(phase1_target_path)

  def run_phase2_host_scripts(self):
    for phase2_host_path in self.phase2_host_paths:
      self._run_script_on_host(phase2_host_path)

  def run_phase2_target_scripts(self):
    for phase2_target_path in self.phase2_target_paths:
      self._run_script_on_target(phase2_target_path)

  def cleanup_chroot(self):
    os.remove(os.path.join(self.chroot_path, "etc", "resolv.conf"))
    shutil.move(
      os.path.join(self.chroot_path, "etc", "resolv.conf.bak"),
      os.path.join(self.chroot_path, "etc", "resolv.conf"),
    )

    os.remove(os.path.join(self.chroot_path, self.build_vars["qemu_user_static_path"].lstrip("/")))
    shutil.rmtree(os.path.join(self.chroot_path, "setup"), ignore_errors=True)

  def umount_everything(self):
    self.logger.info("Final system size:")
    self._run_script_on_host(["df", "-h", self.chroot_path])

    self.logger.info("unmounting everything")
    self._run_script_on_host(["umount", "-R", self.chroot_path])
    self._run_script_on_host(["losetup", "-d", self.loop_device])

  def end_session(self):
    os.remove(self.session_file)
    if os.path.exists(self.session_loop_device_file):
      os.remove(self.session_loop_device_file)

  def run_step(self, f: Callable, always_run: bool = False):
    step = f.__name__
    extra_log = ""
    if not always_run:
      if self._step_in_session(step):
        self.logger.info(f"skipped {step} as it already ran")
        self._check_pause(step)
        return
    else:
      extra_log = "(idempotent step always run)" # To make it clear in the logs that idempotent steps always run

    self.logger.info(f"running {step} {extra_log}")
    f()

    if not always_run:
      self._record_step_in_session(step)

    self._check_pause(step)

  def _parse_config(self, filename: str) -> tuple[dict, dict]:
    if not os.path.isfile(filename):
      raise FileNotFoundError("Cannot find file {}".format(filename))
    config = configparser.ConfigParser()
    # Preserve case sensitivity for configuration keys so that environment variables are properly exported.
    config.optionxform = str
    config.read(filename)
    return (
      dict(config["build"].items()),
      dict(config["env"].items()),
    )

  def _log_builder_information(self):
    # TODO: align the key and value to make the build output prettier.
    self.logger.info("Build information")
    self.logger.info("=================")
    self.logger.info("Profiles: {}".format(",".join(self.profile_dirs)))
    self.logger.info("")
    self.logger.info("Build variables")
    self.logger.info("---------------")
    for var, value in self.build_vars.items():
      self.logger.info(f"{var} = {value}")

    self.logger.info("")
    self.logger.info("Environment variables")
    self.logger.info("---------------------")
    for var, value in self.env_vars.items():
      self.logger.info(f"{var} = {value}")

    self.logger.info("")
    self.logger.info("Custom scripts")
    self.logger.info("--------------")
    for script in self.phase1_host_paths:
      self.logger.info(f"phase1 host:   {script}")

    for script in self.phase1_target_paths:
      self.logger.info(f"phase1 target: {script}")

    for script in self.phase2_host_paths:
      self.logger.info(f"phase2 host:   {script}")

    for script in self.phase2_target_paths:
      self.logger.info(f"phase2 target: {script}")

  def _check_pause(self, step: str):
    if self.build_vars.get("pause_after") == step:
      self.logger.warn(f"pausing after {step} as it is configured via the build var pause_after")
      print("Continue? [y/N] ", end="")
      if input().lower() != "y":
        raise SystemExit

  def _step_in_session(self, step: str) -> bool:
    with open(self.session_file) as f:
      return step in f.read()

  def _record_step_in_session(self, step: str):
    with open(self.session_file, "a") as f:
      print(step, file=f)

  def _cache_loop_device(self, loop_device):
    with open(self.session_loop_device_file, "w") as f:
      f.write(loop_device)

    os.chmod(self.session_loop_device_file, 0o666)
    self._loop_device = loop_device

  def _run_script_on_host(self, args: Sequence[str]|str, shell: bool = False):
    self.logger.debug(f"running {args} with env {self.env_vars}")
    env_vars = os.environ.copy() # So PATH still works...
    env_vars.update(self.env_vars)
    if shell:
      # If there are pipe, it might mask a failure without pipefail.
      cmd = ["/bin/bash", "-o", "pipefail", "-c", args]
      subprocess.run(cmd, check=True, env=env_vars)
    else:
      subprocess.run(args, check=True, env=env_vars)

  def _run_script_on_target(self, script_path: str, args: Sequence[str] = []):
    # Copy the script to inside the container
    script_filename = os.path.basename(script_path)
    script_path_in_target = os.path.join(self.chroot_path, "setup", script_filename)
    self.logger.debug(f"copying {script_path} to {script_path_in_target}")
    shutil.copy(script_path, script_path_in_target)

    try:
      cmd = ["systemd-nspawn", "-D", self.chroot_path]
      # This is the simplest way to preserve merge the default environment of
      # the target container and environment variables we want to pass in.
      cmd.append("env")
      for key, val in self.env_vars.items():
        cmd.append(f"{key}={val}")

      cmd.append(f"/setup/{script_filename}")
      cmd.extend(args)

      self.logger.debug(f"running {cmd} in the target")
      subprocess.run(cmd, check=True, env=self.env_vars)
      return True
    finally:
      os.remove(script_path_in_target)
