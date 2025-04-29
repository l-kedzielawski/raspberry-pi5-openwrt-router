# Guest Portal Setup with OpenNDS on OpenWRT

This guide details how to set up a captive portal (guest portal) for the Guest WiFi network (VLAN 50) on your Raspberry Pi 5 running OpenWRT 24.10.0. We’ll use `openNDS` (open Network Demarcation Service), a high-performance, small-footprint captive portal solution that’s actively maintained and optimized for OpenWRT. The portal will display a simple splash page with a Terms of Service (ToS) and a “Click to Continue” button, granting Internet access to guests without requiring login credentials. The portal will only apply to the Guest WiFi (VLAN 50), leaving other networks (LAN, Trusted WiFi, etc.) unaffected.

## Overview

- **Purpose**:
  - Set up a captive portal for the Guest WiFi (VLAN 50) to display a splash page with a ToS and a “Click to Continue” button.
  - Ensure the portal doesn’t affect other VLANs (e.g., LAN on VLAN 20, Trusted WiFi on VLAN 30).
  - Maintain access to the LuCI interface (`http://192.168.2.1`) and SSH from the LAN.
- **Tools**:
  - `openNDS`: The captive portal software, successor to `nodogsplash`, with modern features and better performance.
  - OpenWRT 24.10.0 on Raspberry Pi 5.
- **Network Setup**:
  - Guest WiFi: VLAN 50, interface `eth0.50`, subnet `192.168.50.0/24`.
  - LAN: VLAN 20, interface `eth0.20`, subnet `192.168.20.0/24` (for management).
  - OpenWRT router IP: `192.168.2.1` (LAN, VLAN 20).

## Prerequisites

- **Hardware**:
  - Raspberry Pi 5 running OpenWRT 24.10.0 (configured as per [openwrt-setup.md](openWRT-setup.md)).
  - TP-Link EAP610 Access Point (configured with Guest WiFi SSID on VLAN 50, as per [access_point-setup.md](access_point-setup.md)).
  - TP-Link TL-SG105E Switch (VLANs configured as per [switch-setup.md](switch-setup.md)).
- **Software**:
  - OpenWRT 24.10.0 with LuCI interface and SSH access.
  - Guest WiFi interface (`eth0.50`) already set up with DHCP (subnet `192.168.50.0/24`).
- **Network Setup**:
  - VLAN 50 (Guest WiFi): Interface `eth0.50`, IP range `192.168.50.2-192.168.50.254`, gateway `192.168.50.1`.
  - VLAN 20 (LAN): Interface `eth0.20`, IP range `192.168.20.2-192.168.20.254`, gateway `192.168.2.1`.
  - Firewall rules for VLAN 50: Internet access allowed, isolated from other VLANs (as per [openwrt-setup.md](openWRT-setup.md)).

## Step 1: Install OpenNDS and set firewall rules

1. **Log into OpenWRT**:
   - SSH into your OpenWRT router from a device on the LAN (VLAN 20):
     ```bash
     ssh root@192.168.2.1
     ```
2. **Install OpenNDS**:
    - Install the `openNDS` package:
     ```bash
     opkg update
     opkg install opennds
     ```
3. **Firewall rules**
    - general
    ```
    config zone
        option name 'guest'
        option input 'REJECT'
        option output 'ACCEPT'
        option forward 'REJECT'
        list network 'guest'

    config forwarding
        option src 'guest'
        option dest 'wan'
    ```

    - we need these rules in traffic rules
    ```
    # Allow DHCP from guest zone to router
    config rule
        option name 'Allow-Guest-DHCP'
        option src 'guest'
        option dest_port '67'
        option proto 'udp'
        option target 'ACCEPT'

    # Allow DNS from guest zone to router
    config rule
        option name 'Allow-Guest-DNS'
        option src 'guest'
        option dest_port '53'
        option proto 'udp'
        option target 'ACCEPT'

    # Allow HTTP/HTTPS for openNDS captive portal
    config rule
        option name 'Allow-Guest-openNDS'
        option src 'guest'
        option dest_port '2050 80 443'
        option proto 'tcp'
        option target 'ACCEPT'
    ```

    

