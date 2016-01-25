#! /bin/bash

OS_TYPE=`uname`
LOG="/tmp/${0}.$$.log"
PATH=/usr/bin:/usr/sbin/:${PATH}
HDIUTIL=/usr/bin/hdiutil
DISKUTIL=/usr/sbin/diskutil
ISO_IMG=$1
DMG_IMG=
CURRENT_DISKS=
SELECTED_DISK=
SELECTED_RDISK=

_preempt() {
  clear
  case $OS_TYPE in
    Darwin)
      echo ''
      echo ''
      ;;
    *)
      echo ''
      echo  "===>>> ${OS_TYPE} not supported. Please run on Mac OSX"
      echo ''
      exit 1;
      ;;
  esac

  echo '+-Burn-ISO-To-USB--------------------------------------------------+'
  echo '| Before continuing, it is recommended all connected external      |'
  echo '| drives be removed. You will be prompted on when to insert the    |' 
  echo '| desired drive.                                                   |'
  echo '+------------------------------------------------------------------+'
  echo '| Go ahead -- remove all connected drives now.                     |'
  echo '+------------------------------------------------------------------+'
  echo ''
  read -p 'Are you sure you want to continue (Yes/No) [No]? ' ANS

  case ${ANS} in
    [Yy][Ee][Ss])
      echo 'Proceeding...'
      echo ''
      ;;
    *)
      exit 1
      ;;
  esac
}

_selectExternalDisk() {
  if [ -z ${SELECTED_DISK} ]; then
    # Note: we grep for 'extern[al]' to avoid any accidents with internal disks.
    EXTERN_DISKS="`${DISKUTIL} list|grep 'extern'|awk '{print $1}'|paste -s -d' ' -`"
    THIS_MANY="`wc -w <<< ${EXTERN_DISKS}|sed 's/ //g'`"
    if [ -z $EXTERN_DISKS ]; then
      echo '===>>> No external disks connected. Please try again.'
    else
      echo "===>>> Found (${THIS_MANY}) connected external disk(s):"
      for d in $EXTERN_DISKS; do
        DISK_NAME="`${DISKUTIL} info ${d}|grep 'Media Name'|cut -f2 -d':'|sed 's/^[ ] *//g'`"
        DISK_SIZE="`${DISKUTIL} info ${d}|grep 'Total Size'|awk '{print $3,$4}'`"
        echo "${d}: ${DISK_NAME} (${DISK_SIZE})"
      done

      echo ''
      select SELECTED_DISK in $EXTERN_DISKS; do break; done
      SELECTED_RDISK=/dev/r${SELECTED_DISK##/dev/}
      echo "Selected: ${SELECTED_DISK}"
      echo ''
    fi
  fi
}

_selectISOImage() {
  echo ''
  read -p 'Enter full path for ISO Image to burn: ' ISO_IMG

  while [ ! -f ${ISO_IMG} ] || [ -z ${ISO_IMG} ]; do
    read -p 'Enter *valid* full path for ISO Image to burn: ' ISO_IMG
  done
}

_convertISO() {
  echo ''

  DMG_IMG=~/"`basename ${ISO_IMG%%.[Ii][Ss][Oo]}`.dmg"
  DMG_IMG_HEAD=~/"`basename ${ISO_IMG%%.[Ii][Ss][Oo]}`"
  if [ -f ${DMG_IMG} ]; then
    read -p "===>>> Overwrite existing image: ${DMG_IMG} [N/y]? " ANS

    case ${ANS:-n} in 
      [Yy]|[Yy][Ee][Ss])
        echo '===>>> Converting ISO to DMG image. This may take awhile ...'
        rm -f ${DMG_IMG}
        ${HDIUTIL} convert -format UDRW -o ${DMG_IMG_HEAD} ${ISO_IMG}
        if [ $? -eq 0 ]; then
          echo 'Done.'
        else
          echo 'Abort. Please check the command for converting the iso image.'
          echo "${HDIUTIL} convert -format UDRW -o ${DMG_IMG} ${ISO_IMG}"
          exit 1
        fi
        ;;

      [Nn]|[Nn][Oo])
        ;;
      *)
        ;;
    esac

  else
    # Note: Refactor this duplicate later
    ${HDIUTIL} convert -format UDRW -o ${DMG_IMG_HEAD} ${ISO_IMG}
    if [ $? -eq 0 ]; then
      echo 'Done.'
    else
      echo 'Abort. Please check the command for converting the iso image.'
      echo "${HDIUTIL} convert -format UDRW -o ${DMG_IMG} ${ISO_IMG}"
      exit 1
    fi

  fi
}

_promptForMedia() {
  if [ -z $SELECTED_DISK ]; then
    echo ''
    read -p 'Insert flash media -- when prompted, select 'Ignore', then continue by typing (C) when ready: ' ANS

    case ${ANS} in
      [Cc])
        echo '===>>> Checking disk...'
        ;;
      *)
        _promptForMedia
        ;;
    esac
  fi
}

_unmountSelectedDisk() {
  ${DISKUTIL} unmountDisk ${SELECTED_DISK}

  if [ $? -eq 0 ]; then
    echo 'Proceeding ...'
  else
    echo 'Could not proceed.'
    # Add more information on why later.
    exit 1
  fi
}

_flashMedia() {
  echo ''
  echo 'The following will be executed:'
  echo "sudo dd if=${DMG_IMG} of=${SELECTED_RDISK} bs=1m"
  echo ''
  read -p 'Are you sure you want to continue (Yes/No)? ' ANS

  case ${ANS} in
    [Yy][Ee][Ss])
      echo ''
      echo 'Proceeding ...'
      sudo dd if=${DMG_IMG} of=${SELECTED_RDISK} bs=1m
      echo 'Done. You may eject the disk if prompted and remove the media physically if so desired'
      ;;

    [Nn][Oo])
      echo 'No changes done'
      exit 1
      ;;

    *)
      _flashMedia
      ;;

  esac
}

_run() {
  _preempt
  _selectExternalDisk
  _selectISOImage
  _convertISO
  _promptForMedia
  _selectExternalDisk
  _unmountSelectedDisk
  _flashMedia
}


# Main
# ---------
_run

# ----
# Author: Samuel A. WINFUL <samuel@winful.com>
#
# Notes:
#   * URL: http://www.ubuntu.com/download/desktop/create-a-usb-stick-on-mac-osx
# 
# Steps:
# ------
#   1. Convert the .iso file to .img 
#      hdiutil convert -format UDRW -o ~/path/to/target.img ~/path/to/ubuntu.iso
#
#   2. Get the current list of devices
#      diskutil list
#
#   3. Insert flash media
#
#   4. *Again* Get the current list of devices
#      diskutil list
#
#   5. Replace N with the disk number from the last command
#      diskutil unmountDisk /dev/diskN
# 
#   6. Execute
#      sudo dd if=/path/to/downloaded.img of=/dev/rdiskN bs=1m
#
