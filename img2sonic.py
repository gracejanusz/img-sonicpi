#!/usr/bin/env python3
"""
img2sonic — turn images into Sonic Pi code, and several images into one set.

    python img2sonic.py photo.jpg                 -> output/photo.rb   (one block)
    python img2sonic.py a.jpg b.jpg c.jpg         -> one block each + output/set.rb
    python img2sonic.py img:/* --bars 12 --order given

How the picture becomes music
  COLOUR  -> feeling. Each colour family has an entry in COLOURS below
             (mood, scale, synths, valence, arousal). The strongest colour
             picks the scale and instruments; the blend of all colours sets
             tempo and chord progression. Edit COLOURS to change the mapping.
  LINES   -> percussion. Sharp, definite edges give crisp, busy drums.
             Blurred / soft edges give little or no percussion, long pads,
             more reverb and a drone (ambient).
  LIGHT   -> register and filter brightness (dark image = low and muffled).
  SHAPE   -> melody. The image is read left to right in 16 strips; where the
             detail sits vertically in each strip sets the pitch.

Every block is a Sonic Pi function (`define :scene_x do |bars, fade| ...`),
so blocks can be played alone or sequenced. The set file orders the scenes
into an energy arc (calm -> peak -> calm), puts them on a shared tonic and
crossfades between them.
"""
import argparse
import colorsys
import re
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageOps

# --------------------------------------------------------------------------
# Colour -> feeling table. This is the part to edit to match your own chart.
#   valence: -1 (dark/sad) .. +1 (bright/happy)     -> chord progression
#   arousal:  0 (still)    ..  1 (energetic)        -> tempo
#   scale:   a 7-note Sonic Pi scale                -> harmony + melody
#   root:    pitch class used when the block is played on its own
# --------------------------------------------------------------------------
COLOURS = {
    #          feeling                        valence arousal scale             root  pad             lead
    "red":    ("passion, urgency, intensity",   0.0,  1.00, "harmonic_minor", "e", "prophet",       "saw"),
    "orange": ("warmth, enthusiasm",            0.6,  0.75, "mixolydian",     "d", "blade",         "pluck"),
    "yellow": ("joy, optimism",                 0.9,  0.70, "major",          "c", "blade",         "pretty_bell"),
    "green":  ("nature, balance, growth",       0.5,  0.35, "major",          "g", "hollow",        "kalimba"),
    "blue":   ("calm, depth, melancholy",      -0.3,  0.20, "minor",          "a", "hollow",        "piano"),
    "purple": ("mystery, dreaminess",           0.0,  0.40, "dorian",         "f", "dark_ambience", "blade"),
    "pink":   ("tenderness, playfulness",       0.7,  0.45, "major",          "f", "hollow",        "pretty_bell"),
    "brown":  ("earthiness, stability",         0.1,  0.25, "dorian",         "d", "fm",            "pluck"),
    "black":  ("weight, the unknown",          -0.6,  0.30, "harmonic_minor", "c", "dark_ambience", "hollow"),
    "white":  ("openness, stillness",           0.4,  0.10, "lydian",         "c", "hollow",        "pretty_bell"),
    "gray":   ("neutrality, distance",         -0.2,  0.15, "minor",          "a", "dark_ambience", "piano"),
}
ACHROMATIC = ("black", "white", "gray")
MINORISH = {"minor", "harmonic_minor", "dorian", "phrygian"}
PITCH = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}

SIZE = 512    # analysis resolution (long side) so results don't depend on megapixels
STRIPS = 16   # melody steps read left -> right


def clamp(x, lo=0.0, hi=1.0):
    return float(max(lo, min(hi, x)))


