# Access Point Setup for TP-Link EAP610

This guide details the configuration of the **TP-Link EAP610 AX1800 WiFi 6 Access Point** to create multiple isolated Wi-Fi networks with VLAN tagging per SSID. The access point integrates with OpenWRT on the Raspberry Pi 5, providing secure, segmented wireless networks for Trusted WiFi, IoT WiFi, and Guest WiFi, while maintaining LAN-side management. The setup includes firewall rules, client isolation, bandwidth limits where applicable, logging forwarding to OpenWRT, and time synchronization settings.

## Prerequisites
- **Hardware**:
  - TP-Link EAP610 Access Point.
  - TP-Link TL-SG105E switch (configured as per [switch-setup.md](switch-setup.md)).
  - Raspberry Pi 5 running OpenWRT (configured as per [openWRT-setup.md](openWRT-setup.md)).
  - Ethernet cables (CAT6a SFTP).
- **Software**:
  - Access to the TP-Link EAP610 web interface.
  - A PC for initial configuration (with `arp-scan` installed for troubleshooting).
- **Network Setup**:
  - Ensure the switch is connected and VLANs are configured (Port 4 handles VLANs 20, 30, 40, 50, 70, tagged).
  - OpenWRT interfaces and firewall rules are set up for VLANs 20 (LAN), 30 (Trusted WiFi), 40 (IoT WiFi), 50 (Guest WiFi), and 70 (Infrastructure).

## Step 1: Connect and Access the EAP610
1. **Connect the Access Point**:
   - Plug the TP-Link EAP610 into Port 4 of the TL-SG105E switch. Port 4 is configured to handle tagged VLANs 20, 30, 40, 50, and 70.
   - Power on the EAP610 (via PoE or a power adapter).
2. **Check DHCP Leases**:
   - On OpenWRT, go to **Status → Overview → Active DHCP Leases** in LuCI (`http://192.168.2.1`) to see if the EAP610 has received an IP.
   - The EAP610 should appear with an IP in the `192.168.2.x` range (e.g., `192.168.2.254` after configuration).
3. **Troubleshoot Connectivity**:
   - If the EAP610 does not appear in DHCP leases:
     - Connect the EAP610 directly to your PC via an Ethernet cable.
     - Set your PC’s IP to the `192.168.0.x` subnet:
       ```bash
       sudo ip addr add 192.168.0.10/24 dev eth0
       ```
     - Scan for the EAP610’s default IP (typically `192.168.0.254`):
       ```bash
       sudo arp-scan -I eth0 192.168.0.1/24
       ```
     - You should see the EAP610 at `192.168.0.254`.
4. **Log In to the EAP610**:
   - Open a browser and navigate to `http://192.168.0.254` (or the IP found via `arp-scan`).
   - Log in with the default credentials (username: `admin`, password: `admin`).
   - You’ll be prompted to set a new password. Choose a strong password and save it securely.

## Step 2: Configure General Settings
1. **Set Static IP**:
   - Navigate to **Settings → Network** in the EAP610 web interface.
   - Configure the following:
     - **IP Address**: `192.168.2.254` (static, on VLAN 20 for LAN management).
     - **Gateway**: `192.168.2.1` (OpenWRT router).
     - **DNS**: `8.8.8.8` (Google DNS).
   - Save and apply. The EAP610 will restart, and you’ll need to access it at `https://192.168.2.254`.
2. **Secure Management Access**:
   - Navigate to **Settings → System → Access Control**.
   - **Disable HTTP**: Uncheck the HTTP option to disable port 80 access.
   - **Enable HTTPS**: Ensure HTTPS (port 443) is enabled.
   - **Disable Layer 3 Access**: If you don’t need remote management, disable Layer 3 access to restrict management to the LAN (VLAN 20).
   - Save and apply.

## Step 3: Configure SSIDs with VLAN Tagging
The EAP610 will create three Wi-Fi networks, each tagged with a specific VLAN ID to match the OpenWRT configuration.

1. **Trusted WiFi (trust_wifi)**:
   - Navigate to **Wireless → SSIDs → Add SSID**.
   - Configure the following:
     - **SSID Name**: `trust_wifi`
     - **Band**: 5GHz
     - **VLAN ID**: `30`
     - **Security**: WPA2/WPA3-Personal, AES encryption
     - **Password**: Set a strong password (e.g., 12+ characters, mix of letters, numbers, symbols).
     - **Wireless Mode**: 802.11a/n/ac/ax mixed
     - **Tx Power**: Max dBm (adjust based on your environment to avoid interference).
     - **Client Isolation**: Off (uncheck “Guest Network” toggle)
     - **PMF (Protected Management Frames)**: Optional
   - Save and apply.

2. **IoT WiFi (iot_wifi)**:
   - Navigate to **Wireless → SSIDs → Add SSID**.
   - Configure the following:
     - **SSID Name**: `iot_wifi`
     - **Band**: 2.4GHz
     - **VLAN ID**: `40`
     - **Security**: WPA2-Personal, AES encryption
     - **Password**: Set a strong password compatible with IoT devices.
     - **Wireless Mode**: 802.11b/g/n mixed
     - **Tx Power**: Max dBm
     - **Client Isolation**: On (check “Guest Network” toggle to enable isolation)
     - **PMF**: Off (for compatibility with older IoT devices)
   - Save and apply.

