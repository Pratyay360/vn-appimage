#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=0.4.2 # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export APPNAME=vn-editor # change the application name here
# Desktop + icon live under AppDir/ (AppDir/APPNAME.desktop, AppDir/APPNAME.svg|.png).
# quick-sharun picks them up automatically — no DESKTOP/ICON env needed.
# MAIN_EXE is always required — the .exe filename identifying your app.
# Used for StartupWMClass (window matching) regardless of which payload
# strategy you use, and as the launcher's fallback search target when
# RUN_EXE is not set.
export MAIN_EXE=vn_editor.exe

# Build-time extraction (see the App payload examples below).
# The installer.exe is a PE executable that embeds a ZIP archive,
# so 7z needs -tzip to extract it correctly.
# Leave INSTALL_URL and RUN_EXE empty for this approach.
INSTALL_URL=
RUN_EXE=

# Silent/unattended flags for the runtime-install .exe or .msi (space-
# separated). Used only when INSTALL_URL points at an installer — archives
# (.zip/.7z/…) ignore this. Leave empty for built-in defaults:
#   .exe → /S /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
#   .msi → /qn /norestart
# Examples:
#   INSTALL_FLAGS="/SILENT /NORESTART"           # Inno Setup
#   INSTALL_FLAGS="/S"                           # NSIS
#   INSTALL_FLAGS="/quiet /norestart"            # MSI (msiexec)
INSTALL_FLAGS=

# Winetricks verbs your app needs to work at all (e.g. .NET, VC++
# runtimes, specific fonts) — space-separated winetricks verb names. Runs
# once on a fresh WINEPREFIX, before the app installs/launches. Leave
# empty if your app doesn't need any. See README "Winetricks verbs".
TRICKS=

# Wine env var defaults, shown here at their actual default values — these
# are what the hook uses out of the box. Change them if your app needs
# something different (e.g. WINEDLLOVERRIDES to disable a misbehaving DLL,
# WINEDEBUG to trace calls during development). Both stay overridable at
# runtime via env regardless of what's set here.
#   mscoree=              — disable Wine Mono
#   mshtml=               — disable Wine Gecko
#   winemenubuilder.exe=d — avoid menu-builder hangs under AppImage
WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d"
WINEDEBUG="fixme-all"

# Share system32/syswow64/winsxs (and Wine Mono trees if Mono was installed)
# across apps via a slim template prefix. Default on — set to 0 to disable.
# Template wineboot uses WINEDLLOVERRIDES above:
#   mscoree=  — disable Wine Mono
#   mshtml=   — disable Wine Gecko
# Drop mscoree= if you want Mono installed and shared in the template.
WINEPREFIX_DEDUP=1

# WINEPREFIX defaults to $DATADIR/wine-appimage/apps/$APPNAME/$WINEPREFIX_SUBDIR
# (DATADIR is typically ~/.local/share). Change the value below if you need
# a different subdir name (e.g. to match an existing installation's layout).
WINEPREFIX_SUBDIR=".wine"

# Shared wine: this template does not bundle wine. AppDir/bin/00-get-wine-appimage.hook
# finds or downloads pkgforge-dev/wine-AppImage at runtime. Override with
# WINE_APPIMAGE_PATH if needed. Do not copy wine/wineserver into AppDir/bin.

# DWARFS compression for the final AppImage. The payload is ~1.2 GB and
# mkdwarfs' defaults (zstd:level=22, 12 writer workers, 12 MB hash windows)
# get OOM-killed on machines with ~5 GB free RAM — which silently truncates
# the AppImage to a few MB. Fewer workers + lower level trades a little
# compression ratio for reliability. Override via env if your build box has
# RAM to spare (e.g. DWARFS_COMP="zstd:level=22 -N 8 -W 12").
DWARFS_COMP="${DWARFS_COMP:-zstd:level=19 -N 3 -W 4}"
export DWARFS_COMP

# Only for patching desktop file
GENERIC_NAME="Wine Application" # example: Audio player
COMMENT_NAME="Wine-packaged Windows application" # example: Simple and powerful audio player
CATEGORIES_NAME="Utility;" # example: AudioVideo;Audio;Player;
MIMETYPES_NAME="" # example: audio/aac;audio/x-mp3;

# Pick ONE of the two approaches below (or use RUNTIME INSTALL in the hook
# instead — see README). Both examples use real, working URLs so you can
# see the pattern end-to-end; replace with your own app's download link.