# --------------------------------------------------------------------------
# Image analysis
# --------------------------------------------------------------------------
def classify_colours(hsv):
    """Share of pixels in each colour family."""
    h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    name = np.full(h.shape, "gray", dtype=object)
    chroma = (s >= 0.15) & (v >= 0.2)
    for lo, hi, n in ((0, 15, "red"), (15, 45, "orange"), (45, 70, "yellow"),
                      (70, 165, "green"), (165, 255, "blue"), (255, 290, "purple"),
                      (290, 345, "pink"), (345, 361, "red")):
        name[chroma & (h >= lo) & (h < hi)] = n
    name[chroma & (h >= 10) & (h < 45) & (v < 0.6)] = "brown"          # dark orange
    name[chroma & ((h < 15) | (h >= 345)) & (s < 0.5) & (v > 0.8)] = "pink"  # pale red
    name[~chroma & (v > 0.8)] = "white"
    name[v < 0.2] = "black"
    return {c: float(np.mean(name == c)) for c in COLOURS}


def gradient(lum):
    gy, gx = np.gradient(lum)
    return np.hypot(gx, gy)


def analyse(path):
    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    img.thumbnail((SIZE, SIZE), Image.LANCZOS)
    rgb = np.asarray(img, dtype=np.float32) / 255
    hsv = np.asarray(img.convert("HSV"), dtype=np.float32) / 255
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)

    # --- lines -------------------------------------------------------------
    g = gradient(lum)
    blurred = np.asarray(img.convert("L").filter(ImageFilter.GaussianBlur(2)), dtype=np.float32) / 255
    g_blur = gradient(blurred)
    strong = np.percentile(g, 99)
    # Sharp edges are steep, and they collapse when the image is blurred.
    # Soft edges are shallow and barely change. Both signals feed "sharpness".
    steepness = clamp(strong / 0.35)
    collapse = clamp(1 - np.percentile(g_blur, 99) / (strong + 1e-6))
    sharpness = clamp(0.5 * steepness + 0.5 * collapse / 0.7)
    density = clamp(np.mean(g > 0.08) / 0.12)            # how much of the frame is line
    activity = clamp(sharpness * (0.65 + 0.35 * density))  # percussion drive

    # --- colour ------------------------------------------------------------
    shares = classify_colours(hsv)
    weights = {c: p * (0.5 if c in ACHROMATIC else 1.0) for c, p in shares.items()}
    total = sum(weights.values()) or 1.0
    valence = sum(w * COLOURS[c][1] for c, w in weights.items()) / total
    arousal = sum(w * COLOURS[c][2] for c, w in weights.items()) / total
    chroma = sorted(((p, c) for c, p in shares.items() if c not in ACHROMATIC), reverse=True)
    ranked = sorted(((p, c) for c, p in shares.items()), reverse=True)
    if sum(p for p, _ in chroma) >= 0.2:
        # Enough colour: the strongest hue sets scale + pad, runner-up picks the lead.
        key = chroma[0][1]
        second = next((c for p, c in ranked if c != key and p > 0.05), key)
    else:
        # Mostly black / white / gray: that sets the mood; a colour accent picks the lead.
        key = ranked[0][1]
        second = chroma[0][1] if chroma[0][0] > 0.03 else key

    # --- melody contour: vertical centre of detail in each strip -------------
    energy = g + 0.3 * hsv[..., 1] * hsv[..., 2]
    rows = np.linspace(1, 0, energy.shape[0])[:, None]     # top of image = high pitch
    contour, weight = [], []
    for strip in np.array_split(np.arange(energy.shape[1]), STRIPS):
        e = energy[:, strip]
        weight.append(float(e.mean()))
        contour.append(float((e * rows).sum() / (e.sum() + 1e-6)))
    contour = np.array(contour)
    span = contour.max() - contour.min()
    contour = (contour - contour.min()) / span if span > 1e-3 else np.full(STRIPS, 0.5)

    return {
        "path": str(path), "shares": shares, "key": key, "second": second,
        "valence": valence, "arousal": arousal,
        "brightness": float(lum.mean()), "saturation": float(hsv[..., 1].mean()),
        "contrast": clamp(float(lum.std()) / 0.3),
        "sharpness": sharpness, "density": density, "activity": activity,
        "contour": contour.tolist(), "strip_weight": weight,
        "seed": zlib.crc32(Path(path).name.encode()) % 100000,
    }


