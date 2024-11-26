#!/bin/bash
#

#TODO $ ln this  script  under /bin
DRIVE=${1}
SPEED=115200

# check if the SD-Card not exist...
if [ -z ${DRIVE} ]; then
   echo -e "\e[31mVar \${1} is empty/not exist... (ex: /dev/ttyUSB0)\e[0m"
   exit 0
fi


picocom -b ${SPEED} ${DRIVE}
