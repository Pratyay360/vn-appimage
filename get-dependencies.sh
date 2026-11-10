#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"

pacman -Syu --noconfirm 7zip unzip wget msitools fuse3

if command -v fusermount3 >/dev/null 2>&1; then
	sudo chmod u+s "$(command -v fusermount3)"
	if ! command -v fusermount >/dev/null 2>&1; then
		sudo ln -sf "$(command -v fusermount3)" /usr/bin/fusermount 2>/dev/null || true
	fi
elif command -v fusermount >/dev/null 2>&1; then
	sudo chmod u+s "$(command -v fusermount)"
fi
