#!/bin/bash
#
# Beaglebone Black - Flashing the eMMC with the Latest Image
#
# Reference:
#  https://gist.github.com/smalinux/d5436c73f2b671f3e1102a9574c6e22a
#

###############################################################################
# ATANTION PLEASE
# Last step ~manual~
###############################################################################

# Why?
#--------------------
# The kernel image that came with the board is usually outdated. Thus, I
# decided to update it to the latest image by flashing the onboard eMMc with an
# SD card. The process I followed is documented here.
#
# First download the latest image from:
#  https://www.beagleboard.org/distros
#
# AM335x 12.2 2023-10-07 4GB eMMC IoT Flasher
# I chose this since my use case does not required the GUI provided by Xfce:
# https://files.beagle.cc/file/beagleboard-public-2021/images/am335x-eMMC-flasher-debian-12.2-iot-armhf-2023-10-07-4gb.img.xz

# TODO understand how init-eMMC-flasher-v3.sh script to write your own version
#  to flash any img, not just this image, example: flash uboot on mmc
#
# TODO mount point broken (you have to make mounting dynamic like gnome-disks)
# TODO use faster tool instead of $ dd

# How to use me:
#--------------------
#  $ ./scirpt.sh /dev/<drive>
#  Example
#  $ ./scirpt.sh /dev/sda1

# Config
#################
DRIVE=${1}

# SMA DELETEME
MOUNT_DIR=/mnt/beaglebone_reset_factory
#


# Preparing the SD Card
#################
# Download img
wget -nc -P ./beaglebone_reset_factory \
   https://files.beagle.cc/file/beagleboard-public-2021/images/am335x-eMMC-flasher-debian-12.2-iot-armhf-2023-10-07-4gb.img.xz

# unzip
unxz -k beaglebone_reset_factory/am335x-eMMC-flasher-debian-12.2-iot-armhf-2023-10-07-4gb.img.xz

# check if the SD-Card not exist...
if [ -z ${DRIVE} ]; then
   echo -e "\e[31mVar \$DRIVE is empty... (ex: /dev/sda1)\e[0m"
   exit 0
fi

# burn img
sudo dd if=beaglebone_reset_factory/am335x-eMMC-flasher-debian-12.2-iot-armhf-2023-10-07-4gb.img of=${DRIVE} bs=4M conv=sync status=progress


# Burn the iso image on board mmc
#################
# mount root
sudo mount /dev/${DRIVE} ${MOUNT_DIR}


###############################################################################
# ATANTION PLEASE
# This step ~manual~
# mount the image using gnome-disks! more dynamic
###############################################################################

# sudo vim /mnt/beaglebone_reset_factory/uEnv.txt

# uncomment this line:
#     cmdline=init=/opt/scripts/tools/eMMC/init-eMMC-flasher-v3.sh
#
#
# This line should be already uncommented by default, just double check it.
