"""Run the install scripts on a fake game folder and examine the result.

The test covers a good install, a package without the executable, and a
failure in the middle of the copy. In each failure the old files must stay.

Use: python tools/test_update_scripts.py [--require-pwsh]
The PowerShell cases run only when pwsh is on the PATH.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXE = "GunFare.x86_64"


def make_zip(path: Path, files: dict[str, str]) -> None:
    with zipfile.ZipFile(path, "w") as archive:
        for name, text in files.items():
            archive.writestr(name, text)


def make_install(folder: Path) -> None:
    folder.mkdir(parents=True)
    (folder / EXE).write_text("old game")
    (folder / "keep.txt").write_text("user file")


def waiter() -> subprocess.Popen:
    """A process that stands in for the game. It stops after one second."""
    return subprocess.Popen([sys.executable, "-c", "import time; time.sleep(1)"])


def run(kind: str, work: Path, zip_files: dict[str, str], moved: bool = False) -> tuple[str, Path]:
    install = work / "install dir"
    if moved:
        install = work / "new home" / "GunFare"
    else:
        make_install(install)
    package = work / "package.zip"
    make_zip(package, zip_files)
    log = work / "logs" / "install.log"
    game = waiter()
    # Collect the exit status at once. Otherwise the stopped process stays a
    # zombie and the script sees it as a running game.
    reaper = threading.Thread(target=game.wait)
    reaper.start()
    env = dict(os.environ, GUNFARE_UPDATE_NO_START="1")
    if kind == "sh":
        command = ["sh", str(ROOT / "tools/apply_update.sh")]
    else:
        command = ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(ROOT / "tools/apply_update.ps1")]
    command += [str(game.pid), str(package), str(install), EXE, str(log), "1" if moved else "0"]
    started = time.time()
    subprocess.run(command, env=env, timeout=240, check=False)
    reaper.join()
    if time.time() - started < 1.0:
        raise AssertionError(f"{kind}: the script did not wait for the game to stop")
    text = log.read_text(encoding="utf-8-sig").strip() if log.exists() else ""
    return text, install


def read(path: Path) -> str:
    return path.read_text() if path.exists() else "<missing>"


def expect(condition: bool, text: str, failures: list[str]) -> None:
    if not condition:
        failures.append(text)
        print("FAIL: " + text)


def leftovers(install: Path) -> list[str]:
    return [p.name for p in install.iterdir() if p.name.startswith(".gunfare-backup") or p.name.endswith(".gunfare-new")]


def cases(kind: str, failures: list[str]) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "good"
        work.mkdir()
        log, install = run(kind, work, {f"GunFare/{EXE}": "new game", "GunFare/data.pck": "data"})
        expect(log == "OK", f"{kind}: a good package gives OK, not {log!r}", failures)
        expect(read(install / EXE) == "new game", f"{kind}: the executable is new", failures)
        expect(read(install / "data.pck") == "data", f"{kind}: a new file is added", failures)
        expect(read(install / "keep.txt") == "user file", f"{kind}: a user file stays", failures)
        expect(not leftovers(install), f"{kind}: no backup is left: {leftovers(install)}", failures)

        work = Path(tmp) / "moved"
        work.mkdir()
        log, install = run(kind, work, {EXE: "new game"}, moved=True)
        expect(log == f"OK MOVED {install}", f"{kind}: a moved install names the new folder, not {log!r}", failures)
        expect(read(install / EXE) == "new game", f"{kind}: a moved install makes the new folder", failures)

        work = Path(tmp) / "missing"
        work.mkdir()
        log, install = run(kind, work, {"readme.txt": "no game"})
        expect(log.startswith("FAIL") and "does not contain" in log, f"{kind}: a package without the executable fails, not {log!r}", failures)
        expect(read(install / EXE) == "old game", f"{kind}: the old executable stays after a bad package", failures)

    if kind != "sh":
        return
    with tempfile.TemporaryDirectory() as tmp:
        # The second entry has a space in its name. The shell script stops at
        # that entry, after it replaced the executable. It must roll back.
        work = Path(tmp) / "rollback"
        work.mkdir()
        log, install = run(kind, work, {EXE: "new game", "z z.txt": "x"})
        expect(log.startswith("FAIL"), f"{kind}: a failure in the copy gives FAIL, not {log!r}", failures)
        expect(read(install / EXE) == "old game", f"{kind}: the rollback puts the old executable back", failures)
        expect(not (install / "z z.txt").exists(), f"{kind}: the rollback removes the new files", failures)
        expect(not leftovers(install), f"{kind}: no backup is left after a rollback: {leftovers(install)}", failures)


def main() -> int:
    failures: list[str] = []
    kinds = []
    if shutil.which("sh"):
        kinds.append("sh")
    if shutil.which("pwsh"):
        kinds.append("pwsh")
    elif "--require-pwsh" in sys.argv[1:]:
        print("pwsh is not installed")
        return 1
    for kind in kinds:
        cases(kind, failures)
    if failures:
        print(f"{len(failures)} install script checks failed")
        return 1
    print("install script checks passed for: " + ", ".join(kinds))
    return 0


if __name__ == "__main__":
    sys.exit(main())
