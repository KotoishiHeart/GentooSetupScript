#!/bin/bash

# /mnt/gentoo にインストール先のドライブをマウントして実行する。
# マウントされていないと失敗する

mountpoint -q /mnt/gentoo/
ret_root=$?

mountpoint -q /mnt/gentoo/boot/
ret_boot=$?

PREFIX_HARDENED="-hardened"
PREFIX_NOMULTILIB="-nomultilib"
PREFIX_INITSYSTEM="-openrc"

GENTOO_TARBALL_MIRROR_ROOT=http://ftp.iij.ad.jp/pub/linux/gentoo/releases/amd64/autobuilds/
GENTOO_TARBALL_LASTEST=`curl ${GENTOO_TARBALL_MIRROR_ROOT}latest-stage3-amd64${PREFIX_HARDENED}${PREFIX_NOMULTILIB}${PREFIX_INITSYSTEM}.txt --silent | grep stage | cut -d' ' -f 1`

if [ $ret_root = 0 ] && [ $ret_boot = 0 ]; then
    cd /mnt/gentoo/
    wget ${GENTOO_TARBALL_MIRROR_ROOT}${GENTOO_TARBALL_LASTEST}
    # Stage Tarball UnPackage
    tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
    # Resolv.conf Copy
    cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
    # Step2 Run Script Download
    wget -O ./gentoo-setup-chroot.sh https://raw.githubusercontent.com/KotoishiHeart/GentooSetupScripts/main/gentoo-setup-chroot.sh
    chmod a+x ./gentoo-setup-chroot.sh
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
