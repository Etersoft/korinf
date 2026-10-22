"""A failed target must not hide later targets in API builds."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ContinueBuild(unittest.TestCase):
    def test_mainbuild_retains_failure_and_visits_next_target(self):
        for nostop, expected in [('', ['bad']), ('1', ['bad', 'good'])]:
            with self.subTest(nostop=nostop), tempfile.TemporaryDirectory() as tmp:
                script = f'''
                kormod() {{ :; }}
                . {ROOT}/share/eterbuild/korinf/mainbuild
                get_distro_list() {{ echo bad good; }}
                get_linked_system() {{ :; }}
                parse_dist_name() {{ DISTRNAME=test; }}
                set_target_var() {{ :; }}
                init_dist_log() {{ LOGFILE={tmp}/log; }}
                clear_restart_build_status() {{ :; }}
                loginfo() {{ :; }}
                reset_dist_log() {{ :; }}
                build_dist_pkg() {{ echo "$dist" >> {tmp}/visited; [ "$dist" = good ]; }}
                logit() {{ :; }}
                set_build_failed() {{ :; }}
                write_report() {{ cat >/dev/null; }}
                fatal() {{ exit 1; }}
                ALOGDIR={tmp} TARGETPATH={tmp} FORCEREBUILDPACKAGE=1
                NIGHTBUILD=1 CONTINUEONFAILURE={nostop}
                mainbuild
                '''
                result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(Path(tmp, 'visited').read_text().split(), expected)

    def test_generic_tasks_request_nostop(self):
        for force in ('0', '1'):
            with self.subTest(force=force), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / 'robot').mkdir()
                (root / 'bin').mkdir()
                fake = root / 'bin/korinf'
                fake.write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" > {tmp}/args\nexit 1\n')
                fake.chmod(0o755)
                task = root / 'build.task'
                task.write_text(f'PACKAGE=eepm\nDIST=ALL\nFORCE={force}\n')
                result = subprocess.run(['bash', '-c', f'''
                    . {ROOT}/share/eterbuild/korinf/taskfield
                    . {ROOT}/robot/funcs/genericbuild
                    AROBOTDIR={tmp}/robot
                    run_generic_build_task {task}
                '''], capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertTrue(Path(str(task) + '.failed').exists())
                self.assertEqual((root / 'args').read_text().split(),
                                 ['--nostop', '-F' if force == '1' else '-f', 'eepm', 'ALL'])
