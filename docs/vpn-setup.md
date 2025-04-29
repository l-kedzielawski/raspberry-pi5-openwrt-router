# WireGuard Setup for Secure Remote Access

This guide details the setup of WireGuard on OpenWRT to enable secure remote access to your network from anywhere. Using WireGuard, you can access your LuCI interface, SSH into devices on your LAN, and manage your network remotely. We’ll configure the OpenWRT router as the WireGuard server and an Android smartphone (e.g., Samsung Galaxy S24 Ultra) as the client.

## Overview

- **Purpose**:
  - Set up a WireGuard VPN server on OpenWRT to allow remote access to your network.
  - Configure an Android smartphone as a WireGuard client to connect to the VPN.
  - Enable access to the LuCI interface (`192.168.2.1`) and other LAN devices from anywhere.
- **Network Details**:
  - WireGuard interface: `wg0`.
  - WireGuard subnet: `10.10.10.0/24`.
  - Server address: `10.10.10.1` (OpenWRT router).
  - Client address: `10.10.10.2` (Android smartphone).

## Prerequisites

- **Hardware**:
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openWRT-setup.md)).
  - Android smartphone (e.g., Samsung Galaxy S24 Ultra) with the WireGuard app installed. You can use any phone or laptop
- **Software**:
  - WireGuard packages installed on OpenWRT.
  - Access to the OpenWRT LuCI interface or SSH.
- **Network Setup**:
  - OpenWRT router IP: `192.168.2.1` (LAN, VLAN 20).
  - A public IP address for the router (or a workaround if behind CGNAT).
  - Port forwarding for UDP port `51820` on your upstream router (if applicable).

## Step 1: Install WireGuard on OpenWRT

1. **Log into OpenWRT**:
   - SSH into your OpenWRT router:
     ```bash
     ssh root@192.168.2.1
     ```
2. **Install WireGuard Packages**:
   - Install the necessary WireGuard packages:
     ```bash
     opkg update
     opkg install wireguard-tools kmod-wireguard luci-proto-wireguard
     ```
3. **Verify Installation**:
   - Check that WireGuard is installed:
     ```bash
     wg --version
     ```

## Step 2: Generate Public and Private Keys

1. **Create Key Directory**:
   - Create a directory for WireGuard keys and set secure permissions:
     ```bash
     mkdir -p /etc/wireguard
     umask 077
     ```
2. **Generate Keys for the Router**:
   - Generate a private and public key pair for the OpenWRT router:
     ```bash
     wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
     ```
3. **Retrieve and Store Keys**:
   - Display the keys and store them securely (e.g., in Bitwarden):
     ```bash
     cat /etc/wireguard/privatekey
     cat /etc/wireguard/publickey
     ```
   - Save the output of both commands. For example:
     - Private key: `aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789ABCDEF=`
     - Public key: `xYzAbCdEfGhIjKlMnOpQrStUvWxY0123456789ABCDE=`

## Step 3: Configure WireGuard on OpenWRT

1. **Edit Network Configuration**:
   - Edit the `/etc/config/network` file to set up the WireGuard interface:
     ```bash
     nano /etc/config/network
     ```
   - Add the following configuration at the end of the file:
     ```
     config interface 'wg0'
         option proto 'wireguard'
         option private_key 'aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789ABCDEF='
         option listen_port '51820'
         list addresses '10.10.10.1/24'

     config wireguard_wg0
         option public_key 'pQrStUvWxY0123456789ABCDEfGhIjKlMnOpQrStUvW='
         option description 'ultra_s24'
         list allowed_ips '10.10.10.2/32'
     ```
   - Replace `aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789ABCDEF=` with the router’s private key (from `/etc/wireguard/privatekey`).
   - Replace `pQrStUvWxY0123456789ABCDEfGhIjKlMnOpQrStUvW=` with the phone’s public key (generated in Step 4).
   - Save and exit.
2. **Apply Changes**:
   - Restart the network service to apply the configuration:
     ```bash
     /etc/init.d/network restart
     ```

