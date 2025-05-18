All monitoring scripts, those starting with taskbar_*, are performance-sensitive, meaning they're designed to use minimal hardware resources. I've started using Awesome Font to add a bit of simple styling, but I'm not sure yet whether I'll keep it this way. I'm not good at that. If you are, feel free to pich in! They are written in pure Bash, avoiding external tools and subshells as much as possible. I use them with the Command Output Plasma KDE widget, which I'll better explain it how I do it later this week in this README.  

This repository contains a set of Bash scripts, which are intended to be shared more as an engine than as a final, styled solution, for system monitoring and hardware control on Linux. Below you will find a detailed description of each script, including all arguments and their functions. 

![](taskbar_screenshot.png)

---

### `taskbar_cpu_usage.sh`

**Description:**  
Displays the current CPU usage percentage over a period of one second, designed for minimal resource usage.  
- The script reads `/proc/stat` directly to calculate CPU usage, ensuring low overhead.
- Output is formatted for easy parsing by widgets or other scripts.
- Optionally uses Awesome Font for visual enhancement, but works without it.
- If CPU usage exceeds 90%, the output is colored red to alert the user to high load.

**Output:**  
- Shows the current CPU usage percentage (e.g., `23%`).
- Output is colored red if usage exceeds 90% to indicate high CPU load.
- Designed to be updated every second for real-time monitoring.

**Changelog:**  
*No changes recorded yet.*
---

### `taskbar_memory_usage.sh`

**Description:**  
Displays current memory usage and ZRAM swap usage in a lightweight and efficient way, ideal for status bars and widgets.  
- Reads memory information from `/proc/meminfo` and ZRAM status from `/sys/block/zram0`.
- Supports two main actions via arguments:  
  - `click`: Toggles ZRAM swap on or off. If ZRAM is not active, it sets up and enables ZRAM swap; if already active, it disables and unloads the ZRAM module.
  - `startup`: Ensures ZRAM swap is enabled and configured at system startup.
- Output is color-coded: memory usage is shown in red if above 5GB, and ZRAM usage is displayed or "OFF" if disabled.
- Optionally uses Awesome Font for enhanced visual presentation, but works without it.
- Minimal resource usage, suitable for frequent updates (e.g., every second).

**Arguments:**  
- `click`: Toggles ZRAM swap on/off.  
  - If ZRAM is not active, enables and configures ZRAM swap.
  - If ZRAM is active, disables ZRAM swap and unloads the module.
- `startup`: Activates and configures ZRAM swap at system startup.

**Output:**  
- Shows memory usage in MB/GB (red if above 5GB).
- Shows ZRAM usage in MB/GB or "OFF" if ZRAM is disabled.

**Changelog:**  
*No changes recorded yet.*

---

### `taskbar_network_speed_monitor.sh`

**Description:**  
Displays real-time network speed (download and upload) and the number of open network connections, optimized for minimal resource usage and fast updates.  
- Reads network statistics from `/proc/net/dev` to calculate current download and upload speeds.
- Output is color-coded: speeds are shown in red if usage is high.
- Shows the number of currently open TCP/UDP connections.
- Optionally uses Awesome Font for enhanced visual presentation, but works without it.
- On click (when the script is called with the `click` argument), displays a detailed list of all open network connections, grouped by process, including the number of connections per process and those without an associated process.
- Waits for a keypress before exiting the detailed view, making it suitable for interactive widgets.

**Arguments:**  
- `click`:  
  - Lists all open TCP/UDP connections, grouped by process.
  - Shows the number of connections per process and those without an associated process.
  - Waits for a keypress before exiting.

**Output:**  
- Shows current download and upload speeds (e.g., `1.2 MB/s ↓  300 KB/s ↑`), color-coded by usage.
- Displays the number of open network connections.
- When called with `click`, outputs a detailed, grouped list of open connections by process.

**Changelog:**  
*No changes recorded yet.*

---

### `taskbar_disk_monitor.sh`

**Description:**  
Monitors disk read and write speeds with high precision for all disks or a specific disk, designed for minimal resource usage and fast updates.  
- Written in pure Bash, avoiding external tools and subshells for efficiency.
- Reads disk statistics from `/proc/diskstats` to calculate real-time read and write speeds.
- Can display stats for a specific disk (e.g., `sda`) or for all disks at once.
- Supports both single-run and continuous monitoring modes (using the `loop` argument).
- Output is color-coded: speeds are shown in red if high activity is detected (above 20MB/s).
- Allows customization of the update interval when running in loop mode.

**Arguments:**  
- `[disk_name]`: *(Optional)* Show stats for a specific disk (e.g., `sda`).
- `all`: Show stats for all disks.
- `loop`: Continuously update stats (use with `disk_name` or `all`).
- `[interval]`: *(Optional, used with `loop`)* Interval in seconds between updates (default: 1).

**Examples:**  
- `./taskbar_disk_monitor.sh sda` — Show stats for disk `sda` once. 
- `./taskbar_disk_monitor.sh all loop 2` — Show stats for all disks, updating every 2 seconds. 

