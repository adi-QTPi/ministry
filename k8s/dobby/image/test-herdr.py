"""Exercise Supervisor-like process groups, remote readiness and clean shutdown."""
import json
import os
import signal
import subprocess
import sys
import tempfile
import time

launcher = sys.argv[1] if len(sys.argv) > 1 else "/usr/local/bin/dobby-herdr-start"
with tempfile.TemporaryDirectory(prefix="dobby-herdr-smoke-") as home:
    env = dict(os.environ, HOME=home, SHELL="/bin/bash")
    for key in ("XDG_CONFIG_HOME", "HERDR_CONFIG_PATH", "HERDR_SESSION"):
        env.pop(key, None)
    # Supervisor starts services as process-group leaders, but not session leaders.
    server = subprocess.Popen(
        ["/usr/bin/python3", launcher, "--session", "image-smoke"],
        env=env, cwd="/workspace", process_group=0,
    )
    try:
        for attempt in range(30):
            assert server.poll() is None, "Herdr exited before becoming ready"
            result = subprocess.run(
                ["herdr", "--session", "image-smoke", "status", "server", "--json"],
                env=env, check=True, capture_output=True, text=True, timeout=5,
            )
            status = json.loads(result.stdout)
            if status.get("running"):
                assert status["capabilities"]["detached_server_daemon"], status
                assert status["compatible"], status
                assert os.getsid(server.pid) == server.pid
                assert os.getpgid(server.pid) == server.pid
                break
            time.sleep(1)
        else:
            raise AssertionError("Herdr did not become ready")
        os.killpg(server.pid, signal.SIGINT)
        assert server.wait(timeout=15) == 0, "Herdr did not stop cleanly"
        print("Herdr detached readiness, tracked PID and SIGINT shutdown passed")
    finally:
        if server.poll() is None:
            os.killpg(server.pid, signal.SIGKILL)
            server.wait(timeout=5)
