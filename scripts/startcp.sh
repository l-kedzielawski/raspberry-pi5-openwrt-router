#!/bin/sh

if [ $# -eq 0 ]; then
    echo "Usage: startcp <interface1> [interface2] [interface3] ..."
    echo "Example: startcp eth0.20 eth0.30 br-lan"
    exit 1
fi

for IFACE in "$@"; do
    echo "Starting capture on $IFACE"
    /etc/init.d/tcpdump_logger start manual "$IFACE" &
done

wait
