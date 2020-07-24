#!/usr/bin/env bash
# Author: Sergey M <yamldeveloper@proton.me>
set -e
die() { echo "$*" 1>&2 ; exit 1; }

usage() {
cat << EOF
    _             _       ___           _        _ _
   / \   _ __ ___| |__   |_ _|_ __  ___| |_ __ _| | | ___ _ __
  / _ \ | '__/ __| '_ \   | || '_ \/ __| __/ _\` | | |/ _ \ '__|
 / ___ \| | | (__| | | |  | || | | \__ \ || (_| | | |  __/ |
/_/   \_\_|  \___|_| |_| |___|_| |_|___/\__\__,_|_|_|\___|_|

Usage:
  bash `basename "$0"` [options]

Args:
  -h, --help      Show help and exit
  -u, --username  Username
  -p, --password  Password
  -H, --hostname  Hostname
  -m, --mount     Mountpoint
  -s, --step      Start from step

Steps:
  1) format device and mount partitions
  2) install base packages and Gnome
  3) generate /etc/fstab
  4) configure system
EOF
}

username='archlinux'
password='1qasw23ed'
mount='/mnt'
step=1

while [ $# -gt 0 ]
do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -u | --username)
      username="$2"
      shift
      ;;
    -p | --password)
      password="$2"
      shift
      ;;
    -H | --hostname)
      hostname="$2"
      shift
      ;;
    -m | --mount | --mount)
      mount="$2"
      shift
      ;;
    -s | --step)
      step="$2"
      shift
      ;;
    *)
      die "Unexpected argument"
      ;;
  esac
  shift
done

hostname="${hostname:=${username}-pc}"

echo "Username:                $username"
echo "Password:                `echo $password | sed -r 's/./*/g'`"
echo "Hostname:                $hostname"
echo "Mount point:             $mount"
echo

parted_commands=$(cat << EOF
mklabel gpt
mkpart primary fat32 1MiB 261MiB
set 1 esp on
mkpart primary btrfs 261MiB 100%
quit
EOF
)

if [[ $step -le 1 ]]
then
  echo '########################################################################'
  echo '#                                                                      #'
  echo '# Step 1: format device and mount partitions                           #'
  echo '#                                                                      #'
  echo '########################################################################'
  echo

  # чтобы случайно не убить данные на диске
  # exit 1

  # Размечаем диск
  umount -R "$mount" 2> /dev/null
  dd if=/dev/zero of="$device" bs=512K count=1

  parted "$device" <<< "$parted_commands"

  part_prefix="$device"

  if [[ $part_prefix == *nvme* ]]
  then
    part_prefix="${part_prefix}p"
  fi

  mkfs.fat -F32 -n ESP "${part_prefix}1"
  mkfs.btrfs -L Linux "${part_prefix}2"

  mount "${part_prefix}2" "$mount"
  btrfs subvolume create "$mount/@"
  btrfs subvolume create "$mount/@home"
  btrfs subvolume create "$mount/@swap"
  umount "$mount"

  # если процессор слабый, то можно уменьшить уровень сжатия, либо заменить zstd
  # на lzo
  opts='rw,noatime,compress=zstd:3,ssd,space_cache'

  mount -o "$opts,subvol=@" "${part_prefix}2" "$mount"

  mkdir -p "$mount"/{boot/efi,home,var/swap}
  mount "${part_prefix}1" "$mount/boot/efi"

  mount -o "$opts,subvol=@home" "${part_prefix}2" "$mount/home"
  mount -o "$opts,subvol=@swap" "${part_prefix}2" "$mount/var/swap"

  echo 'Completed!'
fi

if [[ $step -le 2 ]]
then
  echo '########################################################################'
  echo '#                                                                      #'
  echo '# Step 2: install base packages and Gnome                              #'
  echo '#                                                                      #'
  echo '########################################################################'
  echo

  packages=(
    base
    base-devel
    btrfs-progs
    chromium
    cryptsetup
    docker-compose
    efibootmgr
    exfat-utils
    git
    gnome
    gnome-extra
    grub
    libldm
    linux
    linux-firmware
    linux-headers
    man-db
    man-pages
    mlocate
    nano
    networkmanager-openvpn
    networkmanager-pptp
    noto-fonts
    noto-fonts-emoji
    ntfs-3g
    os-prober
    pkgfile
    proxychains-ng
    reflector
    snapper
    systemd-swap
    terminus-font
    tor
    vim
    wget
    xorg
    zsh
  )

  pacstrap "$mount" "${packages[@]}"
  echo 'Completed!'
fi

if [[ $step -le 3 ]]
then
  echo '########################################################################'
  echo '#                                                                      #'
  echo '# Step 3: generate /etc/fstab                                          #'
  echo '#                                                                      #'
  echo '########################################################################'
  echo

  genfstab -U "$mount" >> "$mount/etc/fstab"
  echo 'Completed!'