# --- Example A: plain zip / portable build (build-time extraction) --------
# e.g. Notepad++'s portable zip release:
#
# mkdir -p "AppDir/share/$APPNAME"
# wget -q "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.7.1/npp.8.7.1.portable.x64.zip" \
#     -O app.zip
# unzip -q app.zip -d "AppDir/share/$APPNAME"

# --- Example B: installer .exe with embedded zip, extracted at build time ---
# Some installers are PE executables that embed a ZIP archive containing
# the actual app files (MSI, DLLs, etc.). Use 7z with -tzip to extract:
#
# mkdir -p "AppDir/share/$APPNAME"
# wget -q "https://fw-download.ubnt.com/data/vn-desktop-app/7d10-windows-0.4.2-bc374063-d84a-42c4-bcb2-eced5b125c95.exe" \
#     -O installer.exe
# 7z x -aos -tzip installer.exe -o"AppDir/share/$APPNAME" >/dev/null 2>&1
# rm -f installer.exe
# # Installer exe names often don't match the real Windows binary name —
# # rename here so it matches MAIN_EXE:
# # mv "AppDir/share/$APPNAME/some-installed-name.exe" "AppDir/share/$APPNAME/$MAIN_EXE"

# --- Example C: .msi installer, extracted at build time --------------------
# msiexec-based installers can be extracted directly with 7z too:
#
# mkdir -p "AppDir/share/$APPNAME"
# wget -q "https://example.com/download/${APPNAME}-${VERSION}.msi" -O app.msi
# 7z x -aos app.msi -o"AppDir/share/$APPNAME" >/dev/null 2>&1
# rm -f app.msi

# --- Example D: bundle the installer/zip itself, install on first launch ---
# Instead of extracting at build time, ship the raw installer/zip inside the
# AppImage and let APPNAME.hook's RUNTIME INSTALL flow run it on first
# launch. Keeps the AppImage self-contained (no network needed at runtime)
# while still deferring the actual install — set INSTALL_URL in the hook to
# the bundled path shown below.
#
# Downloaded fresh during CI (no need to store the file in the repo):
#
# mkdir -p "AppDir/share"
# wget -q "https://example.com/download/MyApp-Setup.exe" \
#     -O "AppDir/share/MyApp-Setup.exe"
# # Then in APPNAME.hook: INSTALL_URL="$APPDIR/share/MyApp-Setup.exe"
#
# Committed directly to this repo instead (e.g. no stable download URL, or
# you want to pin an exact binary) — put the file in a top-level payload/
# directory (add it to .gitattributes as `binary` / consider Git LFS if
# it's large), then just copy it in at build time:
#
# mkdir -p "AppDir/share"
# cp "payload/MyApp-Setup.exe" "AppDir/share/MyApp-Setup.exe"
# # Then in APPNAME.hook: INSTALL_URL="$APPDIR/share/MyApp-Setup.exe"

# --- This app's payload: build-time extraction (ACTIVE) -------------------
# VN Editor's .exe is a PE that embeds a ZIP archive, and the actual app
# files live inside the embedded VN.msi (WiX build, cab media with
# obfuscated filXXX names). Three-step extraction at build time:
#   1. wget the installer .exe
#   2. 7z x -tzip    → pulls VN.msi out of the PE
#   3. msiextract    → restores real file names from the MSI File table
# Result goes into AppDir/share/$APPNAME (flat) so the launcher finds
# $MAIN_EXE at $APP_HOME on first launch (see the thin launcher's
# candidate list). Needs `msitools` (msiextract) — see get-dependencies.sh.
PAYLOAD_URL="https://fw-download.ubnt.com/data/vn-desktop-app/7d10-windows-0.4.2-bc374063-d84a-42c4-bcb2-eced5b125c95.exe"

