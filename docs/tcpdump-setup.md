# Tcpdump Setup for Automated Packet Capturing

This guide details the setup of `tcpdump` on OpenWRT to enable automated, storage-safe packet capturing. Packets are captured per interface (e.g., `eth0.20`, `eth0.30`) and stored on the Seagate NAS at `/mnt/cloud/tcpdumps/`. A retention watchdog ensures storage usage stays within limits, making this setup suitable for network monitoring, auditing, and future SIEM integration.

## Overview

- **Purpose**:
  - Capture packets from specified OpenWRT interfaces (e.g., `eth0.20` for LAN, `eth0.30` for Trusted WiFi).
  - Store packet captures (`.pcap` files) on the NAS at `/mnt/cloud/tcpdumps/`.
  - Manage storage with a 1GB limit, automatically deleting the oldest captures when exceeded.
- **Script**:
  - A custom script (`/etc/init.d/tcpdump_logger`) automates capturing, stopping, and storage management.
  - Captures are saved as `INTERFACE.pcap` (e.g., `eth0.20.pcap`).

## Prerequisites

- **Hardware**:
  - Seagate 4TB NAS (configured as per [nas-setup.md](nas-setup.md)).
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openWRT-setup.md)).
- **Software**:
  - `tcpdump` installed on OpenWRT.
  - NAS mounted at `/mnt/cloud` on OpenWRT (as per [nas-setup.md](nas-setup.md)).
- **Network Setup**:
  - Interfaces like `eth0.20` (LAN), `eth0.30` (Trusted WiFi), etc., are configured (see [openwrt-setup.md](openWRT-setup.md)).
  - VLAN 60 is configured for the NAS (`eth0.60`, `192.168.60.100`).

## Step 1: Install Tcpdump on OpenWRT

1. **Install Tcpdump**:
   - Install `tcpdump` on OpenWRT:
     ```bash
     opkg update
     opkg install tcpdump
     ```
2. **Verify Installation**:
   - Check that `tcpdump` is installed:
     ```bash
     tcpdump --version
     ```

## Step 2: Verify NAS Mount

1. **Confirm NAS Mount**:
   - Ensure the NAS is mounted at `/mnt/cloud` (as set up in [nas-setup.md](nas-setup.md)):
     ```bash
     df -h | grep /mnt/cloud
     ```
   - If not mounted, the automount script should handle this on reboot. Alternatively, mount it manually:
     ```bash
     mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,vers=3.0
     ```

## Step 3: Create Tcpdump Logger Script

