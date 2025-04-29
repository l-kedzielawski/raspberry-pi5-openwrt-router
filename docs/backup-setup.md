# Backup Setup for OpenWRT, Switch, and Access Point

This guide details the process of backing up critical configurations and system images for your OpenWRT router, managed switch, and access point (AP). Backups ensure you can restore your network setup in case of hardware failure, misconfiguration, or other issues. All backups will be stored on the Seagate NAS at `/mnt/cloud/backups/`, organized by device, with timestamps for easy identification.

## Overview

- **Purpose**:
  - Back up OpenWRT router configurations via LuCI.
  - Create a full disk image of the OpenWRT system using `dd` for complete recovery.
  - Back up the managed switch configuration (at `192.168.2.100`).
  - Back up the access point configuration (TP-Link EAP610 at `192.168.2.254`).
- **Storage**:
  - Backups are stored on the Seagate NAS at `/mnt/cloud/backups/`, with subdirectories for each device (e.g., `/mnt/cloud/backups/openwrt/`, `/mnt/cloud/backups/switch/`, `/mnt/cloud/backups/ap/`).

## Prerequisites

- **Hardware**:
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openWRT-setup.md)).
  - Managed switch (at `192.168.2.100`).
  - TP-Link EAP610 Access Point (at `192.168.2.254`, configured as per [access-point-setup.md](access-point-setup.md)).
  - Seagate 4TB NAS (mounted at `/mnt/cloud`, configured as per [nas-setup.md](nas-setup.md)).
- **Software**:
  - OpenWRT LuCI interface and SSH access.
  - Access to the switch and AP web interfaces (admin credentials required).
- **Network Setup**:
  - OpenWRT router IP: `192.168.2.1` (LAN, VLAN 20).
  - Switch IP: `192.168.2.100` (LAN, VLAN 20).
  - AP IP: `192.168.2.254` (LAN, VLAN 20).
  - NAS IP: `192.168.60.100` (VLAN 60, mounted at `/mnt/cloud`).

## Step 1: Verify NAS Mount and Create Backup Directories

1. **Log into OpenWRT**:
   - SSH into your OpenWRT router:
     ```bash
     ssh root@192.168.2.1
     ```
2. **Verify NAS Mount**:
   - Ensure the NAS is mounted at `/mnt/cloud` (as set up in [nas-setup.md](nas-setup.md)):
     ```bash
     df -h | grep /mnt/cloud
     ```
   - If not mounted, remount it manually:
     ```bash
     mount -t cifs //192.168.60.100/Public /mnt/cloud -o guest,vers=3.0
     ```
3. **Create Backup Directories**:
   - Create directories on the NAS for each device’s backups:
     ```bash
     mkdir -p /mnt/cloud/backups/openwrt
     mkdir -p /mnt/cloud/backups/switch
     mkdir -p /mnt/cloud/backups/ap
     ```
   - Verify the directories:
     ```bash
     ls -ld /mnt/cloud/backups/*
     ```

## Step 2: Back Up OpenWRT LuCI Configurations

1. **Access LuCI**:
   - Open a browser and navigate to `http://192.168.2.1`.
   - Log in to the LuCI interface 
2. **Create Configuration Backup**:
   - Go to **System → Backup / Flash Firmware**.
   - Under the **Backup** section, click **Generate archive**.
   - This will download a file named `backup-<hostname>-<date>.tar.gz` (e.g., `backup-router-20250426.tar.gz`).
3. **Transfer Backup to NAS**:
   - On your local machine move the files via a mounted share on your PC, copy the file directly to `/mnt/cloud/backups/openwrt/`.
4. **Verify Backup on NAS**:
   - On the OpenWRT router, check the backup file:
     ```bash
     ls -lh /mnt/cloud/backups/openwrt/
     ```
   - You should see the `.tar.gz` file (e.g., `backup-router-20250426.tar.gz`).

## Step 3: Back Up OpenWRT Full System Image Using `dd`

