#!/usr/bin/env python3
# SteadyCore
# Copyright (C) 2026 Marko Tahvanainen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.


"""Builds a ComfyUI UI-format workflow for a calm, predictable NPF-friendly bed.

UI format is the one you drag onto the canvas. Link ids have to stay consistent
between every node's inputs/outputs and the top level links array, which is why
this is generated rather than typed.
"""

import json

POS = ("ambient drone, instrumental, no vocals, sustained warm pad, "
       "soft felt piano, low strings, very slow, no drums, no percussion, "
       "no build, no drop, no sections, constant dynamics, minimal melody, "
       "repetitive, warm, dark, soft low pass filter, muted high frequencies, "
       "56 BPM, C minor, steady, gentle, patient")

NEG = ("vocals, singing, lyrics, choir, drums, percussion, cymbals, hi-hat, "
       "shaker, bright, harsh, sibilance, crescendo, build up, drop, "
       "dynamic change, sudden entrance, dramatic, orchestral swell, brass, "
       "distortion, arpeggio, fast, busy, glitch, reverse")

SECONDS = 60.0        # loop this rather than generating four minutes in one pass
STEPS = 50
CFG = 4.0
SEED = 1947

nodes = []
links = []
_link = [0]


def link(from_id, from_slot, to_id, to_slot, dtype):
    _link[0] += 1
    links.append([_link[0], from_id, from_slot, to_id, to_slot, dtype])
    return _link[0]


def node(nid, ntype, pos, size, order, widgets=None, inputs=None, outputs=None):
    nodes.append({
        "id": nid,
        "type": ntype,
        "pos": pos,
        "size": size,
        "flags": {},
        "order": order,
        "mode": 0,
        "inputs": inputs or [],
        "outputs": outputs or [],
        "properties": {"Node name for S&R": ntype},
        "widgets_values": widgets or [],
    })


def out(name, dtype, link_ids):
    return {"name": name, "type": dtype, "links": link_ids, "slot_index": 0}


def inp(name, dtype, link_id):
    return {"name": name, "type": dtype, "link": link_id}


# ---- link ids, allocated in graph order -----------------------------------
L_MODEL   = link(1, 0, 5, 0, "MODEL")
L_CLIP_P  = link(1, 1, 2, 0, "CLIP")
L_CLIP_N  = link(1, 1, 3, 0, "CLIP")
L_VAE     = link(1, 2, 7, 1, "VAE")
L_MSAF    = link(5, 0, 6, 0, "MODEL")
L_POS     = link(2, 0, 6, 1, "CONDITIONING")
L_NEG     = link(3, 0, 6, 2, "CONDITIONING")
L_LATENT  = link(4, 0, 6, 3, "LATENT")
L_SAMPLED = link(6, 0, 7, 0, "LATENT")
L_AUDIO   = link(7, 0, 8, 0, "AUDIO")

# ---- nodes ----------------------------------------------------------------
node(1, "CheckpointLoaderSimple", [40, 260], [380, 100], 0,
     widgets=["ace_step_v1.5_xl_turbo_aio.safetensors"],
     outputs=[
         {"name": "MODEL", "type": "MODEL", "links": [L_MODEL], "slot_index": 0},
         {"name": "CLIP", "type": "CLIP", "links": [L_CLIP_P, L_CLIP_N], "slot_index": 1},
         {"name": "VAE", "type": "VAE", "links": [L_VAE], "slot_index": 2},
     ])

node(2, "TextEncodeAceStepAudio1.5", [470, 60], [430, 330], 1,
     widgets=[POS, "[instrumental]", 0.0],
     inputs=[inp("clip", "CLIP", L_CLIP_P)],
     outputs=[out("CONDITIONING", "CONDITIONING", [L_POS])])

node(3, "TextEncodeAceStepAudio1.5", [470, 430], [430, 300], 2,
     widgets=[NEG, "", 0.0],
     inputs=[inp("clip", "CLIP", L_CLIP_N)],
     outputs=[out("CONDITIONING", "CONDITIONING", [L_NEG])])

node(4, "EmptyAceStep1.5LatentAudio", [470, 770], [430, 90], 3,
     widgets=[SECONDS, 1],
     outputs=[out("LATENT", "LATENT", [L_LATENT])])

node(5, "ModelSamplingAuraFlow", [40, 420], [380, 60], 4,
     widgets=[3.0],
     inputs=[inp("model", "MODEL", L_MODEL)],
     outputs=[out("MODEL", "MODEL", [L_MSAF])])

node(6, "KSampler", [960, 260], [340, 290], 5,
     widgets=[SEED, "fixed", STEPS, CFG, "res_multistep", "simple", 1.0],
     inputs=[
         inp("model", "MODEL", L_MSAF),
         inp("positive", "CONDITIONING", L_POS),
         inp("negative", "CONDITIONING", L_NEG),
         inp("latent_image", "LATENT", L_LATENT),
     ],
     outputs=[out("LATENT", "LATENT", [L_SAMPLED])])

node(7, "VAEDecodeAudio", [1350, 260], [270, 60], 6,
     inputs=[
         inp("samples", "LATENT", L_SAMPLED),
         inp("vae", "VAE", L_VAE),
     ],
     outputs=[out("AUDIO", "AUDIO", [L_AUDIO])])

node(8, "SaveAudio", [1350, 380], [340, 110], 7,
     widgets=["npf_bed"],
     inputs=[inp("audio", "AUDIO", L_AUDIO)])

workflow = {
    "last_node_id": 8,
    "last_link_id": _link[0],
    "nodes": nodes,
    "links": links,
    "groups": [],
    "config": {},
    "extra": {},
    "version": 0.4,
}

# ---- validation: every referenced link must exist on both ends -------------
declared = {l[0]: l for l in links}
seen_in, seen_out = set(), set()
for n in nodes:
    for i in n["inputs"]:
        assert i["link"] in declared, f"node {n['id']} input {i['name']} dangling"
        assert declared[i["link"]][3] == n["id"], f"node {n['id']} input target mismatch"
        seen_in.add(i["link"])
    for o in n["outputs"]:
        for lid in o["links"] or []:
            assert lid in declared, f"node {n['id']} output {o['name']} dangling"
            assert declared[lid][1] == n["id"], f"node {n['id']} output source mismatch"
            seen_out.add(lid)
assert seen_in == seen_out == set(declared), "link set mismatch"

path = "npf-calm-bed.json"
with open(path, "w") as f:
    json.dump(workflow, f, indent=2)
print(f"{len(nodes)} nodes, {len(links)} links, all consistent -> {path}")
