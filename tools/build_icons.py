#!/usr/bin/env python3
"""Adds Enhanced Gear item icons to a staged mod tree (the build.sh staging copy).

For every art/icons/<name>.png it writes, following bg3.wiki "Modding:Item icons":
  Public/EnhancedGear/Assets/Textures/Icons/Icons_EnhancedGear.dds  64px-cell atlas, 256x256, BC3 (DXT5), no mips
  Public/EnhancedGear/GUI/Icons_EnhancedGear.lsx                    atlas definition; stays .lsx (not converted)
  Public/EnhancedGear/Content/UI/[PAK]_UI/_merged.lsx               TextureBank pointing at the atlas (converted to .lsf)
  Public/Game/GUI/Assets/Tooltips/ItemIcons/<name>.DDS              380x380 tooltip icon
  Public/Game/GUI/Assets/ControllerUIIcons/items_png/<name>.DDS     144x144 controller icon

usage: build_icons.py <staging-dir> [--art-dir DIR]
"""
import argparse
import re
import struct
import sys
import uuid
from pathlib import Path

from PIL import Image

MOD_FOLDER = "EnhancedGear"
# The atlas uuid and name come from Shared/Ids.lua, the same values the Lua side uses.
IDS_LUA = Path("Mods") / MOD_FOLDER / "ScriptExtender" / "Lua" / "Shared" / "Ids.lua"
ATLAS_RE = re.compile(r'Ids\.IconAtlas\s*=\s*\{\s*uuid\s*=\s*"([^"]+)"\s*,\s*name\s*=\s*"([^"]+)"')
ITEM_ICONS = ["EG_Item_Scrap", "EG_Item_Dust", "EG_Item_Ingot", "EG_Item_Core", "EG_Item_ForgeKit"]
ATLAS_SIZE = 256
CELL = 64
COLUMNS = ATLAS_SIZE // CELL
TOOLTIP_SIZE = 380
CONTROLLER_SIZE = 144
REPO_ART_DIR = Path(__file__).resolve().parent.parent / "art" / "icons"

DDSD_FLAGS = 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000  # caps, height, width, pixelformat, linearsize
DDPF_FOURCC = 0x4
DDSCAPS_TEXTURE = 0x1000

ATLAS_XML = """<?xml version="1.0" encoding="utf-8"?>
<save>
    <version major="4" minor="0" revision="9" build="328"/>
    <region id="TextureAtlasInfo">
        <node id="root">
            <children>
                <node id="TextureAtlasIconSize">
                    <attribute id="Height" type="int64" value="{cell}"/>
                    <attribute id="Width" type="int64" value="{cell}"/>
                </node>
                <node id="TextureAtlasPath">
                    <attribute id="Path" type="LSString" value="Assets/Textures/Icons/{atlas}.dds"/>
                    <attribute id="UUID" type="FixedString" value="{atlas_uuid}"/>
                </node>
                <node id="TextureAtlasTextureSize">
                    <attribute id="Height" type="int64" value="{size}"/>
                    <attribute id="Width" type="int64" value="{size}"/>
                </node>
            </children>
        </node>
    </region>
    <region id="IconUVList">
        <node id="root">
            <children>
{icons}
            </children>
        </node>
    </region>
</save>
"""

ICON_XML = """                <node id="IconUV">
                    <attribute id="MapKey" type="FixedString" value="{name}"/>
                    <attribute id="U1" type="float" value="{u1}"/>
                    <attribute id="U2" type="float" value="{u2}"/>
                    <attribute id="V1" type="float" value="{v1}"/>
                    <attribute id="V2" type="float" value="{v2}"/>
                </node>"""

TEXTURE_BANK_XML = """<?xml version="1.0" encoding="utf-8"?>
<save>
    <version major="4" minor="0" revision="9" build="328"/>
    <region id="TextureBank">
        <node id="TextureBank">
            <children>
                <node id="Resource">
                    <attribute id="ID" type="FixedString" value="{bank_id}"/>
                    <attribute id="Localized" type="bool" value="False"/>
                    <attribute id="Name" type="LSString" value="{atlas}"/>
                    <attribute id="SRGB" type="bool" value="True"/>
                    <attribute id="SourceFile" type="LSString" value="Public/{mod}/Assets/Textures/Icons/{atlas}.dds"/>
                    <attribute id="Streaming" type="bool" value="True"/>
                    <attribute id="Template" type="FixedString" value="{atlas}"/>
                    <attribute id="Type" type="int64" value="0"/>
                </node>
            </children>
        </node>
    </region>
</save>
"""


def load_icon(art_dir, name, size):
    path = art_dir / f"{name}.png"
    if not path.is_file():
        sys.exit(f"build_icons: missing {path} (run tools/make_placeholder_icons.py)")
    img = Image.open(path).convert("RGBA")
    # Premultiplied resize keeps the colour of transparent pixels from bleeding into edges.
    return img.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def read_atlas(stage):
    path = stage / IDS_LUA
    if not path.is_file():
        sys.exit(f"build_icons: missing {path}")
    match = ATLAS_RE.search(path.read_text(encoding="utf-8"))
    if not match:
        sys.exit(f'build_icons: no Ids.IconAtlas = {{ uuid = "...", name = "..." }} in {path}')
    atlas_uuid, atlas_name = match.groups()
    try:
        uuid.UUID(atlas_uuid)
    except ValueError:
        sys.exit(f"build_icons: Ids.IconAtlas.uuid is not a UUID in {path}")
    return atlas_uuid, atlas_name


def _to565(rgb):
    r, g, b = rgb
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def _from565(c):
    r, g, b = (c >> 11) & 31, (c >> 5) & 63, c & 31
    return ((r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2))