**Output:**  
- Displays read and write speeds in KB/s or MB/s for the selected disk(s).
- Output is color-coded: values turn red if activity exceeds 20MB/s.
- When using `all`, shows a summary for each detected disk.
- Designed for easy parsing by widgets or other scripts.

**Changelog:**  
- Fixed output using Awesome font when using "loop" argument

---

### `taskbar_change_brightness.sh`

**Description:**  
Controls screen brightness for both internal and external monitors, supporting both command-line and graphical (YAD slider) interfaces.  
- Written in pure Bash for efficiency and minimal dependencies.
- Supports two main backends:
  - **xrandr**: For internal displays and some external monitors, adjusts brightness via X server.
  - **ddcutil**: For external monitors supporting DDC/CI, communicates directly with the monitor hardware.
- Allows increasing or decreasing brightness in steps, or setting an exact value.
- Provides GUI sliders for both xrandr and ddcutil, automatically switching between them if one is already open.
- Handles detection of available displays and gracefully falls back if a method is unavailable.
- Brightness values for xrandr are between 0.1 and 1.0; for ddcutil, between 0 and 100.
- Can show the current brightness value for each method.

**Arguments:**  
- `increase [xrandr|ddcutil]`: Increase brightness using the specified method.
- `decrease [xrandr|ddcutil]`: Decrease brightness using the specified method.
- `show_xrandr`: Show current brightness for xrandr.
- `show_ddcutil`: Show current brightness for ddcutil.
- `choose_xrandr`: Open GUI slider (YAD) for xrandr.
- `choose_ddcutil`: Open GUI slider (YAD) for ddcutil.

**Output:**  
- Shows the current brightness value for the selected monitor and method.
- Allows interactive adjustment via GUI or command line.
- Prints confirmation messages or errors if an operation fails.

**Changelog:**  
*No changes recorded yet.*

---

### `waydroid_under_xorg.sh`

**Description:**  
Enables running Waydroid under Xorg by automating the setup and teardown of the required Weston compositor session.  
- Designed to toggle Waydroid on and off: run once to launch Waydroid in a Weston window, run again to close everything cleanly.
- Handles starting and stopping both the Waydroid container and the Weston compositor.
- Detects if Waydroid or Weston is already running and acts accordingly to avoid duplicate sessions.
- Can be safely used from the terminal or integrated into desktop widgets and launchers.
- If the Weston window is closed manually, the script ensures Waydroid processes are also stopped.
- Useful for users running Xorg who want to use Waydroid without switching to a full Wayland session.
- Requires `weston` compositor and Waydroid installed and configured.

**Arguments:**  
- No arguments required for basic toggle behavior.

**Changelog:**  
*No changes recorded yet.*

---

## Development Scripts

This section documents the scripts found in the `development` folder. These are utility scripts for advanced system management and automation, intended for users comfortable with Bash and Linux internals.

### `download_videos_terminal.sh`

**Description:**  
A terminal-based video downloader that monitors the clipboard for video URLs and manages a download queue.  
- Supports pausing/resuming downloads (`p` key), and clean exit (`q` key).
- Uses `yt-dlp` for downloading, with progress and speed displayed in real time.
- Avoids duplicate downloads and supports a queue system for multiple URLs.
- Notifies on errors and unsupported domains, and logs errors for review.
- Plays notification sounds on events (success/error).
- Designed for minimal user intervention: just copy a URL to the clipboard and the script handles the rest.

**Features:**  
- Clipboard monitoring for URLs.
- Download queue management (with max concurrent downloads).
- Progress display for each active download.
- Pause/resume functionality.
- Error handling and notification.
- Domain blacklist for unsupported sites.

**Usage:**  
Run the script in a terminal.  
- Copy a video URL to the clipboard to add it to the queue.
- Press `p` to pause/resume downloads.
- Press `q` to quit and clean up. Downloads are resumed when the script is started again.

**Output:**  
- Shows active downloads, queue size, and real-time progress for each download.
- Notifies on errors and completion.

**Changelog:**  
*No changes recorded yet.*

---

### `process_priority_renice_ionice.sh`

**Description:**  
A graphical (YAD-based) utility to manage process priorities using both `renice` (CPU priority) and `ionice` (I/O priority).  
- Allows searching/filtering for processes by name (with history).
- Supports batch selection of processes for priority adjustment.
- Lets you set both CPU and I/O priorities interactively.
- Maintains a log of changes for easy restoration to original priorities.
- Includes an option to restore all modified processes to their default priorities.

**Features:**  
- GUI dialogs for process selection, priority setting, and history management.
- Search history for quick access to previous filters.
- Batch operations on multiple processes.
- Safe restoration of original priorities via a log file.
- Requires root privileges for priority changes (uses `pkexec` if needed).

**Usage:**  
Run the script.  
- Choose to alter priorities or restore defaults.
- Filter and select processes, then set desired priorities.
- Use the restore option to revert all changes.

**Output:**  
- Displays process selection and priority adjustment dialogs.
- Shows confirmation and error messages as needed.

**Changelog:**  
*No changes recorded yet.*

---



