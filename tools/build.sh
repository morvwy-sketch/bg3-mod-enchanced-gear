#!/usr/bin/env bash
# Builds dist/EnhancedGear.pak and dist/EnhancedGear.zip (zip = pak + info.json for BG3 Mod Manager).
# Env: MOD_DIR (default mod/), DIST_DIR (default dist/), SKIP_GENERATE=1 skips tools/generate.lua.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/tools"
CACHE="$TOOLS/.cache"
LSLIB_DIR="$CACHE/lslib"
LSTOOL_OUT="$CACHE/lstool"
LSTOOL_DLL="$LSTOOL_OUT/LsTool.dll"
LSLIB_TAG="v1.20.4"
LSLIB_COMMIT="2746d7f01c4f0573c67a90c11ae09fb8663af0d5"
MOD_DIR="${MOD_DIR:-$ROOT/mod}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
PYTHON="${PYTHON:-python3}"
PAK_NAME="EnhancedGear.pak"

die() { echo "build.sh: error: $*" >&2; exit 1; }
warn() { echo "build.sh: warning: $*" >&2; }
step() { echo "==> $*"; }

export DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1

check_requirements() {
    DOTNET=""
    if command -v dotnet >/dev/null 2>&1; then
        DOTNET="$(command -v dotnet)"
    elif [[ -x "$HOME/.dotnet/dotnet" ]]; then
        DOTNET="$HOME/.dotnet/dotnet"
    else
        die ".NET 8 SDK not found. Install it from https://dot.net or run: curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0"
    fi
    local major
    major="$("$DOTNET" --version 2>/dev/null | cut -d. -f1)"
    [[ "${major:-0}" -ge 8 ]] || die ".NET SDK 8 or newer required, found major version '${major:-none}'"

    local candidate
    LUA=""
    for candidate in "${LUA_BIN:-}" lua5.4 lua; do
        [[ -n "$candidate" ]] || continue
        command -v "$candidate" >/dev/null 2>&1 || continue
        if "$candidate" -e 'assert(_VERSION == "Lua 5.4")' 2>/dev/null; then
            LUA="$candidate"
            break
        fi
    done
    [[ -n "$LUA" ]] || die "Lua 5.4 not found. Install it (apt install lua5.4, brew install lua) or set LUA_BIN=/path/to/lua5.4"

    command -v "$PYTHON" >/dev/null 2>&1 || die "python3 not found"
    "$PYTHON" -c 'import PIL' 2>/dev/null || die "Pillow not installed for $PYTHON. Run: $PYTHON -m pip install -r tools/requirements.txt (Debian/Ubuntu: sudo apt install python3-pil)"

}

# LsTool is compiled from a pinned LSLib checkout; the build runs in a few seconds once the cache is warm.
build_lstool() {
    step "LsTool (LSLib $LSLIB_TAG)"
    if [[ ! -f "$LSLIB_DIR/LSLib/LS/Resource.cs" ]]; then
        command -v git >/dev/null 2>&1 || die "git is required to fetch LSLib"
        rm -rf "$LSLIB_DIR"
        git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$LSLIB_TAG" \
            https://github.com/Norbyte/lslib.git "$LSLIB_DIR"
    fi
    local head
    head="$(git -C "$LSLIB_DIR" rev-parse HEAD)"
    [[ "$head" == "$LSLIB_COMMIT" ]] || die "LSLib checkout is at $head, expected $LSLIB_COMMIT; delete $LSLIB_DIR and rerun"
    "$DOTNET" publish "$TOOLS/LsTool/LsTool.csproj" -c Release -o "$LSTOOL_OUT" --nologo -v quiet
}

lstool() {
    "$DOTNET" "$LSTOOL_DLL" "$@"
}

run_generate() {
    if [[ "${SKIP_GENERATE:-0}" == "1" ]]; then
        warn "SKIP_GENERATE=1: using $MOD_DIR as is"
    elif [[ -f "$TOOLS/generate.lua" ]]; then
        step "generate.lua"
        (cd "$ROOT" && "$LUA" "$TOOLS/generate.lua")
    else
        warn "tools/generate.lua not found; using $MOD_DIR as is"
    fi
    [[ -f "$MOD_DIR/Mods/EnhancedGear/meta.lsx" ]] || die "no Mods/EnhancedGear/meta.lsx under $MOD_DIR (set MOD_DIR or run tools/generate.lua)"
}