## Step 2: Configure OpenNDS for Guest WiFi (VLAN 50)

1. **Edit the OpenNDS Configuration File**:
   - Open the `openNDS` configuration file for editing:
     ```bash
     nano /etc/config/opennds
     ```
   - Replace the default contents with the following configuration, tailored for your Guest WiFi:
     ```
     config opennds
         option enabled '1'
         option gatewayinterface 'eth0.50'
         option gatewayname 'Guest WiFi Portal'
         option gatewayaddress '192.168.50.1'
         option maxclients '50'
         option sessiontimeout '7200'
         option themespec 'theme_click-to-continue-basic'
         option unescape '1'
         option fas_secure_enabled '0'
         option walledgarden_fqdn_list 'google.com facebook.com fbcdn.net'
         option walledgarden_port_list '80 443'
     ```
   - **Explanation**:
     - `enabled '1'`: Enables `openNDS`.
     - `gatewayinterface 'eth0.50'`: Binds `openNDS` to the Guest WiFi interface (VLAN 50). This ensures the portal only affects devices on VLAN 50.
     - `gatewayname 'Guest WiFi Portal'`: The name displayed on the splash page.
     - `gatewayaddress '192.168.50.1'`: The IP address of the Guest WiFi interface.
     - `maxclients '50'`: Limits the number of simultaneous clients to 50, suitable for your setup.
     - `sessiontimeout '7200'`: Sets a 2-hour session timeout (in seconds). After 1 hour, users must re-authenticate via the portal.
     - `themespec 'theme_click-to-continue-basic'`: Uses the default “Click to Continue” theme with a ToS page.
     - `unescape '1'`: Ensures URLs are properly handled in the splash page.
     - `fas_secure_enabled '0'`: Disables Forwarding Authentication Service (FAS) security for simplicity, as we’re using a basic click-to-continue setup.
     - `walledgarden_fqdn_list`: Allows access to specific domains (e.g., Google, Facebook) before authentication, useful for Captive Portal Detection (CPD) on mobile devices.
     - `walledgarden_port_list`: Allows ports 80 and 443 for the walled garden domains.
   - Save the file (`Ctrl+O`, then `Enter`, then `Ctrl+X` to exit).

2. **Verify the Interface**:
   - Ensure the `eth0.50` interface exists and is correctly configured:
     ```bash
     ifconfig eth0.50
     ```
   - You should see the interface with the IP `192.168.50.1`. If it’s missing, double-check your network configuration in `/etc/config/network` (see [openwrt-setup.md](openwrt-setup.md)).

## Step 3: Customize the Splash Page

The default “Click to Continue” theme (`theme_click-to-continue-basic`) is a shell script that generates a splash page.  Customize it to include your ToS and branding.

1. **Locate the Theme Script**:
   - The theme script is typically located at `/usr/lib/opennds/theme_click-to-continue-basic.sh`. Copy it to a custom location to avoid overwriting during updates:
     ```bash
     cp /usr/lib/opennds/theme_click-to-continue-basic.sh /etc/opennds/custom_theme.sh
     ```
   - edit it however you like  

2. **Update the OpenNDS Configuration to Use the Custom Theme**:
   - Edit `/etc/config/opennds` again:
     ```bash
     nano /etc/config/opennds
     ```
   - Change the `themespec` option to point to your custom script:
     ```
     option themespec ''
     ```
   - Save and exit.

## Step 4: Enable and Start OpenNDS

1. **Enable OpenNDS**:
   - Ensure `openNDS` starts on boot:
     ```bash
     /etc/init.d/opennds enable
     ```
2. **Start OpenNDS**:
   - Start the `openNDS` service:
     ```bash
     /etc/init.d/opennds start
     ```
3. **Check the Status**:
   - Verify that `openNDS` is running:
     ```bash
     /etc/init.d/opennds status
     ```
   - You should see output indicating the service is active. If it’s not running, check the logs:
     ```bash
     logread | grep opennds
     ```

## Step 6: Test the Guest Portal

