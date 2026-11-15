"""Exercise preview registration against a real, isolated Supervisor daemon."""
import importlib.util
from importlib.machinery import SourceFileLoader
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest

import yaml

LAUNCHER = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).with_name('preview.py')
spec = importlib.util.spec_from_loader('preview', SourceFileLoader('preview', str(LAUNCHER)))
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


class PreviewLifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dp-', dir='/tmp')
        self.root = Path(self.temp.name).resolve()
        self.registry = self.root / 'tiles'
        self.registry.mkdir()
        self.tiles = self.registry / 'services.yaml'
        self.tiles.write_text('[]\n')
        self.programs = self.root / 'programs'
        self.programs.mkdir()
        self.project = self.root / "project % ; ' space"
        self.project.mkdir()
        self.worker = self.project / 'worker.py'
        self.worker.write_text(
            'import os, sys, time\n'
            'print(repr(sys.argv[1:]), os.getcwd(), os.environ["PORT"], flush=True)\n'
            'while True: time.sleep(1)\n'
        )
        self.command = shlex.join([sys.executable, str(self.worker), "literal % ; ' argument"])
        self.config = self.root / 'supervisord.conf'
        self.config.write_text(f'''[supervisord]
logfile={self.root}/supervisor.log
pidfile={self.root}/supervisor.pid
childlogdir={self.root}
[unix_http_server]
file={self.root}/supervisor.sock
chmod=0700
[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface
[include]
files={self.programs}/*.conf
''')
        self.url = f'unix://{self.root}/supervisor.sock'
        self.start_supervisor()

    def start_supervisor(self):
        self.daemon = subprocess.Popen(
            [sys.executable, '-m', 'supervisor.supervisord', '-n', '-c', str(self.config)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            try:
                self.server = preview.supervisor_client(self.url)
                self.client = self.server.supervisor
                self.client.getState()
                return
            except OSError:
                self.server.__exit__(None, None, None)
                if self.daemon.poll() is not None:
                    self.fail((self.root / 'supervisor.log').read_text())
                time.sleep(0.05)
        self.fail('Supervisor failed to start')

    def stop_supervisor(self):
        if self.daemon.poll() is None:
            self.client.shutdown()
            self.daemon.wait(timeout=25)
        self.server.__exit__(None, None, None)

    def tearDown(self):
        self.stop_supervisor()
        self.temp.cleanup()

    def cli(self, *args, success=True):
        result = subprocess.run([
            sys.executable, str(LAUNCHER), '--config-dir', str(self.registry),
            '--program-dir', str(self.programs), '--supervisor-url', self.url,
            '--base-url', 'https://previews.example.com', *args,
        ], capture_output=True, text=True, timeout=60)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def add(self, command=None, **kwargs):
        return self.cli('add', 'Shop', '5173', '--directory', str(self.project),
                        '--command', command or self.command, **kwargs)

    def running(self, name='preview-5173', old_pid=None):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            info = self.client.getProcessInfo(name)
            if info['statename'] == 'RUNNING' and info['pid'] != old_pid:
                return info['pid']
            time.sleep(0.1)
        self.fail(f'{name} did not become RUNNING')

    def test_lifecycle_and_persistent_restore(self):
        self.add()
        pid = self.running()
        tiles = yaml.safe_load(self.tiles.read_text())
        self.assertEqual(tiles[0]['Live previews'][0]['Shop']['href'], '/live/5173/')
        log = (self.programs / 'preview-5173.log').read_text()
        self.assertIn("literal % ;", log)
        self.assertIn(str(self.project), log)
        self.assertIn('5173', log)
        # Idempotent registration leaves a healthy process running.
        self.add()
        self.assertEqual(self.running(), pid)
        os.kill(pid, signal.SIGKILL)
        pid = self.running(old_pid=pid)
        # A changed command replaces only its own managed server.
        self.cli('add', 'Other', '5174', '--directory', str(self.project), '--command', self.command)
        other_pid = self.running('preview-5174')
        self.add(self.command + ' changed')
        self.running(old_pid=pid)
        self.assertEqual(self.running('preview-5174'), other_pid)
        self.assertIn('changed', (self.programs / 'preview-5173.log').read_text())
        # A replacement Supervisor loads the saved programs without registration.
        self.stop_supervisor()
        self.start_supervisor()
        self.running()
        self.running('preview-5174')
        self.cli('remove', '5173')
        self.assertFalse((self.programs / 'preview-5173.conf').exists())
        self.assertFalse((self.programs / 'preview-5173.json').exists())
        self.assertEqual([p['name'] for p in self.client.getAllProcessInfo()], ['preview-5174'])
        self.cli('remove', '5173')  # Removing an absent or legacy tile is safe.
        self.cli('list')

    def test_failed_start_restores_service_and_tile(self):
        self.add()
        saved = {p: p.read_bytes() for p in (self.tiles, self.programs / 'preview-5173.json', self.programs / 'preview-5173.conf')}
        self.add('/nonexistent/preview-executable', success=False)
        self.running()
        for path, content in saved.items():
            self.assertEqual(path.read_bytes(), content)
        # Invalid new services never publish a tile or persist an auto-start entry.
        self.cli('add', 'Broken', '5175', '--command', '/nonexistent/preview-executable', success=False)
        self.assertFalse((self.programs / 'preview-5175.conf').exists())
        self.assertFalse((self.programs / 'preview-5175.json').exists())
        self.assertEqual(self.tiles.read_bytes(), saved[self.tiles])
        self.cli('add', 'Outside', '6000', '--command', self.command, success=False)
        self.cli('add', 'Missing command', '5176', success=False)


if __name__ == '__main__':
    unittest.main()
