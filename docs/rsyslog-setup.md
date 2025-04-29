# Rsyslog Setup for Centralized Logging

This guide details the setup of `rsyslog` on both your main PC and OpenWRT to collect logs from OpenWRT (router), the main PC, and the TP-Link EAP610 Access Point (AP), and store them on the Seagate NAS mounted at `/mnt/cloud`. Logs are organized by device and service, with log rotation on the PC to manage storage efficiently. This setup supports auditing, detection, and future SIEM integration.

## Overview

- **Log Sources**:
  - OpenWRT (router, `192.168.2.1`).
  - Main PC (your local machine on VLAN 20, `192.168.2.x`).
  - Access Point (AP, `192.168.2.254`).
- **Log Storage**:
  - Seagate NAS mounted at `/mnt/cloud` (NAS IP: `192.168.60.100`, share: `Public`, mounted as per [nas-setup.md](nas-setup.md)).
  - Logs are stored in `/mnt/cloud/logs/` with a structure of `HOSTNAME/PROGRAMNAME.log`.
  - AP logs are stored separately in `/mnt/cloud/logs/AP/syslog.log`.

## Prerequisites

- **Hardware**:
  - Seagate 4TB NAS (configured as per [nas-setup.md](nas-setup.md)).
  - TP-Link EAP610 Access Point (configured as per [access-point-setup.md](access-point-setup.md)).
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openWRT-setup.md)).
- **Software**:
  - `rsyslog` installed on both your PC and OpenWRT.
  - NAS mounted at `/mnt/cloud` on both the PC and OpenWRT.
- **Network Setup**:
  - VLAN 60 is configured for the NAS (`eth0.60`, `192.168.60.1/24`).
  - Firewall rules allow the router to communicate with the AP (`192.168.2.254`) for logging (see [nas-setup.md](nas-setup.md)).

## Part 1: Set Up Rsyslog on Your PC

Your main PC will collect its own logs and write them to the NAS, which is mounted at `/mnt/cloud`.

1. **Install Rsyslog**:
   - Ensure `rsyslog` is installed on your PC (Linux-based):
     ```bash
     sudo apt update
     sudo apt install rsyslog
     ```
2. **Verify NAS Mount**:
   - Confirm the NAS is mounted at `/mnt/cloud` (as set up in [nas-setup.md](nas-setup.md)):
     ```bash
     df -h | grep /mnt/cloud
     ```
3. **Configure Rsyslog to Write Logs to NAS**:
   - Create a new `rsyslog` configuration file:
     ```bash
     sudo nano /etc/rsyslog.d/100-nas-logs.conf
     ```
   - Add the following to store logs in `/mnt/cloud/logs/HOSTNAME/PROGRAMNAME.log`:
     ```
     # Store logs to mounted NAS
     $template NASLogs,"/mnt/cloud/logs/%HOSTNAME%/%PROGRAMNAME%.log"
     *.* ?NASLogs
     ```
   - Save and exit.
4. **Restart Rsyslog**:
   - Restart the `rsyslog` service to apply the changes:
     ```bash
     sudo systemctl enable rsyslog  
     sudo systemctl restart rsyslog
     ```
5. **Test Log Writing**:
   - Check if logs are being written to the NAS:
     ```bash
     tail -f /mnt/cloud/logs/$(hostname)/*.log
     ```
   - You should see logs from your PC (e.g., `/mnt/cloud/logs/your-pc-name/syslog.log`).


## Part 2: Set Up Rsyslog on OpenWRT

OpenWRT will collect logs from itself and the AP (`192.168.2.254`) and write them to the NAS mounted at `/mnt/cloud`.

1. **Install Rsyslog**:
   - Install `rsyslog` on OpenWRT:
     ```bash
     opkg update
     opkg install rsyslog
     opkg install logrotate
     ```
2. **Verify NAS Mount**:
   - Ensure the NAS is mounted at `/mnt/cloud` (as set up in [nas-setup.md](nas-setup.md)):
     ```bash
     df -h | grep /mnt/cloud
     ```
   - If not mounted, check [nas-setup.md](nas-setup.md)

3. **Create Log Directory**:
   - Create a directory for OpenWRT logs on the NAS:
     ```bash
     mkdir -p /mnt/cloud/logs/openwrt
     ```
4. **Configure Rsyslog on OpenWRT**:
   - Edit the main `rsyslog` configuration file:
     ```bash
     nano /etc/rsyslog.conf
     ```
   - Replace its contents with the following to enable input modules and include custom configurations:
     ```
     # Load input modules
     module(load="imuxsock")     # Socket input (e.g., system log)
     module(load="imklog")       # Kernel logs

     # Enable UDP for collecting logs from other devices (e.g., AP)
     module(load="imudp")
     input(type="imudp" port="514")

     # Default template
     $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

     # Include custom config files
     $IncludeConfig /etc/rsyslog.d/*.conf
     ```
   - Save and exit.

5. **Create Rsyslog Configuration for NAS Logs**:
   - Create a new configuration file to direct logs to the NAS:
     ```bash
     mkdir /etc/rsyslog.d/
     nano /etc/rsyslog.d/100-nas-logs.conf
     ```
   - Add the following to store logs in `/mnt/cloud/logs/HOSTNAME/PROGRAMNAME.log`, with a specific rule for the AP:
     ```
     # Queue for NAS logs to prevent blocking
     $ActionQueueFileName naslog

     # Specific logs from the AP go to a dedicated file
     if $fromhost-ip == '192.168.2.254' then {
         action(type="omfile" file="/mnt/cloud/logs/AP/syslog.log")
         stop
     }

     # All other logs go by HOST/PROGRAM structure
     $template NASLogs,"/mnt/cloud/logs/%HOSTNAME%/%PROGRAMNAME%.log"
     *.* ?NASLogs
     ```
   - Save and exit.

