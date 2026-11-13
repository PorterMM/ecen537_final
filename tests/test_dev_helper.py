"""Exercise host lifecycle/error handling without installing Docker or ROS."""

import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DevHelperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ecen537-helper-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "checkout with spaces"
        (self.root / "scripts").mkdir(parents=True)
        # Redirect only the X11 filesystem path in the disposable test copy.
        # No host display sockets or desktop authorization files are touched.
        self.x11 = Path(self.temporary.name) / "x11"
        self.x11.mkdir()
        script = (ROOT / "scripts/dev.sh").read_text()
        (self.root / "scripts/dev.sh").write_text(script.replace("/tmp/.X11-unix", str(self.x11)))
        for name in ("compose.yaml", "compose.gui.yaml"):
            shutil.copy2(ROOT / name, self.root / name)
        self.bin = Path(self.temporary.name) / "bin"
        self.bin.mkdir()
        self.trace = Path(self.temporary.name) / "docker-calls.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}")
        self.env.update(MOCK_TRACE=str(self.trace), MOCK_RUNNING="1", DISPLAY="")
        for key in ("COMPOSE_FILE", "COMPOSE_PROJECT_NAME", "WSL_DISTRO_NAME"):
            self.env.pop(key, None)
        self.make_executable("id", "#!/bin/sh\ncase \"$1\" in -u) echo 1234;; -g) echo 2345;; esac\n")
        self.make_executable("uname", "#!/bin/sh\necho Linux-test-kernel\n")
        self.make_executable("xauth", '''#!/usr/bin/env python3
import os, sys
from pathlib import Path
if sys.argv[1] == 'nlist':
    if os.environ.get('MOCK_EMPTY_COOKIE') != '1':
        print('0100abc123')
else:
    Path(sys.argv[2]).write_text(sys.stdin.read())
''')
        self.make_executable("docker", '''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ['MOCK_TRACE'], 'a') as trace:
    trace.write(json.dumps({'args': args, 'cwd': os.getcwd(),
        'uid': os.environ.get('DEV_UID'), 'gid': os.environ.get('DEV_GID')}) + '\\n')
if args == ['info']:
    sys.exit(int(os.environ.get('MOCK_INFO_STATUS', '0')))
if args == ['compose', 'version']:
    sys.exit(int(os.environ.get('MOCK_COMPOSE_STATUS', '0')))
if 'ps' in args and os.environ.get('MOCK_RUNNING') == '1':
    print('mock-container-id')
if 'up' in args:
    sys.exit(int(os.environ.get('MOCK_UP_STATUS', '0')))
''')

    def make_executable(self, name, contents):
        path = self.bin / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_helper(self, *args):
        return subprocess.run(
            ["/bin/bash", str(self.root / "scripts/dev.sh"), *args],
            cwd=self.temporary.name, env=self.env, text=True, capture_output=True,
            timeout=10,
        )

    def calls(self):
        if not self.trace.exists():
            return []
        return [json.loads(line) for line in self.trace.read_text().splitlines()]

    def test_build_uses_checkout_from_other_directory_and_host_ids(self):
        result = self.run_helper("build")
        self.assertEqual(result.returncode, 0, result.stderr)
        call = self.calls()[-1]
        self.assertEqual(call["args"], [
            "compose", "--project-directory", str(self.root),
            "-f", str(self.root / "compose.yaml"), "build", "dev",
        ])
        self.assertEqual((call["uid"], call["gid"]), ("1234", "2345"))
        self.assertEqual(call["cwd"], str(self.root))

    def test_headless_start_does_not_prepare_display(self):
        result = self.run_helper("up", "--headless")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1]["args"][-6:], [
            "up", "-d", "--no-build", "--pull", "never", "dev",
        ])
        self.assertNotIn(str(self.root / "compose.gui.yaml"), self.calls()[-1]["args"])
        self.assertFalse((self.root / ".docker-state").exists())

    def test_gui_start_rejects_missing_display_without_starting(self):
        result = self.run_helper("up")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("up --headless", result.stderr)
        self.assertFalse(any("up" in call["args"] for call in self.calls()))

    def enable_test_display(self):
        display_socket = socket.socket(socket.AF_UNIX)
        self.addCleanup(display_socket.close)
        display_socket.bind(str(self.x11 / "X99"))
        self.env["DISPLAY"] = ":99"

    def test_ubuntu_gui_prepares_private_cookie_and_gui_override(self):
        self.enable_test_display()
        result = self.run_helper("up")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.root / "compose.gui.yaml"), self.calls()[-1]["args"])
        state = self.root / ".docker-state"
        authority = state / "Xauthority"
        self.assertEqual(state.stat().st_mode & 0o777, 0o700)
        self.assertEqual(authority.stat().st_mode & 0o777, 0o600)
        self.assertEqual(authority.read_text(), "ffffabc123\n")
        inode = authority.stat().st_ino
        result = self.run_helper("up")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(authority.stat().st_ino, inode)

    def test_wslg_start_does_not_require_an_xauthority_cookie(self):
        self.enable_test_display()
        self.env.update(WSL_DISTRO_NAME="Ubuntu-24.04", MOCK_EMPTY_COOKIE="1")
        result = self.run_helper("up")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / ".docker-state/Xauthority").read_bytes(), b"")
        self.assertIn(str(self.root / "compose.gui.yaml"), self.calls()[-1]["args"])

    def test_ubuntu_gui_rejects_missing_cookie_before_starting(self):
        self.enable_test_display()
        self.env["MOCK_EMPTY_COOKIE"] = "1"
        result = self.run_helper("up")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No Xauthority cookie", result.stderr)
        self.assertFalse(any("up" in call["args"] for call in self.calls()))

    def test_shell_can_connect_without_host_display(self):
        result = self.run_helper("shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1]["args"][-4:], [
            "exec", "dev", "/usr/local/bin/ecen537-entrypoint", "bash",
        ])

    def test_smoke_is_noninteractive_and_sources_ros(self):
        result = self.run_helper("smoke")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1]["args"][-7:], [
            "exec", "-T", "dev", "/usr/local/bin/ecen537-entrypoint",
            "/usr/local/bin/ecen537-smoke", "1234", "2345",
        ])

    def test_missing_running_container_has_startup_instructions(self):
        self.env["MOCK_RUNNING"] = "0"
        for command in ("shell", "smoke"):
            with self.subTest(command=command):
                result = self.run_helper(command)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("not running", result.stderr)
        self.assertFalse(any("exec" in call["args"] for call in self.calls()))

    def test_down_works_without_display_and_does_not_delete_volumes(self):
        result = self.run_helper("down")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1]["args"][-1:], ["down"])
        self.assertNotIn("--volumes", self.calls()[-1]["args"])

    def test_doctor_allows_headless_when_only_display_is_missing(self):
        result = self.run_helper("doctor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Headless development is available", result.stdout)

    def test_missing_docker_has_installation_instructions(self):
        isolated = Path(self.temporary.name) / "isolated-bin"
        isolated.mkdir()
        (isolated / "dirname").symlink_to(shutil.which("dirname"))
        self.env["PATH"] = str(isolated)
        result = self.run_helper("doctor")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Docker is not installed", result.stderr)
        self.assertIn("README.md", result.stderr)

    def test_missing_compose_and_unavailable_daemon(self):
        for setting, expected in (
            ("MOCK_COMPOSE_STATUS", "Compose is missing"),
            ("MOCK_INFO_STATUS", "Cannot reach Docker"),
        ):
            with self.subTest(setting=setting):
                self.env[setting] = "1"
                result = self.run_helper("build")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, result.stderr)
                self.env.pop(setting)

    def test_failed_start_recommends_build(self):
        self.env["MOCK_UP_STATUS"] = "1"
        result = self.run_helper("up", "--headless")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("./scripts/dev.sh build", result.stderr)

    def test_root_user_is_rejected(self):
        self.make_executable("id", "#!/bin/sh\necho 0\n")
        result = self.run_helper("build")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("without sudo", result.stderr)

    def test_bad_arguments_fail_before_contacting_docker(self):
        for args in (("build", "--unknown"), ("up", "--gpu"), ("unknown",)):
            with self.subTest(args=args):
                result = self.run_helper(*args)
                self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
