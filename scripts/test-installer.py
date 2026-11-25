#!/usr/bin/env python3
"""Exercise real lifecycle scripts in an isolated copy with mocked OS effects."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
MOCK = '''#!/usr/bin/env python3
import json, sys
from pathlib import Path
path = Path(__file__).parent / 'state.json'
s = json.loads(path.read_text())
command = Path(sys.argv[0]).name
s['events'].append([command, *sys.argv[1:]])
result = 0
if command == 'stat': print(s['uid'])
elif command == 'pgrep': result = 0 if s['running'] else 1
elif command == 'pkill':
    if s['can_quit']: s['running'] = False
elif command == 'launchctl': result = s.get('launch_result', 0)
path.write_text(json.dumps(s))
sys.exit(result)
'''


class InstallerLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='horologium-installer-tests-')
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.state_file = self.directory / 'state.json'
        self.app = self.directory / 'Applications/Horologium.app'
        self.app.mkdir(parents=True)
        for command in ['stat', 'pgrep', 'pkill', 'sleep', 'launchctl']:
            path = self.directory / command
            path.write_text(MOCK)
            path.chmod(0o755)
        for filename in ['common.sh', 'preinstall', 'postinstall']:
            source = (ROOT / 'installer' / filename).read_text()
            source = source.replace('/private/var/run/app.ardens.horologium.installer', str(self.directory / 'marker'))
            source = source.replace('/Applications/Horologium.app', str(self.app))
            for command in ['stat', 'pgrep', 'pkill']:
                source = source.replace('/usr/bin/' + command, str(self.directory / command))
            for command in ['sleep', 'launchctl']:
                source = source.replace('/bin/' + command, str(self.directory / command))
            (self.directory / filename).write_text(source)
        self.set_state()

    def set_state(self, **changes):
        state = dict(uid=501, running=True, can_quit=True, events=[])
        state.update(changes)
        self.state_file.write_text(json.dumps(state))

    def state(self):
        return json.loads(self.state_file.read_text())

    def run_script(self, name, volume='/'):
        return subprocess.run(['/bin/bash', str(self.directory / name), 'package.pkg', '/', volume],
                              capture_output=True, text=True)

    def test_running_app_is_stopped_and_reopened_as_console_user(self):
        self.assertEqual(self.run_script('preinstall').returncode, 0)
        self.assertFalse(self.state()['running'])
        self.assertEqual((self.directory / 'marker/relaunch-user').read_text(), '501\n')
        self.assertEqual(self.run_script('postinstall').returncode, 0)
        events = self.state()['events']
        self.assertIn(['pkill', '-TERM', '-u', '501', '-x', 'Horologium'], events)
        self.assertIn(['launchctl', 'asuser', '501', '/usr/bin/sudo', '-H', '-u', '#501',
                       '/usr/bin/open', str(self.app)], events)
        self.assertFalse((self.directory / 'marker/relaunch-user').exists())
        self.assertEqual(self.run_script('postinstall').returncode, 0)
        self.assertEqual(sum(e[0] == 'launchctl' for e in self.state()['events']), 1)

    def test_closed_app_stays_closed_and_stale_marker_is_removed(self):
        marker = self.directory / 'marker'
        marker.mkdir()
        (marker / 'relaunch-user').write_text('501\n')
        self.set_state(running=False)
        self.assertEqual(self.run_script('preinstall').returncode, 0)
        self.assertEqual(self.run_script('postinstall').returncode, 0)
        self.assertFalse(any(e[0] in ['pkill', 'launchctl'] for e in self.state()['events']))

    def test_app_that_refuses_to_quit_aborts_before_replacement(self):
        self.set_state(can_quit=False)
        result = self.run_script('preinstall')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('still running', result.stderr)
        self.assertFalse((self.directory / 'marker/relaunch-user').exists())
        self.assertTrue(self.state()['running'])

    def test_other_volume_does_not_touch_current_session(self):
        self.assertEqual(self.run_script('preinstall', '/Volumes/Other').returncode, 0)
        self.assertEqual(self.run_script('postinstall', '/Volumes/Other').returncode, 0)
        self.assertEqual(self.state()['events'], [])

    def test_no_logged_in_user_does_not_terminate_or_launch(self):
        self.set_state(uid=0)
        self.assertEqual(self.run_script('preinstall').returncode, 0)
        self.assertEqual(self.run_script('postinstall').returncode, 0)
        self.assertFalse(any(e[0] in ['pkill', 'launchctl'] for e in self.state()['events']))

    def test_session_switch_does_not_launch_for_another_user(self):
        self.assertEqual(self.run_script('preinstall').returncode, 0)
        state = self.state()
        state['uid'] = 502
        self.state_file.write_text(json.dumps(state))
        self.assertEqual(self.run_script('postinstall').returncode, 0)
        self.assertFalse(any(e[0] == 'launchctl' for e in self.state()['events']))

    def test_launch_failure_keeps_install_successful(self):
        self.set_state(launch_result=1)
        self.assertEqual(self.run_script('preinstall').returncode, 0)
        result = self.run_script('postinstall')
        self.assertEqual(result.returncode, 0)
        self.assertIn('Open it from Applications', result.stderr)


if __name__ == '__main__':
    unittest.main()