if [ -n "$PAYLOAD_URL" ]; then
	# Reuse a pre-downloaded installer.exe if present (local re-runs);
	# CI starts fresh so it always downloads.
	[ -s installer.exe ] || wget -q "$PAYLOAD_URL" -O installer.exe
	[ -s installer.exe ] || {
		echo "ERROR: failed to download the installer from $PAYLOAD_URL" >&2
		exit 1
	}

	_pkg_tmp="$(pwd)/.payload-extract"
	rm -rf "$_pkg_tmp"
	mkdir -p "AppDir/share/$APPNAME" "$_pkg_tmp"

	# Step 1: the outer exe is a PE with an embedded ZIP — force -tzip.
	7z x -aos -tzip installer.exe -o"$_pkg_tmp" >/dev/null || {
		echo "ERROR: 7z failed to extract the installer's embedded ZIP" >&2
		exit 1
	}
	rm -f installer.exe

	# Step 2: the app lives inside VN.msi — msiextract (msitools) maps the
	# obfuscated cab names back to the real file names via the File table.
	if [ ! -f "$_pkg_tmp/VN.msi" ]; then
		echo "ERROR: VN.msi not found in the installer's embedded ZIP" >&2
		exit 1
	fi
	msiextract -C "$_pkg_tmp" "$_pkg_tmp/VN.msi" >/dev/null || {
		echo "ERROR: msiextract failed to unpack VN.msi (is msitools installed?)" >&2
		exit 1
	}
	rm -f "$_pkg_tmp/VN.msi"

	# Flatten the VN/ tree into AppDir/share/$APPNAME so the thin launcher's
	# flat-path candidate ($APP_HOME/$MAIN_EXE) hits after the hook syncs it.
	mv "$_pkg_tmp/VN/"* "AppDir/share/$APPNAME"/
	rm -rf "$_pkg_tmp"

	# Installer artifacts inside the MSI — not needed to run the app
	# (the VC runtime DLLs are already in the payload).
	rm -f "AppDir/share/$APPNAME/VnSetup.exe" \
		"AppDir/share/$APPNAME/vc_redist.x64.exe"

	# Fail loudly instead of shipping an empty AppImage.
	[ -f "AppDir/share/$APPNAME/$MAIN_EXE" ] || {
		echo "ERROR: $MAIN_EXE not found in AppDir/share/$APPNAME after extraction" >&2
		echo "       check the extraction steps above" >&2
		exit 1
	}
	echo "Payload extracted: $(du -sh "AppDir/share/$APPNAME" | cut -f1) in AppDir/share/$APPNAME"
fi

# App assets already live under AppDir/ (same layout as other pkgforge templates):
#   AppDir/bin/APPNAME.hook   AppDir/bin/APPNAME
#   AppDir/APPNAME.desktop    AppDir/APPNAME.svg|.png
#   AppDir/bin/00-get-wine-appimage.hook  — shared wine resolver; do not remove
# Rename placeholders to the real APPNAME, then patch in place.
# If files are already renamed, the mv commands are skipped (idempotent).
mkdir -p "AppDir/bin"
if [ -f "AppDir/bin/APPNAME.hook" ] && [ "$APPNAME" != "APPNAME" ]; then
	mv "AppDir/bin/APPNAME.hook" "AppDir/bin/${APPNAME}.hook"
fi
if [ -f "AppDir/bin/APPNAME" ] && [ "$APPNAME" != "APPNAME" ]; then
	mv "AppDir/bin/APPNAME" "AppDir/bin/${APPNAME}"
fi
if [ -f "AppDir/APPNAME.desktop" ] && [ "$APPNAME" != "APPNAME" ]; then
	mv "AppDir/APPNAME.desktop" "AppDir/${APPNAME}.desktop"
fi
if [ -f "AppDir/APPNAME.svg" ] && [ "$APPNAME" != "APPNAME" ]; then
	mv "AppDir/APPNAME.svg" "AppDir/${APPNAME}.svg"
fi
if [ -f "AppDir/APPNAME.png" ] && [ "$APPNAME" != "APPNAME" ]; then
	mv "AppDir/APPNAME.png" "AppDir/${APPNAME}.png"
fi

# Mark files exec
chmod +x "AppDir/bin/${APPNAME}.hook" "AppDir/bin/${APPNAME}"
[ -f "AppDir/bin/00-get-wine-appimage.hook" ] && chmod +x "AppDir/bin/00-get-wine-appimage.hook"

# Sanity check: INSTALL_URL and RUN_EXE only make sense set together — one
# without the other is almost always a mistake (e.g. forgot to set RUN_EXE
# after enabling runtime install, or leftover RUN_EXE from copy-pasting an
# example without INSTALL_URL).
if [ -n "$INSTALL_URL" ] && [ -z "$RUN_EXE" ]; then
	echo "ERROR: INSTALL_URL is set but RUN_EXE is empty — the launcher" >&2
	echo "won't know where the installed app ends up. Set RUN_EXE too." >&2
	exit 1
