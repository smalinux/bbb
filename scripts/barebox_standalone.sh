#!/bin/bash
#
# Usage: ./scripts/uboot_standalone.sh /dev/sda
#
#

# Exit on any error and enable debugging mode
set -e
set -x


# TODO: Make the environment more dynamic


# === Configuration ===
SD_CARD_DEVICE="${1}"                       # SD card device (e.g., /dev/sdb)
CROSS_COMPILE="arm-linux-gnueabihf-"              # Cross-compiler prefix
BASE="am335x_evm"
DEFCONFIG="${BASE}_defconfig"
UENV_FILE="${BASE}.env"                     # Default environment file
PARTITION_SIZE="+64M"                       # Partition size for bootloader
MOUNT_DIR="$(mktemp -d /tmp/sdcard.XXXXXX)"


# === Check for SD card device ===
if [ -z ${SD_CARD_DEVICE} ]; then
   echo -e "\e[31mVar \${1} is empty... Replace with your SD card device (e.g., /dev/sdb)\e[0m"
   exit 1
fi

# Install required packages for Barebox compilation
function install_prerequisites() {
   echo "Installing prerequisites..."
   sudo apt-get update
   sudo apt-get install -y build-essential gcc-arm-none-eabi bison flex libssl-dev git
}

# Clone Barebox repository and build it
clone_and_build_uboot() {
   echo "Cloning and building Barebox..."

   mkdir -p uboot_standalone
   pushd uboot_standalone
      git clone git://git.pengutronix.de/barebox barebox || (cd barebox && git fetch && cd ..)
      pushd barebox
         git checkout v2024.01.0
         build_mlo
         build_barebox
      popd
   popd
}

# Build MLO
build_mlo() {
   echo "Building Barebox..."

   make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_mlo_defconfig
   make ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j12
}

# Build main barebox bootloader
build_barebox() {
   echo "Building Barebox..."

   make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap_defconfig
   make ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j12
}

# Setup Barebox defconfig based on the base configuration
prepare_sdcard() {
   echo "Preparing SD card: $SD_CARD_DEVICE"

   # Unmount any mounted partitions
   echo "Unmounting existing partitions on $SD_CARD_DEVICE..."
   sudo umount ${SD_CARD_DEVICE}* || true

   # Check for existing signatures and wipe them
   echo "Checking for existing filesystem signatures..."
   if sudo blkid ${SD_CARD_DEVICE}1 | grep -q "vfat"; then
      echo "Found existing VFAT signature. Wiping partition..."
      sudo wipefs -a ${SD_CARD_DEVICE}1
   fi

   # Recreate the partition table
   echo "Creating a new partition table and partition..."
   echo -e "o\nn\np\n1\n\n$PARTITION_SIZE\nt\ne\na\n1\nw" | sudo fdisk $SD_CARD_DEVICE

   # Format the partition with VFAT
   echo "Formatting the partition as VFAT..."
   sudo mkfs.vfat -F 32 ${SD_CARD_DEVICE}1
}

mount_sdcard() {
   echo "Mounting the SD card partition..."
   sudo mkdir -p $MOUNT_DIR
   sudo mount ${SD_CARD_DEVICE}1 $MOUNT_DIR
}

# Function to label the partition as "boot"
label_partition() {
   echo ">> Labeling the partition as 'boot'..."
   sudo fatlabel ${SD_CARD_DEVICE}1 boot || {
      echo "Error: Failed to label partition as 'boot'."
         exit 1
   }
}

# Copy Barebox and environment files to the SD card
copy_barebox_to_fat() {
   echo "Copying Barebox components to FAT partition..."

   pushd uboot_standalone
      pushd barebox
         # Copy MLO (SPL) to the SD card partition
         sudo cp images/barebox-am33xx-beaglebone-mlo.img $MOUNT_DIR/MLO
         # Copy barebox.bin to the SD card partition
         sudo cp images/barebox-am33xx-beaglebone.img $MOUNT_DIR/barebox.bin
      popd
   popd
}

# Clean up build files and unmount the SD card
cleanup() {
   echo "Cleaning up build files..."

   sudo umount $MOUNT_DIR
   sudo rm -r $MOUNT_DIR
}


# === Main Script ===
install_prerequisites
clone_and_build_uboot
prepare_sdcard
label_partition
mount_sdcard
copy_barebox_to_fat
cleanup

echo "Barebox build and flash complete! Insert the SD card into the BeagleBone Black and boot."