stage_mod() {
    STAGE="$(mktemp -d "${TMPDIR:-/tmp}/enhancedgear-stage.XXXXXX")"
    trap 'rm -rf "$STAGE"' EXIT
    cp -R "$MOD_DIR/." "$STAGE/"
    step "icons"
    "$PYTHON" "$TOOLS/build_icons.py" "$STAGE"
}

convert_resources() {
    step "convert .lsx -> .lsf and .xml -> .loca"
    local f
    while IFS= read -r -d '' f; do
        # Texture atlas definitions are read as LSX by the game (bg3.wiki: "NOT converted to lsf").
        case "$f" in
            */Public/*/GUI/*.lsx) continue ;;
        esac
        lstool lsx2lsf "$f" "${f%.lsx}.lsf"
        rm "$f"
    done < <(find "$STAGE/Public" -name '*.lsx' -print0)

    if [[ -d "$STAGE/Localization" ]]; then
        while IFS= read -r -d '' f; do
            lstool xml2loca "$f" "${f%.xml}.loca"
            rm "$f"
        done < <(find "$STAGE/Localization" -mindepth 2 -maxdepth 2 -name '*.xml' -print0)
    fi
}

pack_and_zip() {
    mkdir -p "$DIST_DIR"
    PAK="$DIST_DIR/$PAK_NAME"
    rm -f "$PAK" "$DIST_DIR/EnhancedGear.zip"
    step "pack $PAK_NAME"
    lstool pack "$STAGE" "$PAK"

    step "zip with info.json"
    "$PYTHON" - "$MOD_DIR/Mods/EnhancedGear/meta.lsx" "$PAK" "$DIST_DIR/EnhancedGear.zip" <<'PY'
import datetime
import hashlib
import json
import os
import sys
import xml.etree.ElementTree as ET
import zipfile

meta_path, pak_path, zip_path = sys.argv[1:4]
module = ET.parse(meta_path).find(".//node[@id='ModuleInfo']")
if module is None:
    sys.exit(f"{meta_path}: no ModuleInfo node")


def info(name, default=None):
    node = module.find(f"attribute[@id='{name}']")
    if node is None or node.get("value") is None:
        if default is None:
            sys.exit(f"{meta_path}: ModuleInfo.{name} is missing")
        return default
    return node.get("value")


with open(pak_path, "rb") as f:
    md5 = hashlib.md5(f.read()).hexdigest()
uuid = info("UUID")
mod = {
    "Author": info("Author", ""),
    "Name": info("Name"),
    "Folder": info("Folder"),
    "Version": info("Version64"),
    "Description": info("Description", ""),
    "UUID": uuid,
    "Created": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "Group": uuid,
    "Dependencies": [],
}
manifest = json.dumps({"Mods": [mod], "MD5": md5}, ensure_ascii=False, indent=4) + "\n"
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(pak_path, os.path.basename(pak_path))
    zf.writestr("info.json", manifest)
print(f"wrote {zip_path}")
PY
}

verify_pak() {
    step "verify $PAK_NAME"
    local listing names required
    listing="$(lstool list "$PAK")"
    names="$(cut -f1 <<<"$listing")"
    for required in \
        "Mods/EnhancedGear/meta.lsx" \
        "Mods/EnhancedGear/ScriptExtender/Lua/BootstrapServer.lua" \
        "Public/EnhancedGear/RootTemplates/_merged.lsf" \
        "Localization/English/EnhancedGear.loca" \
        "Localization/Ukrainian/EnhancedGear.loca"; do
        grep -qxF "$required" <<<"$names" || die "pak is missing $required"
    done
    printf '%s\n' "$listing"
    echo "pak files: $(wc -l <<<"$names" | tr -d ' ')"
}

main() {
    check_requirements
    build_lstool
    run_generate
    stage_mod
    convert_resources
    pack_and_zip
    verify_pak
    echo "==> built $DIST_DIR/$PAK_NAME and $DIST_DIR/EnhancedGear.zip in ${SECONDS}s"
}

main "$@"
