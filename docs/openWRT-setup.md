# OpenWRT Setup for Raspberry Pi 5 Secure Router

This guide provides detailed instructions for setting up **OpenWRT 24.10.0** on a Raspberry Pi 5 to create a secure, VLAN-segmented home router. The setup supports a 1 Gbps ISP connection via PPPoE (NETIA ISP), network segmentation for LAN, Trusted WiFi, IoT, Guest WiFi, NAS, and Infrastructure services, and includes firewall rules, DHCP, and UHTTPD configurations for secure management.

## Prerequisites
- **Hardware**:
  - Raspberry Pi 5 (4GB RAM, 8GB recommended).
  - MicroSD card (SanDisk Extreme 64GB recommended).
  - Ethernet cables (CAT6a SFTP).
  - TP-Link TL-SG105E switch (configured as per [switch-setup.md](switch-setup.md)).
- **Software**:
  - OpenWRT 24.10.0 image ([download from openwrt.org](https://openwrt.org)).
  - Raspberry Pi Imager or `dd` for flashing.
  - A PC for initial configuration 
  **Configs**
  - full configs in `../configs/...`

## Step 1: Flash OpenWRT to MicroSD Card
1. **Download Op enWRT**:
   - Download the OpenWRT 24.10.0 image for Raspberry Pi 5 from [openwrt.org](https://openwrt.org).
2. **Flash the Image**:
   - Use Raspberry Pi Imager (v1.8.5 or later) or the `dd` command to flash the image to your MicroSD card.
     - **Raspberry Pi Imager**: Select the OpenWRT image, choose your MicroSD card, and flash.
     - **dd Command**: On Linux/macOS, run:
       ```bash
       sudo dd if=openwrt-24.10.0......img of=/dev/sdX bs=4M status=progress
       ```
       Replace `if=` with your file name and `/dev/sdX` with your MicroSD card device (e.g., `/dev/sdb`).
3. **Edit UHTTPD Configuration**:
   - Before ejecting the MicroSD card, mount it and navigate to `/etc/config/`.
   - Edit the `uhttpd` file (`/etc/config/uhttpd`) to add HTTP/HTTPS listeners for the LAN IP:
     - Add the following lines under the existing `list listen_` entries:
       ```
       list listen_http '192.168.2.1:80'
       list listen_https '192.168.2.1:443'
       ```
     - The full `uhttpd` config should look like the one in [configs/uhttpd](../configs/uhttpd).
4. **Insert MicroSD Card**:
   - Safely eject the MicroSD card, insert it into the Raspberry Pi 5, and connect the Pi directly to your PC via an Ethernet cable (using Port 2 on the switch, as configured in [switch-setup.md](switch-setup.md)).

## Step 2: Initial Configuration
1. **Power On and Connect**:
   - connect directly to your PC.      
   - Power on the Raspberry Pi 5. It will boot OpenWRT.

2. **Access OpenWRT**:
   - connect to luCi using 192.168.1.1 , admin, root
   -  The default password is unset; you’ll set it in the next step.

3. **Change Password and Enable SSH**:
   - In LuCI: Go to **System → Administration** and set a new password.
   - Enable SSH access on the `lan` interface:
     - Go to **System → Administration → SSH Access**.
     - Add the `lan` interface (initially named `br-lan`).
     - you can connect via ssh now `ssh root@192.168.1.1`

## Step 3: Configure Network Interfaces and VLANs
1. **Access Network Configuration**:
   - Via LuCI: Go to **Network → Interfaces**.
   - Via SSH: Edit `/etc/config/network` directly (`nano /etc/config/network`).
2. **Set Up Loopback Interface**:
   - This should already exist in `/etc/config/network`:
     ```
     config interface 'loopback'
             option device 'lo'
             option proto 'static'
             option ipaddr '127.0.0.1'
             option netmask '255.0.0.0'
     ```
3. **Configure Global Settings**:
   - Ensure the following global settings are present for IPv6 and performance:
     ```
     config globals 'globals'
             option ula_prefix 'fd6c:36c1:50d2::/48'
             option packet_steering '1'
     ```
   - `packet_steering '1'` enables multi-core processing for better performance.

4. **Create VLAN Devices**:
   - Add VLAN devices for each segment (WAN 10, LAN - 20, Trusted WiFi - 30 , IoT WiFi - 40, Guest WiFi - 50, NAS - 60, Infrastructure - 70):
     ```
     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '10'
             option name 'eth0.10'

     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '20'
             option name 'eth0.20'

     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '30'
             option name 'eth0.30'

     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '40'
             option name 'eth0.40'

     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '50'
             option name 'eth0.50'

     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '60'
             option name 'eth0.60'

     config device
             option type '8021q'
             option ifname 'eth0'
             option vid '70'
             option name 'eth0.70'
     ```
   - Ensure the base device `eth0` is defined (this is typically auto-created):
     ```
     config device
             option name 'eth0'
     ```
5. **Configure WAN Interface (VLAN 10)**:
   - Set up the WAN interface using PPPoE for NETIA ISP:
     ```
     config interface 'wan'
             option proto 'pppoe'
             option device 'eth0.10'
             option username '<your-pppoe-username>'
             option password '<your-pppoe-password>'
             option ipv6 'auto'
     ```
   - Replace `<your-pppoe-username>` and `<your-pppoe-password>` with credentials provided by your ISP, I had to give a call to ISP ask them for this also when your are on the line ask for static ip.

6. **Configure LAN Interface (VLAN 20)**:
   - Set up the LAN interface with a static IP:
     ```
     config interface 'lan'
             option proto 'static'
             option device 'eth0.20'
             option ipaddr '192.168.2.1'
             option netmask '255.255.255.0'
     ```
   - If you encounter issues naming the interface `lan`, temporarily name it `lan20` and rename it later.

7. **Configure Additional VLAN Interfaces**:
   - Add interfaces for Trusted WiFi, IoT WiFi, Guest WiFi, NAS, and Infrastructure:
     ```
     config interface 'trust_wifi'
             option proto 'static'
             option device 'eth0.30'
             option ipaddr '192.168.30.1'
             option netmask '255.255.255.0'

     config interface 'iot_wifi'
             option proto 'static'
             option device 'eth0.40'
             option ipaddr '192.168.40.1'
             option netmask '255.255.255.0'

     config interface 'guest_wifi'
             option proto 'static'
             option device 'eth0.50'
             option ipaddr '192.168.50.1'
             option netmask '255.255.255.0'

     config interface 'nas'
             option proto 'static'
             option device 'eth0.60'
             option ipaddr '192.168.60.1'
             option netmask '255.255.255.0'

     config interface 'infra'
             option proto 'static'
             option device 'eth0.70'
             option ipaddr '192.168.70.1'
             option netmask '255.255.255.0'
     ```
   - The full `/etc/config/network` file is available in [configs/network](../configs/network).

## Step 4: Configure DHCP

1. **Access DHCP Settings**:
   - Via LuCI: Go to **Network → Interfaces → edit on each interface → DHCP Server** and just click enable on all of them
   - Via SSH: Edit `/etc/config/dhcp` (`nano /etc/config/dhcp`).
2. **Enable DHCP for LAN (VLAN 20)**:
   - Add or modify the following in `/etc/config/dhcp`:
     ```
     config dnsmasq
             option domainneeded '1'
             option boguspriv '1'
             option filterwin2k '0'
             option localise_queries '1'
             option rebind_protection '1'
             option rebind_localhost '1'
             option local '/lan/'
             option domain 'lan'
             option expandhosts '1'
             option nonegcache '0'
             option cachesize '1000'
             option authoritative '1'
             option readethers '1'
             option leasefile '/tmp/dhcp.leases'
             option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
             option nonwildcard '1'
             option localservice '1'
             option ednspacket_max '1232'
             option filter_aaaa '0'
             option filter_a '0'

     config dhcp 'wan'
             option interface 'wan'
             option ignore '1'

     config odhcpd 'odhcpd'
             option maindhcp '0'
             option leasefile '/tmp/hosts/odhcpd'
             option leasetrigger '/usr/sbin/odhcpd-update'
             option loglevel '4'

     config dhcp 'lan'
             option interface 'lan'
             option start '100'
             option limit '150'
     ```
3. **Enable DHCP for Other VLANs**:
   - Add DHCP settings for `trust_wifi`, `iot_wifi`, `guest_wifi`, and `nas`:
     ```
     config dhcp 'trust_wifi'
             option interface 'trust_wifi'
             option start '100'
             option limit '150'

     config dhcp 'iot_wifi'
             option interface 'iot_wifi'
             option start '100'
             option limit '150'

     config dhcp 'guest_wifi'
             option interface 'guest_wifi'
             option start '100'
             option limit '150'

     config dhcp 'nas'
             option interface 'nas'
             option start '100'
             option limit '150'
     ```
   - The full `/etc/config/dhcp` file is available in [configs/dhcp](../configs/dhcp).

## Step 5: Configure Firewall Rules

1. **Access Firewall Settings**:
   - Via LuCI: Go to **Network → Firewall**.
   - Via SSH: Edit `/etc/config/firewall` (`nano /etc/config/firewall`).

2. **Delete Existing Rules**:
   - Remove any default firewall rules to start fresh.
   - In LuCI: Delete existing zones and rules.
   - Via SSH: Clear the contents of `/etc/config/firewall` and start anew.

3. **Create Firewall Zones**:
   - Add zones for `lan`, `wan`, `trust_wifi`, `iot_wifi`, `guest_wifi`, and `nas`:
     ```
     config defaults
             option input 'ACCEPT'
             option output 'ACCEPT'
             option forward 'REJECT'
             option synflood_protect '1'

     config zone
             option name 'lan'
             option input 'ACCEPT'
             option output 'ACCEPT'
             option forward 'ACCEPT'
             list network 'lan'

     config zone
             option name 'wan'
             option input 'REJECT'
             option output 'ACCEPT'
             option forward 'REJECT'
             option masq '1'
             option mtu_fix '1'
             list network 'wan'

     config zone
             option name 'trust_wifi'
             option input 'ACCEPT'
             option output 'ACCEPT'
             option forward 'REJECT'
             list network 'trust_wifi'

     config zone
             option name 'iot'
             option input 'REJECT'
             option output 'ACCEPT'
             option forward 'REJECT'
             option masq '1'
             list network 'iot_wifi'

     config zone
             option name 'guest'
             option input 'ACCEPT'
             option output 'ACCEPT'
             option forward 'REJECT'
             option masq '1'
             list network 'guest_wifi'

     config zone
             option name 'nas'
             option input 'ACCEPT'
             option output 'ACCEPT'
             option forward 'REJECT'
             list network 'nas'
     ```

4. **Set Up Forwarding Rules**:

   - Allow forwarding from internal zones to WAN:
     ```
     config forwarding
             option src 'lan'
             option dest 'wan'

     config forwarding
             option src 'trust_wifi'
             option dest 'wan'
             option dest 'lan'

     config forwarding
             option src 'iot'
             option dest 'wan'

     config forwarding
             option src 'guest'
             option dest 'wan'

     config forwarding
             option src 'lan'
             option dest 'nas'
     ```
5. **Add IoT Traffic Rules for DHCP and DNS**:
   - The IoT zone (`iot`) is restricted (`input REJECT`), so you need specific traffic rules to allow DHCP (ports 67-68, UDP) and DNS (port 53, TCP/UDP) for devices to connect and resolve domains.
   - In LuCI: Go to **Network → Firewall → Traffic Rules**.
   - Add the following rules (as shown in the provided screenshots):
     - **Allow IoT DHCP**:
       - Name: `Allow IoT DHCP`
       - Protocol: UDP
       - Source Zone: `iot`
       - Source Address: `-- add IP --` (leave empty for any)
       - Source Port: `any`
       - Destination Zone: `Device (input)`
       - Destination Address: `-- add IP --` (leave empty for any)
       - Destination Port: `67:68`
       - Action: `accept`
       ![IoT DHCP Rule](screenshots/iot-dhcp-rule.png)
     - **Allow IoT DNS**:
       - Name: `Allow IoT DNS`
       - Protocol: TCP + UDP
       - Source Zone: `iot`
       - Source Address: `-- add IP --` (leave empty for any)
       - Source Port: `any`
       - Destination Zone: `Device (input)`
       - Destination Address: `-- add IP --` (leave empty for any)
       - Destination Port: `53`
       - Action: `accept`
       ![IoT DNS Rule](screenshots/iot-dns-rule.png)
   - Via SSH: Add these rules to `/etc/config/firewall`:
     ```
     config rule
             option name 'Allow-IoT-DHCP'
             option src 'iot'
             option dest 'device'
             option proto 'udp'
             option dest_port '67:68'
             option target 'ACCEPT'

     config rule
             option name 'Allow-IoT-DNS'
             option src 'iot'
             option dest 'device'
             option proto 'tcp udp'
             option dest_port '53'
             option target 'ACCEPT'
     ```
   - The full `/etc/config/firewall` file is available in [configs/firewall](../configs/firewall).
6. **Save and Apply**:
   - In LuCI: Click **Save & Apply**.
   - Via SSH: Restart the firewall service:
     ```bash
     /etc/init.d/firewall restart
     ```

## Step 6: Connect Devices to the Switch
- Ensure the switch is configured as per [switch-setup.md](switch-setup.md).
- Connect the devices:
  - Modem → Port 1 (VLAN 10, untagged).
  - Raspberry Pi 5 → Port 2 (all VLANs, tagged).
  - PC → Port 3 (VLAN 20, untagged).
  - Access Point → Port 4 (VLANs 20, 30, 40, 50, 70, tagged).
  - NAS → Port 5 (VLAN 60, untagged).
- The switch will handle VLAN separation based on its configuration.


## Step 7: Finalize UHTTPD Configuration
1. **Verify UHTTPD Settings**:
   - Ensure `/etc/config/uhttpd` matches the following (as edited in Step 1):
     ```
     config uhttpd 'main'
             option redirect_https '0'
             option home '/www'
             option rfc1918_filter '1'
             option max_requests '3'
             option max_connections '100'
             option cert '/etc/uhttpd.crt'
             option key '/etc/uhttpd.key'
             option cgi_prefix '/cgi-bin'
             list lua_prefix '/cgi-bin/luci=/usr/lib/lua/luci/sgi/uhttpd.lua'
             option script_timeout '60'
             option network_timeout '30'
             option http_keepalive '20'
             option tcp_keepalive '1'
             option ubus_prefix '/ubus'
             list listen_http '192.168.2.1:80'
             list listen_https '192.168.2.1:443'

     config cert 'defaults'
             option days '397'
             option key_type 'ec'
             option bits '2048'
             option ec_curve 'P-256'
             option country 'ZZ'
             option state 'Somewhere'
             option location 'Unknown'
             option commonname 'OpenWrt'
     ```
   - This configuration ensures secure access to the LuCI interface on `192.168.2.1`.
2. **Delete `br-lan` Interface**:
   - If everything is working (LAN has internet, devices are accessible), remove the default `br-lan` interface:
     - In LuCI: Go to **Network → Interfaces**, delete `br-lan`.
     - Via SSH: Edit `/etc/config/network` and remove the `br-lan` entry.
   - restart your pc
   - This step cleans up the configuration, as `eth0.20` is now your LAN interface.
   - if it didn't work use
        ```
        sudo ip addr add 192.168.2.100/24 dev eth0
        set ip link set eth0 up
        sudo ip route add default via 192.168.2.1 dev eth0
## Step 8: Test Connectivity
1. **Verify Device IPs**:
   - Your PC (Port 3) should receive an IP in the `192.168.2.x` range (e.g., `192.168.2.100` to `192.168.2.249`) via DHCP.
   - Check with:
     ```bash
     ip a
     ```
2. **Ping Tests**:
   - From your PC, test connectivity:
     ```bash
     ping 192.168.2.1      # Raspberry Pi 5 (OpenWRT)
     ping 192.168.2.100    # Switch
     ping 8.8.8.8          # External IP (Google DNS)
     ping google.com       # DNS resolution
     ```
3. **Scan for Devices**:
   - Use `arp-scan` to verify devices are visible on the LAN:
     ```bash
     sudo arp-scan -I eth0 192.168.2.0/24
     ```

## Troubleshooting
- **No Internet Access**:
  - Verify VLAN and PVID settings on the switch (see [switch-setup.md](switch-setup.md)).
  - Ensure `eth0.20` is set as the LAN interface in OpenWRT.
  - Check firewall zones: Confirm `lan` → `wan` forwarding is enabled.
  - Reboot the modem; some ISPs bind to the last connected MAC address.
  - If using NordVPN or another VPN, disable any killswitch or conflicting firewall rules.
- **PPPoE Authentication Fails**:
  - Double-check your PPPoE credentials with NETIA. If you have DHCP instead, change the WAN protocol to DHCP:
    ```
    config interface 'wan'
            option proto 'dhcp'
            option device 'eth0.10'
            option ipv6 'auto'
    ```
  - NETIA requires PPPoE authentication; DHCP alone won’t work unless the modem handles PPPoE upstream.
- **LAN Blocked**:
  - Check for conflicting firewall rules or VPN settings (e.g., NordVPN killswitch). - iptables  and nftables
  - Ensure the `lan` zone allows input, output, and forwarding.
- **Devices Not Visible**:
  - Use `arp-scan` to confirm devices are on the network.
  - Verify DHCP is enabled and providing IPs in the correct range.

## Notes
- **PPPoE Details**:
  - OpenWRT uses `pppd` to initiate a PPPoE session with NETIA.
  - The ISP authenticates based on username/password, assigns an IP, and masquerading (NAT) enables internet access for LAN devices.
  - This setup is common for DSL/ADSL/FTTH ISPs in Europe.
- **Security**:
  - The UHTTPD configuration ensures secure access via HTTPS on `192.168.2.1:443`.

## Next Steps
- Configure the TP-Link EAP610 Access Point with VLAN-tagged SSIDs - `access_point-setup`
- Set up the Seagate NAS for logging and storage (see [configs/mount_nas](../configs/mount_nas)).
- Install additional software (e.g., WireGuard, AdBlock) as outlined in [setup-guide.md](setup-guide.md).