# Adblock Setup for Network-Wide Ad Blocking

This guide details the setup of Adblock on OpenWRT to block ads and trackers across your entire network. By configuring Adblock on your Raspberry Pi 5 router, you can enhance privacy and reduce unwanted traffic for all devices on your network, including those on VLANs like LAN (VLAN 20), Trusted WiFi (VLAN 30), and others. We’ll use specific blocklist sources to target ads, trackers, and malware, and verify the setup to ensure it’s working correctly.

## Overview

- **Purpose**:
  - Block ads, trackers, and malicious domains network-wide using Adblock on OpenWRT.
  - Configure blocklist sources to balance coverage and performance.
  - Verify the setup to ensure ads are blocked across all devices.
- **Scope**:
  - Applies to all devices on your network, including those on VLAN 20 (LAN), VLAN 30 (Trusted WiFi), etc.
  - Uses a combination of blocklists for comprehensive ad and malware protection.

## Prerequisites

- **Hardware**:
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openWRT-setup.md)).
- **Software**:
  - OpenWRT LuCI interface and SSH access.
  - Adblock and its LuCI app installed on OpenWRT.
- **Network Setup**:
  - OpenWRT router IP: `192.168.2.1` (LAN, VLAN 20).
  - DNS resolution configured (Adblock will intercept DNS queries to block domains).

## Step 1: Install Adblock on OpenWRT

1. **Log into OpenWRT**:
   - SSH into your OpenWRT router:
     ```bash
     ssh root@192.168.2.1
     ```
2. **Install Adblock Packages**:
   - Update the package list and install Adblock along with its LuCI app:
     ```bash
     opkg update
     opkg install adblock luci-app-adblock
     ```
3. **Verify Installation**:
   - Check that Adblock is installed:
     ```bash
     opkg list-installed | grep adblock
     ```
   - You should see `adblock` and `luci-app-adblock` in the output.

## Step 2: Configure Adblock via LuCI

1. **Access LuCI**:
   - Open a browser and navigate to `http://192.168.2.1`.
   - Log in to the LuCI interface 
2. **Enable Adblock Service**:
   - Go to **Services → Adblock**.
   - Check the box for **Enable Adblock** to activate the service.
3. **Select Blocklist Sources**:
   - In the **Blocklist Sources** section, enable the following sources:
     - **AdAway**: Enable (good for general ad blocking).
     - **StevenBlack Lists**: Set to **Standard** (comprehensive ad and tracker blocking).
     - **Disconnect**: Enable (focuses on trackers and privacy-invasive domains).
     - **UTCapitole Archive**: Set to **Malware** (targets known malware domains).
     - **Hagezi List Selection**: Set to **Multi-Normal** (balanced ad, tracker, and privacy blocking).
     - **1Hosts List**: Set to **Lite** (lightweight ad blocking for performance).
     - **Optional**: **Yoyo** (additional ad blocking, enable if desired for extra coverage).
   - **Note**: Avoid enabling too many blocklists to prevent performance issues on the Raspberry Pi 5. The selected lists provide a good balance of coverage and efficiency.
4. **Save and Apply**:
   - Click **Save & Apply** to download the blocklists and activate Adblock.
   - Wait a few moments for the blocklists to download and process (you can monitor the status in LuCI under the **Overview** tab of Adblock).

## Step 3: Reload and Verify Adblock Configuration

1. **Reload Adblock**:
   - From your SSH session, reload the Adblock service to ensure the blocklists are applied:
     ```bash
     /etc/init.d/adblock reload
     ```
2. **Check Logs**:
   - View the Adblock logs to confirm it’s working:
     ```bash
     logread -e adblock
     ```
   - Look for messages indicating that the blocklists were downloaded and applied successfully (e.g., “blocklist processing finished”).
3. **Check Adblock Status**:
   - Verify the status of the Adblock service:
     ```bash
     /etc/init.d/adblock status
     ```
   - You should see output indicating that Adblock is running, along with statistics like the number of blocked domains (e.g., “Status: running, Blocked Domains: 123456”).

## Step 4: Test Adblock Functionality

1. **Test on a Device**:
   - Connect a device (e.g., your phone or laptop) to your network (VLAN 20 or VLAN 30).
   - Open a browser and visit a website known for ads (e.g., a news site like `cnn.com`).
   - You should notice that ads are blocked, and placeholders or empty spaces may appear where ads would normally load.
2. **Test with a Known Ad Domain**:
   - Try resolving a known ad domain to confirm it’s blocked:
     ```bash
     nslookup doubleclick.net 192.168.2.1
     ```
   - If Adblock is working, the response should return `0.0.0.0` or fail to resolve, indicating the domain is blocked.
3. **Check Network-Wide Blocking**:
   - Test on devices across different VLANs (e.g., LAN on VLAN 20, Trusted WiFi on VLAN 30) to ensure Adblock applies to all network traffic.

## Troubleshooting

- **Adblock Not Starting**:
  - Check the Adblock status:
    ```bash
    /etc/init.d/adblock status
    ```
  - If not running, check the logs for errors:
    ```bash
    logread -e adblock
    ```
  - Ensure the service is enabled in LuCI (**Services → Adblock → Enable Adblock**).
- **Ads Still Loading**:
  - Confirm the device is using the router for DNS (e.g., `192.168.2.1`):
    ```bash
    nslookup google.com 192.168.2.1
    ```
  - If devices use a different DNS (e.g., `8.8.8.8`), configure a firewall rule to redirect DNS traffic to the router:
    ```bash
    nano /etc/config/firewall
    ```
    Add:
    ```
    config redirect
        option name 'Force-DNS'
        option src 'lan'
        option src_dport '53'
        option proto 'tcp udp'
        option dest_ip '192.168.2.1'
        option target 'DNAT'
    ```
    Restart the firewall:
    ```bash
    /etc/init.d/firewall restart
    ```
  - Retest ad blocking after forcing DNS.
- **Performance Issues**:
  - If the Raspberry Pi 5 slows down, reduce the number of blocklists (e.g., disable Yoyo or use lighter lists like 1Hosts Lite).
  - Check CPU and memory usage:
    ```bash
    top
    ```

## Notes

- **Coverage**:
  - The selected blocklists (AdAway, StevenBlack, Disconnect, UTCapitole Malware, Hagezi Multi-Normal, 1Hosts Lite) provide a balance of ad, tracker, and malware blocking without overloading the Raspberry Pi 5.
  - Optionally enabling Yoyo adds extra ad-blocking coverage but may increase resource usage.
- **Network-Wide**:
  - Adblock operates at the DNS level, intercepting and blocking requests for ad and tracker domains across all devices on your network, regardless of VLAN.
- **Privacy and Security**:
  - Blocking trackers and malware domains enhances privacy and protects devices from malicious content.
  - Forcing DNS traffic to the router ensures all devices benefit from Adblock, even if they attempt to use external DNS servers.
- **Performance**:
  - The Raspberry Pi 5 has limited resources, so avoid enabling too many blocklists. Monitor performance and adjust as needed.

## Next Steps

- Monitor Adblock logs periodically to ensure blocklists are updating:
  ```bash
  logread -e adblock
  ```