6. **Set Up Log Rotation**:
   - Create a `logrotate` configuration to manage NAS logs:
     ```bash
     sudo nano /etc/logrotate.d/nas_logs
     ```
   - Add the following to rotate logs daily, keep 14 days of logs, compress old logs, and skip empty files:
     ```
     /mnt/cloud/logs/*/*.log {
         daily
         rotate 14
         compress
         missingok
         notifempty
         dateext
         delaycompress
         create 0640 root adm
     }
     ```
   - Edit the correct system crontab 
    ```
    nano /etc/crontabs/root
    ```
   - add this at the bottom
   ```
   0 3 * * * /usr/sbin/logrotate /etc/logrotate.conf
   ```
   - and run
   ```
   /etc/init.d/cron enable
   /etc/init.d/cron start
   ```
   
   - Logs will rotate daily, with older logs compressed (e.g., `syslog-20250426.gz`).
7. **Restart Rsyslog**:
   - Enable and restart the `rsyslog` service:
     ```bash
     /etc/init.d/rsyslog enable
     /etc/init.d/rsyslog restart
     ```
8. **Test Log Writing**:
   - test with 
     ```
     logger -t mytestprogram "This is a test from mytestprogram"
     ```
   - Verify logs are being written to the NAS:
     ```bash
     ls /mnt/cloud/logs/openwrt/
     ```
   - Check AP logs:
     ```bash
     tail -f /mnt/cloud/logs/AP/syslog.log
     ```
   - You should see logs from OpenWRT (e.g., `/mnt/cloud/logs/openwrt/syslog.log`) and the AP.

## Part 3: Verify Logging from All Sources

1. **PC Logs**:
   - On your PC, confirm logs are being written:
     ```bash
     tail -f /mnt/cloud/logs/$(hostname)/*.log
     ```
   - You should see system logs from your PC.
2. **OpenWRT Logs**:
   - On OpenWRT, confirm logs are being written:
     ```bash
     tail -f /mnt/cloud/logs/openwrt/*.log
     ```
   - You should see logs from OpenWRT itself.
3. **AP Logs**:
   - Confirm the AP is sending logs to OpenWRT (as configured in [access-point-setup.md](access-point-setup.md)):
     ```bash
     tail -f /mnt/cloud/logs/AP/syslog.log
     ```
   - If no logs appear, ensure the AP is configured to forward logs to `192.168.2.1:514` (see [access-point-setup.md](access-point-setup.md)).

## Troubleshooting

- **NAS Not Mounted**:
  - Verify the NAS is mounted on both the PC and OpenWRT:
    ```bash
    df -h | grep /mnt/cloud
    ```
  - If not mounted on OpenWRT, check the mount script logs:
    ```bash
    logread | grep "NAS mounted"
    ```
  - Remount manually if needed:
    ```bash
    mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,vers=3.0
    ```
- **No Logs from PC**:
  - Ensure `rsyslog` is running:
    ```bash
    sudo systemctl status rsyslog
    ```
  - Check for errors in the `rsyslog` configuration:
    ```bash
    sudo rsyslogd -N1
    ```
- **No Logs from OpenWRT**:
  - Verify `rsyslog` is running:
    ```bash
    /etc/init.d/rsyslog status
    ```
  - Check OpenWRT logs for errors:
    ```bash
    logread | grep rsyslog
    ```
- **No Logs from AP**:
  - Ensure the AP is configured to send logs to `192.168.2.1:514` (see [access-point-setup.md](access-point-setup.md)).
  - Verify the firewall rule allows UDP port 514 traffic from `192.168.2.254` (see [nas-setup.md](nas-setup.md)).
  - Test connectivity from the AP to OpenWRT:
    ```bash
    ping 192.168.2.1
    ```
- **Log Rotation Not Working**:
  - Test the `logrotate` configuration:
    ```bash
    sudo logrotate -f /etc/logrotate.d/nas_logs
    ```
  - Check for errors in `/var/log/logrotate.log` on your PC.

## Notes

- **Log Structure**:
  - Logs are organized as `/mnt/cloud/logs/HOSTNAME/PROGRAMNAME.log` for the PC and OpenWRT.
  - AP logs are stored separately in `/mnt/cloud/logs/AP/syslog.log` for easier auditing.
- **Log Rotation**:
  - Log rotation is currently set up only on the PC. For OpenWRT, consider installing `logrotate` (`opkg install logrotate`) and configuring a similar rotation policy if storage becomes an issue.
- **Security**:
  - The NAS is isolated from untrusted VLANs (Trust_wifi, IoT, Guest), ensuring logs are only accessible from the LAN (VLAN 20).
  - Logs on the PC are created with permissions `0640` (readable by `root` and `adm` group), ensuring restricted access.
- **Future Enhancements**:
  - Enable log forwarding from other devices on VLANs (e.g., Trusted WiFi, Infrastructure) by adding their IPs to the `rsyslog` configuration.
  - Integrate with a SIEM (e.g., Wazuh) to analyze logs stored on the NAS.

## Next Steps

- Set up `tcpdump` to capture traffic and save to `/mnt/cloud/tcpdumps/` [tcpdump-setup](tcpdump-setup.md)
- Explore SIEM integration by setting up Wazuh to ingest logs from `/mnt/cloud/logs/`.
- Add Suricata for intrusion detection and integrate its logs into the centralized logging system.