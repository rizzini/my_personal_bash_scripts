I'm still learning using Git and Github..

All monitoring scripts, those starting with taskbar_*, are performance-sensitive, meaning they're designed to use minimal hardware resources. From time to time, I'll tweak the scripts to make them consume less and less resources as possible. 
I've started using Awesome Font to add a bit of simple styling, but I'm not sure yet whether I'll keep it this way. I'm not good at that. If you are, feel free to pitch in! They are written in pure Bash, avoiding external tools and subshells as much as possible. I use them with the Command Output Plasma KDE widget, which I'll better explain it how I do it later this week in this README.  

This repository contains a set of Bash scripts, which are intended more as a core toolkit than as a polished, ready-to-use solution for system monitoring and hardware control on Linux. Below you will find a detailed description of each script, including all arguments and their functions. 

![](taskbar_screenshot.png)

### `Important`

It's worth mentioning that I haven't set up the bootstrapping for the scripts yet. Therefore, while the code itself can certainly be reused (if you know what you're doing), the scripts are not redistributable.

---

### [`taskbar_network_speed_monitor.sh`](https://github.com/rizzini/my_personal_bash_scripts/blob/master/taskbar_network_speed_monitor.sh)

**Description:**  
Displays real-time network speed (download and upload) and the number of open network connections, optimized for minimal resource usage.  
- Reads network statistics directly from `/proc/net/dev` to calculate current download and upload speeds for a specified network interface (by default, `enp1s0`; you can edit the script to change this).
- Calculates speed by measuring the difference in bytes sent/received over a 1-second interval.
- Supports three unit display modes (KB/s, MB/s, or automatic selection based on speed), configurable via the `unit_mode` variable in the script at the beginning.
- The output is color-coded, regardless of the display mode you choose(In the near future, I'll make this dynamic depending on your connection):  
  - **Green:** 2-10 MB/s  
  - **Yellow:** 10-30 MB/s  
  - **Red:** > 30 MB/s  
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
- Fixed: 10 MB/s wasn't being colorized due to an off-by-one in the range check (was 11–30 MB/s). Range corrected to 10–30 MB/s so 10 MB/s is colored as expected. (26/10/2025)
 - Performance: replaced `nmcli`-based interface detection with lightweight checks using `/dev/ttyUSB*`, `ip link` and `/proc/net/dev` to reduce CPU overhead when running every second. (30/10/2025)

---

### [`taskbar_memory_usage.sh`](https://github.com/rizzini/my_personal_bash_scripts/blob/master/taskbar_memory_usage.sh)

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
- Safety: prevent disabling ZRAM when there isn't enough physical RAM plus other disco swap free to relocate pages currently stored in ZRAM. The script's `disable_zram` now calls `can_disable_zram` and will refuse to `swapoff` ZRAM if `MemAvailable + other swap free < zram_used`, printing a clear message and aborting to avoid OOM/hang. (01/11/2025)
- Added display of disk swap usage as "Disco: <size>" when any disk swap is used; shown alongside ZRAM or OFF. (01/11/2025)


---

### [`taskbar_disk_monitor.sh`](https://github.com/rizzini/my_personal_bash_scripts/blob/master/taskbar_disk_monitor.sh)

**Description:**  
Monitors disk read and write speeds with high precision for all disks or a specific disk, designed for minimal resource usage and fast updates.  
- Reads disk statistics from `/proc/diskstats` to calculate real-time read and write speeds.
- Can display stats for a specific disk (e.g., `sda`) or for all disks at once.
- Supports both single-run and continuous monitoring modes (using the `loop` argument).
- Supports three unit display modes (KB/s, MB/s, or automatic selection based on speed), configurable via the `unit_mode` variable in the script at the beginning.
- Output is color-coded: speeds are shown in red if high activity is detected (above 20MB/s).
- Allows customization of the update interval when running in loop mode.

**Arguments:**  
- `-h`, `--help` : Show help and exit.
- `-u N`, `--unit N`, `--unit=VALUE` : Force the display unit; accepts `1`/`kb` (KB/s), `2`/`mb` (MB/s), `3`/`auto` (auto-select KB/MB). Case-insensitive. Default: `2` (MB/s).
- `--interval N`, `--interval=VALUE` : Set the interval in seconds when in continuous mode.
- `--loop [N]` : Run in continuous mode; a numeric N can be provided immediately after `--loop` or via `--interval` to set the interval.
- `-d`, `--device` : Device name to display (e.g., `sda`). Use this option to target a single device. As a shortcut you can pass `all` as the only argument to show all devices.

**Examples:**  
- `# Show a specific device`
- `./taskbar_disk_monitor.sh -d sda`
- `./taskbar_disk_monitor.sh --device=sda`

- `# Force unit: KB/MB/Auto`
- `./taskbar_disk_monitor.sh -u kb -d sda`
- `./taskbar_disk_monitor.sh --unit=mb --device=sda`
- `./taskbar_disk_monitor.sh --unit=auto --device=sda`

- `# Continuous mode (loop)`
- `./taskbar_disk_monitor.sh --loop`           — loop with default interval (1s), shows all devices
- `./taskbar_disk_monitor.sh --loop 2`         — loop with a 2-second interval
- `./taskbar_disk_monitor.sh --loop --interval 2`
- `./taskbar_disk_monitor.sh -d sda --loop 1`  — loop showing only `sda`

- `# Shortcut to show all devices`
- `./taskbar_disk_monitor.sh all`

**Output:**  
- Displays read and write speeds in KB/s or MB/s for the selected disk(s).
- Output uses graduated colorization when recent high activity is detected (script sets an alert when the per-sample delta >= 4096, i.e., ≈4 MB for the default sample period). When an alert is active the numeric value is colorized for a short window (3 seconds) and the color reflects magnitude. Color bands are applied to the integer portion of the formatted value and are currently implemented as:
  - **Green:** 4–14 (MB/s)
  - **Yellow:** 15–64 (MB/s)
  - **Red:** ≥65 (MB/s)
- When using `all`, shows a summary for each detected disk.
- Designed for easy parsing by widgets or other scripts.

**Changelog:**
- 22/12/2025 — Alert threshold changed to a per-sample delta of **4096** (≈4 MB for the default sample); this makes the monitor more sensitive to moderate activity.
- 22/12/2025 — Graduated colorization applied to recent alerts: green (4–14), yellow (15–64), red (≥65). Colors apply independently to reads and writes for clearer per-direction visibility.
- 29/12/2025 — Added support for long options and flexible argument forms: `--unit` / `--unit=VALUE` (also `-u VALUE`), `--interval` / `--interval=VALUE`, and `--loop` (numeric interval may follow `--loop` or be specified via `--interval`). The argument parser was updated to accept `--unit=VALUE` without adding a separate `case` branch to keep the code clean and continues to validate `1|2|3` or `kb|mb|auto`.
- 29/12/2025 — Added in-script help and examples to document all supported forms (`--unit=VALUE`, `--unit VALUE`, `--interval=VALUE`, `--loop`, etc.), and the script now shows the help message when invoked with no arguments for easier discovery.


---

### [`pipewire_auto_change_volume.sh`](https://github.com/rizzini/my_personal_bash_scripts/blob/master/pipewire_auto_change_volume.sh)

**Description:**
Automatically enforces a target volume for PipeWire "sink-input" streams. The script listens to `pactl subscribe` events, debounces activity for each stream, and sets the stream volume to the configured `TARGET_VOL` (currently 140%). It's designed to run quietly in the background and be low-overhead.

Why I made this: Firefox with the KDE Plasma (or related audio-stacks like PipeWire/PulseAudio), I noticed that Firefox’s audio stream behaviour is inconsistent: application volume may reset unexpectedly (e.g., from a custom level back to 100%), when media playback is paused for a few seconds (typically more than 3–5 seconds) which can be very annoying. This will workaround that.

**Changelog:**
- *No changes recorded yet.*