3. **Guest WiFi (guest_wifi)**:
   - Navigate to **Wireless → SSIDs → Add SSID**.
   - Configure the following:
     - **SSID Name**: `guest_wifi`
     - **Band**: 5GHz
     - **VLAN ID**: `50`
     - **Security**: None (a captive portal will be set up using Nodogsplash on OpenWRT)
     - **Bandwidth Limits** (optional):
       - **Download Limit**: 50 Mbps
       - **Upload Limit**: 20 Mbps
     - **Client Isolation**: On (check “Guest Network” toggle)
     - **PMF**: Off
   - Save and apply.
   - **Note**: The Guest WiFi is on VLAN 50 but managed via the LAN subnet (`192.168.2.x`) to keep the AP on our 2 subnet not on our guest vlan. We will set up portal on OpenWRT for the guest access.

## Step 4: Enable Logging Forwarding to OpenWRT
To centralize logging, configure the EAP610 to forward its system logs to the OpenWRT router, which can then store or forward them to the NAS (as configured in [configs/rsyslog.conf](../configs/rsyslog.conf)).

1. **Access Logging Settings**:
   - Navigate to **Management → System Log** in the EAP610 web interface.
2. **Configure Log Forwarding**:
   - **System Log Server IP**: `192.168.2.1` (OpenWRT router).
   - **System Log Server Port**: `514` (default syslog port).
   - **More Client Detail Log**: Enable this option to include detailed client information in the logs (useful for troubleshooting connectivity or monitoring client activity).
3. **Save and Apply**:
   - Save the settings. The EAP610 will now forward logs to OpenWRT.
   - On OpenWRT, verify logs are being received:
     - Check `/mnt/cloud/AP/syslog.log` (as configured in [rsyslog-setup](rsyslog-setup.md)).
     - Alternatively, use `logread` on OpenWRT to view incoming logs:
       ```bash
       ssh root@192.168.2.1 logread | grep 192.168.2.254
       ```
     - check NAS storage set up for more info on logs collection.   

## Step 5: Configure Time Settings
Accurate time settings are crucial for logging, security certificates, and network synchronization.

1. **Access Time Settings**:
   - Navigate to **System → Time Settings** in the EAP610 web interface.
2. **Set Up Time Synchronization**:
   - **Time Source**: Select NTP (Network Time Protocol) for automatic synchronization.
   - **NTP Server**: Use a reliable server, e.g., `pool.ntp.org` or `time.google.com`.
   - **Time Zone**: Set your local time zone (e.g., `UTC+1` for Central European Time, adjust for Daylight Saving Time if applicable).
   - **Enable NTP**: Ensure NTP is enabled to keep the time synchronized.
3. **Save and Apply**:
   - Save the settings. The EAP610 will sync its clock with the NTP server.
   - Verify the current time in the EAP610 interface under **System → Time Settings**.

## Step 6: Reboot the Access Point
To ensure all changes take effect, reboot the EAP610.

1. **Access Reboot Settings**:
   - Navigate to **System → Reboot/Reset**.
2. **Reboot the Device**:
   - Click **Reboot** to restart the EAP610.
   - Wait for the device to fully reboot (typically 1-2 minutes).
   - After reboot, reconnect to the EAP610 at `https://192.168.2.254` and verify all settings (SSIDs, logging, time) are correctly applied.

## Step 7: Verify SSID Configuration
- After rebooting, the EAP610 will broadcast the three SSIDs:
  - `trust_wifi` (5GHz, VLAN 30, secure, no isolation).
  - `iot_wifi` (2.4GHz, VLAN 40, secure, isolated).
  - `guest_wifi` (5GHz, VLAN 50, open with bandwidth limits, isolated).
- Connect a device (e.g., phone or laptop) to each SSID:
  - For `trust_wifi` and `iot_wifi`, use the respective passwords.
  - For `guest_wifi`, you should connect without a password (openWRT portal setup will be added later).
- Check the IP address on each device:
  - `trust_wifi`: Should get an IP in `192.168.30.x` (e.g., `192.168.30.100`).
  - `iot_wifi`: Should get an IP in `192.168.40.x` (e.g., `192.168.40.100`).
  - `guest_wifi`: Should get an IP in `192.168.50.x` (e.g., `192.168.50.100`).
- In OpenWRT LuCI, go to **Status → Overview → Active DHCP Leases** to confirm devices are receiving IPs on the correct VLANs.

## Step 8: Test Network Isolation and Connectivity
1. **Test Trusted WiFi (VLAN 30)**:
   - Connect to `trust_wifi`.
   - Verify internet access (`ping 8.8.8.8`, `ping google.com`).
   - Confirm you can access the OpenWRT router (`http://192.168.2.1`) and other LAN devices (`ping 192.168.2.254` for the EAP610).
   - Client isolation is off, so devices on this SSID should be able to communicate with each other.