# --------------------------------------------------------------------------
# Musical decisions
# --------------------------------------------------------------------------
def euclid(hits, steps=16, rotate=0):
    """Evenly spread `hits` over `steps` (same idea as Sonic Pi's `spread`)."""
    if hits <= 0:
        return [0] * steps
    pat = [1 if (i * hits) % steps < hits else 0 for i in range(steps)]
    return pat[-rotate:] + pat[:-rotate] if rotate else pat


def drums(a):
    """Percussion patterns from line activity `a` (0 = all blur, 1 = razor sharp)."""
    kick = snare = hat = [0] * 16
    label = "none - pure ambient"
    if a >= 0.15:
        kick, label = euclid(1), "a soft pulse"
    if a >= 0.28:
        kick, hat, label = euclid(2), euclid(4, rotate=2), "sparse"
    if a >= 0.42:
        hat, snare, label = euclid(8), [1 if i in (4, 12) else 0 for i in range(16)], "steady backbeat"
    if a >= 0.58:
        kick, label = euclid(4), "driving"
    if a >= 0.72:
        kick = [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0]
        hat, label = euclid(12), "busy, syncopated"
    if a >= 0.86:
        hat = [1] * 16
        snare = [0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0]   # 1 = ghost note
        label = "very active"
    return kick, snare, hat, label


def decide(f):
    feeling, _, _, scale, root, pad, _ = COLOURS[f["key"]]
    lead = COLOURS[f["second"]][6] if f["second"] != f["key"] else COLOURS[f["key"]][6]
    a, sharp = f["activity"], f["sharpness"]

    bpm = round((55 + 75 * f["arousal"]) * (0.85 + 0.3 * a))
    v = f["valence"]
    prog = (["i", "v", "vi", "iv"] if v > 0.4 else ["i", "iv", "i", "v"] if v > 0.1
            else ["i", "vii", "iv", "i"] if v > -0.2 else ["i", "vi", "iii", "vii"])

    # Melody: pentatonic-flavoured degrees of the 7-note scale, over two octaves.
    penta = [0, 2, 3, 4, 6] if scale in MINORISH else [0, 1, 2, 4, 5]
    ladder = penta + [d + 7 for d in penta]
    wt = np.array(f["strip_weight"])
    # Quiet strips become rests; muted, low-energy images rest more.
    rest_below = np.quantile(wt, clamp(0.55 - 0.4 * f["saturation"] - 0.3 * f["arousal"], 0.1, 0.6))
    melody = [ladder[min(len(ladder) - 1, int(c * len(ladder)))] if w >= rest_below else None
              for c, w in zip(f["contour"], wt)]

    kick, snare, hat, drum_label = drums(a)
    crisp = sharp >= 0.55
    return {
        "feeling": feeling, "scale": scale, "root": root, "pad": pad, "lead": lead,
        "bpm": bpm, "prog": prog, "melody": melody,
        "kick": kick, "snare": snare, "hat": hat, "drum_label": drum_label,
        "kick_s": "bd_tek" if sharp >= 0.8 else "bd_haus" if crisp else "bd_fat",
        "snare_s": "sn_dolf" if crisp else "drum_snare_soft",
        "hat_s": "drum_cymbal_closed" if crisp else "drum_cymbal_soft",
        "drum_amp": round(0.35 + 0.75 * a, 2),
        "drum_lpf": round(75 + 55 * sharp),
        "octave": 2 if f["brightness"] < 0.35 else 3,
        "cutoff": round(62 + 58 * f["brightness"]),
        "reverb": round(0.3 + 0.5 * (1 - sharp), 2),
        "room": round(0.5 + 0.45 * (1 - sharp), 2),
        "pad_attack": round(0.1 + 2.4 * (1 - sharp), 2),
        "lead_release": round(0.3 + 1.5 * (1 - sharp), 2),
        "lead_amp": round(0.45 + 0.5 * f["saturation"] + 0.2 * f["contrast"], 2),
        "drone": a < 0.42,
        "energy": 0.5 * a + 0.5 * f["arousal"],
    }


# --------------------------------------------------------------------------
# Sonic Pi code generation
# --------------------------------------------------------------------------
def scene_name(path, taken):
    base = "scene_" + (re.sub(r"[^a-z0-9]+", "_", Path(path).stem.lower()).strip("_") or "image")
    name, n = base, 2
    while name in taken:
        name, n = f"{base}_{n}", n + 1
    taken.add(name)
    return name


