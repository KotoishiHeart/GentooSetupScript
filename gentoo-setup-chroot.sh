#!/bin/bash

# In ChRoot
source /etc/profile

# Repositories Sync
emerge-webrsync

# Portage Configure Set
CORES=`grep processor /proc/cpuinfo | wc -l`
JOBS=`bc <<< "scale=0; 10*((0.8*${CORES})+0.5)/10;"`
cat <<EOF > /etc/portage/make.conf
# These settings were set by the catalyst build script that automatically built this stage.
# Please consult /usr/share/portage/config/make.conf.example for a more detailed example.
COMMON_FLAGS="-O2 -march=znver4 -pipe"
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

# Platform Setting
GRUB_PLATFORMS="efi-64"

# Language Setting
L10N="ja"
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

# ESelect Repository Enable
emerge eselect-repository

# KDE Repository Add
eselect repository enable kde

# Original Profile Add
eselect repository add khgenrepo git https://github.com/KotoishiHeart/khgenrepo

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

cd /etc/portage/
rm make.profile
ln -s ../../var/db/repos/khgenrepo/profiles/default/linux/amd64/23.0/no-multilib/desktop make.profile

# KDE Repository Accept Keywords Setting
cd /etc/portage/package.accept_keywords/
FILES=`find . -xtype l`
for FILE in $FILES;
do
    rm -f $FILE
done

FILES=`find /var/db/repos/kde/Documentation/package.accept_keywords/ -name "*.keywords" -not -name "*9999*.keywords" -not -name "*live*.keywords"`
for FILE in $FILES;
do
    FILENAME=`basename $FILE`
    if [ ! -f $FILENAME ]; then
      ln -s $FILE
    fi
done

mkdir /etc/portage/package.unmask/
cd /etc/portage/package.unmask/
ln -s /var/db/repos/kde/Documents/package.unmask/kde-frameworks-6.1
ln -s /var/db/repos/kde/Documents/package.unmask/kde-gear-24.02
ln -s /var/db/repos/kde/Documents/package.unmask/kde-plasma-6.0

# System Upgrade
emerge --verbose --update --deep --newuse --changed-deps=y --with-bdeps=y @world

cat <<EOF >> /etc/portage/make.conf

USE="cjk emoji jumbo-build qt6 kf6compat -kaccounts -cdrom"
EOF

# Setup KDE Desktop
emerge plasma-meta kde-apps-meta

# Setup Japanese Input Methods
emerge media-fonts/kochi-substitute media-fonts/ja-ipafonts media-fonts/vlgothic media-fonts/mplus-outline-fonts media-fonts/monafont media-fonts/sazanami fontconfig app-i18n/mozc

# Display Manager Setting
cat <<EOF > /etc/conf.d/display-manager
CHECKVT=7
DISPLAYMANAGER="sddm"
EOF

# Display Manager Enable
rc-update add display-manager default

# Other Application
emerge app-office/calligra mail-client/thunderbird

# Google Chrome Install
emerge www-client/google-chrome

# EPSON Printer Driver
emerge net-print/cups-meta

# CUPS Daemon Enable
rc-update add cupsd default

# Firmware Install
emerge sys-kernel/linux-firmware

# Kernel Install 
emerge sys-kernel/installkernel
emerge sys-kernel/gentoo-sources
cd /usr/src/*/
cp /var/tmp/kernel/config .config
make olddefconfig
make $JOBS
make modules_install
make install

# Grub Setup
emerge sys-boot/grub os-prober
cat <<EOF >> /etc/default/grub
GRUB_DISABLE_OS_PROBER=false
EOF
grub-install --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg

# Make Gentoo User
useradd -m -G users,wheel,audio,cdrom,video -s /bin/bash gentoo
passwd gentoo
emerge app-admin/sudo
cat /var/tmp/patches/sudo_nopasswd.patch | patch -u /etc/sudoers

# Setting Autostart
mkdir -p /home/gentoo/.config/autostart/
cp /var/tmp/*.desktop /home/gentoo/.config/autostart/

chown gentoo:gentoo -R /home/gentoo.config/autostart/

# System Upgrade
emerge --verbose --update --deep --newuse --changed-deps=y --with-bdeps=y @world
