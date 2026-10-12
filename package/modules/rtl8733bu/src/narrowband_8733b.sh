#!/bin/sh

NIC=$1
CHNL=$2
BW=$3

PROCFS_WR_REG="/proc/net/rtl8733bu/$NIC"

if [ ! -d "$PROCFS_WR_REG" ]; then
    echo "$PROCFS_WR_REG not found. Check CONFIG_PROC_DEBUG in driver Makefile."
    exit 1
fi

iw dev $1 set channel $2 HT20

case "$3" in
    5MHz)
        echo "9b0 40 1" > $PROCFS_WR_REG/write_reg
        echo "9b5 19 1" > $PROCFS_WR_REG/write_reg
        echo "9f0 ca 1" > $PROCFS_WR_REG/write_reg
        echo "81c 00 1" > $PROCFS_WR_REG/write_reg
        ;;
        
    10MHz)
        echo "9b0 80 1" > $PROCFS_WR_REG/write_reg
        echo "9b5 1a 1" > $PROCFS_WR_REG/write_reg
        echo "9f0 cb 1" > $PROCFS_WR_REG/write_reg
        echo "81c 00 1" > $PROCFS_WR_REG/write_reg
        ;;
        
    20MHz)
        echo "9b0 00 1" > $PROCFS_WR_REG/write_reg
        echo "9b5 1b 1" > $PROCFS_WR_REG/write_reg
        echo "9f0 cc 1" > $PROCFS_WR_REG/write_reg
        echo "81c 09 1" > $PROCFS_WR_REG/write_reg
        ;;
        
    *)
        echo "Usage: $0 <wlan0> <channel> <5MHz/10MHz/20MHz>"
        ;;
esac
