# NAS Setup for Seagate 4TB Storage

This guide details the configuration of a **Seagate 4TB NAS** on VLAN 60 to serve as a local storage hub and log collection backend for the Raspberry Pi 5 Secure Router project. The NAS will store logs from OpenWRT and all VLANs, act as a file server via SMB/NFS, and host personal cloud data (photos, documents, backups, etc.). It is isolated from IoT, Guest WiFi, and lab VLANs for security, with plans for future SIEM integration.

## Prerequisites

- **Hardware**:
  - Seagate 4TB NAS (connected to Port 5 of the TL-SG105E switch, VLAN 60 untagged).
  - TP-Link TL-SG105E switch (configured as per [switch-setup.md](switch-setup.md)).
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openwrt-setup.md)).
- **Software**:
  - Access to the Seagate NAS web interface.
  - OpenWRT LuCI interface or SSH access.
- **Network Setup**:
  - VLAN 60 is configured on OpenWRT (`eth0.60`, `192.168.60.1/24`) and the switch (Port 5, untagged).
  - The NAS interface (`nas`) and DHCP settings for VLAN 60 are set up (see [openwrt-setup.md](openwrt-setup.md)).

## Step 1: Configure Firewall Rules on OpenWRT

The NAS on VLAN 60 needs to be accessible from the LAN (VLAN 20) for management and file sharing but isolated from IoT (VLAN 40), Guest WiFi (VLAN 50), and other lab VLANs.

1. **Access Firewall Settings**:
   - Via LuCI: Go to **Network → Firewall**.
   - Via SSH: Edit `/etc/config/firewall` (`nano /etc/config/firewall`).
2. **Verify NAS Zone**:
   - Ensure the `nas` zone exists (created in [openwrt-setup.md](openwrt-setup.md)):
     ```
     config zone
             option name 'nas'
             option input 'ACCEPT'
             option output 'ACCEPT'
             option forward 'REJECT'
             list network 'nas'
     ```
   - Masquerading and MSS Clamping should be off (unchecked in LuCI).
   - “Allow forward to destination zones” should be empty.
3. **Update LAN Zone**:
   - In LuCI:
     - Go to **Network → Firewall → Zones**.
     - Click **Edit** for the `lan` zone.
     - Under “Allow forward to destination zones”, check `nas`.
   - Via SSH: Add or modify the forwarding rule in `/etc/config/firewall`:
     ```
     config forwarding
             option src 'lan'
             option dest 'nas'
     ```
4. **Add Traffic Rule for Router to AP**:
   - This rule ensures the router can communicate with the Access Point (AP), which is necessary for centralized logging (to be set up later in [rsyslog-setup.md](rsyslog-setup.md)).
   - In LuCI:
     - Go to **Network → Firewall → Traffic Rules**.
     - Add a new rule with the following:
       - **Name**: `Allow Router to AP`
       - **Protocol**: TCP and UDP (select both)
       - **Source Zone**: `Device (output)`
       - **Source Address**: Leave empty
       - **Source Port**: `any`
       - **Output Zone**: `lan`
       - **Destination Address**: `192.168.2.254` (EAP610 IP)
       - **Destination Port**: Leave as `any`
       - **Action**: `accept`
     - Save and apply.
   - Via SSH: Add the rule to `/etc/config/firewall`:
     ```
     config rule
             option name 'Allow-Router-to-AP'
             option src 'device'
             option dest 'lan'
             option proto 'tcp udp'
             option dest_ip '192.168.2.254'
             option target 'ACCEPT'
     ```
5. **Save and Apply**:
   - In LuCI: Click **Save & Apply**.
   - Via SSH: Restart the firewall service:
     ```bash
     /etc/init.d/firewall restart
     ```
   - The full `/etc/config/firewall` file is available in [configs/firewall](../configs/firewall).

## Step 2: Verify NAS IP and Set Static IP

