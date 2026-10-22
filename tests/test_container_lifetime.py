"""The build launcher must override short-lived image entrypoints and commands."""
import os
from pathlib import Path
import signal
import subprocess
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ContainerLifetime(unittest.TestCase):
    def test_windows_cleanup_does_not_reuse_a_previous_linux_environment(self):
        script = f"""
            . {ROOT}/share/eterbuild/korinf/mount
            get_remote_host() {{ echo unexpected-backend >&2; exit 91; }}
            rm() {{ echo unexpected-remove >&2; exit 92; }}
            DISTRNAME=Windows BUILDROOT=/previous/linux/buildroot
            unset CONTAINERNAME
            end_umount Windows/ALL
        """
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')

    def test_launcher_overrides_image_command_and_handles_stop(self):
        source = (ROOT / 'share/eterbuild/korinf/mount').read_text()
        command = source.split("a='' docker run -d", 1)[1].split('\n\n', 1)[0]
        stub = "docker() { printf '%s\\0' \"$@\"; }; dockerimage=test-image; contname=test-container; "
        result = subprocess.run(['bash', '-c', stub + "a='' docker run -d" + command], capture_output=True, check=True)
        args = result.stdout.decode().rstrip('\0').split('\0')
        self.assertEqual(args[args.index('--entrypoint') + 1], '/bin/sh')
        mounts = [args[i + 1] for i, arg in enumerate(args) if arg == '--tmpfs']
        self.assertIn('/run', mounts)
        self.assertIn('/tmp:exec', mounts)
        self.assertEqual(args[args.index('test-image') + 1], '-c')
        loop = args[-1]
        process = subprocess.Popen(['/bin/sh', '-c', loop], start_new_session=True)
        try:
            time.sleep(0.1)
            self.assertIsNone(process.poll())
            process.terminate()
            self.assertEqual(process.wait(timeout=3), 0)
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()

if __name__ == '__main__':
    unittest.main()
