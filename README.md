# Reverse SSH Tunnel Scripts

A collection of scripts for various embedded devices to create and maintain persistent reverse SSH tunnels to a central management server. This allows for remote access to devices behind firewalls.

## Script Variants

This repository contains the following script variants:

*   **`ubnt-revssh`**: Designed specifically for Ubiquiti EdgeRouter devices, leveraging their `bash` shell and standard Linux utilities.
*   **`teltonika-revssh`**: Tailored for Teltonika routers (e.g., RUT241) which utilize a BusyBox environment with the `ash` shell and Dropbear SSH client. This variant uses POSIX-compliant commands and `dropbearkey` for SSH key management.


## Features

-   **Persistent Connection:** Automatically checks and re-establishes the SSH tunnel if it drops.
-   **Unique Port Generation:** Creates a unique remote port based on the device's MAC address to prevent conflicts on the server.
-   **Robust Error Handling:** Detects if the remote port is already in use and attempts to kill the stale process. If the process belongs to a different user, it logs the conflict locally for troubleshooting and retries later.
-   **Automatic SSH Key Management:** Automatically generates a unique SSH key on the device and uses `ssh-copy-id` to install it on the management server.
-   **Lightweight:** Designed to run on resource-constrained devices like routers.

## Installation

You can download the script directly to your Ubiquiti device using `curl` or `wget`.

**Using curl:**
```bash
curl -L https://raw.githubusercontent.com/thatguyinoz/ubnt-revssh/master/ubnt-revssh -o ubnt-revssh
chmod +x ubnt-revssh
```

**Using wget:**
```bash
wget https://raw.githubusercontent.com/thatguyinoz/ubnt-revssh/master/ubnt-revssh -O ubnt-revssh
chmod +x ubnt-revssh
```

## Usage

1.  **Place the script:** Move the script to a persistent location on your device, such as `/config/scripts/`.
2.  **Configure:** Edit the `user` and `mgmt` variables at the top of the script to match your management server.
### Schedule Execution (EdgeRouter)
To ensure the script runs automatically and persistently across reboots, use the EdgeRouter's built-in task scheduler. Choose either the CLI or Web GUI method below.

#### Method 1: CLI (Recommended)
1.  **Enter Configuration Mode:**
    ```
    configure
    ```

2.  **Create the Scheduled Task:**
    This command will run the script every 5 minutes.
    ```
    set system task-scheduler task ubnt-revssh executable path /config/scripts/ubnt-revssh
    set system task-scheduler task ubnt-revssh interval 5m
    ```

3.  **Commit and Save the Changes:**
    ```
    commit
    save
    exit
    ```

#### Method 2: Web GUI
1.  **Log in** to your EdgeRouter's web interface.
2.  Go to the **Config Tree** tab.
3.  In the left pane, navigate to `system` -> `task-scheduler`.
4.  In the `task` field, type a name for the job (e.g., `ubnt-revssh`) and click **Update List**.
5.  A new `ubnt-revssh` item will appear in the left pane. Click on it.
6.  In the right pane, configure the following:
    *   Next to `executable`, find the `path` field and enter `/config/scripts/ubnt-revssh`.
    *   Next to `interval`, enter `5m` (for 5 minutes).
7.  Click the **Preview** button at the bottom of the page, then click **Apply**.

### First-Time Setup
The first time the script runs, it will generate a unique SSH key for the device. You will be prompted to enter the password for the user on the management server. This is a one-time action to allow the script to automatically copy its public key to the server. If you do not enter a password within 15 seconds, the script will time out and try again on the next run.
