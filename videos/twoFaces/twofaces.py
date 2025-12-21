#!/usr/bin/env python3
"""
Crash/Faces Studio - Visual Timeline Animation Creator

A modern GUI application for creating animated videos from image sequences
with visual timeline preview and advanced timing controls.

Author: crashserver.fr
License: MIT
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import os
import subprocess
import threading
import sys
from pathlib import Path
import time
import re
import math
import random
from tkinter import Canvas

__version__ = "1.0.0"
__author__ = "crashserver.fr"

class FrameTimeline:
    """Interactive timeline visualization for frame sequences"""
    
    def __init__(self, parent, width=800, height=150):
        self.width = width
        self.height = height
        self.timeline_height = 50
        self.timeline_y = 50
        
        # Colors
        self.bg_color = "#1e1e1e"
        self.normal_color = "#00ff88"  # Green for normal frames
        self.freeze_color = "#ff4444"  # Red for freeze frames
        self.timeline_bg = "#3a3a3a"
        self.separator_color = "#666666"  # Grey for frame separators
        self.text_color = "#ffffff"
        self.accent_color = "#0099ff"
        
        # Create canvas with scrollbar for long timelines
        self.canvas_frame = ttk.Frame(parent)
        self.canvas_frame.pack(fill=tk.X, pady=10)
        
        self.canvas = Canvas(self.canvas_frame, width=width, height=height, 
                           bg=self.bg_color, highlightthickness=0)
        
        # Add horizontal scrollbar for long timelines
        self.h_scrollbar = ttk.Scrollbar(self.canvas_frame, orient=tk.HORIZONTAL, command=self.canvas.xview)
        self.canvas.configure(xscrollcommand=self.h_scrollbar.set)
        
        self.canvas.pack(fill=tk.X)
        self.h_scrollbar.pack(fill=tk.X)
        
        # Timeline data
        self.frames = []
        self.total_frames = 0
        self.fps = 24
        self.hover_info = None
        
        # Bind events
        self.canvas.bind("<Motion>", self.on_hover)
        self.canvas.bind("<Leave>", self.on_leave)
        self.canvas.bind("<Button-1>", self.on_click)
        
    def generate_frame_sequence(self, total_frames, fps, frame_duration, freeze_prob=0.0, 
                               freeze_min=2.0, freeze_max=5.0, seed=None):
        """Generate the frame sequence using the same logic as the rendering scripts"""
        try:
            if seed is not None:
                if isinstance(seed, str) and seed.strip():
                    try:
                        seed = int(seed)
                    except ValueError:
                        seed = hash(seed) % (2**32)
                elif not seed or seed == "":
                    seed = None
                    
            if seed is not None:
                random.seed(seed)
            else:
                random.seed()
                
            self.total_frames = max(1, int(total_frames))
            self.fps = max(1, int(fps))
            self.frames = []
            
            if freeze_prob == 0 or not freeze_prob:
                # Simple mode - no freeze frames
                base_frames_per_image = max(1, int(frame_duration * fps))
                
                current_frame = 0
                image_id = 1
                
                while current_frame < self.total_frames:
                    duration = min(base_frames_per_image, self.total_frames - current_frame)
                    
                    frame_info = {
                        'start': current_frame,
                        'end': current_frame + duration,
                        'duration': duration,
                        'type': 'normal',
                        'image_id': image_id,
                        'time_start': current_frame / fps,
                        'time_end': (current_frame + duration) / fps
                    }
                    
                    self.frames.append(frame_info)
                    current_frame += duration
                    image_id += 1
            else:
                # Advanced mode - with freeze frames
                base_frames_per_image = max(1, int(frame_duration * fps))
                
                current_frame = 0
                image_id = 1
                
                while current_frame < self.total_frames:
                    # Determine if this will be a freeze frame
                    is_freeze = random.random() < freeze_prob
                    
                    if is_freeze:
                        freeze_multiplier = random.uniform(max(freeze_min, 1.0), max(freeze_max, freeze_min + 0.1))
                        duration = int(base_frames_per_image * freeze_multiplier)
                        frame_type = 'freeze'
                    else:
                        duration = base_frames_per_image
                        frame_type = 'normal'
                        freeze_multiplier = 1.0
                    
                    # Don't exceed total frames
                    duration = min(duration, self.total_frames - current_frame)
                    if duration <= 0:
                        break
                    
                    frame_info = {
                        'start': current_frame,
                        'end': current_frame + duration,
                        'duration': duration,
                        'type': frame_type,
                        'image_id': image_id,
                        'time_start': current_frame / fps,
                        'time_end': (current_frame + duration) / fps,
                        'multiplier': freeze_multiplier
                    }
                    
                    self.frames.append(frame_info)
                    current_frame += duration
                    image_id += 1
                    
                    if current_frame >= self.total_frames:
                        break
                        
        except Exception as e:
            print(f"Error generating frame sequence: {e}")
            self.frames = []
            self.total_frames = 0
                    
    def draw_timeline(self):
        """Draw the timeline visualization"""
        try:
            self.canvas.delete("all")
            
            if not self.frames or self.total_frames == 0:
                # Draw empty timeline
                self.canvas.create_rectangle(10, self.timeline_y, self.width - 10, 
                                           self.timeline_y + self.timeline_height,
                                           fill=self.timeline_bg, outline="#555")
                self.canvas.create_text(self.width // 2, self.height // 2, 
                                      text="Configure settings to see timeline preview",
                                      fill=self.text_color, font=("Arial", 12))
                self.canvas.configure(scrollregion=self.canvas.bbox("all"))
                return
                
            # Calculate dimensions
            min_frame_width = 3
            calculated_width = max(self.width - 20, len(self.frames) * min_frame_width)
            timeline_width = calculated_width
            timeline_left = 10
            
            # Set scroll region for horizontal scrolling
            self.canvas.configure(scrollregion=(0, 0, timeline_left + timeline_width + 20, self.height))
            
            # Draw timeline background
            self.canvas.create_rectangle(timeline_left, self.timeline_y, 
                                       timeline_left + timeline_width, 
                                       self.timeline_y + self.timeline_height,
                                       fill=self.timeline_bg, outline="#555")
            
            # Draw frame blocks and separators
            for i, frame in enumerate(self.frames):
                start_x = timeline_left + (i / len(self.frames)) * timeline_width
                end_x = timeline_left + ((i + 1) / len(self.frames)) * timeline_width
                
                if end_x - start_x < min_frame_width:
                    end_x = start_x + min_frame_width
                
                color = self.freeze_color if frame['type'] == 'freeze' else self.normal_color
                
                # Draw frame block
                rect_id = self.canvas.create_rectangle(start_x, self.timeline_y + 2,
                                                     end_x, self.timeline_y + self.timeline_height - 2,
                                                     fill=color, outline=color, width=1, tags="frame")
                
                # Draw frame separator
                if i > 0:
                    self.canvas.create_line(start_x, self.timeline_y + 1,
                                          start_x, self.timeline_y + self.timeline_height - 1,
                                          fill=self.separator_color, width=1)
                
                # Store frame info for hover
                self.canvas.tag_bind(rect_id, "<Enter>", lambda e, f=frame: self.show_frame_info(e, f))
                self.canvas.tag_bind(rect_id, "<Leave>", lambda e: self.hide_frame_info())
                
                # Add frame number if space allows
                if end_x - start_x >= 20:
                    self.canvas.create_text((start_x + end_x) / 2, self.timeline_y + self.timeline_height / 2,
                                          text=str(frame['image_id']), fill="white", 
                                          font=("Arial", 8, "bold"))
            
            # Draw time markers and legend
            self.draw_time_markers(timeline_left, timeline_width)
            self.draw_legend()
            self.draw_statistics()
            
        except Exception as e:
            print(f"Error drawing timeline: {e}")
        
    def draw_time_markers(self, timeline_left, timeline_width):
        """Draw time markers below timeline"""
        try:
            if not self.frames or self.fps == 0:
                return
                
            duration = self.total_frames / self.fps
            
            # Determine appropriate interval
            if duration <= 5:
                interval = 0.5
            elif duration <= 10:
                interval = 1
            elif duration <= 30:
                interval = 5
            elif duration <= 120:
                interval = 10
            else:
                interval = 30
                
            current_time = 0
            while current_time <= duration:
                x = timeline_left + (current_time / duration) * timeline_width
                
                # Draw tick mark
                self.canvas.create_line(x, self.timeline_y + self.timeline_height,
                                      x, self.timeline_y + self.timeline_height + 8,
                                      fill=self.text_color)
                
                # Draw time label
                time_text = f"{int(current_time)}s" if current_time == int(current_time) else f"{current_time:.1f}s"
                self.canvas.create_text(x, self.timeline_y + self.timeline_height + 20,
                                      text=time_text, fill=self.text_color, font=("Arial", 8))
                
                current_time += interval
        except Exception as e:
            print(f"Error drawing time markers: {e}")
            
    def draw_legend(self):
        """Draw color legend"""
        try:
            legend_y = 10
            
            # Clear background for legend
            self.canvas.create_rectangle(5, legend_y - 2, 350, legend_y + 17,
                                       fill=self.bg_color, outline="")
            
            # Normal frames
            self.canvas.create_rectangle(10, legend_y, 25, legend_y + 12,
                                       fill=self.normal_color, outline="")
            self.canvas.create_text(30, legend_y + 6, text="Normal Frames",
                                  fill=self.text_color, font=("Arial", 9), anchor="w")
            
            # Freeze frames
            self.canvas.create_rectangle(150, legend_y, 165, legend_y + 12,
                                       fill=self.freeze_color, outline="")
            self.canvas.create_text(170, legend_y + 6, text="Freeze Frames",
                                  fill=self.text_color, font=("Arial", 9), anchor="w")
            
            # Frame separators
            self.canvas.create_line(280, legend_y + 3, 295, legend_y + 3,
                                  fill=self.separator_color, width=2)
            self.canvas.create_line(280, legend_y + 9, 295, legend_y + 9,
                                  fill=self.separator_color, width=2)
            self.canvas.create_text(300, legend_y + 6, text="Frame Boundaries",
                                  fill=self.text_color, font=("Arial", 9), anchor="w")
        except Exception as e:
            print(f"Error drawing legend: {e}")
                              
    def draw_statistics(self):
        """Draw frame statistics"""
        try:
            if not self.frames:
                return
                
            normal_count = sum(1 for f in self.frames if f['type'] == 'normal')
            freeze_count = sum(1 for f in self.frames if f['type'] == 'freeze')
            normal_frames = sum(f['duration'] for f in self.frames if f['type'] == 'normal')
            freeze_frames = sum(f['duration'] for f in self.frames if f['type'] == 'freeze')
            
            stats_text = f"Images: {len(self.frames)} | Normal: {normal_count} ({normal_frames}f) | Freeze: {freeze_count} ({freeze_frames}f)"
            
            self.canvas.create_text(self.width - 10, self.height - 15, 
                                   text=stats_text, fill=self.accent_color, 
                                   font=("Arial", 9), anchor="se")
            
        except Exception as e:
            print(f"Error drawing statistics: {e}")
                              
    def show_frame_info(self, event, frame):
        """Show detailed info on hover"""
        try:
            if self.hover_info:
                self.canvas.delete(self.hover_info)
                
            x, y = event.x, event.y
            
            info_text = f"Image #{frame['image_id']}\n"
            info_text += f"Type: {'FREEZE' if frame['type'] == 'freeze' else 'NORMAL'}\n"
            info_text += f"Duration: {frame['duration']} frames ({frame['time_end'] - frame['time_start']:.2f}s)\n"
            info_text += f"Time: {frame['time_start']:.2f}s - {frame['time_end']:.2f}s"
            
            if frame['type'] == 'freeze' and 'multiplier' in frame:
                info_text += f"\nMultiplier: {frame['multiplier']:.1f}x"
            
            # Position tooltip
            tooltip_x = min(max(x + 10, 5), self.width - 160)
            tooltip_y = max(y - 70, 5)
            
            # Background rectangle
            self.canvas.create_rectangle(tooltip_x - 5, tooltip_y - 5,
                                       tooltip_x + 150, tooltip_y + 75,
                                       fill="#2a2a2a", outline=self.accent_color,
                                       tags="hover_info")
            
            # Info text
            self.canvas.create_text(tooltip_x, tooltip_y, text=info_text,
                                   fill=self.text_color, font=("Arial", 8),
                                   anchor="nw", tags="hover_info")
            
            self.hover_info = "hover_info"
        except Exception as e:
            print(f"Error showing frame info: {e}")
        
    def hide_frame_info(self):
        """Hide hover info"""
        try:
            if self.hover_info:
                self.canvas.delete(self.hover_info)
                self.hover_info = None
        except:
            pass
            
    def on_hover(self, event):
        """Handle mouse hover"""
        pass
        
    def on_leave(self, event):
        """Handle mouse leave"""
        self.hide_frame_info()
        
    def on_click(self, event):
        """Handle timeline click"""
        pass

class CrashFacesStudio:
    """Main application class"""
    
    def __init__(self, root):
        self.root = root
        self.root.title(f"Crash/Faces Studio v{__version__}")
        self.root.geometry("1200x900")
        
        # Set modern colors
        self.bg_color = "#1e1e1e"
        self.fg_color = "#ffffff"
        self.accent_color = "#0099ff"
        self.success_color = "#00ff88"
        self.warning_color = "#ffaa00"
        self.error_color = "#ff4444"
        self.panel_bg = "#2a2a2a"
        self.input_bg = "#3a3a3a"
        
        self.root.configure(bg=self.bg_color)
        self.setup_styles()
        
        # Variables
        self.input_dir = tk.StringVar()
        self.output_file = tk.StringVar(value="animation.mp4")
        self.duration = tk.DoubleVar(value=45.0)
        self.fps = tk.IntVar(value=24)
        self.frame_duration = tk.DoubleVar(value=1.0)
        self.freeze_prob = tk.DoubleVar(value=0.15)
        self.freeze_min = tk.DoubleVar(value=2.0)
        self.freeze_max = tk.DoubleVar(value=5.0)
        self.black_white = tk.BooleanVar()
        self.use_cache = tk.BooleanVar(value=True)
        self.use_advanced_timing = tk.BooleanVar(value=True)
        self.seed = tk.StringVar()
        
        # Status variables
        self.image_count = tk.IntVar(value=0)
        self.processing = False
        self.process = None
        self.update_scheduled = False
        
        # Create timeline widget
        self.timeline = None
        
        # Create UI
        self.create_widgets()
        self.update_calculations()
        
    def setup_styles(self):
        """Configure ttk styles"""
        style = ttk.Style()
        
        style.configure("Dark.TFrame", background=self.panel_bg)
        style.configure("Darker.TFrame", background=self.bg_color)
        style.configure("Dark.TLabel", background=self.panel_bg, foreground=self.fg_color)
        style.configure("Title.TLabel", background=self.panel_bg, foreground=self.fg_color, 
                       font=("Arial", 12, "bold"))
        style.configure("Accent.TLabel", background=self.panel_bg, foreground=self.accent_color,
                       font=("Arial", 10, "bold"))
        style.configure("Success.TLabel", background=self.panel_bg, foreground=self.success_color)
        style.configure("Warning.TLabel", background=self.panel_bg, foreground=self.warning_color)
        style.configure("Error.TLabel", background=self.panel_bg, foreground=self.error_color)
        
        style.configure("Modern.Horizontal.TProgressbar", 
                       background=self.accent_color, troughcolor=self.input_bg,
                       borderwidth=0, lightcolor=self.accent_color, darkcolor=self.accent_color)
        
    def create_widgets(self):
        """Create the main UI"""
        # Main container
        main_container = ttk.Frame(self.root, style="Darker.TFrame")
        main_container.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Title
        title_label = ttk.Label(main_container, text="CRASH/FACES STUDIO", 
                              font=("Arial", 24, "bold"), foreground=self.accent_color,
                              background=self.bg_color)
        title_label.pack(pady=(0, 10))
        
        # Two column layout
        columns_frame = ttk.Frame(main_container, style="Darker.TFrame")
        columns_frame.pack(fill=tk.BOTH, expand=True)
        
        left_column = ttk.Frame(columns_frame, style="Darker.TFrame")
        left_column.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 10))
        
        right_column = ttk.Frame(columns_frame, style="Darker.TFrame")
        right_column.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)
        
        # Left column - Settings
        self.create_input_section(left_column)
        self.create_basic_settings(left_column)
        self.create_animation_options(left_column)
        self.create_advanced_timing(left_column)
        self.create_seed_section(left_column)
        
        # Right column - Timeline and output
        self.create_timeline_section(right_column)
        self.create_calculations_section(right_column)
        self.create_output_section(right_column)
        self.create_progress_section(right_column)
        
        # Footer
        self.create_footer(main_container)
        
        # Bind events
        self.bind_events()
        
    def create_input_section(self, parent):
        """Create input directory section"""
        frame = self.create_panel(parent, "📁 Input Images")
        frame.pack(fill=tk.X, pady=(0, 10))
        
        dir_frame = ttk.Frame(frame, style="Dark.TFrame")
        dir_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.input_entry = tk.Entry(dir_frame, textvariable=self.input_dir,
                                   bg=self.input_bg, fg=self.fg_color, 
                                   insertbackground=self.fg_color, font=("Arial", 10))
        self.input_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        
        ttk.Button(dir_frame, text="Browse", command=self.browse_input_dir).pack(side=tk.RIGHT)
        
        self.image_status_label = ttk.Label(frame, text="No images detected", style="Dark.TLabel")
        self.image_status_label.pack(anchor=tk.W, padx=10, pady=(0, 5))
        
    def create_basic_settings(self, parent):
        """Create basic settings section"""
        frame = self.create_panel(parent, "⚙️ Basic Settings")
        frame.pack(fill=tk.X, pady=(0, 10))
        
        grid = ttk.Frame(frame, style="Dark.TFrame")
        grid.pack(fill=tk.X, padx=10, pady=5)
        
        # Duration
        ttk.Label(grid, text="Video Duration:", style="Dark.TLabel").grid(row=0, column=0, sticky=tk.W)
        duration_frame = ttk.Frame(grid, style="Dark.TFrame")
        duration_frame.grid(row=0, column=1, padx=(10, 0))
        tk.Spinbox(duration_frame, from_=1, to=300, textvariable=self.duration, width=8,
                  bg=self.input_bg, fg=self.fg_color, buttonbackground=self.panel_bg).pack(side=tk.LEFT)
        ttk.Label(duration_frame, text="seconds", style="Dark.TLabel").pack(side=tk.LEFT, padx=(5, 0))
        
        # FPS
        ttk.Label(grid, text="Frame Rate:", style="Dark.TLabel").grid(row=1, column=0, sticky=tk.W, pady=(5, 0))
        fps_frame = ttk.Frame(grid, style="Dark.TFrame")
        fps_frame.grid(row=1, column=1, padx=(10, 0), pady=(5, 0))
        tk.Spinbox(fps_frame, from_=1, to=60, textvariable=self.fps, width=8,
                  bg=self.input_bg, fg=self.fg_color, buttonbackground=self.panel_bg).pack(side=tk.LEFT)
        ttk.Label(fps_frame, text="fps", style="Dark.TLabel").pack(side=tk.LEFT, padx=(5, 0))
        
        # Frame duration
        ttk.Label(grid, text="Image Duration:", style="Dark.TLabel").grid(row=2, column=0, sticky=tk.W, pady=(5, 0))
        frame_dur_frame = ttk.Frame(grid, style="Dark.TFrame")
        frame_dur_frame.grid(row=2, column=1, padx=(10, 0), pady=(5, 0))
        tk.Spinbox(frame_dur_frame, from_=0.1, to=10.0, increment=0.1, 
                  textvariable=self.frame_duration, width=8,
                  bg=self.input_bg, fg=self.fg_color, buttonbackground=self.panel_bg).pack(side=tk.LEFT)
        ttk.Label(frame_dur_frame, text="sec/image", style="Dark.TLabel").pack(side=tk.LEFT, padx=(5, 0))
        
    def create_animation_options(self, parent):
        """Create animation options section"""
        frame = self.create_panel(parent, "🎨 Animation Style")
        frame.pack(fill=tk.X, pady=(0, 10))
        
        container = ttk.Frame(frame, style="Dark.TFrame")
        container.pack(fill=tk.X, padx=10, pady=5)
        
        tk.Checkbutton(container, text="Black & White", variable=self.black_white,
                      bg=self.panel_bg, fg=self.fg_color, activebackground=self.panel_bg,
                      activeforeground=self.fg_color, selectcolor=self.panel_bg).pack(anchor=tk.W)
        
        tk.Checkbutton(container, text="Use Cache (faster)", variable=self.use_cache,
                      bg=self.panel_bg, fg=self.fg_color, activebackground=self.panel_bg,
                      activeforeground=self.fg_color, selectcolor=self.panel_bg).pack(anchor=tk.W)
        
        tk.Checkbutton(container, text="Advanced Timing Effects", variable=self.use_advanced_timing,
                      bg=self.panel_bg, fg=self.fg_color, activebackground=self.panel_bg,
                      activeforeground=self.fg_color, selectcolor=self.panel_bg).pack(anchor=tk.W)
        
    def create_advanced_timing(self, parent):
        """Create advanced timing section"""
        self.advanced_frame = self.create_panel(parent, "⏱️ Advanced Timing")
        self.advanced_frame.pack(fill=tk.X, pady=(0, 10))
        
        container = ttk.Frame(self.advanced_frame, style="Dark.TFrame")
        container.pack(fill=tk.X, padx=10, pady=5)
        
        # Freeze probability
        freeze_frame = ttk.Frame(container, style="Dark.TFrame")
        freeze_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Label(freeze_frame, text="Freeze Frame Chance:", style="Dark.TLabel").pack(anchor=tk.W)
        
        slider_frame = ttk.Frame(freeze_frame, style="Dark.TFrame")
        slider_frame.pack(fill=tk.X, pady=(5, 0))
        
        self.freeze_scale = ttk.Scale(slider_frame, from_=0.0, to=1.0, orient=tk.HORIZONTAL,
                                     variable=self.freeze_prob, length=200)
        self.freeze_scale.pack(side=tk.LEFT, padx=(0, 10))
        
        self.freeze_percent_label = ttk.Label(slider_frame, text="15%", style="Accent.TLabel")
        self.freeze_percent_label.pack(side=tk.LEFT)
        
        # Freeze duration range
        range_frame = ttk.Frame(container, style="Dark.TFrame")
        range_frame.pack(fill=tk.X)
        
        ttk.Label(range_frame, text="Freeze Duration Range:", style="Dark.TLabel").pack(anchor=tk.W)
        
        range_input = ttk.Frame(range_frame, style="Dark.TFrame")
        range_input.pack(fill=tk.X, pady=(5, 0))
        
        tk.Spinbox(range_input, from_=1.0, to=10.0, increment=0.5,
                  textvariable=self.freeze_min, width=6,
                  bg=self.input_bg, fg=self.fg_color, buttonbackground=self.panel_bg).pack(side=tk.LEFT)
        
        ttk.Label(range_input, text="x to", style="Dark.TLabel").pack(side=tk.LEFT, padx=5)
        
        tk.Spinbox(range_input, from_=1.0, to=20.0, increment=0.5,
                  textvariable=self.freeze_max, width=6,
                  bg=self.input_bg, fg=self.fg_color, buttonbackground=self.panel_bg).pack(side=tk.LEFT)
        
        ttk.Label(range_input, text="x normal duration", style="Dark.TLabel").pack(side=tk.LEFT, padx=(5, 0))
        
    def create_seed_section(self, parent):
        """Create random seed section"""
        frame = self.create_panel(parent, "🎲 Random Seed")
        frame.pack(fill=tk.X)
        
        container = ttk.Frame(frame, style="Dark.TFrame")
        container.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(container, text="Seed (optional):", style="Dark.TLabel").pack(side=tk.LEFT)
        seed_entry = tk.Entry(container, textvariable=self.seed, width=15,
                             bg=self.input_bg, fg=self.fg_color, insertbackground=self.fg_color)
        seed_entry.pack(side=tk.LEFT, padx=(10, 0))
        
    def create_timeline_section(self, parent):
        """Create timeline visualization section"""
        frame = self.create_panel(parent, "📊 Timeline Preview")
        frame.pack(fill=tk.X, pady=(0, 10))
        
        # Create timeline widget
        self.timeline = FrameTimeline(frame, width=580, height=150)
        
        # Quick presets
        preset_frame = ttk.Frame(frame, style="Dark.TFrame")
        preset_frame.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(preset_frame, text="Quick Presets:", style="Dark.TLabel").pack(side=tk.LEFT)
        
        ttk.Button(preset_frame, text="Short (10s)", 
                  command=lambda: self.apply_preset(10, 24, 0.5, 0.2)).pack(side=tk.LEFT, padx=5)
        ttk.Button(preset_frame, text="Medium (45s)", 
                  command=lambda: self.apply_preset(45, 24, 1.0, 0.15)).pack(side=tk.LEFT, padx=5)
        ttk.Button(preset_frame, text="Long (120s)", 
                  command=lambda: self.apply_preset(120, 30, 2.0, 0.1)).pack(side=tk.LEFT, padx=5)
        
    def create_calculations_section(self, parent):
        """Create timing calculations section"""
        frame = self.create_panel(parent, "📈 Timing Calculations")
        frame.pack(fill=tk.X, pady=(0, 10))
        
        self.calc_text = tk.Text(frame, height=8, width=40,
                               bg=self.input_bg, fg=self.fg_color, font=("Consolas", 9))
        self.calc_text.pack(padx=10, pady=5)
        
    def create_output_section(self, parent):
        """Create output section"""
        frame = self.create_panel(parent, "💾 Output")
        frame.pack(fill=tk.X, pady=(0, 10))
        
        container = ttk.Frame(frame, style="Dark.TFrame")
        container.pack(fill=tk.X, padx=10, pady=5)
        
        self.output_entry = tk.Entry(container, textvariable=self.output_file,
                                    bg=self.input_bg, fg=self.fg_color,
                                    insertbackground=self.fg_color, font=("Arial", 10))
        self.output_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        
        ttk.Button(container, text="Save As", command=self.browse_output_file).pack(side=tk.RIGHT)
        
        # Render buttons
        render_frame = ttk.Frame(parent, style="Darker.TFrame")
        render_frame.pack(fill=tk.X, pady=(0, 10))
        
        button_container = ttk.Frame(render_frame, style="Darker.TFrame")
        button_container.pack()
        
        self.render_btn = tk.Button(button_container, text="🎬 CREATE ANIMATION",
                                   command=self.start_rendering,
                                   bg=self.accent_color, fg="white",
                                   font=("Arial", 14, "bold"), bd=0, padx=30, pady=15,
                                   activebackground="#0077cc")
        self.render_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        self.stop_btn = tk.Button(button_container, text="⏹ STOP",
                                 command=self.stop_rendering, state='disabled',
                                 bg=self.error_color, fg="white",
                                 font=("Arial", 12, "bold"), bd=0, padx=20, pady=15,
                                 activebackground="#cc3333")
        self.stop_btn.pack(side=tk.LEFT)
        
    def create_progress_section(self, parent):
        """Create progress section"""
        frame = self.create_panel(parent, "📈 Progress")
        frame.pack(fill=tk.BOTH, expand=True)
        
        # Progress bar
        prog_container = ttk.Frame(frame, style="Dark.TFrame")
        prog_container.pack(fill=tk.X, padx=10, pady=5)
        
        self.progress_bar = ttk.Progressbar(prog_container, mode='determinate', 
                                           style="Modern.Horizontal.TProgressbar")
        self.progress_bar.pack(fill=tk.X, side=tk.LEFT, expand=True)
        
        self.progress_label = ttk.Label(prog_container, text="0%", style="Accent.TLabel", width=5)
        self.progress_label.pack(side=tk.LEFT, padx=(5, 0))
        
        # Status
        self.status_label = ttk.Label(frame, text="Ready", style="Success.TLabel")
        self.status_label.pack(padx=10, pady=(0, 5))
        
        # Log
        self.log_text = scrolledtext.ScrolledText(frame, height=6,
                                                bg=self.input_bg, fg=self.fg_color,
                                                font=("Consolas", 9))
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 5))
        
    def create_footer(self, parent):
        """Create footer"""
        frame = ttk.Frame(parent, style="Darker.TFrame")
        frame.pack(fill=tk.X, pady=(10, 0))
        
        label = tk.Label(frame, text="crashserver.fr", bg=self.bg_color, fg=self.accent_color,
                        font=("Arial", 10, "underline"), cursor="hand2")
        label.pack()
        label.bind("<Button-1>", self.open_website)
        
    def create_panel(self, parent, title):
        """Create a styled panel with title"""
        frame = ttk.Frame(parent, style="Dark.TFrame", relief=tk.FLAT)
        
        title_frame = ttk.Frame(frame, style="Dark.TFrame")
        title_frame.pack(fill=tk.X)
        
        ttk.Label(title_frame, text=title, style="Title.TLabel").pack(anchor=tk.W, padx=8, pady=3)
        
        sep = ttk.Separator(frame, orient=tk.HORIZONTAL)
        sep.pack(fill=tk.X)
        
        return frame
        
    def bind_events(self):
        """Bind all events"""
        self.duration.trace_add('write', self.schedule_update)
        self.fps.trace_add('write', self.schedule_update)
        self.frame_duration.trace_add('write', self.schedule_update)
        self.freeze_prob.trace_add('write', self.schedule_update)
        self.freeze_min.trace_add('write', self.schedule_update)
        self.freeze_max.trace_add('write', self.schedule_update)
        self.seed.trace_add('write', self.schedule_update)
        self.input_dir.trace_add('write', self.check_images)
        self.use_advanced_timing.trace_add('write', self.toggle_advanced_options)
        
    def apply_preset(self, duration, fps, frame_dur, freeze_prob):
        """Apply a quick preset"""
        try:
            self.duration.set(duration)
            self.fps.set(fps)
            self.frame_duration.set(frame_dur)
            self.freeze_prob.set(freeze_prob)
            self.force_update_timeline()
        except Exception as e:
            print(f"Error applying preset: {e}")
        
    def schedule_update(self, *args):
        """Schedule timeline update with debouncing"""
        try:
            if self.update_scheduled:
                return
                
            if not self.root or not self.root.winfo_exists():
                return
                
            self.update_scheduled = True
            self.root.after(300, self.delayed_update)
        except Exception as e:
            print(f"Error scheduling update: {e}")
            self.update_scheduled = False
            
    def delayed_update(self):
        """Perform delayed update"""
        try:
            self.update_scheduled = False
            
            if not self.root or not self.root.winfo_exists():
                return
                
            self.update_calculations()
        except Exception as e:
            print(f"Error in delayed update: {e}")
            self.update_scheduled = False
        
    def force_update_timeline(self):
        """Force immediate timeline update"""
        try:
            self.update_timeline()
        except Exception as e:
            print(f"Error forcing timeline update: {e}")
        
    def update_timeline(self):
        """Update timeline visualization"""
        try:
            if not self.root or not self.root.winfo_exists() or not self.timeline:
                return
                
            # Validate inputs
            try:
                duration_val = float(self.duration.get())
                fps_val = int(self.fps.get())
                frame_dur_val = float(self.frame_duration.get())
            except (ValueError, TypeError):
                return
                
            total_frames = max(1, int(duration_val * fps_val))
            
            # Parse seed
            seed_val = None
            seed_str = str(self.seed.get()).strip()
            if seed_str:
                try:
                    seed_val = int(seed_str)
                except ValueError:
                    seed_val = hash(seed_str) % (2**32)
            
            # Generate frame sequence
            if self.use_advanced_timing.get():
                try:
                    freeze_prob_val = max(0.0, min(1.0, float(self.freeze_prob.get())))
                    freeze_min_val = max(1.0, float(self.freeze_min.get()))
                    freeze_max_val = max(freeze_min_val, float(self.freeze_max.get()))
                except (ValueError, TypeError):
                    freeze_prob_val, freeze_min_val, freeze_max_val = 0.0, 2.0, 5.0
                    
                self.timeline.generate_frame_sequence(
                    total_frames, max(1, fps_val), max(0.1, frame_dur_val),
                    freeze_prob_val, freeze_min_val, freeze_max_val, seed_val
                )
            else:
                self.timeline.generate_frame_sequence(
                    total_frames, max(1, fps_val), max(0.1, frame_dur_val),
                    0.0, 2.0, 5.0, seed_val
                )
            
            self.timeline.draw_timeline()
            
        except Exception as e:
            print(f"Timeline update error: {e}")
            self.update_scheduled = False
            
    def update_calculations(self, *args):
        """Update timing calculations and display"""
        try:
            self.update_timeline()
            
            # Get values
            duration = self.duration.get()
            fps = self.fps.get()
            frame_dur = self.frame_duration.get()
            freeze_prob = self.freeze_prob.get()
            freeze_min = self.freeze_min.get()
            freeze_max = self.freeze_max.get()
            
            # Basic calculations
            total_frames = int(duration * fps)
            frames_per_image = max(1, int(frame_dur * fps))
            actual_frame_dur = max(frame_dur, 1.0 / fps)
            
            # Update freeze probability label
            self.freeze_percent_label.config(text=f"{int(freeze_prob * 100)}%")
            
            # Clear and update calculation text
            self.calc_text.delete(1.0, tk.END)
            
            self.calc_text.insert(tk.END, "=== VIDEO SPECIFICATIONS ===\n", "heading")
            self.calc_text.insert(tk.END, f"Duration: {duration}s @ {fps}fps\n")
            self.calc_text.insert(tk.END, f"Total Frames: {total_frames}\n")
            self.calc_text.insert(tk.END, f"\n=== IMAGE TIMING ===\n", "heading")
            self.calc_text.insert(tk.END, f"Image Duration: {actual_frame_dur:.2f}s\n")
            self.calc_text.insert(tk.END, f"Frames per Image: {frames_per_image}\n")
            
            if self.use_advanced_timing.get() and freeze_prob > 0:
                # Advanced calculations
                self.calc_text.insert(tk.END, f"\n=== FREEZE FRAMES ===\n", "heading")
                
                avg_multiplier = (freeze_min + freeze_max) / 2
                avg_frames_per_image = frames_per_image * (1 - freeze_prob) + \
                                      frames_per_image * avg_multiplier * freeze_prob
                expected_images = int(total_frames / avg_frames_per_image)
                expected_freezes = int(expected_images * freeze_prob)
                
                self.calc_text.insert(tk.END, f"Freeze Chance: {int(freeze_prob * 100)}%\n")
                self.calc_text.insert(tk.END, f"Expected Freezes: ~{expected_freezes}\n")
                self.calc_text.insert(tk.END, f"Duration Range: {freeze_min:.1f}x - {freeze_max:.1f}x\n")
                
                # Image requirements
                self.calc_text.insert(tk.END, f"\n=== REQUIREMENTS ===\n", "heading")
                min_images = max(10, int(total_frames / (frames_per_image * freeze_max)))
                self.calc_text.insert(tk.END, f"Recommended: {expected_images}+ images\n")
                self.calc_text.insert(tk.END, f"Minimum: {min_images} images\n")
                
                if self.image_count.get() > 0:
                    if self.image_count.get() < min_images:
                        self.calc_text.insert(tk.END, f"\n⚠️ Current: {self.image_count.get()} images (low)", "warning")
                    else:
                        self.calc_text.insert(tk.END, f"\n✓ Current: {self.image_count.get()} images", "success")
            else:
                images_needed = math.ceil(total_frames / frames_per_image)
                self.calc_text.insert(tk.END, f"\n=== REQUIREMENTS ===\n", "heading")
                self.calc_text.insert(tk.END, f"Images Needed: {images_needed}\n")
                
                if self.image_count.get() > 0:
                    if self.image_count.get() < images_needed:
                        self.calc_text.insert(tk.END, f"\n⚠️ Current: {self.image_count.get()} images (will repeat)", "warning")
                    else:
                        self.calc_text.insert(tk.END, f"\n✓ Current: {self.image_count.get()} images", "success")
            
            # Configure text styling
            self.calc_text.tag_configure("heading", foreground=self.accent_color, font=("Consolas", 9, "bold"))
            self.calc_text.tag_configure("warning", foreground=self.warning_color)
            self.calc_text.tag_configure("success", foreground=self.success_color)
            
        except Exception as e:
            print(f"Error updating calculations: {e}")
            
    def toggle_advanced_options(self, *args):
        """Toggle advanced timing options"""
        try:
            if self.use_advanced_timing.get():
                self.advanced_frame.pack(fill=tk.X, pady=(0, 10))
            else:
                self.advanced_frame.pack_forget()
            self.update_calculations()
        except Exception as e:
            print(f"Error toggling advanced options: {e}")
        
    def check_images(self, *args):
        """Check and display image count"""
        try:
            directory = self.input_dir.get()
            if not directory or not os.path.exists(directory):
                self.image_status_label.config(text="No folder selected", style="Dark.TLabel")
                self.image_count.set(0)
                return
                
            image_files = [f for f in os.listdir(directory) 
                          if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            count = len(image_files)
            self.image_count.set(count)
            
            jpg_count = len([f for f in image_files if f.lower().endswith(('.jpg', '.jpeg'))])
            png_count = len([f for f in image_files if f.lower().endswith('.png')])
            
            if count == 0:
                self.image_status_label.config(text="❌ No images found", style="Error.TLabel")
            else:
                type_parts = []
                if jpg_count > 0:
                    type_parts.append(f"{jpg_count} JPG")
                if png_count > 0:
                    type_parts.append(f"{png_count} PNG")
                type_str = " + ".join(type_parts)
                
                if count < 10:
                    self.image_status_label.config(
                        text=f"⚠️ {count} images ({type_str}) - Need more!",
                        style="Warning.TLabel"
                    )
                else:
                    self.image_status_label.config(
                        text=f"✓ {count} images ({type_str})",
                        style="Success.TLabel"
                    )
            
            self.update_calculations()
            
        except Exception as e:
            self.image_status_label.config(text=f"❌ Error: {e}", style="Error.TLabel")
            self.image_count.set(0)
            
    def browse_input_dir(self):
        """Browse for input directory"""
        directory = filedialog.askdirectory(title="Select Folder with Images")
        if directory:
            self.input_dir.set(directory)
            
    def browse_output_file(self):
        """Browse for output file"""
        filename = filedialog.asksaveasfilename(
            title="Save Video As",
            defaultextension=".mp4",
            filetypes=[("MP4 files", "*.mp4"), ("All files", "*.*")]
        )
        if filename:
            self.output_file.set(filename)
            
    def log(self, message):
        """Add message to log"""
        try:
            self.log_text.insert(tk.END, message + "\n")
            self.log_text.see(tk.END)
            self.root.update_idletasks()
        except:
            pass
        
    def update_progress(self, value):
        """Update progress bar"""
        try:
            self.progress_bar['value'] = value
            self.progress_label.config(text=f"{int(value)}%")
            self.root.update_idletasks()
        except:
            pass
        
    def open_website(self, event):
        """Open website"""
        import webbrowser
        webbrowser.open("https://crashserver.fr")
        
    def validate_inputs(self):
        """Validate inputs before rendering"""
        if not self.input_dir.get():
            messagebox.showerror("Error", "Please select an input directory")
            return False
            
        if not os.path.exists(self.input_dir.get()):
            messagebox.showerror("Error", "Input directory does not exist")
            return False
            
        if self.image_count.get() == 0:
            messagebox.showerror("Error", "No images found in the selected directory")
            return False
            
        if not self.output_file.get():
            messagebox.showerror("Error", "Please specify an output file")
            return False
            
        if self.use_advanced_timing.get():
            if self.freeze_min.get() > self.freeze_max.get():
                messagebox.showerror("Error", "Freeze minimum cannot be greater than maximum")
                return False
                
        return True
        
    def start_rendering(self):
        """Start rendering process"""
        if not self.validate_inputs():
            return
            
        self.processing = True
        self.render_btn.config(state='disabled', text="RENDERING...", bg=self.warning_color)
        self.stop_btn.config(state='normal')
        self.update_progress(0)
        self.status_label.config(text="Starting render...", style="Dark.TLabel")
        self.log_text.delete(1.0, tk.END)
        
        thread = threading.Thread(target=self.render_video, daemon=True)
        thread.start()
        
    def stop_rendering(self):
        """Stop the rendering process"""
        if self.process and self.processing:
            self.process.terminate()
            self.log("❌ Rendering stopped by user")
            self.processing = False
            self.status_label.config(text="Stopped", style="Error.TLabel")
        
        # Reset buttons
        self.render_btn.config(state='normal', text="🎬 CREATE ANIMATION", bg=self.accent_color)
        self.stop_btn.config(state='disabled')
        
    def render_video(self):
        """Render video using the integrated scripts"""
        try:
            # Determine which script to use based on advanced timing setting
            script_name = "blackwhite.py" if self.use_advanced_timing.get() else "script.py"
            
            self.log(f"🎬 Starting render with {script_name}")
            self.log(f"📁 Input: {self.input_dir.get()}")
            self.log(f"💾 Output: {self.output_file.get()}")
            self.log(f"📊 Settings: {self.duration.get()}s @ {self.fps.get()}fps")
            
            # Calculate expected frames for progress tracking
            total_frames_for_ffmpeg = int(self.duration.get() * self.fps.get())
            
            # Build command arguments
            cmd = [
                sys.executable, script_name,
                self.input_dir.get(),
                "-o", self.output_file.get(),
                "--duration", str(self.duration.get()),
                "--fps", str(self.fps.get()),
                "--frame-duration", str(self.frame_duration.get())
            ]
            
            # Add advanced options if using blackwhite.py
            if self.use_advanced_timing.get():
                cmd.extend([
                    "--freeze-prob", str(self.freeze_prob.get()),
                    "--freeze-min", str(self.freeze_min.get()),
                    "--freeze-max", str(self.freeze_max.get())
                ])
                
                if self.black_white.get():
                    cmd.append("--bw")
                    
                if not self.use_cache.get():
                    cmd.append("--no-cache")
            
            if self.seed.get():
                cmd.extend(["--seed", self.seed.get()])
            
            self.log(f"🔧 Command: {' '.join(cmd)}")
            self.log("")
            
            # Update status
            self.root.after(0, lambda: self.status_label.config(text="Rendering...", style="Accent.TLabel"))
            
            # Run the rendering script
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                universal_newlines=True,
                cwd=os.path.dirname(os.path.abspath(__file__))
            )
            
            # Stream output and parse progress
            while True:
                if not self.processing:
                    break
                    
                output = self.process.stdout.readline()
                if output == '' and self.process.poll() is not None:
                    break
                if output:
                    line = output.strip()
                    # Log important lines
                    if any(keyword in line for keyword in [
                        'Frame', 'Progress', '✓', '✅', '❌', 'Creating', 'Video', 
                        'complete', 'Error', 'cached', 'Optimized', 'FFmpeg'
                    ]):
                        self.root.after(0, lambda msg=line: self.log(msg))
                    
                    # Parse progress from frame generation
                    frame_match = re.search(r'Frame\s+(\d+)/(\d+):', line)
                    if frame_match:
                        current = int(frame_match.group(1))
                        total = int(frame_match.group(2))
                        progress = (current / total) * 80  # 80% for frame generation
                        self.root.after(0, lambda p=progress: self.update_progress(p))
                    
                    # Parse progress from FFmpeg encoding
                    ffmpeg_match = re.search(r'frame=\s*(\d+)', line)
                    if ffmpeg_match:
                        current = int(ffmpeg_match.group(1))
                        progress = 80 + (current / total_frames_for_ffmpeg) * 20  # Last 20%
                        self.root.after(0, lambda p=progress: self.update_progress(p))
                    
            return_code = self.process.poll()
            
            if return_code == 0 and self.processing:
                self.root.after(0, lambda: self.update_progress(100))
                self.root.after(0, lambda: self.status_label.config(text="✅ Complete!", style="Success.TLabel"))
                self.root.after(0, lambda: self.log("\n🎉 Video created successfully!"))
                self.root.after(0, lambda: messagebox.showinfo("Success", f"Animation created successfully!\n\nSaved to: {self.output_file.get()}"))
            elif self.processing:
                self.root.after(0, lambda: self.status_label.config(text="❌ Failed", style="Error.TLabel"))
                self.root.after(0, lambda: self.log(f"\n❌ Rendering failed (exit code: {return_code})"))
                self.root.after(0, lambda: messagebox.showerror("Error", "Rendering failed. Check the log for details."))
                
        except FileNotFoundError as e:
            error_msg = "Required script not found. Ensure blackwhite.py and script.py are in the same directory."
            self.root.after(0, lambda: self.log(f"\n💥 Error: {error_msg}"))
            self.root.after(0, lambda: self.status_label.config(text="❌ Script Missing", style="Error.TLabel"))
            self.root.after(0, lambda: messagebox.showerror("Missing Scripts", error_msg))
        except Exception as e:
            self.root.after(0, lambda: self.log(f"\n💥 Unexpected error: {e}"))
            self.root.after(0, lambda: self.status_label.config(text="❌ Error", style="Error.TLabel"))
            self.root.after(0, lambda: messagebox.showerror("Error", f"An error occurred: {e}"))
        finally:
            self.processing = False
            self.root.after(0, lambda: self.render_btn.config(state='normal', text="🎬 CREATE ANIMATION", bg=self.accent_color))
            self.root.after(0, lambda: self.stop_btn.config(state='disabled'))

def main():
    """Main entry point"""
    root = tk.Tk()
    app = CrashFacesStudio(root)
    
    # Center window
    root.update_idletasks()
    width = root.winfo_width()
    height = root.winfo_height()
    x = (root.winfo_screenwidth() // 2) - (width // 2)
    y = (root.winfo_screenheight() // 2) - (height // 2)
    root.geometry(f'{width}x{height}+{x}+{y}')
    
    root.mainloop()

if __name__ == "__main__":
    main()
