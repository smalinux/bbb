#!/bin/bash

# Why?
#--------------------
# I want very basic image to burn it into sdcard quickly and boot from it.
# All what you want to run this script once and give the sd driver.
# And It will take care of everything, building & burning image into sd.
# Easy & smooth...
# The main perpose of this, to be fast to pringup, not optimal & clean...

# TODO fix all dir location to be more dynamic
# TODO document everything like the article
# TODO add header comment, write steps for users and where is the output
# TODO allow  user to path vars th ur script
# TODO ask Ahmed Fatum for feed back :)

# How to use me:
#--------------------
#  $ ./scirpt.sh /dev/<drive>
#  Example
#  $ ./scirpt.sh /dev/sda1

# Config
#################
DRIVE=${1}

# SMA DELETEME
MOUNT_DIR=/mnt/sd-card
#


# Install require packages
#################
yes | sudo apt-get install build-essential
yes | sudo apt-get install flex bison
yes | sudo apt-get install lzop
yes | sudo apt-get install u-boot-tools
# GCC Cross Compiler
yes | sudo apt-get install gcc-arm-linux-gnueabihf
# Partition Manager
yes | sudo apt-get install gparted
# uboot: https://docs.u-boot.org/en/latest/build/gcc.html
yes | sudo apt-get install gcc gcc-aarch64-linux-gnu
yes | sudo apt-get install bc bison build-essential coccinelle \
  device-tree-compiler dfu-util efitools flex gdisk graphviz imagemagick \
  liblz4-tool libgnutls28-dev libguestfs-tools libncurses-dev \
  libpython3-dev libsdl2-dev libssl-dev lz4 lzma lzma-alone openssl \
  pkg-config python3 python3-asteval python3-coverage python3-filelock \
  python3-pkg-resources python3-pycryptodome python3-pyelftools \
  python3-pytest python3-pytest-xdist python3-sphinxcontrib.apidoc \
  python3-sphinx-rtd-theme python3-subunit python3-testtools \
  python3-virtualenv swig uuid-dev


# BootLoader (U-boot)
#################
# TODO move this  into clean dir
mkdir buildroot_basic_image
pushd buildroot_basic_image
   # TODO hard coded link, move all links to vars at top
   git clone -b master --single-branch https://github.com/buildroot/buildroot
   pushd buildroot
      make beaglebone_defconfig
      make -j12

      if [ -z ]; then
         echo -e "\e[31mVar \$DRIVE is empty... (ex: /dev/sda1)\e[0m"
         exit 0
      fi
      sudo dd if=output/images/sdcard.img of=${DRIVE} bs=4M conv=sync status=progress
   popd
popd


###############################################################################
# SMA DELETEME
## Preparing the MicroSD Card
##################
## umount
#sudo umount /dev/${DRIVE}
## Erese everything
#sudo dd if=/dev/zero of=/dev/${DRIVE} bs=1M count=16
## sfdisk
#sudo sfdisk /dev/${DRIVE} << EOF
#,64M,0x0c,*
#,1024M,L,
#EOF
## setup file systems...
#sudo mkfs.vfat -a -F 16 -n boot /dev/${DRIVE}1
#sudo mkfs.ext4 -L rootfs /dev/${DRIVE}2
## mount
#sudo mount /dev/${DRIVE}1 ${MOUNT_DIR}
## cp uboot bin into the SD-card
#pushd uboot
#   pushd u-boot
#      echo "............................"
#      ls
#      sudo cp MLO u-boot.img /media/root/boot/
#   popd
#popd



# SMA DELETEME
# https://buildroot.uclibc.narkive.com/7gAqWqus/how-to-flash-emmc
#cat /dev/mmcblk0 > /dev/mmcblk1
