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

# Install required packages for U-Boot compilation
function install_prerequisites() {
   echo "Installing prerequisites..."
   sudo apt-get update
   sudo apt-get install -y build-essential gcc-arm-none-eabi bison flex libssl-dev git
}

# Clone U-Boot repository and build it
clone_and_build_uboot() {
   echo "Cloning and building U-Boot..."

   mkdir -p uboot_standalone
   pushd uboot_standalone
      git clone https://source.denx.de/u-boot/u-boot.git u-boot || (cd u-boot && git fetch && cd ..)
      pushd u-boot
         setup_defconfig
         build_uboot
      popd
   popd
}

# Setup U-Boot defconfig based on the base configuration
setup_defconfig() {
   if [ ! -f .config ]; then
      # this part should use only once, at the very  first time
      cp ../configs/${BASE}.config .config
   else
   if [ ! -f .config ]; then
      cp ../configs/${BASE}.config .config
   else
      echo "Using existing config..."

      # take screenshot fro it!
      cp .config ../configs/${BASE}.config
   fi

   # Copy environment file
   cp ../env/$UENV_FILE ../env/uEnv.txt
}

# Build U-Boot using the provided defconfig
build_uboot() {
   echo "Building U-Boot..."
   make ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j12
}

# Setup U-Boot defconfig based on the base configuration
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

# TODO Function to generate uboot.env from uEnv.txt
create_uboot_env() {
   echo "Creating uboot.env from uEnv.txt..."

   # Use mkimage to create the environment binary file
   mkimage -A arm -O linux -T script -C none -n "U-Boot Environment" -d ./uboot_standalone/env/$UENV_FILE ./uboot_standalone/env/uboot.env
}

## TODO I Don't use this function now
#function flash_uboot_to_raw() {
#   echo "Flashing U-Boot components to raw storage..."
#
#   echo "Flashing MLO at ${MLO_OFFSET} KiB..."
#   sudo dd if=MLO of=${SD_CARD_DEVICE} bs=1K seek=$MLO_OFFSET conv=notrunc status=progress
#   echo "Flashing u-boot.img at ${UBOOT_OFFSET} KiB..."
#   sudo dd if=u-boot.img of=${SD_CARD_DEVICE} bs=1K seek=$UBOOT_OFFSET conv=notrunc status=progress
#   echo "Creating and flashing default environment at ${ENV_OFFSET} KiB..."
#   #dd if=/dev/zero bs=1K count=$ENV_SIZE | tr '\000' '\377' > uboot.env
#   #sudo dd if=uboot.env of=$SD_CARD_DEVICE bs=1K seek=$ENV_OFFSET conv=notrunc status=progress
#}

# Copy U-Boot and environment files to the SD card
copy_uboot_to_fat() {
   echo "Copying U-Boot components to FAT partition..."

   pushd uboot_standalone
      pushd u-boot
         # Copy MLO (U-Boot SPL) to the SD card partition
         sudo cp MLO $MOUNT_DIR
         # Copy u-boot.img to the SD card partition
         sudo cp u-boot.img $MOUNT_DIR
      popd

      pushd env
         # TODO Create and copy the environment file
         sudo cp uboot.env $MOUNT_DIR
         # TODO Optionally: Add a uEnv.txt for U-Boot to load at boot
         sudo cp $UENV_FILE $MOUNT_DIR/uEnv.txt
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
#create_uboot_env
mount_sdcard
copy_uboot_to_fat
#flash_uboot_to_raw
cleanup

echo "U-Boot build and flash complete! Insert the SD card into the BeagleBone Black and boot."
