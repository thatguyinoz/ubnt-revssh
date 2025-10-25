#!/bin/bash
# check in with the mgmt server
#version 0.09
#
# v0.09 - 2025-10-25 - Modernized network commands to use 'ip'
# v0.08 - 2025-10-25 - Added configurable interface variables
# v0.07 - 2025-10-25 - Prevent hang on initial key check
# v0.06 - 2025-10-25 - Fixed ssh-copy-id timeout issue
# v0.05 - 2025-10-25 - Improved remote kill function with local logging
# v0.04 - 2025-10-25 - Added SSH key generation and distribution
# v0.03 - 2025-10-25 - Added robust error handling for port-in-use condition
# v0.02 - 2020-03-17 - Initial Version

# user is the dyndns username, probably hctech, or maybe cammo
user="hctech"


# key might be elsewhere
key="/config/auth/$user-$(hostname)-rev_id_rsa"
mgmt="dyndns.hctech.com.au"
timestamp=`date +%Y-%m-%d-%T`
TUNNEL_STATE_FILE="/run/user/1000/tun_state"

# --- Network Configuration ---
lanIface="switch0"			# edit this to suit the local LAN
wanIface="eth0"				# edit this to suit the locaL WAN

lanip=$(ip -4 addr show $lanIface | grep -oP 'inet \\K[\\d.]+')
wanip=$(ip -4 addr show $wanIface | grep -oP 'inet \\K[\\d.]+')
# psuedo random port based on the the last 2 sets from the mac address
porthex=$(ip link show eth0 | awk '/ether/ {print $2}' | awk -F: '{print $4$5}')	#we need a physical interface, if wanIface=pppoe0 this would fail.
portdec=`echo $((16#$porthex))`
sshport="222"   #what port are we running ssh on?

# --- Core Functions ---

#
# Ensures the SSH key exists and is copied to the management server.
#
setup_ssh_key() {
  # 1. Check if the key exists, create it if it doesn't
  if [ ! -f "$key" ]; then
    echo "SSH key not found. Generating a new key at $key..."
    ssh-keygen -t rsa -b 4096 -f "$key" -N ""
    if [ $? -ne 0 ]; then
      logger "FATAL: Failed to generate SSH key."
      exit 1 # Exit because without a key, nothing else will work.
    fi
  fi

  # 2. Check if the public key is on the server, copy it if it isn't
  # Use PreferredAuthentications=publickey to prevent a password prompt here, which would hang the script.
  if ! ssh -o "PreferredAuthentications=publickey" -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" -i "$key" -T "$user@$mgmt" -p 3333 'exit' 2>/dev/null; then
    echo "Public key not found on server, or other SSH error occurred. Attempting to copy..."
    # Use ConnectTimeout to prevent hangs on network issues, without blocking the interactive password prompt.
    ssh-copy-id -o "StrictHostKeyChecking no" -o "ConnectTimeout=10" -p 3333 -i "${key}.pub" "$user@$mgmt"

    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
      logger "Failed to copy SSH key to server (ssh-copy-id exit code: $exit_code). Will retry on next run."
    else
      echo "SSH key successfully copied to server."
    fi
  fi
}

#
# Kills a listening process on the remote server by port number
#
kill_remote_process_by_port() {
  local port_to_kill=$1
  echo "Executing remote command to find and kill process on port $port_to_kill"

  # This command is designed to exit with code 1 if 'kill' fails.
  local remote_command="
    PID=\$(ss -tulpn | grep ':$port_to_kill' | awk -F, '{print \$2}' | awk -F= '{print \$2}')
    if [ -n \"\$PID\" ]; then
      # Attempt to kill the PID. If the kill command fails, exit with code 1.
      kill \"\$PID\" || exit 1
    fi
    # If no PID was found, or kill succeeded, exit cleanly.
    exit 0
  "

  # Execute the command and capture the result.
  ssh -o BatchMode=yes -o "StrictHostKeyChecking no" -i "$key" "$user@$mgmt" -p 3333 "$remote_command"
  
  local exit_code=$?
  if [ $exit_code -eq 1 ]; then
    # This block runs ONLY if the remote 'kill' command failed.
    logger "Could not kill remote process on port $port_to_kill. Different owner?"
  elif [ $exit_code -ne 0 ]; then
    # This block handles other SSH errors (e.g., connection refused).
    logger "SSH command failed while trying to kill remote process. Exit code: $exit_code"
  fi
}


# --- Main Logic ---

# Ensure our SSH key is set up before we do anything else.
setup_ssh_key

#check if our process is running
if pgrep -f "ssh -fNT" > /dev/null
then
  #echo "process exists"
  # log our port and connection time
  ssh -o BatchMode=yes -o "StrictHostKeyChecking no"  -i $key -T $user@$mgmt -p 3333 "echo $timestamp LAN:$lanip WAN:$wanip hopcon@127.0.0.1 -p$portdec > `hostname`"
  exit
else
  if ip route | grep -q '^default'; then
    # Attempt to open the tunnel, redirecting any errors to our log file
    ssh -fNT -o ExitOnForwardFailure=yes -o BatchMode=yes -o "StrictHostKeyChecking no" -i $key -R $portdec:127.0.0.1:$sshport $user@$mgmt -p 3333 2> "$TUNNEL_STATE_FILE"

    # Give SSH a moment to connect or fail
    sleep 2

    # Check if the error log has anything in it
    if [ -s "$TUNNEL_STATE_FILE" ]; then
      # SSH failed, check for the specific error
      if grep -q "Address already in use" "$TUNNEL_STATE_FILE"; then
        # THE PORT IS IN USE. TRIGGER THE NEW FUNCTION
        echo "Port $portdec is already in use on $mgmt. Attempting to clear it."
        # We will call the new function here, passing it the port to kill
        kill_remote_process_by_port "$portdec"
        # After killing, retry the connection
        ssh -fNT -o ExitOnForwardFailure=yes -o BatchMode=yes -o "StrictHostKeyChecking no" -i $key -R $portdec:127.0.0.1:$sshport $user@$mgmt -p 3333
      else
        # A different SSH error occurred, log it for debugging
        echo "An unexpected SSH error occurred: `cat $TUNNEL_STATE_FILE`"
      fi
    else
      # Success! The tunnel should be up. Log our connection time.
      ssh -o BatchMode=yes -o "StrictHostKeyChecking no"  -i $key -T $user@$mgmt -p 3333 "echo \"$timestamp LAN:$lanip WAN:$wanip hopcon@127.0.0.1 -p$portdec\" > `hostname`"
    fi

    # Clean up the temporary file
    rm -f "$TUNNEL_STATE_FILE"
  else
    #echo "no gateway exiting."
    exit
  fi
fi
