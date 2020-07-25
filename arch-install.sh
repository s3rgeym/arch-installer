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
  -d, --device    Device
  -m, --mount     Mountpoint
  -s, --step      Start from step

Steps:
  1) format device and mount partitions
  2) install base packages and Gnome
  3) generate /etc/fstab
  4) configure system
  5) install AUR packages and configure user
EOF
}

username='archlinux'
password='1qasw23ed'
device='/dev/nvme0n1'
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
    -d | --device)
      device="$2"
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

# TODO: добавить выбор DE

# case "$DESKTOP" in
#   kde )
#     pacman -S --noconfirm plasma plasma-nm kde-applications-meta ssdm
#     systemctl enable NetworkManager
#     systemctl enable sddm
#     ;;
#   xfce )
#     pacman -S --noconfirm xfce4 xfce4-goodies networkmanager network-manager-applet xfce4-notifyd gnome-keyring
#     sed -i /etc/lxdm/lxdm.conf -e 's;^# session=/usr/bin/startlxde;session=/usr/bin/startxfce4;g'
#     systemctl enable NetworkManager
#     systemctl enable lxdm
#     ;;
#   # Самый красивый и самый глючный. У меня сломался через пару дней после установки
#   deepin )
#     pacman -S --noconfirm deepin deepin-extra networkmanager lightdm
#     sed -i 's/^#greeter-session=.*/greeter-session=lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
#     systemctl enable NetworkManager
#     systemctl enable lightdm
#     ;;
#   * )
#     pacman -S --noconfirm gnome gnome-extra
#     systemctl enable NetworkManager
#     systemctl enable gdm
#     ;;

if [[ $step -le 2 ]]
then
  echo '########################################################################'
  echo '#                                                                      #'
  echo '# Step 2: install base packages and Gnome                              #'
  echo '#                                                                      #'
  echo '########################################################################'
  echo

  packages=(
    adapta-gtk-theme
    arc-icon-theme
    arc-gtk-theme
    # for qt apps
    # arc-kde-theme
    base
    base-devel
    btrfs-progs
    chromium
    # LUKS
    cryptsetup
    docker-compose
    efibootmgr
    exfat-utils
    fd
    fzf
    gimp
    git
    gnome
    gnome-extra
    gparted
    grub
    gvm
    htop
    jq
    libldm
    linux
    linux-firmware
    linux-headers
    man-db
    man-pages
    # materia-kde-theme for qt apps
    materia-gtk-theme
    mc
    mlocate
    mpv
    nano
    neofetch
    networkmanager-openvpn
    networkmanager-pptp
    noto-fonts
    noto-fonts-emoji
    ntfs-3g
    nvme-cli
    os-prober
    papirus-icon-theme
    pkgfile
    parallel
    pass
    proxychains-ng
    pwgen
    # настройка тем для qt-приложений
    qt5ct
    reflector
    rsync
    snapper
    systemd-swap
    telegram-desktop
    terminus-font
    ttf-fira-code
    ttf-fira-mono
    ttf-ibm-plex
    ttf-inconsolata
    ttf-roboto
    ttf-roboto-mono
    ttf-ubuntu-font-family
    tor
    # vim
    wget
    whois
    xorg
    zsh
  )

  set +e
  pacstrap "$mount" "${packages[@]}"
  set -e

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

cat << EOF > /etc/locale.gen
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
EOF

locale-gen

# localectl set-locale LANG=en_US.UTF-8
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

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

echo '[main]' >> /etc/NetworkManager/NetworkManager.conf
echo 'dns=none' >> /etc/NetworkManager/NetworkManager.conf

# DNS от Cloudflare
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

mkdir -p /var/swap /etc/systemd/swap.conf.d
echo 'swapfc_enabled=1' > /etc/systemd/swap.conf.d/myswap.conf
echo 'swapfc_path=/var/swap/' >> /etc/systemd/swap.conf.d/myswap.conf
systemctl enable systemd-swap

systemctl enable man-db.timer

systemctl enable fstrim.timer

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

# запрещаем mlocate индексировать снапшоты
sed -ir 's/^PRUNENAMES = "/\0.snapshots /g' /etc/updatedb.conf

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

echo 'export QT_QPA_PLATFORMTHEME="qt5ct"' > /etc/profile.d/qt5ct.sh

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
  echo 'Completed!'
fi

user_commands=$(cat << COMMANDS
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd -
rm -rf /tmp/yay-bin

# problem importing keys fix
gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org

# TODO: убрать все пакеты из стандартного репо
packages=(
  asdf-vm
  cht.sh
  # firefox-nightly
  gitflow-avh
  github-cli-bin
  chrome-gnome-shell
  gotop-bin
  httpie
  hub
  hyperfine
  micro
  pet-bin
  thefuck
  tokei
  tor-browser
  ttf-cascadia-code
  ttf-jetbrains-mono-git
  vim-plug
  visual-studio-code-bin
  vi-vim-symlink
  wrk
  xcursor-breeze
  zplug
)

yay -S --noconfirm "\${packages[@]}"

mkdir -p ~/.config/fontconfig

cat > ~/.config/fontconfig/fonts.conf << EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Noto Sans Mono</family>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
</fontconfig>
EOF

cat > ~/.config/chromium-flags.conf << EOF
--ignore-gpu-blacklist
--enable-gpu-rasterization
--enable-native-gpu-memory-buffers
--enable-zero-copy
--disable-gpu-driver-bug-workarounds
EOF

COMMANDS
)

if [[ $step -le 5 ]]
then
  echo '########################################################################'
  echo '#                                                                      #'
  echo '# Step 5: install AUR packages and configure user                      #'
  echo '#                                                                      #'
  echo '########################################################################'
  echo

  # временно отключаем запрос пароля
  # `echo "password" | sudo -S <command>` не всегда работает
  arch-chroot "$mount" bash -c "echo '$username ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/$username"
  arch-chroot "$mount" su -l "$username" -c "$user_commands"
  arch-chroot "$mount" bash -c "rm /etc/sudoers.d/$username"
  echo 'Completed'
fi

echo
echo 'Finished. U can reboot'
