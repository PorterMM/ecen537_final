#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

usage() {
    cat <<'EOF'
Usage: ./scripts/dev.sh COMMAND
  doctor          Check Docker, Compose, daemon access, and GUI prerequisites
  build           Build the ROS 2 Jazzy development image
  up [--headless] Start the container (desktop GUI enabled by default)
  shell           Open a ROS-enabled Bash shell in the running container
  down            Remove the container and network; keep checkout files
  smoke           Check dependencies, ROS messaging, and a temporary build
EOF
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

command_name=${1:-help}
case "$command_name" in
    help|-h|--help) usage; exit 0 ;;
    doctor|build|shell|down|smoke)
        [[ $# -eq 1 ]] || { usage >&2; exit 2; } ;;
    up)
        [[ $# -eq 1 || ( $# -eq 2 && $2 == --headless ) ]] || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
esac

command -v docker >/dev/null || fail 'Docker is not installed. Follow the Ubuntu or Windows installation steps in README.md.'
docker compose version >/dev/null 2>&1 || fail 'Docker Compose is missing. Install the Compose plugin (Ubuntu), or enable Docker Desktop WSL integration (Windows).'
docker info >/dev/null || fail 'Cannot reach Docker. Start Docker Engine / Docker Desktop and check access to its socket. See README.md; run this helper without sudo.'

DEV_UID=$(id -u)
DEV_GID=$(id -g)
[[ $DEV_UID -gt 0 && $DEV_GID -gt 0 ]] || fail 'Run this helper as your normal Linux/WSL user, without sudo.'
export DEV_UID DEV_GID
compose=(docker compose --project-directory "$PROJECT_ROOT" -f "$PROJECT_ROOT/compose.yaml")

is_wsl() {
    [[ -n ${WSL_DISTRO_NAME:-} || $(uname -r) == *[Mm]icrosoft* ]]
}

check_display() {
    if [[ ! ${DISPLAY:-} =~ ^(unix)?:[0-9]+(\.[0-9]+)?$ ]]; then
        printf 'GUI needs a local DISPLAY such as :0. Use an Ubuntu desktop or Windows WSLg terminal.\n' >&2
        return 1
    fi
    local display_number=${DISPLAY##*:}
    display_number=${display_number%%.*}
    if [[ ! -S /tmp/.X11-unix/X$display_number ]]; then
        printf 'X11 socket /tmp/.X11-unix/X%s is missing. Check XWayland or WSLg.\n' "$display_number" >&2
        return 1
    fi
    if ! is_wsl && ! command -v xauth >/dev/null; then
        printf 'Install host display tools: sudo apt install xauth x11-utils\n' >&2
        return 1
    fi
    # WSLg normally permits local X11 clients without an Xauthority cookie.
    if ! is_wsl; then
        local cookies
        cookies=$(xauth nlist "$DISPLAY") || return 1
        if [[ -z $cookies ]]; then
            printf 'No Xauthority cookie for DISPLAY=%s. Run from your desktop session; check XAUTHORITY.\n' "$DISPLAY" >&2
            return 1
        fi
    fi
}

prepare_display() {
    check_display || fail 'GUI prerequisites are missing. See README.md, or use ./scripts/dev.sh up --headless.'
    local state_dir="$PROJECT_ROOT/.docker-state"
    mkdir -p "$state_dir"
    chmod 0700 "$state_dir"
    local auth_tmp
    auth_tmp=$(mktemp "$state_dir/Xauthority.XXXXXX")
    chmod 0600 "$auth_tmp"
    if ! is_wsl; then
        # FamilyWild makes the desktop cookie work with a container hostname.
        if ! xauth nlist "$DISPLAY" | sed 's/^..../ffff/' | xauth -f "$auth_tmp" nmerge -; then
            rm -f "$auth_tmp"
            fail 'Could not prepare the Xauthority file. Check your desktop session.'
        fi
    fi
    # Keep the inode stable: an already-running container bind-mounts this file.
    cat "$auth_tmp" > "$state_dir/Xauthority"
    rm -f "$auth_tmp"
    chmod 0600 "$state_dir/Xauthority"
    DEV_XAUTHORITY="$state_dir/Xauthority"
    DEV_X11_SOCKET_DIR=$(readlink -f /tmp/.X11-unix)
    export DEV_XAUTHORITY DEV_X11_SOCKET_DIR
    compose+=(-f "$PROJECT_ROOT/compose.gui.yaml")
}

require_running() {
    [[ -n $("${compose[@]}" ps --status running -q dev) ]] || fail 'Development container is not running. Run ./scripts/dev.sh up (or up --headless) first.'
}

case "$command_name" in
    doctor)
        printf 'Docker, Compose, and daemon access: OK (host UID:GID %s:%s)\n' "$DEV_UID" "$DEV_GID"
        if check_display; then
            printf 'Display prerequisites: OK. Gazebo/RViz still need an interactive launch check.\n'
        else
            printf 'Display prerequisites: unavailable. Headless development is available with up --headless.\n'
        fi
        ;;
    build)
        "${compose[@]}" build dev
        ;;
    up)
        if [[ ${2:-} != --headless ]]; then prepare_display; fi
        if ! "${compose[@]}" up -d --no-build --pull never dev; then
            fail 'Container startup failed. If the image is missing or your UID changed, run ./scripts/dev.sh build, then retry.'
        fi
        printf 'Connect with ./scripts/dev.sh shell; stop with ./scripts/dev.sh down.\n'
        ;;
    shell)
        require_running
        "${compose[@]}" exec dev /usr/local/bin/ecen537-entrypoint bash
        ;;
    down)
        "${compose[@]}" down
        ;;
    smoke)
        require_running
        "${compose[@]}" exec -T dev /usr/local/bin/ecen537-entrypoint /usr/local/bin/ecen537-smoke "$DEV_UID" "$DEV_GID"
        ;;
esac