1. **Create the Script**:
   - Create a new script to automate packet capturing:
     ```bash
     nano /etc/init.d/tcpdump_logger
     ```
   - Add the following content:
     ```
    #!/bin/sh /etc/rc.common

    START=99
    PID_DIR="/tmp/tcpdump_logger_pids"
    LOG_DIR="/mnt/cloud/tcpdumps"
    MAX_SIZE_MB=1024  # 1GB limit

    start() {
        MODE="$1"
        shift

        mkdir -p "$PID_DIR"

        if [ ! -d "$LOG_DIR" ]; then
            echo "$(date) NAS mount not found at $LOG_DIR. Aborting." | tee -a /tmp/tcpdump_logger.log
            return 1
        fi

        echo "$(date) Starting tcpdump_logger... Mode: ${MODE:-background}" | tee -a /tmp/tcpdump_logger.log

        INTERFACES="$@"
        if [ -z "$INTERFACES" ]; then
            INTERFACES=$(ip link show | awk -F: '/: e/{print $2}' | tr -d ' ')
        fi

        for IFACE in $INTERFACES; do
            OUT_FILE="$LOG_DIR/$IFACE.pcap"
            echo "$(date) Starting tcpdump on $IFACE -> $OUT_FILE" | tee -a /tmp/tcpdump_logger.log
            if [ "$MODE" = "manual" ]; then
                # Foreground mode, CTRL+C will work
                tcpdump -i "$IFACE" -n -s 0 -U -w - | tee "$OUT_FILE" | tcpdump -n -r -
            else
                # Background mode
                ( tcpdump -i "$IFACE" -n -s 0 -U -w - | tee "$OUT_FILE" | tcpdump -n -r - ) &
                echo $! > "$PID_DIR/$IFACE.pid"
            fi
        done

        if [ "$MODE" != "manual" ]; then
            # Start retention watchdog only in background mode
            retention_watchdog &
            echo $! > "$PID_DIR/retention.pid"
        fi
    }

    stop() {
        echo "$(date) Stopping tcpdump_logger..." | tee -a /tmp/tcpdump_logger.log
        for PIDFILE in "$PID_DIR"/*.pid; do
            [ -f "$PIDFILE" ] || continue
            PID=$(cat "$PIDFILE")
            kill "$PID" 2>/dev/null
            rm -f "$PIDFILE"
        done
        rm -rf "$PID_DIR"
    }

    retention_watchdog() {
        while true; do
            TOTAL_MB=$(du -sm "$LOG_DIR" | awk '{print $1}')
            if [ "$TOTAL_MB" -gt "$MAX_SIZE_MB" ]; then
                echo "$(date) Limit reached: ${TOTAL_MB}MB used, deleting oldest..." | tee -a /tmp/tcpdump_logger.log
                OLDEST=$(find "$LOG_DIR" -type f -name "*.pcap" -printf "%T@ %p\n" | sort -n | awk 'NR==1 {print $2}')
                [ -n "$OLDEST" ] && rm -f "$OLDEST" && echo "$(date) Deleted $OLDEST" | tee -a /tmp/tcpdump_logger.log
            fi
            sleep 60
        done
    }
     ```
   - Save and exit.

3. **Create a Startcp (optional)**

Let's create a short script that will save us some time
  - startcp is a helper script for OpenWRT that allows you to quickly start a manual packet capture session with:

    - Live real-time packet output on the screen (just like normal tcpdump)
    - Saving full .pcap files to your mounted NAS (/mnt/cloud/tcpdumps/)
    - Clean exit using CTRL+C — no background zombies, no manual kills needed
    - Minimal typing — just startcp <interface>

1. **Create the Script**
   - create the file 
   ```
   nano /usr/bin/startcp
   ```
   - paste this script
   ```
   #!/bin/sh


    if [ $# -eq 0 ]; then
        echo "Usage: startcp <interface1> [interface2] [interface3] ..."
        echo "Example: startcp eth0.20 eth0.30 br-lan"
        exit 1
    fi

    for IFACE in "$@"; do
        echo "Starting capture on $IFACE"
        /etc/init.d/tcpdump_logger start manual "$IFACE" &
    done

    wait
    ```

2. **Enable and Test the Script**:
   - Set the correct permissions and enable the scripts:
     ```bash
     chmod +x /etc/init.d/tcpdump_logger
     chmod +x /usr/bin/startcp
     ```
   - Start capturing on specific interfaces (e.g., `eth0.20` for LAN, `eth0.30` for Trusted WiFi):
     ```bash
     /etc/init.d/tcpdump_logger start  eth0.30
     ```
     or
     ```
     startcp eth0.20
     ```
   - Verify that `.pcap` files are being created:
     ```bash
     ls -lh /mnt/cloud/tcpdumps
     ```
   - You should see files like `eth0.20.pcap` and `eth0.30.pcap`.

## Step 4: Usage Instructions

The `tcpdump_logger` script provides flexible options for capturing packets:

- **Capture on All `eth0.X` Interfaces**:
  ```bash
  /etc/init.d/tcpdump_logger start
  ```
  - This captures packets on all interfaces matching `eth0.X` (e.g., `eth0.20`, `eth0.30`, `eth0.40`).
- **Capture on a Specific Interface**:
  ```bash
  /etc/init.d/tcpdump_logger start eth0.20
  ```
  or
  ```
  startcp eth0.20
  ```
  - This captures packets only on `eth0.20`.
