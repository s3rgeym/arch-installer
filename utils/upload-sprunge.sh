#!/usr/bin/env bash
# Author: Sergey M <yamldeveloper@proton.me>
# Загружает сниппет на аналог Pastebin'а
set -e
cd `dirname "$0"`
cat ../arch-install.sh | curl -sF 'sprunge=<-' http://sprunge.us
