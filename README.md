
This repository contains a set of Bash scripts, which are intended to be shared more as an engine than as a final, styled solution, for system monitoring and hardware control on Linux. Below you will find a detailed description of each script, including all arguments and their functions. 

All monitoring scripts, those starting with taskbar_*, are performance-sensitive, meaning they're designed to use minimal hardware resources. I've started using Awesome Font to add a bit of simple styling, but I'm not sure yet whether I'll keep it this way. I'm not good at that part. If you are, feel to pich in! They are written in pure Bash, avoiding external tools and subshells as much as possible. I use them with the Command Output Plasma KDE widget, which I'll better explain it how I do it later this week in this README.  

![](taskbar_screenshot.png)

---

### `taskbar_cpu_usage.sh`

**Description:**  
Displays the current CPU usage percentage of a priod of one second.  
- If CPU usage exceeds 90%, the output is colored red for emphasis.

---

### `taskbar_memory_usage.sh`

**Description:**  
Displays current memory usage and ZRAM swap usage.  
- Allows toggling ZRAM swap on click or activating it at startup.

**Arguments:**  
- `click`: Toggles ZRAM swap on/off.  
  - If ZRAM is not active, it enables and configures ZRAM swap.
  - If ZRAM is active, it disables ZRAM swap and unloads the module.
- `startup`: Activates and configures ZRAM swap at system startup.

**Output:**  
- Shows memory usage in MB/GB (red if above 5GB).
- Shows ZRAM usage or "OFF" if ZRAM is disabled.

---

### `taskbar_network_speed_monitor.sh`

**Description:**  
Displays current network speed (download/upload) and the number of open network connections.  
- On click, shows a detailed list of open network connections grouped by process.

**Arguments:**  
- `click`:  
  - Lists all open TCP/UDP connections, grouped by process.
  - Shows the number of connections per process and those without an associated process.
  - Waits for a keypress before exiting.

**Output:**  
- Download and upload speeds (color-coded by usage).
- Number of open connections.

---

### `taskbar_disk_monitor.sh`

**Description:**  
Monitors disk read/write speeds with high precision for all disks or a specific disk.  
- Can run once or in a continuous loop.

**Arguments:**  
- `[disk_name]`: *(Optional)* Show stats for a specific disk (e.g., `sda`).
- `all`: Show stats for all disks.
- `loop`: Continuously update stats (use with `disk_name` or `all`).
- `[interval]`: *(Optional, used with `loop`)* Interval in seconds between updates (default: 1).

**Examples:**  
- `./taskbar_disk_monitor.sh sda` — Show stats for disk `sda` once.
- `./taskbar_disk_monitor.sh all loop 2` — Show stats for all disks, updating every 2 seconds. (needs fixing in the output)(to-do)

**Output:**  
- Read/write speeds in KB/s or MB/s (red if high activity, above 20MB/s).
- For all disks or a specific disk as requested.

---

### `taskbar_change_brightness.sh`

**Description:**  
Controls screen brightness for internal (xrandr) and external (ddcutil) monitors.  
- Provides both command-line and GUI (slider) controls.

**Arguments:**  
- `increase [xrandr|ddcutil]`: Increase brightness using the specified method.
- `decrease [xrandr|ddcutil]`: Decrease brightness using the specified method.
- `show_xrandr`: Show current brightness for xrandr.
- `show_ddcutil`: Show current brightness for ddcutil.
- `choose_xrandr`: Open GUI slider for xrandr.
- `choose_ddcutil`: Open GUI slider for ddcutil.

**Details:**  
- The script automatically switches between xrandr and ddcutil sliders if one is already open.
- Brightness values for xrandr are between 0.1 and 1.0; for ddcutil, between 0 and 100.

---

### `waydroid_under_xorg.sh`

**Description:**  
Enable the use of Waydroid under Xorg through a toggleable script. Run it once to launch Waydroid, and again to close it. Alternatively, you can also stop waydroid service process and container by just closing the Weston window.
Dependency: weston compositor.



