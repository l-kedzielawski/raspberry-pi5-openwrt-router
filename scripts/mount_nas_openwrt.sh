#!/bin/sh /etc/rc.common

START=99
STOP=10

NAS_IP="192.168.60.100"
SHARE="//192.168.60.100/Public"
MOUNT_POINT="/mnt/cloud"

is_mounted() {
    grep -qs "$MOUNT_POINT" /proc/mounts
}

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
    if ! is_mounted; then
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
    if is_mounted; then
        umount "$MOUNT_POINT"
        logger "Unmounted $MOUNT_POINT on service stop."
    fi
}
