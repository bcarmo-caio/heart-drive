#!/bin/bash

set -e

die() {
	echo -e $1
	exit 1
}

usage() {
	echo Usages:
	echo "$0 --write-image <so image> <device target> <bkp_file>"
	echo "$0 --restore-partitions <device target> <bkp_file>"
}

restore() {
	TARGET_DEVICE=$1
	BKP_FILE=$2

	test -e $BKP_FILE || die "Backup file not found [$BKP_FILE]."
	read -p "Restoring [$BKP_FILE] to [$TARGET_DEVICE]. Is that right? Confirm typing yes uppercase: " conf

	if [[ "$conf" == "YES" ]]; then
		dd if=$BKP_FILE of=$TARGET_DEVICE
		sync
	else
		echo "Aborting."
		exit 0
	fi

	echo "Done."
	exit 0
}

write_image() {
	[[ $# -ne 3 ]] && { usage; die "Missing arguments"; };

	IMAGE=$1
	TARGET_DEVICE=$2
	IMAGES_MNT_DIR=`findmnt ${TARGET_DEVICE}2 | tail -n 1 | awk '{print $1}'`
	RAMDISK_MNT_DIR=/mnt/ramdisk_magicbooter
	BKP_FILE=$3

	test -e $IMAGES_MNT_DIR/$IMAGE || die "$IMAGE not found."
	test -e $IMAGES_MNT_DIR/i_am_the_magical_booter.dummyfile || die "Target $TARGET_DEVICE is invalid."
	test -e $BKP_FILE && die "Backup [$BKP_FILE] file exists. Please remove it first or provide another one."

	IMAGE_SIZE=`stat --print=%s $IMAGES_MNT_DIR/$IMAGE`
	[[ $IMAGE_SIZE -ge 5242880000 ]] && die "Image file is too large. Cannot proceed [$IMAGE: $IMAGE_SIZE >= 5242880000]."

	#[[ "fuser $IMAGES_MNT_DIR 2>&1" != "" ]] || { fuser -vc $IMAGES_MNT_DIR; die "$IMAGES_MNT_DIR is busy. Note: you cannot run this script directly from magic thumb drive."; }
	#echo yay
	#exit 0

	echo "Backing up $TARGET_DEVICE first 2048 sectors to $BKP_FILE"
	dd if=$TARGET_DEVICE of=$BKP_FILE bs=2048 count=512

	echo "Creating ramdisk at [$RAMDISK_MNT_DIR]"
	mkdir $RAMDISK_MNT_DIR
	mount -t tmpfs -o size=5100m tmpfs $RAMDISK_MNT_DIR
	echo "Copying [$IMAGE] to [$RAMDISK_MNT_DIR]"
	cp "$IMAGES_MNT_DIR/$IMAGE" "$RAMDISK_MNT_DIR/$IMAGE"
	sync

	echo "Unmounting umount ${TARGET_DEVICE}2"
	umount ${TARGET_DEVICE}2
	sync

	echo "dding $RAMDISK_MNT_DIR/$IMAGE to $TARGET_DEVICE"
	read -p "Is that right? Confirm typing yes uppercase: " conf
	if [[ "$conf" == "YES" ]]; then
		dd if=$RAMDISK_MNT_DIR/$IMAGE of=$TARGET_DEVICE
		sync
	else
		echo "Aborting"
	fi

	umount $RAMDISK_MNT_DIR
	rmdir $RAMDISK_MNT_DIR

	echo "Done"

	exit 0
}

[[ $EUID -ne 0 ]] && die "Run as root or using sudo."

case "$1" in
	--restore-partitions) shift; restore $@;;
	--write-image) shift; write_image $@;;
	*) usage; exit 0;;
esac

