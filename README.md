# Arch Installer

Если уже установлен Arch Linux, то ставим пакет:

```zsh
$ yay -S arch-install-scripts
```

Далее монтируем `/boot/efi`, `/home`, `/var/swap` и запускаем `./install/arch-install.sh`.

Справка по аргументам:

```zsh
$ ./install/arch-install.sh -h
```

После установки, заходим под пользователем и запускаем `./install/post-install.sh`.
