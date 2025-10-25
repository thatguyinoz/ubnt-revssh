# ubnt-revssh

A script for Ubiquiti devices to create and maintain a persistent reverse SSH tunnel to a central management server. This allows for remote access to devices behind firewalls.

## Features

-   **Persistent Connection:** Automatically checks and re-establishes the SSH tunnel if it drops.
-   **Unique Port Generation:** Creates a unique remote port based on the device's MAC address to prevent conflicts on the server.
-   **Robust Error Handling:** Detects if the remote port is already in use, attempts to kill the stale process on the server, and retries the connection.
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
3.  **Schedule Execution:** Set up a cron job to run the script at a regular interval (e.g., every 5 minutes) to ensure the tunnel remains active.

   Example cron job:
   ```
   */5 * * * * /config/scripts/ubnt-revssh
   ```

### First-Time Setup
The first time the script runs, it will generate a unique SSH key for the device. You will be prompted to enter the password for the user on the management server. This is a one-time action to allow the script to automatically copy its public key to the server. If you do not enter a password within 15 seconds, the script will time out and try again on the next run.
