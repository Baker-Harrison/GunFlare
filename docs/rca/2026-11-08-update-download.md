# Root cause analysis: the update download fails

Date: 2026-11-08. Scope: the update from v0.1.0.9 to v0.1.0.10. The menu showed "The download failed" with no other text.

## What the tests show

| Test | Result |
|---|---|
| `curl` with the headers of the game, on the asset URL of v0.1.0.10 | GitHub sends a redirect. The storage server then sends the package (HTTP 206 for a range). The server side is correct. |
| `tests/test_update_download.gd` in CI, normal frame rate | The game's request downloads and verifies the Windows package (298,900,754 bytes) in 8.3 seconds, with the old headers and the new headers. |
| The same test at 5 frames per second | The download does not finish in 600 seconds. |

## Root cause

The download used `HTTPRequest` without a thread. Without a thread, `HTTPRequest` reads one chunk of the body on each frame. The chunk was 256 KB. Thus the speed of the download depended on the frame rate of the game.

The packages became larger (about 300 MB) with the new models. At a low frame rate the transfer takes many minutes, for example when the window is in the background or the frames are slow. The storage server can then close the connection. The game showed only "The download failed (result, HTTP)", so the cause was not clear.

## Fix

| Change | Effect |
|---|---|
| The download request uses a thread (`use_threads = true`) and 1 MB chunks. | The download speed does not depend on the frame rate. |
| A download that fails on the network or with a server error tries again two times. | A short network problem does not stop the update. |
| The error text names the cause, for example "The connection closed during the download". | A player can report the cause. |
| The download asks for `application/octet-stream`. | The download request does not use the media type of the GitHub API. |

## Changes to the pipeline

- CI downloads the latest release with the game's own download code at 5 frames per second, and checks the size, the SHA-256 digest, and the contents. A change that makes the download depend on the frame rate again fails CI.
- After each release, the release workflow downloads the three published packages the same way. A broken or incomplete release fails the release run.

## A player on v0.1.0.10 or older

The download code runs in the old game. If the update fails, keep the game window in front during the download. If it still fails, download the newest zip from the releases page one time. The next updates use the new download code.
