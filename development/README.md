## Development Scripts

These are utility scripts for advanced system management and automation, intended for users comfortable with Bash and Linux internals.

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
