#!/usr/bin/env bash
# Author: Sergey M <yamldeveloper@proton.me>
# Я не нашел способа выполнить этот скрипт во время установки
set -e

cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -Ssi --noconfirm
cd -
rm -rf /tmp/yay-bin

packages=(
  asdf-vm
  cht.sh
  fd
  firefox-nightly
  fzf
  gitflow-avh
  github-cli-bin
  gotop-bin
  htop
  httpie
  hub
  hyperfine
  jo
  jq
  mc
  neofetch
  nmap
  nvme-cli
  parallel
  pass
  pet-bin
  pwgen
  sqlmap
  thefuck
  tokei
  tor-browser
  ttf-cascadia-code
  ttf-fira-code
  ttf-fira-mono
  ttf-iosevka
  ttf-jetbrains-mono-git
  ttf-roboto
  ttf-roboto-mono
  vim-plug
  visual-studio-code-bin
  vi-vim-symlink
  whois
  wrk
  zplug
)

yay -si --noconfirm "\${packages[@]}"

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