def ring(values):
    return "(ring " + ", ".join("nil" if v is None else str(v) for v in values) + ")"


def render_scene(name, f, m, root=None):
    """One image -> one `define` block. `root` overrides the key (used by sets)."""
    root = root or m["root"]
    top = sorted(((p, c) for c, p in f["shares"].items() if p >= 0.03), reverse=True)[:4]
    palette = ", ".join(f"{c} {p:.0%}" for p, c in top)
    has_drums = any(m["kick"]) or any(m["snare"]) or any(m["hat"])
    # piano / kalimba / pluck have no filter cutoff opt
    lead_cutoff = "" if m["lead"] in ("piano", "kalimba", "pluck") else f"cutoff: {min(130, m['cutoff'] + 10)}, "
    L = [
        f"# ── {Path(f['path']).name} " + "─" * max(4, 60 - len(Path(f['path']).name)),
        f"# colour : {palette}",
        f"#          {f['key']} leads -> {m['feeling']} -> {root.upper()} {m['scale']}, {m['bpm']} bpm",
        f"# lines  : sharpness {f['sharpness']:.2f}, density {f['density']:.2f}"
        f" -> percussion: {m['drum_label']}",
        f"# light  : brightness {f['brightness']:.2f}, saturation {f['saturation']:.2f}",
        f"define :{name} do |bars = 8, fade = 1|",
        f"  use_bpm {m['bpm']}",
        f"  use_random_seed {f['seed']}",
        f"  root  = :{root}{m['octave']}",
        f"  mode  = :{m['scale']}",
        f"  notes = scale(root + 12, mode, num_octaves: 2)",
        f"  fade  = [fade, bars / 2.0].min",
        f"  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|",
        f"    with_fx :reverb, room: {m['room']}, mix: {m['reverb']} do",
        "",
        f"      in_thread do  # harmony - colour mood",
        f"        chords = (ring {', '.join(':' + d for d in m['prog'])})",
        f"        bars.times do |b|",
        f"          synth :{m['pad']}, notes: chord_degree(chords[b], root, mode, 3),",
        f"            attack: {m['pad_attack']}, sustain: {round(max(0.5, 3.5 - m['pad_attack']), 2)}, release: 1.5,",
        f"            cutoff: {m['cutoff']}, amp: 0.6",
        f"          sleep 4",
        f"        end",
        f"      end",
        "",
        f"      in_thread do  # melody - the image read left to right",
        f"        steps = {ring(m['melody'])}",
        f"        (bars * 8).times do |i|",
        f"          d = steps[i]",
        f"          synth :{m['lead']}, note: notes[d], release: {m['lead_release']},",
        f"            {lead_cutoff}amp: {m['lead_amp']} * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d",
        f"          sleep 0.5",
        f"        end",
        f"      end",
    ]
    if m["drone"]:
        L += [
            "",
            f"      in_thread do  # drone - soft lines leave room for air",
            f"        (bars / 2.0).ceil.times do",
            f"          synth :dark_ambience, note: root - 12, attack: 3, sustain: 2, release: 3, amp: 0.5",
            f"          sleep 8",
            f"        end",
            f"      end",
        ]
    L += ["    end"]
    if has_drums:
        L += [
            "",
            f"    in_thread do  # percussion - line sharpness",
            f"      kick  = {ring(m['kick'])}",
            f"      snare = {ring(m['snare'])}",
            f"      hat   = {ring(m['hat'])}",
            f"      with_fx :lpf, cutoff: {m['drum_lpf']} do",
            f"        (bars * 16).times do |i|",
            f"          sample :{m['kick_s']}, amp: {m['drum_amp']} if kick[i] > 0",
            f"          sample :{m['snare_s']}, amp: {m['drum_amp']} * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0",
            f"          sample :{m['hat_s']}, amp: {round(m['drum_amp'] * 0.5, 2)} * rrand(0.6, 1), finish: 0.2 if hat[i] > 0",
            f"          sleep 0.25",
            f"        end",
            f"      end",
            f"    end",
        ]
    L += [
        "",
        "    # fade in, hold, fade out",
        "    sleep 0.01",
        "    control vol, amp: 1",
        "    sleep (bars - fade) * 4 - 0.01",
        "    control vol, amp: 0",
        "    sleep fade * 4",
        "  end",
        "end",
    ]
    return "\n".join(L)