## Step 4: Configure WireGuard Client on Android Smartphone

1. **Install WireGuard App**:
   - Download and install the WireGuard app from the Google Play Store on your Android smartphone or laptop
2. **Generate Keys for the Phone**:
   - On your phone, open the WireGuard app.
   - Tap the “+” button and select “Create from scratch” to create a new tunnel.
   - The app will automatically generate a private and public key pair for the phone.
   - Note down the phone’s public key (you’ll need it for the OpenWRT configuration in Step 3). For example:
     - Phone public key: `pQrStUvWxY0123456789ABCDEfGhIjKlMnOpQrStUvW=`
     - Phone private key: `mNoPqRsTuVwXyZ0123456789ABCDEFaBcDeFgHiJkL=`
3. **Configure the Tunnel**:
   - In the WireGuard app, configure the tunnel with the following details:
     ```
     [Interface]
     PrivateKey = mNoPqRsTuVwXyZ0123456789ABCDEFaBcDeFgHiJkL=
     Address = 10.10.10.2/32
     DNS = 192.168.2.1

     [Peer]
     PublicKey = xYzAbCdEfGhIjKlMnOpQrStUvWxY0123456789ABCDE=
     Endpoint = <PUBLIC_IP>:51820
     AllowedIPs = 0.0.0.0/0
     PersistentKeepalive = 25
     ```
   - Replace `mNoPqRsTuVwXyZ0123456789ABCDEFaBcDeFgHiJkL=` with the phone’s private key (generated by the app).
   - Replace `xYzAbCdEfGhIjKlMnOpQrStUvWxY0123456789ABCDE=` with the router’s public key (from `/etc/wireguard/publickey`).
   - Replace `<PUBLIC_IP>` with your router’s public IP address (see Step 5 for how to find this).
   - Save the configuration.

## Step 5: Determine Your Public IP and Handle CGNAT

1. **Find Your Public IP**:
   - On OpenWRT, check your public IP using one of these methods:
     - Via LuCI: Go to **Status → Overview** and look for the “Upstream IPv4” address under the WAN interface.
     - Via SSH:
       ```bash
       curl ifconfig.me
       ```
   - Note the IP address (e.g., `203.0.113.1`).
2. **Check for CGNAT**:
   - If the IP shown in LuCI differs from the one returned by `curl ifconfig.me`, your router is likely behind Carrier-Grade NAT (CGNAT), meaning your ISP assigns a shared public IP.
   - To confirm, compare the IPs:
     ```bash
     curl ifconfig.me
     # Compare with LuCI WAN IP
     ```
   - If they differ, you’re behind CGNAT, and you won’t be able to directly connect to your router from outside your network.
3. **Resolve CGNAT (if applicable)**:
   - Contact your ISP and request a static public IP or ask them to remove CGNAT for your connection.
   - Alternatively, use a dynamic DNS service (e.g., DuckDNS) and a reverse proxy if you can’t get a public IP, though this is more complex and not covered here.
   - If you’re not behind CGNAT, proceed to the next step.

## Step 6: Configure Firewall and Port Forwarding

1. **Create Firewall Zone for WireGuard**:
   - Edit the firewall configuration:
     ```bash
     nano /etc/config/firewall
     ```
   - Add a new zone for `wg0`:
     ```
     config zone
         option name 'wg0'
         option input 'ACCEPT'
         option output 'ACCEPT'
         option forward 'REJECT'
         list network 'wg0'
     ```
   - Allow forwarding from `wg0` to `lan` (to access LAN devices):
     ```
     config forwarding
         option src 'wg0'
         option dest 'lan'
     ```
   - Allow forwarding from `lan` to `wg0` (for responses):
     ```
     config forwarding
         option src 'lan'
         option dest 'wg0'
     ```
   - Save and exit.
