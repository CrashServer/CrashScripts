# Installation Guide - Crash/Faces Studio

Complete installation instructions for all platforms.

## Quick Installation (Recommended)

### Step 1: Check Python
```bash
python --version
```

**Required**: Python 3.7 or higher

### Step 2: Install Dependencies
```bash
# Install required Python package for image processing
pip install Pillow
```
```
# Run the complete application
python crash_faces_studio.py
```

**Full rendering functionality included!** All features are now enabled.

---

## Detailed Installation by Platform

### 🐧 Linux (Ubuntu/Debian)

```bash
# Update system
sudo apt update

# Install Python, tkinter, and FFmpeg
sudo apt install python3 python3-tk python3-pip ffmpeg

# Install Python dependencies
pip3 install Pillow


# Run the application
python3 crash_faces_studio.py
```

### 🍎 macOS

```bash
# Install dependencies via Homebrew
brew install python-tk ffmpeg

# Install Python dependencies
pip3 install Pillow


# Run the application
python3 crash_faces_studio.py
```

### 🪟 Windows

1. **Install Python**:
   - Download from [python.org](https://www.python.org/downloads/)
   - ✅ Check "Add Python to PATH" during installation
   - tkinter is included automatically

2. **Install FFmpeg**:
   - Download from [ffmpeg.org](https://ffmpeg.org/download.html)
   - Extract to `C:\ffmpeg`
   - Add `C:\ffmpeg\bin` to your system PATH

3. **Install Dependencies & Run**:
   ```cmd
   # Open Command Prompt or PowerShell
   pip install Pillow
  
   # Run the application
   python crash_faces_studio.py
   ```

---

## ✅ Full Rendering Enabled

**All features are now included and functional!**

The repository now contains:
```
crash-faces-studio/
├── crash_faces_studio.py    # Main application with full rendering
├── blackwhite.py             # Advanced rendering with freeze frames  
├── script.py                 # Basic rendering
├── README.md                 # User guide
├── INSTALL.md               # This installation guide
└── ...                      # Documentation files
```

- **Website**: https://crashserver.fr
- **Issues**: GitHub repository issue tracker

---

**Happy installing!** 🚀
