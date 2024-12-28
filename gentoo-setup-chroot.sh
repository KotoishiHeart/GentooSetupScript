#!/bin/bash

# In ChRoot
source /etc/profile

# Repositories Sync
emerge-webrsync

# Portage Configure Set
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
EMERGE_DEFAULT_OPTS="--autounmask-write=y --autounmask-license=y --autounmask-continue=y --with-bdeps=y --verbose-conflicts --verbose --quiet-build --keep-going"

# CPU Flags
CPU_FLAGS_X86="aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse3 sse4_1 sse4_2 sse4a ssse3 vpclmulqdq"

# Add Compile Option
MAKEOPTS="-j 20"

# Video Chip Setting
VIDEO_CARDS="amdgpu radeonsi radeon"

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

# Use Flags
USE="wayland-only"
EOF

# Need eclean
emerge app-portage/gentoolkit

# GIT Install
emerge dev-vcs/git

# Bash Support Install
emerge app-shells/bash-completion

# IO Scheduler Install
emerge sys-block/io-scheduler-udev-rules

# Smart Live Rebuild
emerge app-portage/smart-live-rebuild

# Generate Locale JP
echo "ja_JP.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set 4
source /etc/profile

# Keymap Setting
sed -i -e 's/keymap="us"/keymap="jp106"/' /etc/conf.d/keymaps
rc-update add keymaps boot

# Timezone Setting
echo "Asia/Tokyo" > /etc/timezone
emerge --config sys-libs/timezone-data

# DHCP Service Setup
emerge sys-apps/mlocate net-misc/dhcpcd
rc-update add dhcpcd default

# NTPD Setting
emerge net-misc/chrony
cat <<EOF > /etc/chrony/chrony.conf
# Use public NTP servers from the pool.ntp.org project.
pool ntp.nict.jp iburst

# In first three updates step the system clock instead of slew
# if the adjustment is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

hwclockfile /etc/adjtime
EOF

# Chronyd Booted Start
rc-update add chronyd default

# ESelect Repository Enable
emerge eselect-repository

# Gentoo Repository Setup
eselect repository enable gentoo

# Original Profile Add
eselect repository add custom_profile git https://github.com/KotoishiHeart/khcustomprofile/

# Add Repository Setup
eselect repository enable kde
eselect repository enable guru
eselect repository enable qt
eselect repository enable catalyst

# Repositories Sync
emaint sync --repo custom_profile
emaint sync --repo kde
emaint sync --repo guru
emaint sync --repo qt
emaint sync --repo catalyst

# System Upgrade
emerge --update --deep --newuse --changed-deps=y --with-bdeps=y @world

# Custom Profile Set
cd /etc/portage/
rm make.profile
ln -s ../../var/db/repos/custom_profile/profiles/default/linux/amd64/23.0/no-multilib/desktop/plasma make.profile

# Sound Mode Change
emerge --unmerge media-video/pipewire media-sound/pulseaudio
emerge --noreplace media-sound/pulseaudio-daemon

# Change no-multilib desktop profile
emerge --update --deep --newuse --changed-deps=y --with-bdeps=y @world

# Setup KDE Desktop
emerge plasma-meta kde-apps-meta app-i18n/mozc

# Setup Japanese Input Methods
emerge media-fonts/fonts-meta media-fonts/kochi-substitute media-fonts/vlgothic media-fonts/mplus-outline-fonts media-fonts/sazanami

# Display Manager Setting
cat <<EOF > /etc/conf.d/display-manager
CHECKVT=7
DISPLAYMANAGER="sddm"
EOF

# Display Manager Enable
rc-update add display-manager default

# Other Application
emerge mail-client/thunderbird

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
make -j 20
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
chown gentoo:gentoo -R /home/gentoo/.config/autostart/

rm -rf /varr/db/repos/gentoo
emerge --sync

# System Upgrade
emerge --update --deep --newuse --changed-deps=y --with-bdeps=y @world

# CleanUp
emerge --depclean
eclean --deep distfiles
eclean --deep packages

find /var/tmp/portage/ -maxdepth 2
rm -rf /var/tmp/portage/*
rm -rf /var/cache/distfiles/*
rm -rf /var/cache/binpkgs/*
