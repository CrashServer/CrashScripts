inject-360 — 360° Spherical Metadata Injector for Videos
Project Overview
A self-installing Bash wrapper around Google's spatial-media tool that injects
(or checks) 360° equirectangular metadata on MP4/MOV files so platforms like
YouTube, Facebook and VR players recognise them as spherical videos.

Why it exists
When you re-encode or trim a 360° video with ffmpeg (especially with -c copy),
the sv3d MP4 box carrying the "equirectangular" spherical metadata is often
dropped. YouTube then treats the upload as a flat 2D video. This script makes
re-injecting the metadata a one-command (or one-click menu) operation, with no
manual cloning or venv setup.

Features

Interactive CLI menu (default when run with no args) with:
  - File path prompt (tab-completion, handles drag-and-drop paths with
    file:// prefix, escaped spaces, or surrounding quotes)
  - Live status check of current metadata (PRESENT / ABSENT)
  - Presets: mono equirectangular, stereo top-bottom, stereo left-right
  - Custom mode (pick projection + stereo mode independently)
  - Post-injection verification via ffmpeg

One-shot CLI mode for scripting / batch use:
  inject-360.sh INPUT [OUTPUT]
  inject-360.sh --check INPUT
  inject-360.sh -s top-bottom IN OUT

Self-installing:
  - On first run, clones google/spatial-media into ~/.local/share/spatial-media
  - Creates a local Python venv there
  - Reuses both on subsequent runs (no network needed after first run)
  - --update flag pulls latest spatial-media before running

Dependencies

Required:
  - bash 4+
  - python3 (for the spatial-media tool)
  - git (only for first-run clone)

Recommended:
  - ffmpeg (for --check mode and post-injection verification)

Installation

Option A — drop-in single-file install:
  curl -o ~/.local/bin/inject-360 https://raw.githubusercontent.com/CrashServer/CrashScripts/main/video/inject-360/inject-360.sh
  chmod +x ~/.local/bin/inject-360

Option B — clone the repo:
  git clone https://github.com/CrashServer/CrashScripts.git
  cp CrashScripts/video/inject-360/inject-360.sh ~/.local/bin/inject-360
  chmod +x ~/.local/bin/inject-360

Make sure ~/.local/bin is in your PATH.

Usage

Interactive menu (recommended):
  inject-360

Check whether a file has 360° metadata:
  inject-360 --check myvideo.mp4

Inject mono equirectangular metadata (most common):
  inject-360 myvideo.mp4
  # -> writes myvideo_360.mp4 next to the original

Inject stereo (3D VR) metadata:
  inject-360 -s top-bottom myvideo.mp4 out.mp4
  inject-360 -s left-right myvideo.mp4 out.mp4

Overwrite an existing output:
  inject-360 -f myvideo.mp4 out.mp4

Update the underlying spatial-media tool:
  inject-360 --update myvideo.mp4

Options

  -s, --stereo MODE       none | top-bottom | left-right    (default: none)
  -p, --projection TYPE   equirectangular | none            (default: equirectangular)
  -f, --force             Overwrite OUTPUT if it exists
  -c, --check             Only print the 360° metadata status of INPUT
  -I, --interactive       Force interactive menu
      --update            Pull latest spatial-media before running
  -h, --help              Show help

Notes

  - The spatial-media tool never writes in place: an output file is always
    created alongside the input. The original is never modified.
  - INPUT and OUTPUT must differ.
  - Default output path is INPUT with "_360" appended before the extension
    (e.g. foo.mp4 -> foo_360.mp4).
  - The --projection option only supports equirectangular and none in the
    upstream tool (no cubemap in this version of spatial-media).

Uninstall

  rm ~/.local/bin/inject-360
  rm -rf ~/.local/share/spatial-media

Credits

Wraps https://github.com/google/spatial-media (Apache 2.0).
