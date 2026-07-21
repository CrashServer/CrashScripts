instagram — Make videos Instagram-compatible (fix the silent "unknown error")
Project Overview
A small Bash wrapper around ffmpeg that re-encodes a video into an MP4 that
Instagram will actually accept, without changing its aspect ratio or resolution.

Why it exists
Instagram often rejects otherwise-fine videos with a generic "unknown error"
and no explanation. The usual culprits are:
  - a full-range yuvj420p pixel format (screen/game recorders love this)
  - a very high bitrate and huge file size
  - a 60fps (or otherwise odd) frame rate
  - the moov atom sitting at the end of the file
This script normalises all four in one pass so the upload just goes through.

What it does to every file
  - yuvj420p full-range   -> standard yuv420p, limited (tv) range  [main fix]
  - high bitrate / size   -> capped ~8 Mbps video bitrate, smaller file
  - 60fps / odd rate      -> 30fps
  - moov atom at end      -> +faststart (metadata moved to the front)
  - audio                 -> AAC 128k, 48kHz -> 44.1kHz
Aspect ratio and resolution are left untouched.

Dependencies
Required:
  - bash
  - ffmpeg (with libx264 + aac)

Installation

Option A — drop-in single-file install:
  curl -o ~/.local/bin/instagram https://raw.githubusercontent.com/CrashServer/CrashScripts/main/video/instagram-compat/instagram.sh
  chmod +x ~/.local/bin/instagram

Option B — clone the repo:
  git clone https://github.com/CrashServer/CrashScripts.git
  cp CrashScripts/video/instagram-compat/instagram.sh ~/.local/bin/instagram
  chmod +x ~/.local/bin/instagram

Make sure ~/.local/bin is in your PATH.

Usage

Single file (output name derived automatically):
  instagram clip.mp4
  # -> writes clip_instagram.mp4 next to the original

Explicit output name:
  instagram clip.mp4 out.mp4

Batch mode (each input -> <name>_instagram.mp4):
  instagram *.mp4

Tuning (environment variables)

Any of these can be overridden per run:
  FPS        target frame rate      (default: 30)
  VBITRATE   target video bitrate   (default: 8M)
  MAXRATE    peak video bitrate     (default: 10M)
  BUFSIZE    rate-control buffer    (default: 12M)
  ABITRATE   audio bitrate          (default: 128k)

Examples:
  FPS=60 VBITRATE=12M instagram clip.mp4     # keep 60fps, higher bitrate
  VBITRATE=5M instagram clip.mp4             # smaller file for slow uploads

Notes

  - The original file is never modified; a new file is always written.
  - Batch mode and the explicit-output form can't be mixed: if you pass exactly
    two arguments and the second does not already exist, it is treated as the
    output filename. Otherwise every argument is treated as an input.
  - Output resolution and aspect ratio always match the input. If a landscape
    post still misbehaves, Instagram may want a square (1:1) or vertical (9:16)
    crop for Reels — that is out of scope for this script.
  - Not related to extract_instagram.sh in otherscripts/, which is a one-off
    clip extractor with hardcoded paths; this is a general-purpose re-encoder.

Verifying the result

  ffprobe -v error -show_entries \
    stream=codec_name,width,height,pix_fmt,color_range,avg_frame_rate \
    -of default=noprint_wrappers=1 out.mp4
  # expect: pix_fmt=yuv420p, color_range=tv, avg_frame_rate=30/1
