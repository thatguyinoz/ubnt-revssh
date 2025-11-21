#!/bin/sh
# check in with the mgmt server
# version 0.06
#
# v0.06 - 2025-11-21 - Fixed SSH options for Dropbear and uci command for device name, fixed login name (not the same as webgui name)
# v0.05 - 2025-11-21 - Replaced hostname command with uci for device name
# v0.04 - 2025-11-21 - Implemented portable hex conversion with awk
# v0.03 - 2025-11-21 - Fixed arithmetic syntax error for ash shell
# v0.02 - 2025-11-21 - Replaced ssh-keygen with dropbearkey for key generation
# v0.01 - 2025-11-21 - First version for Teltonika devices (ash shell)
#

# --- Configuration ---
# user is the username on the management server
user="hctech"
# mgmt is the hostname or IP address of the management server
mgmt="dyndns.hctech.com.au"
# key is the location to store the persistent SSH key on this device
key="/etc/dropbear/revssh_$(uci get system.@system[0].hostname)_id_rsa"
# The port on the management server to connect to
mgmt_port="3333"
# The local SSH port to forward
local_ssh_port="5222"
# Temporary file to store SSH connection errors
TUNNEL_STATE_FILE="/tmp/tun_state"

# --- Network Configuration ---
# Interface for the LAN
lanIface="br-lan"
# Interface for the WAN
wanIface="wwan0"
# A physical interface with a stable MAC address to generate the unique port
macIface="eth0"

# --- Script Variables ---
timestamp=$(date +"%Y-%m-%d-%T")
lanip=$(ifconfig $lanIface | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
wanip=$(ifconfig $wanIface | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
# Generate a unique port from the device's MAC address
porthex=$(ifconfig $macIface | grep 'HWaddr' | awk '{print $5}' | sed 's/://g' | cut -c 7-10)
portdec=$(echo "$porthex" | awk '{ printf "%d", "0x" $1 }')

# --- Core Functions ---

#
# Ensures the SSH key exists and is copied to the management server.
#
setup_ssh_key() {
  # 1. Check if the key exists, create it if it doesn't
  if [ ! -f "$key" ]; then
    echo "SSH key not found. Generating a new key at $key..."
    # Generate Dropbear RSA key
    dropbearkey -t rsa -s 4096 -f "$key"
    if [ $? -ne 0 ]; then
      logger "FATAL: Failed to generate SSH key with dropbearkey."
      exit 1 # Exit because without a key, nothing else will work.
    fi
    # Extract public key in OpenSSH format
    dropbearkey -y -f "$key" > "${key}.pub"
    if [ $? -ne 0 ]; then
      logger "FATAL: Failed to extract public key from dropbearkey."
      exit 1
    fi
  fi

  # 2. Check if the public key is on the server, copy it if it isn't
  if ! ssh -y -o "UserKnownHostsFile=/dev/null" -i "$key" -T "$user@$mgmt" -p "$mgmt_port" 'exit' 2>/dev/null; then
    echo "Public key not found on server. Attempting to copy..."
    # Manually replicate ssh-copy-id for BusyBox environments
    cat "${key}.pub" | ssh -y -p "$mgmt_port" "$user@$mgmt" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
      logger "Failed to copy SSH key to server (exit code: $exit_code). Will retry on next run."
    else
      echo "SSH key successfully copied to server."
    fi
  fi
}

#
# Request that the management server release an orphaned port.
#
request_kill_port() {
  local port_to_kill=$1
  echo "Requesting server to find and kill process using port $port_to_kill"
  ssh -y -i "$key" "$user@$mgmt" -p "$mgmt_port" "echo \"$port_to_kill\" >> orphaned_ports"
}


# --- Main Logic ---

# Ensure our SSH key is set up before we do anything else.
setup_ssh_key

# Check if the reverse SSH tunnel process is already running
if ps | grep -v grep | grep -q "ssh -fNT"; then
  # The process exists, log the current status to the server, note the user is root not the gui username
  ssh -y  -i "$key" -T "$user@$mgmt" -p "$mgmt_port" "echo $timestamp LAN:$lanip WAN:$wanip root@127.0.0.1 -p$portdec > $(uci get system.@system[0].hostname)"
  exit 0
else
  # Check for a default route to ensure there is an internet connection
  if route -n | grep -q '^0.0.0.0'; then
    # Attempt to open the tunnel, redirecting any errors to our log file
    ssh -fNT -y -i "$key" -R "$portdec:127.0.0.1:$local_ssh_port" "$user@$mgmt" -p "$mgmt_port" 2> "$TUNNEL_STATE_FILE"

    # Give SSH a moment to connect or fail
    sleep 5

    # Check if the error log has anything in it
    if [ -s "$TUNNEL_STATE_FILE" ]; then
      # SSH failed, check for the specific error
      if grep -q "forwarding failed for listen port" "$TUNNEL_STATE_FILE"; then
        # The port is in use on the server
        echo "Port $portdec is already in use on $mgmt. Requesting it to be cleared."
        request_kill_port "$portdec"
        # After request, wait and retry the connection
        sleep 30
        ssh -fNT -y -i "$key" -R "$portdec:127.0.0.1:$local_ssh_port" "$user@$mgmt" -p "$mgmt_port"
      else
        # A different SSH error occurred, log it for debugging
        logger "An unexpected SSH error occurred: $(cat $TUNNEL_STATE_FILE)"
      fi
    else
      # Success! The tunnel should be up. Log our connection time. note the user is root not the gui username
ssh -y  -i "$key" -T "$user@$mgmt" -p "$mgmt_port" "echo \"$timestamp LAN:$lanip WAN:$wanip root@127.0.0.1 -p$portdec\" > $(uci get system.@system[0].hostname)"
    fi

    # Clean up the temporary file
    rm -f "$TUNNEL_STATE_FILE"
  else
    # No default gateway, so exit.
    exit 1
  fi
fi