The NAS should have received a DHCP IP from OpenWRT on VLAN 60 (`192.168.60.x` range).

1. **Check DHCP Leases**:
   - On OpenWRT, go to **Status → Overview → Active DHCP Leases** in LuCI (`http://192.168.2.1`).
   - Look for the Seagate NAS (e.g., hostname `Seagate-NAS` or MAC address). It should have an IP in the `192.168.60.100` to `192.168.60.249` range (e.g., `192.168.60.101`).
   - Alternatively, via SSH:
     ```bash
     ssh root@192.168.2.1
     cat /tmp/dhcp.leases | grep 192.168.60
     ```
   - Or perform an `nmap` scan:
     ```bash
     nmap -sn 192.168.60.0/24
     ```
2. **Access the NAS Web Interface**:
   - From a device on the LAN (VLAN 20), ensure you can reach VLAN 60 (firewall rules are now set up to allow this).
   - Temporarily add a route on your PC if needed:
     ```bash
     sudo ip route add 192.168.60.0/24 via 192.168.2.1 dev eth0
     ```
   - Open a browser and navigate to the NAS’s DHCP IP (e.g., `http://192.168.60.101`).
   - Log in to the NAS (default credentials may be `admin`/`admin`; check the device manual).
3. **Change Login Credentials**:
   - Since the NAS is a legacy device and sandboxed on VLAN 60, we will use the `192.168.60.100/Public` folder for mounting. However, it’s best practice to change the default username and password for security.
   - In the NAS web interface, go to **Settings → Users** (or similar, depending on the NAS model).
   - Update the admin username and password to something secure (e.g., a 12+ character password with letters, numbers, and symbols).
4. **Set Static IP**:
   - In the NAS web interface, go to **Network → Settings**.
   - Configure the following:
     - **IP Address**: `192.168.60.100` (static).
     - **Subnet Mask**: `255.255.255.0`.
     - **Gateway**: `192.168.60.1` (OpenWRT VLAN 60 interface).
     - **DNS**: `8.8.8.8` (Google DNS, though the NAS won’t access the internet).
   - Save and apply. The NAS will restart.
   - Access the NAS at its new static IP: `http://192.168.60.100`.

## Step 3: Configure Your PC to Mount the NAS

The NAS will be mounted on your PC for initial testing before setting up OpenWRT. We’ll use SMB (CIFS) to mount the `Public` share, which will later store `rsyslog` logs and `tcpdump` captures.

1. **Install CIFS Utilities**:
   - On your PC (Linux), install `cifs-utils` for SMB mounting:
     ```bash
     sudo apt update
     sudo apt install cifs-utils
     ```
2. **Create Mount Point**:
   - Create a directory on your PC to mount the NAS:
     ```bash
     sudo mkdir -p /mnt/cloud
     ```
3. **Test the Mount**:
   - Test mounting the NAS `Public` share as a guest:
     ```bash
     sudo mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,uid=1000,gid=1000,vers=3.0
     ```
   - If successful, you should see the contents of the `Public` share:
     ```bash
     ls /mnt/cloud
     ```
   - Unmount after testing:
     ```bash
     sudo umount /mnt/cloud
     ```
4. **Set Up Automount**:
   - Edit `/etc/fstab` on your PC to automount the NAS on reboot:
     ```bash
     sudo nano /etc/fstab
     ```
   - Add the following line:
     ```
     //192.168.60.100/Public /mnt/cloud cifs guest,uid=1000,gid=1000,vers=3.0,nounix,noserverino 0 0
     ```
5. **Verify Automount**:
   - Test the `fstab` entry:
     ```bash
     sudo mount -a
     ```
   - Check if the mount is active:
     ```bash
     df -h | grep /mnt/cloud
     ```
   - Reboot your PC and verify the mount:
     ```bash
     ls /mnt/cloud
     ```
6. **Create Folders**:
   - Create folders for logs and `tcpdump` captures; these will be used later:
     ```bash
     sudo mkdir -p /mnt/cloud/logs
     sudo mkdir -p /mnt/cloud/tcpdumps
     ```