1. **Connect to the Guest WiFi**:
   - Connect a device (e.g., a phone or laptop) to the Guest WiFi SSID (VLAN 50).
   - The device should receive an IP in the `192.168.50.x` range (e.g., `192.168.50.10`).
2. **Trigger the Captive Portal**:
   - Open a browser and attempt to visit any website (e.g., `http://google.com`).
   - The device should be redirected to the `openNDS` splash page at `http://192.168.50.1:2050/`.
   - You should see your customized splash page with the ToS and a “Click to Continue” button.
3. **Accept the ToS**:
   - Click the “Accept and Continue” button.
   - The device should now have Internet access.
4. **Verify Client Status**:
   - On the OpenWRT router, check the list of connected clients:
     ```bash
     ndsctl status
     ```
   - You should see your device listed as authenticated, with details like IP, MAC, and session duration.
5. **Test Session Timeout**:
   - Wait for 1 hour (or reduce `sessiontimeout` to a smaller value like `300` seconds for testing).
   - After the timeout, attempt to access the Internet again. The splash page should reappear, requiring the user to click to continue again.

## Troubleshooting

- **Splash Page Doesn’t Appear**:
  - Ensure `openNDS` is running:
    ```bash
    /etc/init.d/opennds status
    ```
  - Check the `gatewayinterface` in `/etc/config/opennds`. It should be `eth0.50` for VLAN 50.
  - Verify the device is on VLAN 50:
    ```bash
    ip addr show eth0.50
    ```
  - Some devices may not trigger the portal automatically. Manually navigate to `http://192.168.50.1:2050/` to see the splash page.
  - Check logs for errors:
    ```bash
    logread | grep opennds
    ```
- **Cannot Access LuCI After Enabling OpenNDS**:
  - Ensure `openNDS` is only bound to `eth0.50`, not `eth0.20` (LAN). Double-check the `gatewayinterface` in `/etc/config/opennds`.
  - Verify firewall rules allow LuCI and SSH access from VLAN 20 (see Step 5).
  - If still inaccessible, temporarily stop `openNDS`:
    ```bash
    /etc/init.d/opennds stop
    ```
  - Access LuCI, then restart `openNDS`:
    ```bash
    /etc/init.d/opennds start
    ```
- **Internet Access Blocked After Authentication**:
  - Check firewall rules for VLAN 50. Ensure forwarding from `eth0.50` to WAN is allowed:
    ```bash
    cat /etc/config/firewall
    ```
  - Look for a rule like:
    ```
    config zone
        option name 'guest'
        option input 'REJECT'
        option output 'ACCEPT'
        option forward 'REJECT'
        list network 'guest'

    config forwarding
        option src 'guest'
        option dest 'wan'
    ```
  - If missing, add it via LuCI under **Network → Firewall → Zones**.
- **Custom Theme Not Displaying**:
  - Ensure the `themespec` path in `/etc/config/opennds` points to your custom script (`/etc/opennds/custom_theme.sh`).
  - Check the script permissions:
    ```bash
    chmod +x /etc/opennds/custom_theme.sh
    ```
  - Restart `openNDS`:
    ```bash
    /etc/init.d/opennds restart
    ```
- **Session Timeout Not Working**:
  - Verify the `sessiontimeout` value in `/etc/config/opennds`. It’s in seconds (e.g., `3600` = 1 hour).
  - Check the client status:
    ```bash
    ndsctl status
    ```
  - If the timeout isn’t enforced, ensure `openNDS` is checking timeouts regularly (default is every 15 seconds, controlled by `checkinterval` in the config).

## Notes

- **Security**:
  - The Guest WiFi (VLAN 50) is already isolated from other VLANs (e.g., LAN, NAS) via firewall rules, ensuring guests cannot access your internal network.
  - Using `fas_secure_enabled '0'` simplifies the setup but sends authentication tokens in clear text. For a production environment, consider enabling FAS security (e.g., `fas_secure_enabled '1'`) and setting up a secure FAS server.
- **Scalability**:
  - The `maxclients '50'` setting limits simultaneous users to 50, which is suitable for a small guest network. Increase this if needed, but monitor the Raspberry Pi 5’s performance.
