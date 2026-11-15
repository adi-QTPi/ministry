#!/usr/bin/python3
"""Keep Supervisor's tracked PID while making Herdr a detached session leader."""
import os
import sys

if os.getsid(0) != os.getpid():
    # Supervisor makes its child a process-group leader, which cannot setsid().
    # Join its parent's group first; setsid then creates a new session without
    # forking. The final PGID still equals Supervisor's tracked PID, so group
    # stop/kill and child reaping continue to work normally.
    if os.getpgrp() == os.getpid():
        os.setpgid(0, os.getpgid(os.getppid()))
    os.setsid()

binary = "/usr/local/bin/herdr"
os.execv(binary, [binary, *sys.argv[1:], "server"])
