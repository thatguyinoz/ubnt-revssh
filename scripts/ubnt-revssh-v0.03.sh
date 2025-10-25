#!/bin/bash
# check in with the mgmt server
#version 0.03
#2020-03-17
#
# v0.03 - 2025-10-25 - Added robust error handling for port-in-use condition
# v0.02 - 2020-03-17 - Initial Version

# user is the dyndns username, probably hctech, or maybe cammo
# copy the id_rsa (not pub) from the dyndns user/.ssh dir to the key file below
user="hctech"


# key might be elsewhere
key="/config/auth/hctech-id_rsa"
mgmt="dyndns.hctech.com.au"
timestamp=`date +%Y-%m-%d-%T`
TUNNEL_STATE_FILE="/run/user/1000/tun_state"
lanip=$(ifconfig eth2|grep broadcast|awk '{print $2}'|sed 's/addr://')
wanip=`ifconfig eth0|grep broadcast|awk '{print $2}'|sed 's/addr://'`
# psuedo random port based on the the last 2 sets from the mac address
porthex=`/sbin/ifconfig eth0|grep ether|awk -F: '{print $4$5}'`
portdec=`echo $((16#$porthex))`
sshport="222"   #what port are we running ssh on?

# --- Core Functions ---

#
# Kills a listening process on the remote server by port number
#
kill_remote_process_by_port() {
  local port_to_kill=$1
  echo "Executing remote command to kill process on port $port_to_kill"

  # Connect to the management server and execute the kill command.
  # This will only kill a process owned by $user on the specified port.
  ssh -o BatchMode=yes -o "StrictHostKeyChecking no" -i $key $user@$mgmt -p 3333 "lsof -t -u $user -i :$port_to_kill | xargs kill -9"
}


# --- Main Logic ---

#check if our process is running
if pgrep -f "ssh -fNT" > /dev/null
then
  #echo "process exists"
  # log our port and connection time
  ssh -o BatchMode=yes -o "StrictHostKeyChecking no"  -i $key -T $user@$mgmt -p 3333 "echo $timestamp LAN:$lanip WAN:$wanip hopcon@127.0.0.1 -p$portdec > `hostname`"
  exit
else
  if /sbin/route -n |grep -q -m1 ^0.0.0.0; then
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