def render_single(name, block):
    return (f"{block}\n\n# Loop this image on its own. Change the 8 to play longer phrases.\n"
            f"live_loop :play_{name} do\n  {name} 8, 0\nend\n")


def arc_order(scenes):
    """Calm -> build -> peak -> come down: low energy at the edges, high in the middle."""
    by_energy = sorted(scenes, key=lambda s: s["m"]["energy"])
    rise, fall = by_energy[0::2], by_energy[1::2]
    return rise + fall[::-1] if len(scenes) > 2 else by_energy


def render_set(scenes, bars, order):
    if order == "arc":
        scenes = arc_order(scenes)
    # Shared tonic: the leading colour across every image. Modes still change per scene.
    totals = {}
    for s in scenes:
        totals[s["f"]["key"]] = totals.get(s["f"]["key"], 0) + 1
    root = COLOURS[max(totals, key=totals.get)][4]

    out = [
        "# ═══ Performance set " + "═" * 50,
        f"# {len(scenes)} images, {bars} bars each, shared tonic {root.upper()}, 1-bar crossfades.",
        "# Running order (edit the list at the bottom to rearrange):",
    ]
    total = 0.0
    for i, s in enumerate(scenes, 1):
        secs = bars * 4 * 60 / s["m"]["bpm"]
        out.append(f"#   {i}. {total // 60:.0f}:{total % 60:04.1f}  {s['name']:<28} {s['m']['bpm']:>3} bpm  "
                   f"{s['f']['key']:<7} drums: {s['m']['drum_label']}")
        total += secs - 4 * 60 / s["m"]["bpm"]
    out.append("")
    for s in scenes:
        out += [render_scene(s["name"], s["f"], s["m"], root), ""]
    out += [
        "# ── running order ──────────────────────────────────────────────",
        "# Each scene is called as: name bars, fade_bars. The sleep is the scene's",
        "# length in seconds minus its last bar, so the next one fades in over it.",
        "# Reorder, repeat or delete pairs of lines to reshape the set.",
        "use_bpm 60",
        "",
    ]
    for s in scenes:
        bar_secs = 4 * 60 / s["m"]["bpm"]
        out += [f"in_thread {{ {s['name']} {bars}, 1 }}", f"sleep {round((bars - 1) * bar_secs, 2)}", ""]
    return "\n".join(out)


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Images -> Sonic Pi code / performance set")
    ap.add_argument("images", nargs="+", type=Path)
    ap.add_argument("-o", "--out", type=Path, default=Path("output"))
    ap.add_argument("--bars", type=int, default=8, help="bars per scene in the set (default 8)")
    ap.add_argument("--order", choices=("arc", "given"), default="arc",
                    help="set order: energy arc (default) or the order given on the command line")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    scenes, taken = [], set()
    for path in args.images:
        try:
            f = analyse(path)
        except Exception as e:  # not an image, unreadable, ...
            print(f"skip {path}: {e}", file=sys.stderr)
            continue
        m = decide(f)
        name = scene_name(path, taken)
        dest = args.out / f"{name}.rb"
        dest.write_text(render_single(name, render_scene(name, f, m)))
        scenes.append({"name": name, "f": f, "m": m})
        print(f"{Path(path).name:<22} {f['key']:<7} {m['root'].upper()} {m['scale']:<15} {m['bpm']:>3} bpm  "
              f"sharp {f['sharpness']:.2f} dens {f['density']:.2f} -> {m['drum_label']:<20} {dest}")

    if not scenes:
        sys.exit("no readable images")
    if len(scenes) > 1:
        dest = args.out / "set.rb"
        dest.write_text(render_set(scenes, args.bars, args.order))
        print(f"\nset: {dest}\nIn Sonic Pi, run:  run_file \"{dest.resolve()}\"")


if __name__ == "__main__":
    main()
