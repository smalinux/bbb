#!/bin/bash
set -e  # Exit on any error
set -x  # Debugging mode

# TODO default config
# TODO default env
# make env more dynamic

# How to call me:
# ./scripts/uboot_standalone.sh /dev/sda
#

# === Configuration ===
SD_CARD_DEVICE="${1}"        # Replace with your SD card device (e.g., /dev/sdb)
CROSS_COMPILE="arm-none-eabi-"   # Cross-compiler prefix
base=am335x_evm
DEFCONFIG=${base}_defconfig
UENV_FILE=${base}.env            # Default environment file
PARTITION_SIZE="+64M"            # Partition size for bootloader
MOUNT_DIR="$(mktemp -d /tmp/sdcard.XXXXXX)"


# === Check ===
if [ -z ${SD_CARD_DEVICE} ]; then
   echo -e "\e[31mVar \${1} is empty... Replace with your SD card device (e.g., /dev/sdb)\e[0m"
   exit 1
fi


# === Functions ===

function install_prerequisites() {
   echo "Installing prerequisites..."
   sudo apt-get update
   sudo apt-get install -y build-essential gcc-arm-none-eabi bison flex libssl-dev git
}

function clone_and_build_uboot() {
   echo "Cloning and building U-Boot..."

   mkdir -p uboot_standalone
   pushd uboot_standalone
      git clone https://source.denx.de/u-boot/u-boot.git u-boot || (cd u-boot && git fetch && cd ..)
      pushd u-boot
         # === defconfig
         # Backup: Nice trick: to track any changes you did with menuconfig:
         if [ -f .config ]; then
            cp .config ../configs/${base}.config
         fi

         # Use defconfig
         if [ ! -f .config ]; then
            make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- ${DEFCONFIG}
            make savedefconfig
            cp defconfig ../configs/${base}.config
         else
            # use my modified defconfig version
            cp ../configs/${base}.config .config
         fi

         # TODO generate this with python!
         # TODO move this to independant variable
         # Generate uEnv.txt
         cp ../env/$UENV_FILE ../env/uEnv.txt

         # === build
         make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j12
      popd
   popd
}

function prepare_sdcard() {
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

function mount_sdcard() {
    echo "Mounting the SD card partition..."
    sudo mkdir -p $MOUNT_DIR
    sudo mount ${SD_CARD_DEVICE}1 $MOUNT_DIR
}

# Function to label the partition as "boot"
function label_partition() {
   echo ">> Labeling the partition as 'boot'..."
   sudo fatlabel ${SD_CARD_DEVICE}1 boot || {
      echo "Error: Failed to label partition as 'boot'."
         exit 1
   }
}

# TODO Function to generate uboot.env from uEnv.txt
function create_uboot_env() {
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

function copy_uboot_to_fat() {
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

function cleanup() {
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
