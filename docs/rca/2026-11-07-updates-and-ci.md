# Root cause analysis: updates, saves, and CI

Date: 2026-11-07. Scope: pull requests 1 to 6, all CI runs and releases to v0.1.0.7. The repository has no issues.

## Problems that occurred

| Problem | Where it occurred | Root cause | Fix |
|---|---|---|---|
| The macOS export failed after the merge of PR 1. | Release run 2 | CI did not export the packages. The error showed only in the release after the merge. | CI now runs `tools/export_all.sh` for each pull request. |
| The pull-request check failed on PR 3 and PR 5. | CI runs 8 and 12 | The check read the footer after `---` as part of the Table section. | The check now ends a section at `---`. The self-test covers a footer. |
| The update failed with "The process cannot access the file". | Windows, v0.1.0.4 | The player started GunFare.exe from inside the zip. Explorer ran the game from a temporary folder and held the files. The script copied over the files with no retry and no rollback. | The update goes to a permanent folder (PR 6). The script now waits for each lock, retries, keeps a backup, and puts the old files back on a failure. |
| The menu cut the error text in the middle of a word. | Windows, v0.1.0.4 | The game kept only 180 characters of the log. | The menu shows a clear instruction for a known error. Other text keeps 300 characters. |

## Problems found in the review

| Problem | Effect | Fix |
|---|---|---|
| The download had a timeout of 30 seconds for the full request. | A slow connection could not download a package of 80 MB or more. | The download has no total timeout. A download that stops for 45 seconds fails. |
| The game did not examine the package. | A short or damaged download could replace a good game. | The game compares the size and the SHA-256 digest from GitHub. It also opens the zip and finds the executable. |
| The game checked for a release only at start. | A player had to restart the game to see a new version. | The game checks every 5 minutes and when the window gets the focus. The check sends an ETag, so the GitHub rate limit is not used up. |
| After a download error, the menu showed only TRY AGAIN. | The player could not try the install again. | An error keeps the release, so INSTALL UPDATE shows again. |
| The profile and the settings were written in place. | A crash or an update during a write could delete all progress. | `SafeFile` writes a temporary file, keeps a backup, and reads the backup when the main file is damaged. |
| The game quit for an update without a save. | Progress after the last save could be lost. | The game saves the profile and the settings before it quits for an update. |
| A test that stopped on a script error still printed "0 failures". | A broken script could pass CI. | `tools/run_godot.py` fails a run that prints a script error. `tests/load_all_scripts.gd` loads every script. |
| The install scripts had no test. | A change to a script could break all updates. | `tools/test_update_scripts.py` runs both scripts on a fake game folder in CI. |
| Two quick merges could publish releases out of order. | The older release could become the latest release. | The release workflow runs one release at a time, in merge order. |
| A second run of a release workflow failed when the tag existed. | A failed upload could not be repaired with a new run. | The workflow replaces the packages of an existing tag. |
| PowerShell wrote the log with a byte order mark. | A good install could read as a failure. | The script writes UTF-8 without a byte order mark. The game also removes the mark. |

## Rules that prevent a repeat

- Run each Godot command through `tools/run_godot.py`.
- Write a player file with `SafeFile.write_text` only.
- Change the install scripts in `tools/`. Then run `python tools/check_update_scripts.py --fix`.
- Do not merge a pull request when the export job fails.

## A player on an old version

The installer runs from the old game. A player on v0.1.0.7 or older has the old installer. If that update fails, download the newest zip from the releases page one time. Extract the zip to a folder, for example `Documents\GunFare`. Start GunFare.exe from that folder. The next updates use the new installer.
