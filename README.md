# Arch Installer

Usage:

```zsh
$ ./arch-install.sh -h
```

Если уже установлен Arch Linux, то ставим пакет:

```zsh
$ yay -S arch-install-scripts
```

Далее монтируем `/boot/efi`, `/home`, `/var/swap` и запускаем:

```zsh

$ sudo ./arch-install.sh --username <newuser> --password <newuser-pass> --mount /path/to/mnt --step 2
```
