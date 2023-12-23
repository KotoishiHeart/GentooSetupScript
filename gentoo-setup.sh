#!/bin/bash

# fdisk process (temp)
<< COMMENTOUT
Welcome to fdisk (util-linux 2.37.2).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS disklabel with disk identifier 0x35d3a221.

Command (m for help): g
Created a new GPT disklabel (GUID: B8A55BBE-10FF-9C42-A8BD-44DF42D433C3).

Command (m for help): n
Partition number (1-128, default 1):
First sector (2048-20971486, default 2048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-20971486, default 20971486): +1GiB

Created a new partition 1 of type 'Linux filesystem' and of size 1 GiB.

Command (m for help): t
Selected partition 1
Partition type or alias (type L to list all): 1
Changed type of partition 'Linux filesystem' to 'EFI System'.

Command (m for help): n
Partition number (2-128, default 2):
First sector (2099200-20971486, default 2099200):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2099200-20971486, default 20971486): +32GiB

Created a new partition 2 of type 'Linux filesystem' and of size 32 GiB.

Command (m for help): t
Partition number (1,2, default 2): 2
Partition type or alias (type L to list all): 19

Changed type of partition 'Linux filesystem' to 'Linux swap'.

Command (m for help): n
Partition number (3-128, default 3):
First sector (6293504-20971486, default 6293504):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (6293504-20971486, default 20971486):

Created a new partition 3 of type 'Linux filesystem' and of size *** GiB.

Command (m for help): w
The partition table has been altered.
Syncing disks.
COMMENTOUT

# Require: Mounting the system drive and bootloader drive
# マウントされていないと失敗する

mountpoint -q /mnt/gentoo/
ret_root=$?

mountpoint -q /mnt/gentoo/boot/
ret_boot=$?

GENTOO_TARBALL_MIRROR_ROOT=http://ftp.iij.ad.jp/pub/linux/gentoo/releases/amd64/autobuilds/
GENTOO_TARBALL_LASTEST=`curl ${GENTOO_TARBALL_MIRROR_ROOT}latest-stage3-amd64-desktop-openrc.txt --silent | grep stage | cut -d' ' -f 1`

if [ $ret_root = 0 ] && [ $ret_boot = 0 ]; then
    # User Script Copy
    mkdir -p /mnt/gentoo/usr/local/bin/
    mkdir -p /mnt/gentoo/var/tmp/
    cp gentoo-setup-chroot.sh /mnt/gentoo/
    cp myscripts/gentoo-update /mnt/gentoo/usr/local/bin/
    cp myscripts/linux-update /mnt/gentoo/usr/local/bin/
    cp --parents patches/sudo_nopasswd.patch /mnt/gentoo/var/tmp/
    
    # UnPackage
    cd /mnt/gentoo/
    wget ${GENTOO_TARBALL_MIRROR_ROOT}${GENTOO_TARBALL_LASTEST}
    # Stage Tarball UnPackage
    tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
    # Resolv.conf Copy
    cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
    # Autowrite File
    touch /mnt/gentoo/etc/portage/package.accept_keywords/zzz.keywords
    touch /mnt/gentoo/etc/portage/package.use/zzz.use
    # Add Run Permission
    chmod a+x ./gentoo-setup-chroot.sh
    chmod a+x ./usr/local/bin/*
    # Mount System Point
    mount --types proc /proc /mnt/gentoo/proc
    mount --rbind /sys /mnt/gentoo/sys
    mount --make-rslave /mnt/gentoo/sys
    mount --rbind /dev /mnt/gentoo/dev
    mount --make-rslave /mnt/gentoo/dev
    mount --rbind /run /mnt/gentoo/run
    mount --make-rslave /mnt/gentoo/run
    # Setup Start
    chroot /mnt/gentoo /gentoo-setup-chroot.sh
elif [ $ret_root = 1 ]; then
    echo "ERROR: The drive for installing Gentoo Linux is not mounted in the /mnt/gentoo/ folder."
else
    echo "ERROR: The drive for installing the boot manager and Linux kernel is not mounted in the /mnt/gentoo/boot/ folder."
fi

echo "Setup Complete"

# Cleanup
rm ./stage3-*.tar.*
rm ./gentoo-setup-chroot.sh