def _encode_alpha(block):
    alphas = [px[3] for px in block]
    a0, a1 = max(alphas), min(alphas)  # a0 > a1 selects the 8-value mode
    palette = [a0, a1] + [round(((8 - k) * a0 + (k - 1) * a1) / 7) for k in range(2, 8)]
    bits = 0
    for i, a in enumerate(alphas):
        bits |= min(range(8), key=lambda k: abs(palette[k] - a)) << (3 * i)
    return struct.pack("<BB", a0, a1) + bits.to_bytes(6, "little")


def _encode_color(block):
    opaque = [px for px in block if px[3] > 0] or block
    c0 = _to565([max(px[c] for px in opaque) for c in range(3)])
    c1 = _to565([min(px[c] for px in opaque) for c in range(3)])
    if c0 < c1:
        c0, c1 = c1, c0
    if c0 == c1:  # BC1 needs c0 > c1 for the 4-colour mode
        if c0 > 0:
            c1 = c0 - 1
        else:
            c0 = 1
    e0, e1 = _from565(c0), _from565(c1)
    palette = [e0, e1,
               tuple((2 * p + q) // 3 for p, q in zip(e0, e1)),
               tuple((p + 2 * q) // 3 for p, q in zip(e0, e1))]
    bits = 0
    for i, px in enumerate(block):
        best = min(range(4), key=lambda k: sum((px[c] - palette[k][c]) ** 2 for c in range(3)))
        bits |= best << (2 * i)
    return struct.pack("<HHI", c0, c1, bits)


def encode_bc3(img):
    """Encodes an RGBA image as BC3 (DXT5) blocks, row-major, 4x4 pixel blocks."""
    width, height = img.size
    data = img.tobytes()
    out = bytearray()
    for by in range(0, height, 4):
        for bx in range(0, width, 4):
            block = []
            for y in range(by, by + 4):
                row = (y * width + bx) * 4
                block.extend(tuple(data[row + x * 4: row + x * 4 + 4]) for x in range(4))
            out += _encode_alpha(block)
            out += _encode_color(block)
    return bytes(out)


def dds_bc3(img):
    width, height = img.size
    linear_size = max(1, (width + 3) // 4) * max(1, (height + 3) // 4) * 16
    header = struct.pack("<4sI", b"DDS ", 124)
    header += struct.pack("<IIIII", DDSD_FLAGS, height, width, linear_size, 0)
    header += struct.pack("<I", 0) + bytes(44)  # no mipmaps, reserved
    header += struct.pack("<II4sIIIII", 32, DDPF_FOURCC, b"DXT5", 0, 0, 0, 0, 0)
    header += struct.pack("<IIIII", DDSCAPS_TEXTURE, 0, 0, 0, 0)
    return header + encode_bc3(img)


def build_atlas(art_dir, atlas_name, atlas_uuid):
    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    icon_xml = []
    for i, name in enumerate(ITEM_ICONS):
        col, row = i % COLUMNS, i // COLUMNS
        if (row + 1) * CELL > ATLAS_SIZE:
            sys.exit("build_icons: too many icons for one atlas")
        atlas.paste(load_icon(art_dir, name, CELL), (col * CELL, row * CELL))
        u1, u2 = col / COLUMNS, (col + 1) / COLUMNS
        v1, v2 = row / COLUMNS, (row + 1) / COLUMNS
        icon_xml.append(ICON_XML.format(name=name, u1=repr(u1), u2=repr(u2), v1=repr(v1), v2=repr(v2)))
    lsx = ATLAS_XML.format(cell=CELL, atlas=atlas_name, atlas_uuid=atlas_uuid, size=ATLAS_SIZE,
                           icons="\n".join(icon_xml))
    return atlas, lsx


def write_bytes(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description="Adds Enhanced Gear item icons to a staged mod tree.")
    parser.add_argument("staging", type=Path)
    parser.add_argument("--art-dir", type=Path, default=REPO_ART_DIR)
    args = parser.parse_args()
    stage = args.staging
    public = stage / "Public"

    atlas_uuid, atlas_name = read_atlas(stage)
    atlas, atlas_lsx = build_atlas(args.art_dir, atlas_name, atlas_uuid)
    write_bytes(public / MOD_FOLDER / "Assets" / "Textures" / "Icons" / f"{atlas_name}.dds", dds_bc3(atlas))
    write_bytes(public / MOD_FOLDER / "GUI" / f"{atlas_name}.lsx", atlas_lsx.encode("utf-8"))
    bank = TEXTURE_BANK_XML.format(bank_id=uuid.uuid5(uuid.UUID(atlas_uuid), "TextureBank"),
                                   atlas=atlas_name, mod=MOD_FOLDER)
    write_bytes(public / MOD_FOLDER / "Content" / "UI" / "[PAK]_UI" / "_merged.lsx", bank.encode("utf-8"))

    for name in ITEM_ICONS:
        tooltip = load_icon(args.art_dir, name, TOOLTIP_SIZE)
        write_bytes(public / "Game" / "GUI" / "Assets" / "Tooltips" / "ItemIcons" / f"{name}.DDS", dds_bc3(tooltip))
        controller = load_icon(args.art_dir, name, CONTROLLER_SIZE)
        write_bytes(public / "Game" / "GUI" / "Assets" / "ControllerUIIcons" / "items_png" / f"{name}.DDS",
                    dds_bc3(controller))
    print(f"build_icons: atlas {atlas_name} with {len(ITEM_ICONS)} icons, tooltip and controller DDS written to {stage}")


if __name__ == "__main__":
    main()