**Why This Is Important**:
- A full disk image backup using `dd` captures the entire OpenWRT system, including the operating system, configurations, and installed packages. This allows you to restore the exact state of your router if the Raspberry Pi 5’s SD card fails or if you need to replicate the setup on new hardware. Given the complexity of your setup (WireGuard, Adblock, `rsyslog`, etc.), this is a critical step for disaster recovery.

1. **Identify the Device**:
   - Determine the device name of your Raspberry Pi 5’s SD card (or storage device OpenWRT is installed on):
     ```bash
     lsblk
     ```
   - Look for the device mounted as `/` (e.g., `/dev/sdf` for an SD card). Note the device name (e.g., `/dev/sdf`).
   - **Caution**: Ensure you identify the correct device to avoid overwriting other storage.
2. **Create the Disk Image**:
   - Use `dd` to create a full disk image and save it directly to the NAS:
     ```bash
     sudo dd if=/dev/sdf bs=4M status=progress | gzip > /mnt/cloud/backups/openwrt/openwrt-full-image-$(date +%Y%m%d).img.gz
     ```
3. **Verify the Image**:
   - Check the size and presence of the image file:
     ```bash
     ls -lh /mnt/cloud/backups/openwrt/
     ```
   - You should see the `.img.gz` file (e.g., `openwrt-full-image-20250426.img.gz`).
   - The compressed image size will vary (e.g., a 16GB SD card might compress to 1–2GB if sparsely used).

## Step 4: Back Up the Managed Switch Configuration

1. **Access the Switch**:
   - Open a browser and navigate to `http://192.168.2.100`.
   - Log in to the switch’s web interface 
2. **Create Configuration Backup**:
   - Go to **System Tools → Backup & Restore**.
   - Under the **Backup** section, select **Backup Config**.
   - This will download a configuration file (e.g., `config.bin` or a similar format, depending on your switch model). 
   - move the file to your NAS
4. **Verify Backup on NAS**:
   - On the OpenWRT router, check the backup file:
     ```bash
     ls -lh /mnt/cloud/backups/switch/
     ```
   - You should see the `.bin` file (e.g., `switch-config-20250426.bin`).

## Step 5: Back Up the Access Point Configuration

1. **Access the AP**:
   - Open a browser and navigate to `http://192.168.2.254`.
   - Log in to the TP-Link EAP610’s web interface (use the admin credentials you set during setup, as per [access-point-setup.md](access-point-setup.md)).
2. **Create Configuration Backup**:
   - Go to **System → Backup & Restore**.
   - Under the **Backup** section, click **Backup** or **Download** to save the configuration.
   - This will download a file (e.g., `EAP610-config.bin` or a similar format).
   - Transfer Backup to NAS

4. **Verify Backup on NAS**:
   - On the OpenWRT router, check the backup file:
     ```bash
     ls -lh /mnt/cloud/backups/ap/
     ```
   - You should see the `.bin` file (e.g., `ap-config-20250426.bin`).

## Notes

- **Backup Frequency**:
  - LuCI configurations: Back up weekly or after significant configuration changes (e.g., adding WireGuard, Adblock).
  - Full image: Back up monthly or after major system updates, as it’s resource-intensive.
  - Switch and AP: Back up after configuration changes.
- **Storage Management**:
  - Monitor the NAS storage usage to ensure there’s enough space for backups:
    ```bash
    du -sh /mnt/cloud/backups/*
    ```
  - Consider implementing a retention policy (e.g., keep only the last 3 full image backups to save space).
- **Security**:
  - The NAS is isolated from untrusted VLANs (IoT, Guest), ensuring backups are only accessible from the LAN (VLAN 20).
  - If the NAS supports it, enable encryption for the backup directory or use a password-protected share for added security, also you can store backups somewhere else like offline usb stick
- **Restoration**:
  - To restore LuCI configurations, go to **System → Backup / Flash Firmware → Restore** in LuCI and upload the `.tar.gz` file.
  - To restore the full image, write the `.img.gz` file back to an SD card (on a separate system):
    ```bash
    zcat openwrt-full-image-20250426.img.gz | dd of=/dev/sdX bs=4M
    ```
    Replace `/dev/sdX` with the target SD card device.
  - To restore the switch or AP, upload the `.bin` file via their respective web interfaces under 