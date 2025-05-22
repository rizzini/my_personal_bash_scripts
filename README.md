All monitoring scripts, those starting with taskbar_*, are performance-sensitive, meaning they're designed to use minimal hardware resources. From time to time, I'll tweak the scripts to make them consume less and less resourcess as posssible. 
I've started using Awesome Font to add a bit of simple styling, but I'm not sure yet whether I'll keep it this way. I'm not good at that. If you are, feel free to pich in! They are written in pure Bash, avoiding external tools and subshells as much as possible. I use them with the Command Output Plasma KDE widget, which I'll better explain it how I do it later this week in this README.  

This repository contains a set of Bash scripts, which are intended to be shared more as an engine than as a final, styled solution, for system monitoring and hardware control on Linux. Below you will find a detailed description of each script, including all arguments and their functions. 

![](taskbar_screenshot.png)

### `Important`

It's worth mentioning that I haven't set up the bootstrapping for the scripts yet. Therefore, while the code itself can certainly be reused (if you know what you're doing), the scripts are not yet redistributable.

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

**Changelog:**  
*No changes recorded yet.*

---

### `taskbar_network_speed_monitor.sh`

**Description:**  
Displays real-time network speed (download and upload) and the number of open network connections, optimized for minimal resource usage.  
- Reads network statistics directly from `/proc/net/dev` to calculate current download and upload speeds for a specified network interface (by default, `enp1s0`; you can edit the script to change this).
- Calculates speed by measuring the difference in bytes sent/received over a 1-second interval.
- Supports three unit display modes (KB/s, MB/s, or automatic selection based on speed), configurable via the `unit_mode` variable in the script at the beginning.
- The output is color-coded, regardless of the display mode you choose(In the near future, I'll make this dynamic depending on your conection):  
  - **Green:** 2–10 MB/s  
  - **Yellow:** 11–30 MB/s  
  - **Red:** above 30 MB/s  
  This helps to quickly identify high network usage.
- Shows the current number of open TCP/UDP connections using the `ss` command.

**Arguments:**  
- `click`:  
  - Shows a detailed list of all open TCP/UDP connections, grouped by process.
  - Displays the number of connections per process and the count of connections without an associated process.
  - Waits for a keypress before exiting the detailed view.

  **Changelog:**  
- Refactored unit conversion logic: added `unit_mode` variable to allow switching between KB/s(`unit_mode=1`), MB/s(`unit_mode=2`), or automatic(`unit_mode=3`) unit selection depending on the speed. (19/05/2025)
- Added `colorize_speed` function for more accurate and flexible color-coding of speeds, no matter the unit mode mode, (green for 2–10 MB/s, yellow for 11–30 MB/s, red for above 30 MB/s) (19/05/2025)
- Added the interface variable at the beginning of the script (20/05/2025)
- The new unit conversion logic follow the same logic used by the taskbar_disk_monitor.sh script, which uses `case` (20/05/2025)


---

### `taskbar_cpu_usage.sh`

**Description:**  
Displays the current CPU usage percentage over a period of one second, designed for minimal resource usage.  
- The script reads `/proc/stat` directly to calculate CPU usage, ensuring low overhead.
- Output is formatted for easy parsing by widgets or other scripts.
- Uses Awesome Font for visual enhancement, but works without it.
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
- Uses Awesome Font for enhanced visual presentation, but works without it.
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

### `taskbar_disk_monitor.sh`

**Description:**  
Monitors disk read and write speeds with high precision for all disks or a specific disk, designed for minimal resource usage and fast updates.  
- Reads disk statistics from `/proc/diskstats` to calculate real-time read and write speeds.
- Can display stats for a specific disk (e.g., `sda`) or for all disks at once.
- Supports both single-run and continuous monitoring modes (using the `loop` argument).
- Supports three unit display modes (KB/s, MB/s, or automatic selection based on speed), configurable via the `unit_mode` variable in the script at the beginning.
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
- Updated the 'loop' argument output to also use the Awesome font. (18/05/2025)
- Refactored unit conversion logic: added `unit_mode` variable to allow switching between KB/s(`unit_mode=1`), MB/s(`unit_mode=2`), or automatic(`unit_mode=3`) unit selection depending on the speed. (19/05/2025)

---

### `taskbar_change_brightness.sh`

**Description:**  
Controls screen brightness for both internal and external monitors, supporting both command-line and graphical (YAD slider) interfaces.  
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
- Identified possible infinite loop from unresponsive YAD processes. The script now uses SIGKILL (-9) to forcefully terminate previous yad/script instances when switching modes to prevent this. (21/05/2025)
- Improved brightness value conversion between xrandr (0.1–1.0) and ddcutil (0–100) modes. (21/05/2025)
- Fixed bug where switching between xrandr and ddcutil using the Switch button could result in "Initial value greater than maximum" errors in YAD. (21/05/2025)
- Now, when switching modes, the initial brightness value is always converted to the correct scale for the selected tool. (21/05/2025)
- Enhanced robustness by ensuring default values are set if brightness cannot be retrieved. (21/05/2025)
- Minor code cleanup and improved comments for maintainability. (21/05/2025)
- When switching modes, the brightness value from the previous tool, whether xrandr or ddcutil, was being carried over, which shouldn't happen. Both tools have their own independent brightness systems. (21/05/2025)
- Added the option to turn off monitor on both xrandr and ddcutil interfaces. (22/05/2025)
- Some coding improvement for redeability and maintainability .(22/05/2025)
- Removed the feature where the YAD interface closes automatically after a short period. This is not a good idea on slow systems, as YAD can take some time to load, and this feature could result in no interface being shown at all.
---