## Step 4: Configure OpenWRT to Mount the NAS

The NAS will be mounted on OpenWRT at `/mnt/cloud` for centralized log storage and file sharing. We’ll use SMB (CIFS) to mount the `Public` share.

1. **Install CIFS Utilities**:
   - On OpenWRT, install `kmod-fs-cifs` for SMB mounting:
     ```bash
     opkg update
     opkg install kmod-fs-cifs
     ```
2. **Create Mount Point**:
   - Create a directory on OpenWRT to mount the NAS:
     ```bash
     mkdir -p /mnt/cloud
     ```
3. **Test the Mount**:
   - Test mounting the NAS `Public` share:
     ```bash
     mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,uid=1000,gid=1000,vers=3.0
     ```
   - If successful, you should see the contents of the `Public` share:
     ```bash
     ls /mnt/cloud
     ```
   - Unmount after testing:
     ```bash
     umount /mnt/cloud
     ```
4. **Set Up Script for Automount**:
   - Create a script to mount the NAS with a 10-second delay after reboot to ensure network availability.
   - Create the script:
     ```bash
     nano /etc/init.d/mount_cloud
     ```
   - Add the following:
     ```
     #!/bin/sh /etc/rc.common
     START=99
     STOP=10

     NAS_IP="192.168.60.100"
     SHARE="//192.168.60.100/Public"
     MOUNT_POINT="/mnt/cloud"

     start() {
         logger "Waiting 10 seconds for system startup..."
         sleep 10

         logger "Checking if NAS is reachable..."

         # Try to ping NAS up to 30 times (about 60 seconds max wait)
         try=0
         while ! ping -c1 -W1 "$NAS_IP" >/dev/null 2>&1; do
             try=$((try+1))
             logger "NAS not reachable yet (try $try)..."
             if [ "$try" -ge 30 ]; then
                 logger "NAS still unreachable after 30 tries, giving up."
                 return 1
             fi
             sleep 2
         done

         logger "NAS is reachable, proceeding to mount."

         # Make sure mount point exists
         mkdir -p "$MOUNT_POINT"

         # Only mount if not already mounted
         if ! mountpoint -q "$MOUNT_POINT"; then
             mount -t cifs "$SHARE" "$MOUNT_POINT" -o guest,uid=1000,gid=1000,vers=3.0,nounix,noserverino
             if [ $? -eq 0 ]; then
                 logger "Seagate NAS mounted successfully!"
             else
                 logger "Failed to mount Seagate NAS!"
             fi
         else
             logger "Mount point $MOUNT_POINT already mounted."
         fi
     }

     stop() {
         # Optional: unmount when stopping the service
         if mountpoint -q "$MOUNT_POINT"; then
             umount "$MOUNT_POINT"
             logger "Unmounted $MOUNT_POINT on service stop."
         fi
     }
     ```
5. **Test and Enable the Script**:
   - Set the correct permissions, enable, and restart the script:
     ```bash
     chmod +x /etc/init.d/mount_cloud
     /etc/init.d/mount_cloud enable
     /etc/init.d/mount_cloud restart
     ```
   - Reboot OpenWRT to test; you should not encounter any errors:
     ```bash
     reboot
     ```
6. **Verify Automount**:
   - Check the script contents:
     ```bash
     cat /etc/init.d/mount_cloud
     ```
   - Verify the mount is active:
     ```bash
     df -h | grep /mnt/cloud
     ```
   - After reboot, confirm the mount:
     ```bash
     ls /mnt/cloud
     ```
7. **Create Folders**:
   - Create folders for logs and `tcpdump` captures on OpenWRT:
     ```bash
     mkdir -p /mnt/cloud/logs
     mkdir -p /mnt/cloud/tcpdumps
     ```

## Step 5: Verify Access and Isolation

