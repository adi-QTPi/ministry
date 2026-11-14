#!/usr/bin/python3
"""Copy the bundled Firstmate checkout to its persistent home once."""
import os
import pathlib
import shutil
import sys
import tempfile


def seed(source, destination):
    if destination.exists() or destination.is_symlink():
        return False
    if not (source / "AGENTS.md").is_file() or not (source / ".git").is_dir():
        raise ValueError("Bundled Firstmate checkout is incomplete.")
    staging = pathlib.Path(tempfile.mkdtemp(prefix=".firstmate-seed-", dir=destination.parent))
    try:
        shutil.copytree(source, staging, dirs_exist_ok=True, symlinks=True)
        (staging / "config").mkdir(exist_ok=True)
        (staging / "config/backend").write_text("tmux\n")
        # One startup process owns the fresh workspace. Existing homes are never updated.
        if destination.exists() or destination.is_symlink():
            return False
        os.rename(staging, destination)
        return True
    finally:
        if staging.exists():
            shutil.rmtree(staging)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: dobby-seed-firstmate SOURCE DESTINATION")
    try:
        if seed(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])):
            print("Firstmate initialized at /workspace/firstmate; launch with dobby-firstmate.")
    except (OSError, ValueError) as error:
        sys.exit(str(error))