2. **Test IoT WiFi (VLAN 40)**:
   - Connect to `iot_wifi`.
   - Verify internet access (`ping 8.8.8.8`, `ping google.com`).
   - Confirm you cannot access the OpenWRT router (`http://192.168.2.1`) or other VLANs due to firewall rules (see [openWRT-setup.md](openWRT-setup.md)).
   - Client isolation is on, so IoT devices should not communicate with each other.
3. **Test Guest WiFi (VLAN 50)**:
   - Connect to `guest_wifi`.
   - Verify internet access (once Nodogsplash is configured).
   - Confirm bandwidth limits (download 50 Mbps, upload 20 Mbps) using a speed test.
   - Confirm you cannot access the OpenWRT router or other VLANs.
   - Client isolation is on, so guest devices should be isolated from each other.

## Troubleshooting
- **EAP610 Not Visible in DHCP Leases**:
  - Ensure the switch is configured correctly (Port 4 should tag VLANs 20, 30, 40, 50, 70).
  - Connect the EAP610 directly to your PC, set your IP to `192.168.0.10/24`, and scan for the device:
    ```bash
    sudo arp-scan -I eth0 192.168.0.1/24
    ```
  - Access the EAP610 at `192.168.0.254` and set the static IP to `192.168.2.254`.
- **Devices Not Receiving IPs**:
  - Verify OpenWRT DHCP settings for each VLAN (`trust_wifi`, `iot_wifi`, `guest_wifi`) are enabled (see [configs/dhcp](../configs/dhcp)).
  - Check firewall rules for IoT WiFi (VLAN 40) to ensure DHCP and DNS traffic is allowed (see [openWRT-setup.md](openWRT-setup.md)).
- **No Internet Access on SSIDs**:
  - Confirm OpenWRT firewall forwarding rules (`trust_wifi` → `wan`, `iot` → `wan`, `guest` → `wan`) are set (see [configs/firewall](../configs/firewall)).
  - Verify VLAN tagging on the switch and EAP610 matches OpenWRT VLAN IDs.
- **Cannot Access EAP610 After IP Change**:
  - Use `arp-scan` on the `192.168.2.x` subnet to find the EAP610:
    ```bash
    sudo arp-scan -I eth0 192.168.2.0/24
    ```
  - Ensure your PC is on the `192.168.2.x` subnet and VLAN 20.
  - Access the EAP610 at `https://192.168.2.254`.
- **Logs Not Forwarding to OpenWRT**:
  - Verify the OpenWRT router (`192.168.2.1`) is reachable from the EAP610 (`ping 192.168.2.1` from a device on VLAN 20).
  - Ensure OpenWRT’s syslog service is running and configured to accept logs on port 514 (see [rsyslog-setup](rsyslog-setup.md)).
  - Check firewall rules on OpenWRT to allow UDP port 514 traffic from `192.168.2.254`.
- **Time Not Synchronizing**:
  - Ensure the EAP610 has internet access to reach the NTP server.
  - Verify the NTP server (`pool.ntp.org` or `time.google.com`) is reachable (`ping pool.ntp.org` from a device on VLAN 20).
  - Check the time zone setting and adjust if necessary.

## Notes
- **Management Security**:
  - Disabling HTTP and enabling HTTPS ensures secure management access.
  - Disabling Layer 3 Access restricts management to the LAN (VLAN 20), reducing exposure.
- **VLAN Tagging**:
  - The EAP610 tags each SSID with the appropriate VLAN ID, which matches the OpenWRT interfaces (`eth0.30`, `eth0.40`, `eth0.50`).
  - The switch (Port 4) must tag these VLANs to forward traffic to OpenWRT (Port 2).
- **Client Isolation**:
  - Enabled for `iot_wifi` and `guest_wifi` to prevent devices from communicating with each other, enhancing security.
  - Disabled for `trust_wifi` to allow trusted devices to communicate (e.g., for file sharing or casting).
- **Guest WiFi Setup**:
  - The `guest_wifi` SSID has no security, as a captive portal will be implemented using Nodogsplash on OpenWRT. This keeps the AP on the LAN subnet (`192.168.2.x`) for management while isolating guest traffic on VLAN 50.
- **Bandwidth Limits**:
  - The 50 Mbps download and 20 Mbps upload limits on `guest_wifi` are optional and can be adjusted based on your needs. Test with a speed test tool to confirm.
- **Logging**:
  - Logs are forwarded to OpenWRT at `192.168.2.1:514`, where they are processed by `rsyslog` and stored on the NAS.
  - The “More Client Detail Log” option provides additional visibility into client activity, useful for monitoring and troubleshooting.
- **Time Settings**:
  - NTP synchronization ensures accurate timestamps for logs and security operations.
  - A reboot after configuration ensures all settings are applied correctly.

## Next Steps
- Set up portal on OpenWRT for the Guest WiFi captive portal [portal-setup](portal-setup.md).
- Configure additional SSIDs for Infrastructure services (e.g., Pi-hole, Home Assistant) on VLAN 70 if needed.
- Verify logs on the NAS (`/mnt/cloud/AP/syslog.log`) and analyze them for any issues. [rsyslog-setup](rsyslog-setup.md).

