# ECEn 537: Robot arm visual servoing

Development environment for a ROS 2 robot arm project using Gazebo and camera feedback. The container includes **Ubuntu 24.04, ROS 2 Jazzy, and Gazebo Harmonic**, plus RViz, MoveIt 2 / MoveIt Servo, ros2_control, Gazebo control integration, camera tools, OpenCV with ArUco, NumPy, SciPy, and Matplotlib. C++ and Python development tools are included.

This is the environment foundation. An arm model, robot configuration, camera setup, and visual servoing nodes still need to be added. Starting the container does not start a robot or a simulation.

Supported hosts are Ubuntu 24.04 Desktop and Windows 11 with Ubuntu 24.04 in WSL2. GUI windows use X11/XWayland on Ubuntu and WSLg on Windows. Software rendering is enabled, so an NVIDIA GPU or NVIDIA Container Toolkit is not required. Simulation can be slower than real time.

## 1. Install prerequisites

Choose **one** installation path below. ROS, Gazebo, and Python project dependencies go inside Docker; you do not need to install them on your host.

Complete your installation path, then follow **[2. Get the project](#2-get-the-project)**, **[3. Build, start, and connect](#3-build-start-and-connect)**, and **[4. Startup scripts and development commands](#4-startup-scripts-and-development-commands)** in order. Having Docker installed does not build this project. Section 5 is a reference for later, not the next setup step.

### Option A: Ubuntu 24.04

These steps install Docker Engine directly on Ubuntu. Use a terminal in your desktop session. See the [official Ubuntu Docker installation guide](https://docs.docker.com/engine/install/ubuntu/) for supported versions and upgrades.

1. Open an Ubuntu terminal with **Ctrl+Alt+T**. Check whether the Docker commands are installed:

   ```bash
   docker --version
   docker compose version
   ```

   If both print version numbers, leave the two **Install if needed** blocks below alone, and complete the remaining Ubuntu checks. Version numbers alone do not tell you whether Docker is running. If either command is missing, use the installation blocks. For an older or conflicting Docker installation, follow the official guide's **Uninstall old versions** instructions first.

2. **Install if needed — Ubuntu host terminal:** install tools and add Docker's package signing key:

   ```bash
   sudo apt update
   sudo apt install -y ca-certificates curl git xauth x11-utils
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

3. **Install if needed — Ubuntu host terminal:** register Docker's Ubuntu 24.04 repository and install Engine, Buildx, and Compose:

   ```bash
   DOCKER_ARCH=$(dpkg --print-architecture)
   echo "deb [arch=$DOCKER_ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   sudo systemctl enable --now docker
   ```

4. **Ubuntu host terminal:** allow your normal user to run Docker:

   ```bash
   sudo usermod -aG docker "$USER"
   ```

   **Log out of Ubuntu completely and log back in**, then open a new terminal. Docker group membership gives administrative control over the host; see [Docker's post-installation instructions](https://docs.docker.com/engine/install/linux-postinstall/). Run the project helper as your normal user, without `sudo`, so files belong to you.

5. **Everyone using this Ubuntu path — Ubuntu host terminal:** install Git/display tools and start Docker:

   ```bash
   sudo apt update
   sudo apt install -y git xauth x11-utils
   sudo systemctl start docker
   systemctl is-active docker
   ```

   `systemctl is-active docker` should print `active`. If it prints `inactive` or `failed`, check `sudo systemctl status docker --no-pager` before continuing. You do not need to open a separate VM window for this Ubuntu setup. These are the [Docker service start instructions](https://docs.docker.com/engine/daemon/start/).

   In the same terminal, verify Docker and display access:

   ```bash
   docker version
   docker compose version
   docker run --rm hello-world
   echo "$DISPLAY"
   xdpyinfo > /dev/null
   ```

   Docker should report both client and server information, `hello-world` should print its success message, and `xdpyinfo` should exit without an error. A normal local display looks like `:0` or `:1`. Ubuntu's standard Wayland desktop works through XWayland.

Your Ubuntu prerequisites are now ready. Continue to **[2. Get the project](#2-get-the-project)** below, then complete sections 3 and 4 to build and use this project.

### Option B: Windows 11 + WSL2

Use [Microsoft's WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install), [Docker Desktop's Windows installation guide](https://docs.docker.com/desktop/setup/install/windows-install/), and [Docker's WSL integration guide](https://docs.docker.com/desktop/features/wsl/) alongside these steps.

1. **Windows PowerShell, run as Administrator:** install Ubuntu 24.04 in WSL:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

   Restart Windows if prompted. Open **Ubuntu 24.04** from the Start menu and finish creating your Linux username/password. If this distribution is already installed, keep it and continue.

2. **Windows PowerShell:** update WSL and verify the Ubuntu distribution uses version 2:

   ```powershell
   wsl --update
   wsl --list --verbose
   ```

   Find the `Ubuntu-24.04` row. The `VERSION` column should say `2`. The `STATE` column says `Running` or `Stopped`; `Stopped` means it needs to be opened, not reinstalled. See [Microsoft's WSL status commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#list-installed-linux-distributions).

   If Ubuntu-24.04 shows version 1, convert it:

   ```powershell
   wsl --set-version Ubuntu-24.04 2
   ```

   Open **Ubuntu 24.04** from the Windows Start menu and leave its terminal open. Alternatively, start it from PowerShell with:

   ```powershell
   wsl --distribution Ubuntu-24.04
   ```

   That command enters an Ubuntu shell. Use it for subsequent commands labeled **Ubuntu 24.04 WSL terminal**. To check the running state again, open a separate PowerShell window and repeat `wsl --list --verbose`; the Ubuntu row should now say `Running`.

   WSL requires virtualization enabled in your computer's firmware. Follow Microsoft's guide if installation reports a virtualization error.

3. **Windows:** download and install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) if it is not installed yet. Select the **WSL 2 backend** when offered. Restart if requested. Whether newly installed or already installed, open the **Windows Start menu**, search for **Docker Desktop**, open it, and complete any initial setup. Leave the application running.

4. **Docker Desktop settings:** enable **Use the WSL 2 based engine** under **General** (it may already be enabled by default) and enable **Ubuntu-24.04** under **Resources → WSL Integration**. Apply the changes. Use the WSL 2 backend and **Linux containers** for this guide. Leave Docker Desktop running while working on the project. Do not also install Docker Engine with `apt` inside this WSL distribution.

5. **Ubuntu 24.04 WSL terminal:** install host tools and verify Docker:

   ```bash
   sudo apt update
   sudo apt install -y git xauth x11-utils
   docker version
   docker compose version
   docker info
   docker run --rm hello-world
   echo "$DISPLAY"
   xdpyinfo > /dev/null
   ```

   `docker info` must show a **Server** section without a connection error. If Docker Desktop is still starting, wait and run it again. If `docker` is not found, recheck WSL Integration and reopen Ubuntu. `hello-world` should print its success message.

   Windows 11 provides the GUI server through [WSLg](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps). `DISPLAY` normally reads `:0`; do not replace it with a Windows IP address or install a separate X server. If display checks fail, see troubleshooting below.

Your Windows prerequisites are now ready. Continue to **[2. Get the project](#2-get-the-project)** below, then complete sections 3 and 4 to build and use this project. A running WSL session or Docker Desktop by itself does not mean the project container exists yet.

**From here on, every “host terminal” command means your Ubuntu desktop terminal or your Ubuntu 24.04 WSL terminal, not PowerShell.**

## 2. Get the project

1. **Host terminal:** clone into your Linux home directory:

   ```bash
   mkdir -p ~/repos
   cd ~/repos
   git clone --branch dockerenv git@github.com:PorterMM/ecen537_final.git
   cd ecen537_final
   ```

   SSH cloning requires a GitHub SSH key configured in this Linux/WSL account; follow [GitHub's SSH setup instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh). Alternatively, clone using HTTPS and your GitHub credentials when required:

   ```bash
   git clone --branch dockerenv https://github.com/PorterMM/ecen537_final.git
   cd ecen537_final
   ```

   On Windows, use `~/repos`, **not `/mnt/c/...`**, for Linux build performance and file permissions. On an existing checkout, `cd` to it and run `git switch dockerenv` instead of cloning. The branch must be available on GitHub before a teammate can clone it.

2. **Host terminal:** optionally create local configuration:

   ```bash
   cp .env.example .env
   ```

   Leave `ROS_DOMAIN_ID=0` for now. `.env` is ignored by Git. All ROS processes initially run inside the same container using local discovery; communicating with external robots or other containers will need additional networking configuration.

## 3. Build, start, and connect

Run these steps in order, including when Docker was already installed before you started this guide. The commands below create the project environment; there is no separate project VM to open or Python environment to activate on the host.

1. **Start Docker and open your Linux terminal.**

   **Ubuntu 24.04:** open a terminal with **Ctrl+Alt+T** and run:

   ```bash
   sudo systemctl start docker
   systemctl is-active docker
   ```

   Expect `active`. If starting the service fails, return to the Ubuntu installation instructions before continuing.

   **Windows 11:** open **Docker Desktop** from the Windows Start menu and leave it running. Open **Ubuntu 24.04** from the Start menu as well. To check WSL from a separate **PowerShell** window:

   ```powershell
   wsl --list --verbose
   ```

   The `Ubuntu-24.04` row should show `Running` and version `2`. If it is stopped, open Ubuntu from the Start menu or run `wsl --distribution Ubuntu-24.04` in PowerShell. Continue in the resulting Ubuntu terminal.

2. **Host terminal:** confirm Docker is ready to accept commands:

   ```bash
   docker info
   ```

   Look for a **Server** section without an error. If you see a connection error on Windows, give Docker Desktop time to finish starting, then retry. If the error persists, return to the installation instructions for your operating system. On Ubuntu, a socket permission error means you need to complete the Docker group and logout/login steps. Continue only once this check works.

3. **Host terminal:** enter the project directory you cloned in section 2:

   ```bash
   cd ~/repos/ecen537_final
   pwd
   ls scripts/dev.sh compose.yaml
   ```

   If your checkout is somewhere else, use that directory in the `cd` command. `ls` should list both files. If it says a file is missing, return to **[2. Get the project](#2-get-the-project)** and check your checkout and branch. Run all remaining host commands from this directory.

4. **Host terminal:** check project prerequisites:

   ```bash
   ./scripts/dev.sh doctor
   ```

   Expect `Docker, Compose, and daemon access: OK` and `Display prerequisites: OK`, with additional details on each line. If a check reports an error, resolve it before proceeding. If only the display is unavailable, you can use the **[Headless startup](#headless-startup)** sequence below, which still includes building the image.

5. **Host terminal:** build the project image:

   ```bash
   ./scripts/dev.sh build
   ```

   Wait for the build to finish and the terminal prompt to return without errors. Do not continue after a failed build. The first build downloads several gigabytes and can take a while. Reserve roughly 15–20 GB of disk space for images, caches, and workspaces. Later builds reuse cached layers. The image creates a `developer` user with your Linux/WSL UID and GID so generated project files belong to you.

6. **Host terminal:** create and start the project container with GUI access:

   ```bash
   ./scripts/dev.sh up
   docker compose ps
   ```

   `up` creates the `dev` container from the image you just built and leaves it running in the background. You do not need to create it manually in Docker Desktop. `docker compose ps` should show a row whose **SERVICE** is `dev` and whose **STATUS** starts with `Up`. The helper should also print `Connect with ./scripts/dev.sh shell`. If the row is missing or says `Exited`, read the error and check `docker compose logs --tail=100 dev` before continuing. No simulation window is expected yet.

7. **Host terminal:** open a shell inside that running container:

   ```bash
   ./scripts/dev.sh shell
   ```

   The prompt should change to one starting with `developer@`. Confirm you are in the right place by running these commands **inside the container**:

   ```bash
   whoami
   pwd
   echo "$ROS_DISTRO"
   ```

   Expected output, in order:

   ```text
   developer
   /workspaces/ecen537_final/ros2_ws
   jazzy
   ```

   The host checkout is mounted at `/workspaces/ecen537_final`. File edits on either side appear on the other side immediately. Shells opened with this helper automatically source ROS and an existing workspace overlay.

   You are now ready for **[4. Startup scripts and development commands](#4-startup-scripts-and-development-commands)**. Run its Gazebo and ROS commands in this container shell.

### Open another terminal, leave, and stop

1. To open another container terminal, open a **second host terminal**, `cd` to the checkout, and run:

   ```bash
   ./scripts/dev.sh shell
   ```

   Each shell connects to the same container. No SSH server or connection port is needed.

2. **Inside each container shell:** leave with:

   ```bash
   exit
   ```

   Exiting a shell leaves the container running. **Host terminal:** stop and remove it with:

   ```bash
   ./scripts/dev.sh down
   ```

3. **On a later day:** start Docker using section 3's first step, open your host terminal, and return to your checkout. If the image was already built successfully and the Dockerfile has not changed, reconnect with:

   ```bash
   cd ~/repos/ecen537_final
   ./scripts/dev.sh up
   ./scripts/dev.sh shell
   ```

   Use your actual checkout path if different. A first-time setup still needs the build step above.

### Headless startup

For command-line work without GUI windows, first complete section 3's Docker readiness and project-directory checks. Then run this sequence in your **host terminal**, including the build on a first-time setup:

```bash
./scripts/dev.sh doctor
./scripts/dev.sh build
./scripts/dev.sh up --headless
./scripts/dev.sh smoke
./scripts/dev.sh shell
```

Here, `doctor` may report that the display is unavailable; Docker, Compose, and daemon access must still pass. Stop if the build or startup fails. Use `down` before switching between GUI and headless modes. Headless startup does not mount X11 sockets or require `DISPLAY`/Xauthority. Gazebo's server can run headlessly, but RViz and Gazebo's GUI need GUI startup. After `shell`, continue to section 4 for the development and headless server commands.

### Helper reference

| Host command | Purpose |
| --- | --- |
| `./scripts/dev.sh doctor` | Check Docker, Compose, daemon access, and display prerequisites |
| `./scripts/dev.sh build` | Build the image with your host UID/GID |
| `./scripts/dev.sh up` | Start the container with GUI access |
| `./scripts/dev.sh up --headless` | Start without GUI mounts |
| `./scripts/dev.sh shell` | Open a ROS-enabled Bash shell |
| `./scripts/dev.sh smoke` | Check dependencies, ROS messaging, and a temporary workspace build |
| `./scripts/dev.sh down` | Remove the container and its network; preserve checkout files |

## 4. Startup scripts and development commands

### Automatic startup behavior

The container entrypoint sources `/opt/ros/jazzy/setup.bash` and, if present, `/workspaces/ecen537_final/ros2_ws/install/setup.bash`. Each new interactive Bash shell sources them as well. Startup then runs `sleep infinity` to keep the environment available; launch tools in your connected shells.

`rosdep` is initialized and its Jazzy index is downloaded when the image is built. Startup does not install packages, rebuild your workspace, or start a simulation.

### Check the environment

**Host terminal**, while the container is running:

```bash
./scripts/dev.sh smoke
```

This verifies installed ROS packages, Python imports, OpenCV ArUco, and the Gazebo CLI. It runs isolated ROS talker/listener nodes with a 30-second messaging timeout, builds a temporary CMake ROS package, and checks write access to the mounted workspace as the developer user. Temporary test files and processes are cleaned up. Expected final output:

```text
Smoke checks passed. Gazebo/RViz GUI rendering is a separate manual check.
```

### Add and build ROS packages

Put project packages under `ros2_ws/src/` on the host, or create one **inside the container**:

```bash
cd "$ROS_WS/src"
ros2 pkg create --build-type ament_python --license Apache-2.0 visual_servoing
cd "$ROS_WS"
```

After adding packages and declaring their dependencies in `package.xml`, run **inside the container**:

```bash
sudo apt update
rosdep update --rosdistro jazzy
rosdep install --from-paths src --ignore-src --rosdistro jazzy -r -y
colcon build --symlink-install
source install/setup.bash
```

Run the build commands once packages exist; `src/` starts empty. Source `install/setup.bash` in existing shells after a build; new helper shells pick it up automatically. Build outputs under `ros2_ws/build`, `install`, and `log` are ignored by Git. Put persistent new system dependencies in the Dockerfile so teammates get them when rebuilding.

### Start an empty Gazebo world

Start the container in GUI mode. **Inside a container shell:**

```bash
ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="-r /opt/ecen537/worlds/empty.sdf"
```

A Gazebo window should open with a ground plane. The provided world uses only local assets and does not download a robot from Gazebo Fuel. Press **Ctrl+C** in its terminal to stop it. This launches Gazebo; topic bridges, arm controllers, and cameras will be configured when the robot is added.

For a **headless physics server**, use this **inside the container** instead:

```bash
gz sim -s -r /opt/ecen537/worlds/empty.sdf
```

Press **Ctrl+C** to stop. A future camera may need additional headless rendering configuration; this command currently exercises the empty simulation server.

### Start RViz

Connect another shell with `./scripts/dev.sh shell` in a host terminal, then run **inside that container shell**:

```bash
rviz2
```

RViz should open. With no robot or TF publishers running, an empty view and a fixed-frame warning are expected. Add the robot's frames and topics when those packages are available. Close the window or press **Ctrl+C** to stop RViz.

## 5. Docker tips and troubleshooting

### Daily workflow and persistence

- **Image:** the reusable operating system and installed tools built from the Dockerfile. **Container:** a running instance of that image. Multiple shell sessions use our single `dev` container.
- Source edits in the mounted checkout do not require an image rebuild. They survive `down`, rebuilds, and container replacement, including workspace build results.
- Files elsewhere in the container, including `/home/developer`, and packages installed manually with `apt` are lost when it is removed or recreated. Keep important work in the checkout and declare dependencies in the Dockerfile.
- After changing the Dockerfile or container support files under `docker/` (including the example world), run `./scripts/dev.sh down`, `./scripts/dev.sh build`, then `./scripts/dev.sh up`. A different host UID/GID also requires a new build.
- GUI authorization is prepared by `up` in the ignored `.docker-state/` directory. Run GUI startup from your logged-in desktop session. Do not commit or share that directory.
- Use **Ctrl+C** to stop the foreground ROS/Gazebo process. `exit` leaves your current shell. `down` stops everything in the container.
- Ubuntu desktop and WSL terminal commands use Bash. Avoid running the Linux helper directly from PowerShell. `.gitattributes` preserves Linux line endings for scripts.

### Inspect logs and resource use

**Host terminal**, from the checkout:

```bash
docker compose ps
docker compose logs --tail=100 dev
docker stats --no-stream
docker system df
```

The idle container normally produces little log output. Processes launched with `shell` print to that terminal; Compose logs do not capture those interactive commands. On Windows, keep adequate memory available to WSL; consult [Microsoft's WSL memory configuration](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#main-wsl-settings) if builds run out of memory. A practical starting point is 4 CPU cores and 8 GB of available RAM.

Raw `docker compose exec` bypasses the image entrypoint. For a one-off command that needs ROS, use **on the host**:

```bash
docker compose exec dev /usr/local/bin/ecen537-entrypoint ros2 pkg list
```

### Common problems

| Symptom | What to do |
| --- | --- |
| `docker: command not found` | Complete the matching installation path. In WSL, enable Docker Desktop integration for Ubuntu-24.04 and reopen the terminal. |
| Cannot connect to Docker | Ubuntu: `sudo systemctl start docker`. Windows: start Docker Desktop and wait for its engine to be ready. |
| Permission denied on the Docker socket | Ubuntu: complete the Docker group step and fully log out/in. Do not work around it by running the helper with `sudo`. |
| Project helper says the image is missing | Run `./scripts/dev.sh build` before `up`, on this Linux/WSL account. |
| `shell` says the container is not running | Run `./scripts/dev.sh up` or `./scripts/dev.sh up --headless`. |
| Missing X11 socket or display | Ubuntu: use a local desktop terminal with XWayland running. Windows: check WSLg with `xdpyinfo`; run `wsl --update` in PowerShell if needed. |
| WSLg stopped working after an update | Save your work, run `wsl --shutdown` in PowerShell, restart Docker Desktop and Ubuntu, then run `doctor` again. This stops running WSL sessions. |
| No Xauthority cookie / cannot open display | Ubuntu: install `xauth x11-utils`, check `echo "$DISPLAY"` and `echo "$XAUTHORITY"`, and run from your own desktop session. Do not use `xhost +`. After a login/display change, run `down` then `up`. |
| Gazebo or RViz is slow | Software rendering uses CPU. Reduce simulation complexity and camera resolution; stop unused GUI tools. This setup does not configure GPU passthrough. |
| Files are owned by root | Do not use `sudo` for the project helper or for workspace builds. Rebuild as your normal user if the image came from another account. |
| `ros2` or package not found | Enter with the helper; after a workspace build, run `source install/setup.bash` in existing shells. |
| Scripts report `bad interpreter` | Clone within WSL and retain LF line endings; avoid Windows tools that rewrite shell scripts with CRLF. |
| Workspace behaves strangely after changing ROS versions | Remove only the generated `ros2_ws/build`, `ros2_ws/install`, and `ros2_ws/log` directories, then rebuild. Keep `ros2_ws/src`. |

### Cleanup

Use `./scripts/dev.sh down` for normal project cleanup. It leaves the image and mounted checkout available for next time. To reclaim unused build cache, review usage with `docker system df`, then run `docker builder prune` and read its confirmation prompt. This can affect caches from other projects and makes future builds slower. Avoid broad volume deletion commands as routine cleanup.

### Reference and validation notes

- [ROS 2 Jazzy Ubuntu installation](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)
- [Gazebo's ROS installation and version pairing](https://gazebosim.org/docs/harmonic/ros_installation/)
- [MoveIt 2 binary installation](https://moveit.ai/install-moveit2/binary/)
- [Microsoft's WSLg container display guidance](https://github.com/microsoft/wslg/blob/main/samples/container/Containers.md)

The host-side helper tests can run without Docker:

```bash
python3 -m unittest discover -s tests -v
```

Passing these tests does not verify an image build or graphics. Run `build`, `up --headless`, and `smoke`, then manually launch Gazebo and RViz in GUI mode on each target host before considering that platform validated. The initial development host did not have Docker installed; image execution and Ubuntu/Windows GUI behavior have not been verified there.
