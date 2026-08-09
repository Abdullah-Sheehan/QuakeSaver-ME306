#!/usr/bin/env bash
# QuakeSAVER development bootstrap for Ubuntu 22.04 (Jammy) / WSL2.
#
# Installs ROS 2 Humble, colcon/rosdep, MAVROS + Nav2 + Gazebo, and ArduPilot
# SITL pinned to Copter-4.5.7, then builds this workspace.
# Safe to re-run: every step is idempotent.
#
# Usage:
#   ./scripts/bootstrap.sh
#
# Env toggles:
#   QS_SKIP_ROS=1         skip ROS 2 apt setup + install
#   QS_SKIP_ARDUPILOT=1   skip ArduPilot clone + SITL build (~15 min, ~3 GB)
#   QS_SKIP_BUILD=1       skip the final colcon build
#   ARDUPILOT_DIR=<path>  ArduPilot checkout location (default ~/ardupilot)

set -euo pipefail

ROS_DISTRO_TARGET="humble"
UBUNTU_CODENAME_TARGET="jammy"
ARDUPILOT_TAG="Copter-4.5.7"          # must match the firmware on the airframes
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"

log()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# Append a line to a file only if it is not already present.
ensure_line() {
  local line="$1" file="$2"
  touch "$file"
  grep -qxF "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

# ---------------------------------------------------------------- preflight --

[ "$(id -u)" -ne 0 ] || die "Do not run as root. The script calls sudo where needed."

. /etc/os-release
[ "${VERSION_CODENAME:-}" = "$UBUNTU_CODENAME_TARGET" ] || \
  warn "Expected Ubuntu 22.04 ($UBUNTU_CODENAME_TARGET), found '${VERSION_CODENAME:-unknown}'. Continuing anyway."

log "Caching sudo credentials"
sudo -v

export DEBIAN_FRONTEND=noninteractive

log "Installing base tooling"
sudo apt-get update
sudo apt-get install -y \
  curl gnupg2 lsb-release ca-certificates software-properties-common \
  git build-essential cmake tmux python3-pip python3-venv

sudo add-apt-repository -y universe

# ------------------------------------------------------------------- ROS 2 --

if [ "${QS_SKIP_ROS:-0}" = "1" ]; then
  log "QS_SKIP_ROS=1 — skipping ROS 2 install"
else
  log "Configuring the ROS 2 apt repository"
  if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then
    sudo curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg
  fi
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $UBUNTU_CODENAME_TARGET main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

  log "Installing ROS 2 $ROS_DISTRO_TARGET and build tools"
  sudo apt-get update
  sudo apt-get install -y \
    "ros-${ROS_DISTRO_TARGET}-desktop" \
    ros-dev-tools \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool

  log "Installing MAVROS, Nav2, SLAM, Gazebo, and vision dependencies"
  sudo apt-get install -y \
    "ros-${ROS_DISTRO_TARGET}-mavros" \
    "ros-${ROS_DISTRO_TARGET}-mavros-extras" \
    "ros-${ROS_DISTRO_TARGET}-navigation2" \
    "ros-${ROS_DISTRO_TARGET}-nav2-bringup" \
    "ros-${ROS_DISTRO_TARGET}-slam-toolbox" \
    "ros-${ROS_DISTRO_TARGET}-gazebo-ros-pkgs" \
    "ros-${ROS_DISTRO_TARGET}-cv-bridge" \
    "ros-${ROS_DISTRO_TARGET}-tf-transformations" \
    python3-opencv python3-numpy

  # MAVROS needs the GeographicLib geoid dataset to convert AMSL <-> ellipsoid.
  GEO_SCRIPT="/opt/ros/${ROS_DISTRO_TARGET}/lib/mavros/install_geographiclib_datasets.sh"
  if [ -f "$GEO_SCRIPT" ] && [ ! -f /usr/share/GeographicLib/geoids/egm96-5.pgm ]; then
    log "Installing GeographicLib datasets for MAVROS"
    sudo "$GEO_SCRIPT"
  fi
fi

log "Initializing rosdep"
sudo rosdep init 2>/dev/null || true   # already-initialized is not an error
rosdep update

# --------------------------------------------------------- ArduPilot SITL --

if [ "${QS_SKIP_ARDUPILOT:-0}" = "1" ]; then
  log "QS_SKIP_ARDUPILOT=1 — skipping ArduPilot SITL"
else
  if [ ! -d "$ARDUPILOT_DIR/.git" ]; then
    log "Cloning ArduPilot into $ARDUPILOT_DIR"
    git clone https://github.com/ArduPilot/ardupilot.git "$ARDUPILOT_DIR"
  fi

  log "Checking out $ARDUPILOT_TAG and syncing submodules"
  git -C "$ARDUPILOT_DIR" fetch --tags
  git -C "$ARDUPILOT_DIR" checkout "$ARDUPILOT_TAG"
  git -C "$ARDUPILOT_DIR" submodule update --init --recursive

  log "Installing ArduPilot prerequisites (this also installs MAVProxy)"
  # The installer edits ~/.bashrc itself and expects to run from the checkout.
  ( cd "$ARDUPILOT_DIR" && USER="${USER:-$(id -un)}" \
      Tools/environment_install/install-prereqs-ubuntu.sh -y )

  log "Building ArduCopter for SITL"
  ( cd "$ARDUPILOT_DIR" && ./waf configure --board sitl && ./waf copter )

  ensure_line "export PATH=\"\$PATH:$ARDUPILOT_DIR/Tools/autotest\"" "$HOME/.bashrc"
fi

# ---------------------------------------------------------------- workspace --

# ROS setup scripts reference unbound vars; set -u must be off while sourcing.
if [ "${QS_SKIP_ROS:-0}" != "1" ]; then
  set +u
  # shellcheck disable=SC1090
  source "/opt/ros/${ROS_DISTRO_TARGET}/setup.bash"
  set -u
fi

log "Resolving workspace dependencies with rosdep"
rosdep install --from-paths "$WS_DIR/src" --ignore-src -r -y \
  --rosdistro "$ROS_DISTRO_TARGET" || warn "rosdep reported unresolved keys; see output above"

if [ "${QS_SKIP_BUILD:-0}" = "1" ]; then
  log "QS_SKIP_BUILD=1 — skipping colcon build"
else
  log "Building the workspace"
  ( cd "$WS_DIR" && colcon build --symlink-install )
fi

log "Wiring up ~/.bashrc"
ensure_line "source /opt/ros/${ROS_DISTRO_TARGET}/setup.bash" "$HOME/.bashrc"
ensure_line "[ -f $WS_DIR/install/setup.bash ] && source $WS_DIR/install/setup.bash" "$HOME/.bashrc"
# Single-machine simulation: avoids WSL2 multicast discovery problems.
ensure_line "export ROS_LOCALHOST_ONLY=1" "$HOME/.bashrc"

cat <<EOF

Bootstrap complete.

  source ~/.bashrc
  ros2 interface list | grep qs_msgs     # should list the six qs_msgs types
  sim_vehicle.py -v ArduCopter --console --map

EOF