fi

configure_system_commands=$(cat << COMMANDS
timedatectl set-timezone UTC
timedatectl set-ntp on
timedatectl set-local-rtc 1

locale-gen en_US en_US.UTF-8 ru_RU ru_RU.UTF-8
localectl set-locale LANG=en_US.UTF-8

cat > /etc/vconsole.conf << EOF
LOCALE="en_US.UTF-8"
KEYMAP="ruwin_alt_sh-UTF-8"
FONT="ter-v18b"
CONSOLEMAP=""
TIMEZONE="UTC"
HARDWARECLOCK="UTC"
USECOLOR="yes"
EOF

echo "$hostname" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
EOF

cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

useradd -m -g users -G wheel -s /bin/zsh $username
echo "$username:$password" | chpasswd
passwd -l root

echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/10-wheel

cat > /etc/sudoers.d/10-defaults << EOF
Defaults env_keep += "EDITOR SYSTEMD_EDITOR"
Defaults timestamp_timeout=30
EOF

chmod 0440 /etc/sudoers.d/*

grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

cat > /etc/sysctl.d/99-sysctl.conf << EOF
vm.swappiness = 10
vm.vfs_cache_pressure = 1000
EOF

systemctl enable man-db.timer

systemctl enable fstrim.timer

mkdir -p /var/swap /etc/systemd/swap.conf.d
echo 'swapfc_enabled=1' > /etc/systemd/swap.conf.d/myswap.conf
echo 'swapfc_path=/var/swap/' >> /etc/systemd/swap.conf.d/myswap.conf
systemctl enable systemd-swap

pkgfile --update
systemctl enable pkgfile-update.timer

cat > /etc/snapper/config-templates/custom << EOF
# subvolume to snapshot
SUBVOLUME="/"
# filesystem type
FSTYPE="btrfs"
# btrfs qgroup for space aware cleanup algorithms
QGROUP=""
# fraction of the filesystems space the snapshots may use
SPACE_LIMIT="0.5"
# fraction of the filesystems space that should be free
FREE_LIMIT="0.2"
# users and groups allowed to work with config
ALLOW_USERS=""
ALLOW_GROUPS=""
# sync users and groups from ALLOW_USERS and ALLOW_GROUPS to .snapshots
# directory
SYNC_ACL="no"
# start comparing pre- and post-snapshot in background after creating
# post-snapshot
BACKGROUND_COMPARISON="yes"
# run daily number cleanup
NUMBER_CLEANUP="yes"
# limit for number cleanup
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
# create hourly snapshots
TIMELINE_CREATE="yes"
# cleanup hourly snapshots after some time
TIMELINE_CLEANUP="yes"
# limits for timeline cleanup
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="3"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
# cleanup empty pre-post-pairs
EMPTY_PRE_POST_CLEANUP="yes"
# limits for empty pre-post-pair cleanup
EMPTY_PRE_POST_MIN_AGE="1800"
EOF

snapper -c root create-config -t custom /
snapper -c home create-config -t custom /home

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

sed -r 's/^(PRUNENAMES = "[^"]+)/\1 .snapshots/' /etc/updatedb.conf

systemctl enable updatedb.timer

cat > /usr/lib/systemd/system/reflector.service << EOF
[Unit]
Description=Pacman mirrorlist update
Requires=network.target
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --protocol https --latest 30 --number 20 --sort rate --save /etc/pacman.d/mirrorlist
[Install]
RequiredBy=network.target
EOF

cat > /usr/lib/systemd/system/reflector.timer << EOF
[Unit]
Description=Run reflector weekly
[Timer]
OnCalendar=weekly
AccuracySec=12h
Persistent=true
[Install]
WantedBy=timers.target
EOF

systemctl enable reflector.timer

cat > /etc/systemd/system/ldmtool.service << EOF
[Unit]
Description=Windows Dynamic Disk Mount
Before=local-fs-pre.target
DefaultDependencies=no
[Service]
Type=simple
User=root
ExecStart=/usr/bin/ldmtool create all
[Install]
WantedBy=local-fs-pre.target
EOF

systemctl enable ldmtool.service

systemctl enable gdm
systemctl enable NetworkManager
systemctl enable tor
COMMANDS
)

if [[ $step -le 4 ]]
then
  echo '########################################################################'
  echo '#                                                                      #'
  echo '# Step 4: configure system                                             #'
  echo '#                                                                      #'
  echo '########################################################################'
  echo

  arch-chroot "$mount" bash <<< "$configure_system_commands"
  echo 'Completed.'
fi

echo
echo 'Reboot and run ./install/post-install.sh'
