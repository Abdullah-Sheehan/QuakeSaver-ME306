# SITL + MAVROS — verified single-drone bring-up

Confirmed working on Ubuntu 22.04 / WSL2, Humble, ArduPilot Copter-4.5.7.

## Launch SITL (terminal 1)

sim_vehicle.py -v ArduCopter --console --map --out=udp:127.0.0.1:14550


## Launch MAVROS (terminal 2)

ros2 launch mavros apm.launch fcu_url:=udp://127.0.0.1:14550@14555


Explicit `--out=` on the SITL side and explicit `@<port>` on the MAVROS
side were both required — leaving either implicit caused MAVROS to
report `connected: false` even with SITL running fine and armable.

## Verify

ros2 topic echo /mavros/state --once

Expect `connected: true`.

## Arm + takeoff test (MAVProxy console, not the status window)

mode GUIDED
arm throttle
takeoff 5


## Next: dual-drone
Two instances need `-I0`/`-I1` (auto-offsets ports) and two MAVROS
nodes need distinct namespaces (`/uav1`, `/uav2`). Not yet built.