2. **Add Traffic Rule for WireGuard Port**:
   - Add a rule to allow incoming traffic on port `51820`:
     ```
     config rule
         option name 'Allow-WireGuard'
         option src 'wan'
         option dest_port '51820'
         option proto 'udp'
         option target 'ACCEPT'
     ```
   - Save and exit.
3. **Apply Firewall Changes**:
   - Restart the firewall service:
     ```bash
     /etc/init.d/firewall restart
     ```
4. **Port Forwarding on Upstream Router (if applicable)**:
   - If your OpenWRT router is behind another router (e.g., your ISP’s modem/router), log into that device.
   - Forward UDP port `51820` to your OpenWRT router’s WAN IP (check LuCI for the WAN IP, e.g., `192.168.1.x`).
   - Save the changes on the upstream router.

## Step 7: Test the VPN Connection

1. **Activate the Tunnel on Your Phone**:
   - In the WireGuard app on your Android phone, toggle the tunnel to “On”.
   - The app should show a connection to your router’s public IP on port `51820`.
2. **Test Access to LuCI**:
   - Open a browser on your phone and navigate to `http://192.168.2.1`.
   - You should be able to access the LuCI interface remotely.
3. **Test SSH Access**:
   - From your phone, use an SSH app (e.g., Termux or JuiceSSH) to connect to the router:
     ```bash
     ssh root@192.168.2.1
     ```
   - You should be able to log in successfully.
4. **Test Access to Other LAN Devices**:
   - Try accessing other devices on your LAN (e.g., the NAS at `192.168.60.100` or the AP at `192.168.2.254`).
   - For example, open a browser and navigate to `http://192.168.60.100` to access the NAS web interface.


## Troubleshooting

- **Cannot Connect to VPN**:
  - Verify the public IP and port in the phone’s WireGuard configuration match your router’s public IP and port `51820`.
  - Check if port `51820` is open:
    ```bash
    nc -zv <PUBLIC_IP> 51820
    ```
  - Ensure the firewall rule allows UDP port `51820` from the WAN:
    ```bash
    cat /etc/config/firewall | grep WireGuard
    ```
- **Behind CGNAT**:
  - If you’re behind CGNAT, the VPN won’t work until you obtain a public IP from your ISP. Contact your ISP to resolve this.
  - Alternatively, consider a third-party VPN service or a dynamic DNS setup with a reverse proxy (not covered here).
- **Cannot Access LAN Devices**:
  - Verify the firewall forwarding rules (`wg0` → `lan` and `lan` → `wg0`):
    ```bash
    cat /etc/config/firewall | grep forwarding
    ```
  - Ensure the `AllowedIPs` in the phone’s configuration is set to `0.0.0.0/0` to route all traffic through the VPN.
- **WireGuard Not Starting**:
  - Check the WireGuard interface status:
    ```bash
    wg show
    ```
  - If empty, ensure the private key in `/etc/config/network` is correct and the network service was restarted:
    ```bash
    /etc/init.d/network restart
    ```

## Notes

- **Security**:
  - WireGuard uses modern cryptography and is lightweight, making it secure and efficient for your setup.
  - The private keys are stored with restricted permissions (`umask 077`), ensuring they are only accessible by `root`.
  - The firewall rules restrict VPN access to the LAN, preventing exposure to untrusted VLANs (e.g., IoT, Guest).
- **Remote Access**:
  - With the `AllowedIPs = 0.0.0.0/0` setting, all traffic from your phone routes through the VPN, allowing access to the internet via your home network and protecting your traffic on public Wi-Fi.
  - The `PersistentKeepalive = 25` setting ensures the connection stays alive, especially if your phone is behind NAT.
- **CGNAT Considerations**:
  - If you’re behind CGNAT, remote access won’t work without a public IP. Contacting your ISP is the most straightforward solution.

## Next Steps

- Add more WireGuard clients (e.g., a laptop or another phone) by generating new key pairs and adding them to `/etc/config/network`.
- Add Suricata for intrusion detection on the `wg0` interface to monitor VPN traffic for anomalies.