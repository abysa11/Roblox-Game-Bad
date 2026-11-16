#!/usr/bin/env python3
"""
Builds FrontlineFPS.rbxlx (a Roblox place file you can open directly in Roblox Studio)
from the Luau sources in ./src, using Rojo's file conventions:

    *.server.lua -> Script        *.client.lua -> LocalScript        *.lua -> ModuleScript
    directories  -> Folder

    src/ReplicatedStorage     -> ReplicatedStorage
    src/ServerScriptService   -> ServerScriptService
    src/StarterPlayerScripts  -> StarterPlayer.StarterPlayerScripts

Usage:  python3 tools/build_place.py [output.rbxlx]
No third-party packages needed.
"""

import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return "RBX%08X" % _ref


def cdata(text):
    # "]]>" cannot appear inside CDATA; split it across two sections
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def prop_string(name, value):
    return '<string name="%s">%s</string>' % (name, escape(value))


def script_item(path, name):
    if name.endswith(".server.lua"):
        cls, inst = "Script", name[: -len(".server.lua")]
    elif name.endswith(".client.lua"):
        cls, inst = "LocalScript", name[: -len(".client.lua")]
    else:
        cls, inst = "ModuleScript", name[: -len(".lua")]
    with open(path, "r", encoding="utf-8") as f:
        source = f.read()
    props = [prop_string("Name", inst), '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source)]
    if cls == "Script":
        props.append('<token name="RunContext">0</token>')
    return '<Item class="%s" referent="%s"><Properties>%s</Properties></Item>' % (cls, ref(), "".join(props))


def children_of(directory):
    out = []
    for name in sorted(os.listdir(directory)):
        if name.startswith("."):
            continue
        path = os.path.join(directory, name)
        if os.path.isdir(path):
            out.append(folder_item(path, name))
        elif name.endswith(".lua") or name.endswith(".luau"):
            out.append(script_item(path, name.replace(".luau", ".lua")))
    return "".join(out)


def folder_item(path, name):
    return '<Item class="Folder" referent="%s"><Properties>%s</Properties>%s</Item>' % (
        ref(),
        prop_string("Name", name),
        children_of(path),
    )


def service(cls, props="", children=""):
    return '<Item class="%s" referent="%s"><Properties>%s%s</Properties>%s</Item>' % (
        cls,
        ref(),
        prop_string("Name", cls),
        props,
        children,
    )


def build(out_path):
    parts = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        "<External>null</External><External>nil</External>",
        service(
            "Workspace",
            '<bool name="StreamingEnabled">true</bool>'
            '<float name="StreamingMinRadius">96</float>'
            '<float name="StreamingTargetRadius">700</float>',
        ),
        service(
            "Lighting",
            '<token name="Technology">3</token>'
            '<float name="ClockTime">17.4</float>'
            '<bool name="GlobalShadows">true</bool>',
        ),
        service("ReplicatedStorage", "", children_of(os.path.join(SRC, "ReplicatedStorage"))),
        service("ServerScriptService", "", children_of(os.path.join(SRC, "ServerScriptService"))),
        service(
            "StarterPlayer",
            '<bool name="EnableMouseLockOption">false</bool>'
            '<float name="CameraMaxZoomDistance">22</float>',
            '<Item class="StarterPlayerScripts" referent="%s"><Properties>%s</Properties>%s</Item>'
            % (ref(), prop_string("Name", "StarterPlayerScripts"), children_of(os.path.join(SRC, "StarterPlayerScripts")))
            + '<Item class="StarterCharacterScripts" referent="%s"><Properties>%s</Properties></Item>'
            % (ref(), prop_string("Name", "StarterCharacterScripts")),
        ),
        service("StarterGui"),
        service("SoundService"),
        service("Players", '<bool name="CharacterAutoLoads">false</bool>'),
        "</roblox>",
    ]
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("".join(parts))
    print("Wrote %s (%d instances)" % (out_path, _ref))


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "FrontlineFPS.rbxlx"))
