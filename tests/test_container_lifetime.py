"""The build launcher must override short-lived image entrypoints and commands."""
import os
from pathlib import Path
import signal
import subprocess
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ContainerLifetime(unittest.TestCase):
    def test_launcher_overrides_image_command_and_handles_stop(self):
        source = (ROOT / 'share/eterbuild/korinf/mount').read_text()
        command = source.split("a='' docker run -d", 1)[1].split('\n\n', 1)[0]
        stub = "docker() { printf '%s\\0' \"$@\"; }; dockerimage=test-image; contname=test-container; "
        result = subprocess.run(['bash', '-c', stub + "a='' docker run -d" + command], capture_output=True, check=True)
        args = result.stdout.decode().rstrip('\0').split('\0')
        self.assertEqual(args[args.index('--entrypoint') + 1], '/bin/sh')
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