1. **Access from LAN (VLAN 20)**:
   - From a device on the LAN (e.g., your PC on `192.168.2.x`), access the NAS:
     - Via browser: `http://192.168.60.100`.
     - Via SMB: On Windows, map a network drive to `\\192.168.60.100\Public`. On Linux/macOS, mount it using:
       ```bash
       sudo mount -t cifs //192.168.60.100/Public /mnt/nas -o guest,vers=3.0
       ```
   - Verify you can read/write files to the `Public` share.
2. **Test Isolation**:
   - From a device on IoT WiFi (VLAN 40) or Guest WiFi (VLAN 50), attempt to access the NAS (`http://192.168.60.100` or `ping 192.168.60.100`).
   - Access should fail due to firewall rules (no forwarding from `iot` or `guest` to `nas`).
3. **Test File Server Functionality**:
   - Upload sample files (e.g., photos, documents, ISOs, backups) to the `Public` share.
   - Confirm access from the LAN but not from other VLANs.

## Troubleshooting

- **NAS Not Receiving DHCP IP**:
  - Verify VLAN 60 is correctly configured on the switch (Port 5, untagged) and OpenWRT (`eth0.60`).
  - Check DHCP settings for the `nas` interface in `/etc/config/dhcp` (see [configs/dhcp](../configs/dhcp)).
  - Use `arp-scan` on VLAN 60:
    ```bash
    ssh root@192.168.2.1 arp-scan -I eth0.60 192.168.60.0/24
    ```
- **Cannot Access NAS from LAN**:
  - Ensure the `lan` → `nas` forwarding rule is set in the firewall.
  - Verify your PC can route to `192.168.60.0/24` via `192.168.2.1`.
  - Check that the NAS IP is correctly set to `192.168.60.100`.
- **Mount Fails**:
  - Confirm the NAS `Public` share allows guest access.
  - Test with a manual mount:
    ```bash
    mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,vers=3.0
    ```
  - If the NAS doesn’t support SMB 3.0, try `vers=2.1` (less secure) or update the NAS firmware.
  - Check OpenWRT logs for errors:
    ```bash
    logread | grep cifs
    ```
- **Isolation Not Working**:
  - Verify firewall rules: IoT and Guest zones should not have forwarding to `nas`.
  - Test with `ping` or `curl` from IoT/Guest devices to `192.168.60.100`.

## Notes

- **NAS Role**:
  - The NAS on VLAN 60 serves as a local storage hub for logs, file sharing (SMB/NFS), and personal cloud data (photos, documents, ISOs, backups, malware samples, lab data).
  - It is isolated from IoT (VLAN 40), Guest WiFi (VLAN 50), and lab VLANs for security.
- **Legacy Device**:
  - The NAS is a legacy device and kept offline (no internet access) to reduce security risks.
  - SMB version 3.0 is used for compatibility. If you encounter issues, consider downgrading to `vers=2.1` (less secure) or upgrading to a newer device supporting SMB 3.0 for better security.
- **SIEM Integration**:
  - Future integration with a SIEM (e.g., Wazuh, Splunk) can be achieved by analyzing logs stored on the NAS.
  - Logs will be forwarded via `rsyslog`, and `tcpdump` captures will be saved to `/mnt/cloud` (to be configured later).
- **Security**:
  - Firewall rules ensure the NAS is only accessible from the LAN, protecting it from untrusted VLANs.
  - Changing the default NAS credentials enhances security, especially for a legacy device.

## Next Steps

- Configure `rsyslog` on OpenWRT to forward logs to `/mnt/cloud/logs/` (see [rsyslog-setup.md](rsyslog-setup.md)).
- Set up `tcpdump` to capture traffic and save to `/mnt/cloud/tcpdumps/` (to be covered in a separate guide).
- Explore SIEM integration by setting up Wazuh to ingest logs from the NAS.
- Add Suricata for intrusion detection and integrate its logs into the centralized logging system.