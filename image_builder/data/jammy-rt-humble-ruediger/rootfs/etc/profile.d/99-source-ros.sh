if [ -f /opt/ros/humble/setup.bash ]; then
  source /opt/ros/humble/setup.bash
fi
if [ -f /opt/ruediger2/ruediger2_control/setup.bash ]; then
  source /opt/ruediger2/ruediger2_control/local_setup.bash
fi
if [ -f /opt/ruediger_ws/setup.bash ]; then
  source /opt/ruediger_ws/local_setup.bash
fi