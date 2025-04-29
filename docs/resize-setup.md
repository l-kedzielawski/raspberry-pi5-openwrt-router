# Resize MicroSD Card to Use Full Capacity

This guide details how to resize the MicroSD card used by your Raspberry Pi 5 running OpenWRT to utilize its full capacity. By default, OpenWRT’s image may not use the entire space on your MicroSD card (e.g., a 64GB card might only use 100mb initially). Resizing the partitions and filesystem ensures you can take advantage of the full storage for logs, backups, or additional packages. We’ll use a Kali Linux system with `gparted` and `resize2fs` to perform the resizing, and address any changes in partition numbers that might affect OpenWRT’s boot or mount configuration.

## Overview

- **Purpose**:
  - Expand the MicroSD card’s partitions and filesystem to use its full capacity.
  - Update OpenWRT’s configuration to account for any changes in partition numbers or UUIDs.
- **Tools**:
  - Kali Linux system with `gparted` and `resize2fs`.
  - A MicroSD card reader or adapter to access the card on Kali.
- **Storage**:
  - Backups of the MicroSD card will be stored on the Seagate NAS at `/mnt/cloud/backups/openwrt/` for safety.

## Prerequisites

- **Hardware**:
  - Raspberry Pi 5 running OpenWRT (configured as per [openwrt-setup.md](openwrt-setup.md)).
  - MicroSD card (e.g., SanDisk Extreme 64GB) used by the Raspberry Pi 5.
  - Seagate 4TB NAS (mounted at `/mnt/cloud`, configured as per [nas-setup.md](nas-setup.md)).
  - A Kali Linux system (e.g., a laptop or VM) with a MicroSD card reader.
- **Software**:
  - `gparted` and `e2fsprogs` (for `resize2fs`) installed on Kali Linux.
  - OpenWRT LuCI interface and SSH access.
- **Network Setup**:
  - OpenWRT router IP: `192.168.2.1` (LAN, VLAN 20).
  - NAS IP: `192.168.60.100` (VLAN 60, mounted at `/mnt/cloud`).

## Step 1: Install Required Tools on Kali Linux

1. **Log into Kali Linux**:
   - Boot your Kali Linux system (e.g., a laptop or VM).
2. **Install `gparted` and `e2fsprogs`**:
   - Update the package list and install the tools:
     ```bash
     sudo apt update
     sudo apt install gparted e2fsprogs
     ```
## Step 2: Resize the MicroSD Card Using `gparted`

1. **Launch `gparted`**:
   - Open `gparted` on Kali with sudo privileges:
     ```bash
     sudo gparted
     ```
2. **Select the MicroSD Card**:
   - In the top-right corner of `gparted`, select your MicroSD card (e.g., `/dev/sdb`).
   - You’ll see the current partition layout, typically:
     - A small boot partition (e.g., `/dev/sdb1`, ~256MB, FAT32).
     - A root partition (e.g., `/dev/sdb2`, ~3GB, ext4).
     - Unallocated space (e.g., the remaining ~60GB on a 64GB card).
3. **Delete and Recreate the Root Partition**:
   - **Note**: OpenWRT typically uses a boot partition (`/dev/sdb1`) and a root partition (`/dev/sdb2`). We’ll expand the root partition to use the unallocated space.
   - Right-click the root partition (e.g., `/dev/sdb2`) and select **Delete**.
   - Right-click the unallocated space and select **New**.
   - Set the following:
     - **File system**: `ext4`.
     - **Size**: Use the maximum available space (e.g., the remaining 60GB).
     - **Label**: (Optional) Set to `rootfs` for clarity.
   - Click **Add**.
4. **Apply Changes**:
   - Click the green checkmark (✔) in `gparted` to apply the changes.
   - This will recreate the root partition to use the full available space.
5. **Note the New Partition Details**:
   - After applying changes, note the new partition number (e.g., it might still be `/dev/sdb2`, but if the partition table changes, it could be different, like `/dev/sdb3`).
   - Also note the UUID of the new partition (you’ll need this later):
     ```bash
     sudo blkid /dev/sdb2
     ```
   - Example output: `/dev/sdb2: UUID="123e4567-e89b-12d3-a456-426614174000" TYPE="ext4"`.

## Step 3: Resize the Filesystem Using `resize2fs`

1. **Check the Filesystem**:
   - Run a filesystem check on the new root partition to ensure it’s clean:
     ```bash
     sudo e2fsck -f /dev/sdb2
     ```
   - Replace `/dev/sdb2` with the correct partition number if it changed.
2. **Resize the Filesystem**:
   - Expand the filesystem to use the full partition size:
     ```bash
     sudo resize2fs /dev/sdb2
     ```
   - This will adjust the `ext4` filesystem to match the new partition size (e.g., from 3GB to 64GB).
