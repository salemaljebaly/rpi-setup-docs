#!/usr/bin/env python3
"""Print RC channel changes received by the Cube over MAVLink."""

import argparse
from pymavlink import mavutil


def parse_args():
    parser = argparse.ArgumentParser(
        description="Monitor RC_CHANNELS from a MAVLink endpoint."
    )
    parser.add_argument(
        "--endpoint",
        default="tcp:127.0.0.1:5760",
        help="MAVLink endpoint, default: tcp:127.0.0.1:5760",
    )
    parser.add_argument(
        "--channels",
        type=int,
        default=8,
        choices=(4, 8),
        help="Number of channels to print: 4 or 8 (default: 8)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    print(f"Connecting to {args.endpoint}...")
    master = mavutil.mavlink_connection(args.endpoint)
    master.wait_heartbeat()
    print("Watching RC_CHANNELS. Move one stick at a time. Press Ctrl+C to stop.")

    last = None
    while True:
        msg = master.recv_match(type="RC_CHANNELS", blocking=True)
        if args.channels == 4:
            current = (
                msg.chan1_raw,
                msg.chan2_raw,
                msg.chan3_raw,
                msg.chan4_raw,
            )
        else:
            current = (
                msg.chan1_raw,
                msg.chan2_raw,
                msg.chan3_raw,
                msg.chan4_raw,
                msg.chan5_raw,
                msg.chan6_raw,
                msg.chan7_raw,
                msg.chan8_raw,
            )

        if current != last:
            labeled = " ".join(
                f"RC{index}={value}" for index, value in enumerate(current, start=1)
            )
            print(f"{current}  {labeled}", flush=True)
            last = current


if __name__ == "__main__":
    main()
