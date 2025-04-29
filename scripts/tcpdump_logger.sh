#!/bin/sh /etc/rc.common

# Automated packet capturing with live display and storage management
# Now with manual (foreground) mode support

START=99
PID_DIR="/tmp/tcpdump_logger_pids"
LOG_DIR="/mnt/cloud/tcpdumps"
MAX_SIZE_MB=1024  # 1GB limit

start() {
    MODE="$1"
    shift

    mkdir -p "$PID_DIR"

    if [ ! -d "$LOG_DIR" ]; then
        echo "$(date) NAS mount not found at $LOG_DIR. Aborting." | tee -a /tmp/tcpdump_logger.log
        return 1
    fi

    echo "$(date) Starting tcpdump_logger... Mode: ${MODE:-background}" | tee -a /tmp/tcpdump_logger.log

    INTERFACES="$@"
    if [ -z "$INTERFACES" ]; then
        INTERFACES=$(ip link show | awk -F: '/: e/{print $2}' | tr -d ' ')
    fi

    for IFACE in $INTERFACES; do
        OUT_FILE="$LOG_DIR/$IFACE.pcap"
        echo "$(date) Starting tcpdump on $IFACE -> $OUT_FILE" | tee -a /tmp/tcpdump_logger.log
        if [ "$MODE" = "manual" ]; then
            # Foreground mode, CTRL+C will work
            tcpdump -i "$IFACE" -n -s 0 -U -w - | tee "$OUT_FILE" | tcpdump -n -r -
        else
            # Background mode
            ( tcpdump -i "$IFACE" -n -s 0 -U -w - | tee "$OUT_FILE" | tcpdump -n -r - ) &
            echo $! > "$PID_DIR/$IFACE.pid"
        fi
    done

    if [ "$MODE" != "manual" ]; then
        # Start retention watchdog only in background mode
        retention_watchdog &
        echo $! > "$PID_DIR/retention.pid"
    fi
}

stop() {
    echo "$(date) Stopping tcpdump_logger..." | tee -a /tmp/tcpdump_logger.log
    for PIDFILE in "$PID_DIR"/*.pid; do
        [ -f "$PIDFILE" ] || continue
        PID=$(cat "$PIDFILE")
        kill "$PID" 2>/dev/null
        rm -f "$PIDFILE"
    done
    rm -rf "$PID_DIR"
}

retention_watchdog() {
    while true; do
        TOTAL_MB=$(du -sm "$LOG_DIR" | awk '{print $1}')
        if [ "$TOTAL_MB" -gt "$MAX_SIZE_MB" ]; then
            echo "$(date) Limit reached: ${TOTAL_MB}MB used, deleting oldest..." | tee -a /tmp/tcpdump_logger.log
            OLDEST=$(find "$LOG_DIR" -type f -name "*.pcap" -printf "%T@ %p\n" | sort -n | awk 'NR==1 {print $2}')
            [ -n "$OLDEST" ] && rm -f "$OLDEST" && echo "$(date) Deleted $OLDEST" | tee -a /tmp/tcpdump_logger.log
        fi
        sleep 60
    done
}