3. **Verify the New Size**:
   - Mount the partition temporarily to check its size:
     ```bash
     sudo mkdir /mnt/sdcard
     sudo mount /dev/sdb2 /mnt/sdcard
     df -h /mnt/sdcard
     ```
   - You should see the full capacity (e.g., ~60GB available on a 64GB card).
   - Unmount when done:
     ```bash
     sudo umount /mnt/sdcard
     ```

## Step 4: Update OpenWRT Configuration for Partition Changes

When you resize partitions, the partition numbers or UUIDs may change, which can affect OpenWRT’s boot process or filesystem mounts (e.g., the root filesystem or `/etc/config/fstab`). Let’s update the configuration to ensure OpenWRT boots correctly.

1. **Insert the MicroSD Card Back into the Raspberry Pi 5**:
   - Safely eject the MicroSD card from Kali:
     ```bash
     sudo eject /dev/sdb
     ```
   - Insert it back into the Raspberry Pi 5 and power it on.
2. **Check if OpenWRT Boots**:
   - Attempt to access the LuCI interface (`http://192.168.2.1`) or SSH:
     ```bash
     ssh root@192.168.2.1
     ```
   - If OpenWRT boots and mounts the root filesystem correctly, skip to Step 6.
   - If it fails to boot (e.g., stuck at boot, or root filesystem not found), proceed to the next steps.
3. **Access the OpenWRT Filesystem via Kali**:
   - If OpenWRT doesn’t boot, remove the MicroSD card again and insert it back into Kali.
   - Mount the root partition:
     ```bash
     sudo mkdir /mnt/sdcard
     sudo mount /dev/sdb2 /mnt/sdcard
     ```
4. **Check the Boot Configuration**:
   - OpenWRT uses the `u-boot` bootloader, which references the root filesystem in its boot arguments. These are often stored in `/boot/boot.scr` or passed via the kernel command line.
   - Check the boot configuration:
     ```bash
     cat /mnt/sdcard/boot/boot.scr
     ```
   - If it’s a binary script, you may need to check the kernel command line in `/proc/cmdline` (when the system is running) or inspect the OpenWRT image’s default boot arguments.
   - Typically, the root filesystem is specified as `root=/dev/mmcblk0p2` or by UUID (e.g., `root=UUID=123e4567-e89b-12d3-a456-426614174000`).
   - If the partition number changed (e.g., from `/dev/mmcblk0p2` to `/dev/mmcblk0p3`), or the UUID changed, you’ll need to update this.
5. **Update the Root Filesystem Reference**:
   - If OpenWRT uses `u-boot` with a `boot.scr` script, you’ll need to regenerate it. However, for simplicity, we’ll update the root filesystem in OpenWRT’s configuration.
   - Mount the boot partition as well (if separate):
     ```bash
     sudo mkdir /mnt/boot
     sudo mount /dev/sdb1 /mnt/boot
     ```
   - Check for a `uEnv.txt` or similar file in the boot partition:
     ```bash
     cat /mnt/boot/uEnv.txt
     ```
   - If it specifies the root (e.g., `root=/dev/mmcblk0p2`), update it to the new partition number or UUID:
     ```
     root=UUID=123e4567-e89b-12d3-a456-426614174000
     ```
   - If there’s no `uEnv.txt`, the root is likely specified in the OpenWRT image’s default bootargs, which are harder to modify without rebuilding the image. In this case, proceed to update `/etc/config/fstab` instead.

7. **Unmount and Reinsert the MicroSD Card**:
   - Unmount the partitions:
     ```bash
     sudo umount /mnt/sdcard
     sudo umount /mnt/boot
     ```
   - Eject the MicroSD card:
     ```bash
     sudo eject /dev/sdb
     ```
   - Insert it back into the Raspberry Pi 5 and power it on.

## Step 5: Verify the Resized MicroSD Card

1. **Check if OpenWRT Boots**:
   - Access the LuCI interface (`http://192.168.2.1`) or SSH:
     ```bash
     ssh root@192.168.2.1
     ```
   - If OpenWRT boots successfully, proceed to the next step.
2. **Verify the New Size**:
   - Check the size of the root filesystem:
     ```bash
     df -h /
     ```
   - You should see the full capacity (e.g., ~60GB on a 64GB card, minus space used by the boot partition).
3. **Verify Mounts**:
   - Check that the root filesystem is mounted with the correct UUID:
     ```bash
     blkid /dev/mmcblk0p2
     mount | grep ' / '
     ```
   - Ensure the UUID matches what you updated in `/etc/config/fstab`.
