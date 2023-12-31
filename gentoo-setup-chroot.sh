#!/bin/bash

# In ChRoot
source /etc/profile

# Repositories Sync
emerge-webrsync

# Portage Configure Set
CORES=`grep cpu.cores /proc/cpuinfo | sort -u | sed 's/[^0-9]//g'`
JOBS=`bc <<< "scale=0; 10*((1.4*${CORES})+0.5)/10;"`
cat <<EOF > /etc/portage/make.conf
# These settings were set by the catalyst build script that automatically built this stage.
# Please consult /usr/share/portage/config/make.conf.example for a more detailed example.
COMMON_FLAGS="-O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# NOTE: This stage was built with the bindist Use flag enabled

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C.utf8

# autounmask-write disable protects
CONFIG_PROTECT_MASK="/etc/portage/package.accept_keywords/zzz.keywords /etc/portage/package.use/zzz.use"

# add option autounmask-write and continue
EMERGE_DEFAULT_OPTS="--autounmask-write=y --autounmask-license=y --autounmask-continue=y --with-bdeps=y --verbose-conflicts"

# Add Compile Option
MAKEOPTS="-j $JOBS"

# Video Chip Setting
VIDEO_CARDS="amdgpu radeon"

# Accepted Licanse
ACCEPT_LICENSE="* -@EULA google-chrome"

# Accepted Keywords
ACCEPT_KEYWORDS="~amd64"

# Mirror Setting
GENTOO_MIRRORS="http://ftp.iij.ad.jp/pub/linux/gentoo/ https://ftp.jaist.ac.jp/pub/Linux/Gentoo/ http://ftp.jaist.ac.jp/pub/Linux/Gentoo/ https://ftp.riken.jp/Linux/gentoo/ http://ftp.riken.jp/Linux/gentoo/"

# Language Setting
L10N="ja"
EOF

cat <<EOF > /etc/portage/package.use/gcc.use
sys-devel/gcc openmp
EOF

# GIT Install
emerge dev-vcs/git

# Generate Locale JP
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
locale-gen
eselect locale set 4
source /etc/profile

# Timezone Setting
echo "Asia/Tokyo" > /etc/timezone
emerge --config sys-libs/timezone-data

# DHCP Service Setup
emerge sys-apps/mlocate net-misc/dhcpcd
rc-update add dhcpcd default

# NTPD Setting
emerge net-misc/ntp
mv /etc/ntp.conf /etc/ntp.conf.old
mv /etc/conf.d/ntp-client /etc/conf.d/ntp-client.old

# NTPD Server Select
cat <<EOF > /etc/ntp.conf
server ntp.nict.jp
EOF

# NTPD Client Setting
cat <<EOF > /etc/conf.d/ntp-client
NTPCLIENT_CMD="ntpdate"
NTPCLIENT_OPTS="-s -d -u "ntp.nict.jp"
EOF

# NTPD Booted Start
rc-update add ntpd default

cat <<EOF > /etc/portage/package.use/common.use
media-libs/libsndfile minimal
EOF

# ESelect Repository Enable
emerge eselect-repository

# KDE Repository Add
eselect repository enable kde

# Gentoo Repository Setup
mkdir -p /etc/portage/repos.conf/
rm -rf /var/db/repos/gentoo
cat <<EOF > /etc/portage/repos.conf/gentoo.conf
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo-mirror/gentoo
sync-git-verify-commit-signature = yes
auto-sync = yes
sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc
sync-openpgp-keyserver = hkps://keys.gentoo.org
sync-openpgp-key-refresh-retry-count = 40
sync-openpgp-key-refresh-retry-overall-timeout = 1200
sync-openpgp-key-refresh-retry-delay-exp-base = 2
sync-openpgp-key-refresh-retry-delay-max = 60
sync-openpgp-key-refresh-retry-delay-mult = 4
EOF

# Repositories Sync
emerge --sync

# KDE Repository Accept Keywords Setting
cd /etc/portage/package.accept_keywords/
find /var/db/repos/kde/Documentation/package.accept_keywords/ -maxdepth 1 -name '*.keywords' -not -name '*live*' -not -name '*9999*' | xargs -L 1 ln -s

# First Stage System Upgrade
emerge --verbose --update --deep --changed-use --changed-deps=y @world

cat <<EOF >> /etc/portage/make.conf

USE="ibus dbus cjk gd emoji qt5 qt6 kde openmp dvd pulseaudio alsa cdr vulkan"
EOF

cat <<EOF > /etc/portage/package.use/cmake.use
dev-util/cmake -qt5
EOF

cat <<EOF > /etc/portage/package.use/grub.use
sys-boot/grub mount
EOF

cat <<EOF > /etc/portage/package.use/kde-plasma.use
# KDE Plasma
kde-plasma/plasma-meta discover flatpak grub
dev-qt/qttools qdbus designer

# KDE Gear 23.04 on KF6
kde-apps/kde-apps-meta accessibility admin -education -games -graphics multimedia -network pim -sdk utils
kde-apps/kdenetwork-meta -bittorrent -dropbox -samba -screencast -webengine
kde-apps/kdeutils-meta -cups
EOF

# Second Stage System Upgrade
emerge --verbose --update --deep --changed-use --changed-deps=y @world

# Setup Japanese Input Methods
emerge media-fonts/kochi-substitute media-fonts/ja-ipafonts media-fonts/vlgothic media-fonts/mplus-outline-fonts media-fonts/monafont media-fonts/sazanami fontconfig app-i18n/mozc

# Display Manager Install
emerge x11-misc/sddm gui-libs/display-manager-init

# Display Manager Setting
cat <<EOF > /etc/conf.d/display-manager
CHECKVT=7
DISPLAYMANAGER="sddm"
EOF

# Display Manager Enable
rc-update add display-manager default

# KDE Plasma Install
emerge kde-plasma/plasma-meta kde-apps/kde-apps-meta kde-plasma/sddm-kcm

# Other Application
emerge app-office/calligra mail-client/thunderbird

# PulseAudio Daemon Setup
emerge --noreplace media-sound/pulseaudio-daemon

# Google Chrome Install
emerge www-client/google-chrome

# EPSON Printer Driver
emerge net-print/cups-meta

# CUPS Daemon Enable
rc-update add cupsd default

# Firmware Install
emerge sys-kernel/linux-firmware

# Linux Kernel
emerge sys-kernel/gentoo-kernel

# Grub2 Install
emerge --verbose sys-boot/grub

# Grub2 Boot Loader Install
grub-install --target=x86_64-efi --efi-directory=/boot

# Build Linux Kernel
grub-mkconfig -o /boot/grub/grub.cfg

# Make Gentoo User
useradd -m -G users,wheel,audio,cdrom,video -s /bin/bash gentoo
passwd gentoo
emerge app-admin/sudo
cat /var/tmp/patches/sudo_nopasswd.patch | patch -u /etc/sudoers

# Setting ibus
cat <<EOF > /home/gentoo/.xprofile
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx
EOF

chown gentoo:gentoo -R /home/gentoo/