- **Capture on Multiple Specific Interfaces**:
  ```bash
  /etc/init.d/tcpdump_logger start eth0.20 eth0.30
  ```
  - This captures packets on `eth0.20` and `eth0.30`.
- **Stop All Captures**:
  ```bash
  /etc/init.d/tcpdump_logger stop
  ```
  or ctrl+c
  - This stops all running `tcpdump` processes and the retention watchdog.


## Step 5: Verify Packet Captures

1. **Check Capture Files**:
   - List the capture files on the NAS:
     ```bash
     ls -lh /mnt/cloud/tcpdumps
     ```
   - You should see `.pcap` files for each interface you specified (e.g., `eth0.20.pcap`).
2. **Analyze Captures**:
   - Copy a `.pcap` file to your PC for analysis with Wireshark:
     ```bash
     scp root@192.168.2.1:/mnt/cloud/tcpdumps/eth0.20.pcap .
     ```
   - Open the file in Wireshark to inspect the captured packets.
3. **Verify Retention**:
   - Generate traffic to fill up the captures (e.g., by pinging or browsing from devices on VLAN 20 or 30).
   - Check the total size of the `tcpdumps` directory:
     ```bash
     du -sh /mnt/cloud/tcpdumps
     ```
   - Once the size exceeds 100GB, the retention watchdog should delete the oldest `.pcap` file. Check the logs:
     ```bash
     cat /tmp/tcpdump_logger.log
     ```

## Troubleshooting

- **NAS Not Mounted**:
  - Verify the NAS is mounted at `/mnt/cloud`:
    ```bash
    df -h | grep /mnt/cloud
    ```
  - If not mounted, check the mount script logs:
    ```bash
    logread | grep "NAS mounted"
    ```
  - Remount manually if needed:
    ```bash
    mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,vers=3.0
    ```
- **No `.pcap` Files Created**:
  - Ensure `tcpdump` is running:
    ```bash
    ps | grep tcpdump
    ```
  - Check the script logs for errors:
    ```bash
    cat /tmp/tcpdump_logger.log
    ```
  - Verify the specified interfaces exist:
    ```bash
    ip link show
    ```
- **Retention Watchdog Not Deleting Files**:
  - Confirm the watchdog is running:
    ```bash
    ps | grep retention
    ```
  - Check the total size of the `tcpdumps` directory:
    ```bash
    du -sm /mnt/cloud/tcpdumps
    ```
  - If the size exceeds 1GB and no files are deleted, review the script logs:
    ```bash
    cat /tmp/tcpdump_logger.log
    ```

## Notes

- **Storage Management**:
  - The script enforces a 1GB storage limit for `/mnt/cloud/tcpdumps/`. Adjust `MAX_SIZE_MB` in the script if you need more or less storage.
  - The retention watchdog deletes the oldest `.pcap` file when the limit is exceeded, ensuring the NAS doesn’t run out of space.
- **Capture Options**:
  - The script uses `tcpdump -C 100 -W 1` to limit each `.pcap` file to 100MB before overwriting, preventing large files from consuming too much space.
  - The `-U` flag ensures packets are written immediately to the file, making captures suitable for real-time analysis.
- **Security**:
  - Packet captures are stored on the NAS, which is isolated from untrusted VLANs (IoT, Guest), ensuring they are only accessible from the LAN (VLAN 20).
- **Future Enhancements**:
  - Integrate captures with a SIEM (e.g., Wazuh) by analyzing `.pcap` files stored on the NAS.
  - Add filters to `tcpdump` (e.g., `tcpdump -i eth0.20 port 80`) to capture specific traffic types.

## Next Steps

- Explore SIEM integration by setting up Wazuh to analyze packet captures from `/mnt/cloud/tcpdumps/`.
- Add Suricata for intrusion detection and integrate its logs with the centralized logging system (see [rsyslog-setup.md](rsyslog-setup.md)).
- Consider adding filters to `tcpdump` to capture specific traffic (e.g., HTTP, DNS) for targeted analysis.