fi
if [ -z "$INSTALL_URL" ] && [ -n "$RUN_EXE" ]; then
	echo "ERROR: RUN_EXE is set but INSTALL_URL is empty — RUN_EXE has" >&2
	echo "no effect without a runtime install to place the app there." >&2
	exit 1
fi

# Patch hook script
# VERSION_HERE must be replaced as a whole token (hook has _APP_VER="VERSION_HERE").
sed -i "s|VERSION_HERE|${VERSION}|g" "AppDir/bin/${APPNAME}.hook"
sed -i "s|_APP_NAME=\"APPNAME_HERE\"|_APP_NAME=\"${APPNAME}\"|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|_APP_BIN=\"MAIN_EXE_HERE\"|_APP_BIN=\"${MAIN_EXE}\"|" "AppDir/bin/${APPNAME}.hook"
# INSTALL_URL/RUN_EXE/TRICKS patches always run, substituting either the
# real value or an empty string — never conditionally skipped. Skipping the
# sed when a variable is empty would leave the literal placeholder text
# (e.g. "INSTALL_URL_HERE") in place as the hook's actual runtime value,
# since ${INSTALL_URL:-INSTALL_URL_HERE} only supplies that text as a
# default, it doesn't distinguish "empty on purpose" from "never patched".
#
# sed's REPLACEMENT text (not just its search pattern) interprets
# backslashes specially (\1, \n, etc.), so any literal backslash in
# INSTALL_URL/RUN_EXE — near-guaranteed for RUN_EXE since Windows paths
# use "C:\Program Files\App\App.exe" — gets silently eaten unless doubled
# first. Escape before substituting so the path survives intact.
_install_url_escaped=$(printf '%s' "$INSTALL_URL" | sed 's/\\/\\\\/g')
_run_exe_escaped=$(printf '%s' "$RUN_EXE" | sed 's/\\/\\\\/g')
sed -i "s|INSTALL_URL_HERE|${_install_url_escaped}|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|RUN_EXE_HERE|${_run_exe_escaped}|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|INSTALL_FLAGS_HERE|${INSTALL_FLAGS}|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|TRICKS_HERE|${TRICKS}|" "AppDir/bin/${APPNAME}.hook"
# WINEDLLOVERRIDES/WINEDEBUG/WINEPREFIX_SUBDIR always have real default
# values set above (never empty), so these always patch correctly as-is.
sed -i "s|WINEDLLOVERRIDES_HERE|${WINEDLLOVERRIDES}|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|WINEDEBUG_HERE|${WINEDEBUG}|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|WINEPREFIX_SUBDIR_HERE|${WINEPREFIX_SUBDIR}|" "AppDir/bin/${APPNAME}.hook"
sed -i "s|WINEPREFIX_DEDUP_HERE|${WINEPREFIX_DEDUP}|" "AppDir/bin/${APPNAME}.hook"
# Convert the literal "AppDir" marker in INSTALL_URL to "$APPDIR"
sed -i 's|INSTALL_URL:-AppDir/|INSTALL_URL:-$APPDIR/|' "AppDir/bin/${APPNAME}.hook"

# Patch thin script
sed -i "s|MAIN_EXE_HERE|${MAIN_EXE}|" "AppDir/bin/${APPNAME}"
sed -i -z "s|APPNAME_HERE|${APPNAME}|1" "AppDir/bin/${APPNAME}"

# Patch desktop file (already under AppDir/; quick-sharun finds AppDir/*.desktop)
sed -i "s|MAIN_EXE_HERE|${MAIN_EXE}|" "AppDir/${APPNAME}.desktop"
sed -i "s|APPNAME|${APPNAME}|g" "AppDir/${APPNAME}.desktop"
sed -i "s|^Version=.*|Version=${VERSION}|" "AppDir/${APPNAME}.desktop"
sed -i "s|^GenericName=.*|GenericName=${GENERIC_NAME}|" "AppDir/${APPNAME}.desktop"
sed -i "s|^Comment=.*|Comment=${COMMENT_NAME}|" "AppDir/${APPNAME}.desktop"
sed -i "s|^Categories=.*|Categories=${CATEGORIES_NAME}|" "AppDir/${APPNAME}.desktop"
sed -i "s|^MimeType=.*|MimeType=${MIMETYPES_NAME}|" "AppDir/${APPNAME}.desktop"

# Deploy dependencies
quick-sharun \
	./AppDir/bin/*

# Turn AppDir into AppImage
quick-sharun --make-appimage
