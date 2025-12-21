Beat-Synced Image Sequence Video Generator
Project Overview
A bash/ffmpeg pipeline that combines multiple image sequence folders into a single synchronized video, switching folders on beat to create a rhythmic visual experience.
Technical Specifications
Video Settings:

Resolution: 1920x1080
Frame rate: 30 fps
Tempo: 120 BPM
Folder switching: Every 4 beats (2 seconds / 60 frames)

Processing Logic:

Randomly selects folders every 2 seconds
Plays 60 consecutive frames from each folder sequentially
Scales images to fit with letterboxing/pillarboxing
Removes folders when they can't provide a full 60-frame segment (prevents freezing)
Continues until all folders are exhausted

Key Features

Parallel Processing: Uses multi-threading for image scaling (memory-limited to 8 concurrent jobs)
Progress Previews: Generates preview MP4s every 600 frames (20 seconds) in previews/ folder
Memory Efficient: Batched parallel processing prevents memory exhaustion
No Freezing: Only uses folders with enough frames for complete segments

Usage
