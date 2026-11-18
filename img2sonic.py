#!/usr/bin/env python3
"""
img2sonic — turn images into Sonic Pi code, and several images into one live set.

    python img2sonic.py photo.jpg                 -> output/scene_photo.rb
    python img2sonic.py a.jpg b.jpg c.jpg         -> one file each + output/set.rb
    python img2sonic.py img:/* --bars 24 --transition 8 --bpm 84 --order given

How the picture becomes music
  COLOUR  -> feeling. Each colour family has an entry in COLOURS below
             (mood, scale, synths, valence, arousal). The strongest colour
             picks the scale and pad; the blend of all colours sets the chord
             progression and tempo. Edit COLOURS to change the mapping.
  LINES   -> percussion. Sharp, definite edges give crisp, busy drums.
             Blurred / soft edges give little or no percussion, slower pads,
             more reverb and a drone (ambient).
  LIGHT   -> register and filter brightness (dark image = low and muffled).
  SHAPE   -> melody. The image is read left to right in 16 strips; where the
             detail sits vertically in each strip sets the pitch. Neighbouring
             strips on the same pitch are tied into one long note.

Everything melodic is played on soft pad voices (slow attack, long release,
low-pass filtered) so the scenes share one vibe.

Every file starts with the same small player (scene_tune, scene_drums,
play_scene). Each image is then one function holding its settings:
    scene_x bars, step, last

In a set every scene has the same tempo and the same seven notes (each colour
keeps its own mode, moved to the relative key), so anything can overlap.
Scenes are called one after another and each one takes over in stages:
    old melody fades out, old drums keep going
    new melody fades in slowly
    then the hats switch, then the snare, and last the kick
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
    "red":    ("passion, urgency, intensity",   0.0,  1.00, "harmonic_minor", "e", "blade",         "blade"),
    "orange": ("warmth, enthusiasm",            0.6,  0.75, "mixolydian",     "d", "blade",         "tri"),
    "yellow": ("joy, optimism",                 0.9,  0.70, "major",          "c", "blade",         "sine"),
    "green":  ("nature, balance, growth",       0.5,  0.35, "major",          "g", "hollow",        "tri"),
    "blue":   ("calm, depth, melancholy",      -0.3,  0.20, "minor",          "a", "hollow",        "sine"),
    "purple": ("mystery, dreaminess",           0.0,  0.40, "dorian",         "f", "dark_ambience", "blade"),
    "pink":   ("tenderness, playfulness",       0.7,  0.45, "major",          "f", "hollow",        "tri"),
    "brown":  ("earthiness, stability",         0.1,  0.25, "dorian",         "d", "dark_ambience", "tri"),
    "black":  ("weight, the unknown",          -0.6,  0.30, "harmonic_minor", "c", "dark_ambience", "hollow"),
    "white":  ("openness, stillness",           0.4,  0.10, "lydian",         "c", "hollow",        "sine"),
    "gray":   ("neutrality, distance",         -0.2,  0.15, "minor",          "a", "dark_ambience", "hollow"),
}
# Every voice above is a soft one. LEAD_GAIN evens out their loudness and
# LEAD_SWAP keeps the melody from disappearing into a pad of the same timbre.
LEAD_GAIN = {"hollow": 1.8, "sine": 0.7, "tri": 0.6, "blade": 0.7}
LEAD_SWAP = {"hollow": "tri", "blade": "sine", "dark_ambience": "hollow"}
# Where each mode's tonic sits above its relative major (semitones). Used to
# put every scene of a set on the same seven notes.
MODE_OFFSET = {"major": 0, "dorian": 2, "phrygian": 4, "lydian": 5, "mixolydian": 7, "minor": 9}
NOTE_NAMES = ["c", "cs", "d", "eb", "e", "f", "fs", "g", "ab", "a", "bb", "b"]
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
    lead = COLOURS[f["second"]][6]
    if lead == pad:
        lead = LEAD_SWAP.get(lead, lead)
    a, sharp = f["activity"], f["sharpness"]

    bpm = round((55 + 75 * f["arousal"]) * (0.85 + 0.3 * a))
    v = f["valence"]
    prog = (["i", "v", "vi", "iv"] if v > 0.4 else ["i", "iv", "i", "v"] if v > 0.1
            else ["i", "vii", "iv", "i"] if v > -0.2 else ["i", "vi", "iii", "vii"])

    # Melody: pentatonic-flavoured degrees of the 7-note scale, about a tenth wide
    # so it stays in a warm register.
    penta = [0, 2, 3, 4, 6] if scale in MINORISH else [0, 1, 2, 4, 5]
    ladder = penta + [d + 7 for d in penta[:3]]
    wt = np.array(f["strip_weight"])
    # Quiet strips become rests; muted, low-energy images rest more.
    rest_below = np.quantile(wt, clamp(0.55 - 0.4 * f["saturation"] - 0.3 * f["arousal"], 0.1, 0.6))
    melody = [ladder[min(len(ladder) - 1, int(c * len(ladder)))] if w >= rest_below else None
              for c, w in zip(f["contour"], wt)]
    # Tie repeated pitches into one held note: holds[i] = length in steps, 0 = no new note.
    holds, start = [0] * len(melody), None
    for i, d in enumerate(melody):
        if d is None:
            start = None
        elif start is not None and melody[start] == d and holds[start] < 8:
            holds[start] += 1
        else:
            start, holds[i] = i, 1

    kick, snare, hat, drum_label = drums(a)
    crisp = sharp >= 0.55

    # Bass: a :dsaw note on every kick (plus the off-beats when the image is busy),
    # each held until the next one. No kick -> one long note per bar.
    hits = sorted({i for i, k in enumerate(kick) if k} | ({2, 6, 10, 14} if a >= 0.72 else set()))
    bass = [0] * 16
    if not hits:
        bass[0] = 16
    for j, i in enumerate(hits):
        bass[i] = (hits[j + 1] if j + 1 < len(hits) else 16) - i
    return {
        "feeling": feeling, "scale": scale, "root_pc": PITCH[root], "pad": pad, "lead": lead,
        "bpm": bpm, "prog": prog, "melody": melody, "holds": holds,
        "kick": kick, "snare": snare, "hat": hat, "drum_label": drum_label,
        "kick_s": "bd_klub" if crisp else "bd_fat",
        "snare_s": "sn_dolf" if crisp else "drum_snare_soft",
        "hat_s": "drum_cymbal_closed" if crisp else "drum_cymbal_soft",
        "bass": bass,
        "bass_amp": round(0.35 + 0.25 * a, 2),
        "bass_lpf": round(68 + 30 * f["brightness"] + 12 * sharp),
        "kick_on": any(kick), "snare_on": any(snare), "hat_on": any(hat),
        "drum_amp": round(0.35 + 0.75 * a, 2),
        "drum_lpf": round(75 + 55 * sharp),
        "low": f["brightness"] < 0.35,
        "cutoff": round(62 + 40 * f["brightness"]),
        "reverb": round(0.4 + 0.4 * (1 - sharp), 2),
        "room": round(0.6 + 0.35 * (1 - sharp), 2),
        "pad_attack": round(0.6 + 1.9 * (1 - sharp), 2),
        "lead_attack": round(0.12 + 0.3 * (1 - sharp), 2),
        "lead_release": round(0.8 + 1.4 * (1 - sharp), 2),
        "lead_lpf": round(72 + 26 * f["brightness"]),
        "lead_amp": round((0.3 + 0.25 * f["saturation"] + 0.1 * f["contrast"]) * LEAD_GAIN[lead], 2),
        "drone": a < 0.42,
        "energy": 0.5 * a + 0.5 * f["arousal"],
    }


def root_note(m):
    """Tonic as a Sonic Pi note: G2..F#3 for dark images, C3..B3 for bright ones."""
    base = 43 if m["low"] else 48
    midi = base + (m["root_pc"] - base) % 12
    return f"{NOTE_NAMES[midi % 12]}{midi // 12 - 1}"


def share_key(scenes):
    """Put every scene on the same seven notes. The most common leading colour
    names the key; every other scene keeps its mode but moves to the relative
    tonic (G major / A dorian / E minor ...). Harmonic minor becomes natural
    minor, because its raised 7th is the one note that would clash."""
    totals = {}
    for s in scenes:
        totals[s["f"]["key"]] = totals.get(s["f"]["key"], 0) + 1
    _, _, _, scale, root, _, _ = COLOURS[max(totals, key=totals.get)]
    scale = "minor" if scale == "harmonic_minor" else scale
    parent = (PITCH[root] - MODE_OFFSET[scale]) % 12
    for s in scenes:
        m = s["m"]
        if m["scale"] == "harmonic_minor":
            m["scale"] = "minor"
        m["root_pc"] = (parent + MODE_OFFSET[m["scale"]]) % 12
    return NOTE_NAMES[parent].upper() + " major"


# ----# --------------------------------------------------------------------------
# Sonic Pi code generation
# --------------------------------------------------------------------------
def scene_name(path, taken):
    base = "scene_" + (re.sub(r"[^a-z0-9]+", "_", Path(path).stem.lower()).strip("_") or "image")
    name, n = base, 2
    while name in taken:
        name, n = f"{base}_{n}", n + 1
    taken.add(name)
    return name


def rb(v):
    return "true" if v else "false"


def ring(values):
    return "(ring " + ", ".join("nil" if v is None else str(v) for v in values) + ")"


# The player, written once per file. Each image is then only a block of settings
# (this also keeps set.rb small: Sonic Pi on the web crashes on very long code).
ENGINE = """\
# ── the player: shared by every scene ───────────────────────────
# s is a scene's settings. Fades are in bars.
#
# Mix (loudest to quietest): melody, pad, chord stabs, drums, bass.
# Scenes with a backbeat get the techno treatment: four-on-the-floor kick,
# off-beat open hats and bass, a sidechain-style pump on the pad, and
# echoed chord stabs.
define :scene_fade do |vol, bars, fade_in, fade_out|
  sleep 0.01
  control vol, amp: 1, amp_slide: fade_in * 4
  sleep (bars - fade_out) * 4 - 0.01
  control vol, amp: 0, amp_slide: fade_out * 4 if fade_out > 0
  sleep fade_out * 4
end

# a chord squeezed into the octave above `lo`, so it sits between the bass
# (an octave below the root) and the melody (from an octave above the root)
define :mid_voicing do |degree, root, mode, size, lo|
  chord_degree(degree, root, mode, size).to_a.map { |n| lo + (n - lo) % 12 }.sort
end

# pads + chord stabs + melody (+ drone)
define :scene_tune do |s, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed] + get(:take).to_i
  c     = s[:chaos]
  root  = note(s[:root])
  notes = scale(root + 12, s[:mode], num_octaves: 3)
  techno = s[:snare_on]
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :reverb, room: s[:room], mix: s[:reverb] do
      in_thread do  # harmony - colour mood, pumping with the kick in techno scenes
        with_fx :slicer, phase: 1, wave: 0, amp_min: 0.3, smooth: 0.04, mix: (techno ? 0.6 : 0) do
          bars.times do |b|
            lo = root - 5 + (rand < c * 0.6 ? [-2, 2].choose : 0)  # random voicing
            synth s[:pad], notes: mid_voicing(s[:chords][b], root, s[:mode], 3, lo),
              attack: s[:pad_attack], sustain: [3.5 - s[:pad_attack], 0.5].max, release: 2,
              cutoff: s[:cutoff] + rrand(-10, 10) * c, amp: 0.65
            sleep 4
          end
        end
      end
      in_thread do  # chords - 7th chords between bass and melody, rhythm from the drums
        hits = if !s[:hat_on] then [[0, 2], [2, 2]]                  # ambient: half notes
               elsif !techno then [[0, 1.5], [1.5, 1.5], [3, 1]]    # sparse: 3+3+2
               else [[0.5, 0.25], [1.5, 0.25], [2.5, 0.25], [3.5, 0.25]]  # off-beat stabs
               end
        with_fx :echo, phase: 0.75, decay: 3, mix: (techno ? 0.3 : 0.15) do
          bars.times do |b|
            ch = mid_voicing(s[:chords][b], root, s[:mode], 4, root - 2)
            t = 0
            hits.each do |at, len|
              sleep at - t
              t = at
              next if rand < c * 0.15
              synth :prophet, notes: ch, attack: (len >= 1 ? 0.2 : 0.005),
                sustain: len * 0.6, release: (len >= 1 ? len * 0.5 : 0.2),
                cutoff: s[:cutoff] - 4 + rrand(-6, 6) * c, res: 0.2, amp: 0.4
            end
            sleep 4 - t
          end
        end
      end
      in_thread do  # melody - the image read left to right, on a soft pad voice
        # high notes: quieter the higher they go, a gentle high-shelf cut, and a
        # compressor that squashes the loud peaks so nothing pierces
        with_fx :compressor, threshold: 0.25, slope_above: 0.4, clamp_time: 0.01,
            relax_time: 0.15, pre_amp: 1, amp: 1.1 do
          with_fx :eq, high_shelf: -0.4, high_shelf_note: 84 do
            with_fx :echo, phase: 0.75, decay: 2, mix: 0.18 do
              with_fx :lpf, cutoff: s[:lead_lpf] do
                (bars * 8).times do |i|
                  if s[:holds][i] > 0
                    d = s[:steps][i]
                    d = [d + [-1, 1].choose, 0].max if rand < c * 0.4  # wander to a neighbour
                    d += 7 if rand < c * 0.12                          # jump up an octave
                    n = notes[d]
                    tame = 1 - [[(n - root - 17) * 0.035, 0].max, 0.4].min  # -3.5% per semitone above the 5th
                    synth s[:lead], note: n, attack: s[:lead_attack],
                      sustain: s[:holds][i] * 0.5 - s[:lead_attack], release: s[:lead_release],
                      amp: s[:lead_amp] * 1.5 * tame * rrand(0.8, 1), pan: rrand(-0.4, 0.4)
                  end
                  sleep 0.5
                end
              end
            end
          end
        end
      end
      if s[:drone]  # soft lines leave room for air
        in_thread do
          (bars / 2.0).ceil.times do
            synth :dark_ambience, note: root - 12, attack: 3, sustain: 2, release: 3, amp: 0.35
            sleep 8
          end
        end
      end
    end
    scene_fade vol, bars, fade_in, fade_out
  end
end

# percussion. part = :high (hats), :mid (snare), :low (kick) or :all
# The bass rides with the kick (part :low), so it hands over with it.
define :scene_drums do |s, part = :all, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed] + get(:take).to_i
  c   = s[:chaos]
  techno = s[:snare_on]
  low = (part == :all || part == :low)
  mid = (part == :all || part == :mid)
  hi  = (part == :all || part == :high)
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :lpf, cutoff: s[:drum_lpf] do
      in_thread do
        (bars * 16).times do |i|
          fill = (i % 64) >= 60 && rand < c  # end of every 4th bar: maybe a fill
          if low
            if s[:kick][i] > 0 || (techno && i % 4 == 0)  # techno: four on the floor
              sample s[:kick_s], amp: s[:drum_amp] unless i % 16 > 0 && rand < c * 0.1
            elsif s[:kick_on] && rand < c * 0.06
              sample s[:kick_s], amp: s[:drum_amp] * 0.6       # stray kick
            end
          end
          if mid
            if s[:snare][i] > 0
              sample s[:snare_s], amp: s[:drum_amp] * (s[:snare][i] == 2 ? 0.9 : 0.35)
              sample :perc_snap, amp: s[:drum_amp] * 0.4 if s[:snare][i] == 2  # clap layer
            elsif s[:snare_on] && (fill || rand < c * 0.08)
              sample s[:snare_s], amp: s[:drum_amp] * rrand(0.15, 0.4)  # ghost note / fill
            end
          end
          if hi
            if s[:hat][i] > 0 ? rand > c * 0.25 : (s[:hat_on] && rand < c * 0.15)
              sample s[:hat_s], amp: s[:drum_amp] * 0.5 * rrand(0.5, 1), finish: 0.2,
                rate: 1 + rrand(-0.06, 0.06) * c, pan: rrand(-0.3, 0.3) * c
            end
            if techno && i % 4 == 2  # off-beat open hat
              sample :drum_cymbal_open, amp: s[:drum_amp] * 0.35, finish: 0.12, rate: 1.1
            end
          end
          sleep 0.25
        end
      end
    end
    if low
      in_thread do  # bassline - chord roots
        root = note(s[:root]) - 12
        (bars * 16).times do |i|
          tri = chord_degree(s[:chords][i / 16], root, s[:mode], 3)
          if techno  # rolling off-beat bass between the kicks
            if i % 4 == 2 || (i % 4 == 3 && rand < c * 0.3)
              n = rand < c * 0.3 ? [tri[2], tri[0] + 12].choose : tri[0]
              synth :tb303, note: n, wave: 0, attack: 0, sustain: 0.1, release: 0.15,
                cutoff: s[:bass_lpf] - 8 + rrand(-6, 6) * c, res: 0.3,
                amp: s[:bass_amp] * 0.5 * rrand(0.85, 1)
            end
          else       # held until the next hit
            len = s[:bass][i]
            if len > 0
              n = rand < c * 0.35 ? [tri[2], tri[0] + 12].choose : tri[0]
              synth :dsaw, note: n, attack: (len >= 8 ? 0.6 : 0.01),
                sustain: [len * 0.25 - 0.2, 0.05].max, release: (len >= 8 ? 1 : 0.15),
                detune: 0.1 + rrand(0, 0.15) * c, cutoff: s[:bass_lpf] + rrand(-10, 10) * c,
                amp: s[:bass_amp] * 0.6 * rrand(0.85, 1)
            elsif s[:kick_on] && i.odd? && rand < c * 0.1  # passing 16th
              synth :dsaw, note: [tri[0], tri[2]].choose + [0, 12].choose, sustain: 0.05,
                release: 0.1, cutoff: s[:bass_lpf], amp: s[:bass_amp] * 0.4
            end
          end
          sleep 0.25
        end
      end
    end
    scene_fade vol, bars, fade_in, fade_out
  end
end

# a whole scene. step = 0: everything together, no fades (good for looping).
# step > 0: staged takeover - the melody fades in over 2 steps, then the hats,
# snare and kick switch one step apart. last: stretch the melody over the ending.
define :play_scene do |s, bars = 8, step = 0, last = false|
  use_bpm s[:bpm]
  xf = step > 0 ? 1 : 0  # drum layers swap over one bar
  in_thread { scene_tune s, bars + (last ? step * 4 : 0), step * 2, step * 2 }
  in_thread { sleep step * 8;  scene_drums s, :high, bars + xf, xf, xf }
  in_thread { sleep step * 12; scene_drums s, :mid,  bars + xf, xf, xf }
  in_thread { sleep step * 16; scene_drums s, :low,  bars + xf, xf, xf }
  sleep bars * 4
end
"""


def render_scene(name, f, m):
    """One image -> a `define` holding its settings, played by the shared player."""
    root = root_note(m)
    top = sorted(((p, c) for c, p in f["shares"].items() if p >= 0.03), reverse=True)[:4]
    palette = ", ".join(f"{c} {p:.0%}" for p, c in top)
    L = [
        f"# ── {Path(f['path']).name} " + "─" * max(4, 60 - len(Path(f['path']).name)),
        f"# colour : {palette}",
        f"#          {f['key']} leads -> {m['feeling']} -> {root[:-1].upper()} {m['scale']}",
        f"# lines  : sharpness {f['sharpness']:.2f}, density {f['density']:.2f}"
        f" -> percussion: {m['drum_label']}",
        f"# light  : brightness {f['brightness']:.2f}, saturation {f['saturation']:.2f}",
        f"define :{name} do |bars = 8, step = 0, last = false|",
        f"  play_scene({{",
        f"    bpm: {m['bpm']}, seed: {f['seed']}, root: :{root}, mode: :{m['scale']},",
        f"    room: {m['room']}, reverb: {m['reverb']},",
        f"    pad: :{m['pad']}, pad_attack: {m['pad_attack']}, cutoff: {m['cutoff']},",
        f"    chords: (ring {', '.join(':' + d for d in m['prog'])}),",
        f"    lead: :{m['lead']}, lead_attack: {m['lead_attack']}, lead_release: {m['lead_release']},",
        f"    lead_lpf: {m['lead_lpf']}, lead_amp: {m['lead_amp']}, drone: {'true' if m['drone'] else 'false'},",
        f"    steps: {ring(0 if d is None else d for d in m['melody'])},",
        f"    holds: {ring(m['holds'])},  # steps each note is held, 0 = rest",
        f"    kick:  {ring(m['kick'])},",
        f"    snare: {ring(m['snare'])},",
        f"    hat:   {ring(m['hat'])},",
        f"    kick_s: :{m['kick_s']}, snare_s: :{m['snare_s']}, hat_s: :{m['hat_s']},",
        f"    drum_amp: {m['drum_amp']}, drum_lpf: {m['drum_lpf']},",
        f"    kick_on: {rb(m['kick_on'])}, snare_on: {rb(m['snare_on'])}, hat_on: {rb(m['hat_on'])},",
        f"    bass: {ring(m['bass'])},  # steps each bass note is held",
        f"    bass_amp: {m['bass_amp']}, bass_lpf: {m['bass_lpf']},",
        f"    chaos: {m['chaos']}  # 0 = plays exactly as written, 1 = very loose",
        f"  }}, bars, step, last)",
        f"end",
    ]
    return "\n".join(L)


def render_single(name, block):
    return (f"{ENGINE}\n{block}\n\n# Loop this image on its own. Change the 8 to play longer phrases.\n"
            f"live_loop :play_{name} do\n  set :take, tick  # a new random take every pass\n  {name} 8\nend\n")


def arc_order(scenes):
    """Calm -> build -> peak -> come down: low energy at the edges, high in the middle."""
    by_energy = sorted(scenes, key=lambda s: s["m"]["energy"])
    rise, fall = by_energy[0::2], by_energy[1::2]
    return rise + fall[::-1] if len(scenes) > 2 else by_energy


def clock(bar, bpm):
    secs = bar * 240 / bpm
    return f"{secs // 60:.0f}:{secs % 60:04.1f}"


def render_set(scenes, bars, step, key_name, order):
    if order == "arc":
        scenes = arc_order(scenes)
    bpm = scenes[0]["m"]["bpm"]
    end = len(scenes) * bars + step * 4
    out = [
        "# ═══ Live set " + "═" * 57,
        f"# {len(scenes)} images, {bpm} bpm throughout, all on the notes of {key_name}.",
        f"# {bars} bars per scene, about {clock(end, bpm)} in total.",
        "#",
        f"# How one scene hands over to the next (bars counted from the new scene's start):",
        f"#   -{step * 2:<3} old melody starts fading out, old drums keep going",
        f"#    0   new melody starts fading in ({step * 2} bars)",
        f"#   +{step * 2:<3} hats switch to the new scene",
        f"#   +{step * 3:<3} snare switches",
        f"#   +{step * 4:<3} kick switches - the new scene has fully arrived",
        "# The first scene builds up the same way and the last one strips back",
        "# hats -> snare -> kick while its melody fades.",
        "#",
        "# Running order (edit the list at the bottom to rearrange):",
    ]
    for i, s in enumerate(scenes):
        out.append(f"#   {i + 1:>2}. {clock(i * bars, bpm):>7}  {s['name']:<26} {s['f']['key']:<7}"
                   f"{root_note(s['m'])[:-1].upper():<3}{s['m']['scale']:<11} drums: {s['m']['drum_label']}")
    out += ["", ENGINE]
    for s in scenes:
        out += [render_scene(s["name"], s["f"], s["m"]), ""]
    out += [
        "# ── running order ──────────────────────────────────────────────",
        "# Each line is: name bars, step. `bars` is how long the scene lasts, `step`",
        "# is the pace of the handover (melody fades take 2 steps, then hats, snare",
        "# and kick switch one step apart). Reorder, repeat or delete lines to",
        "# reshape the set; keep `true` on the last line so the ending strips back.",
        f"use_bpm {bpm}",
        "set :take, 0  # change this number for a different random take of the whole set",
        "",
    ]
    width = max(len(s["name"]) for s in scenes)
    for i, s in enumerate(scenes):
        out.append(f"{s['name']:<{width}} {bars}, {step}" + (", true" if i == len(scenes) - 1 else ""))
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Images -> Sonic Pi code / live set")
    ap.add_argument("images", nargs="+", type=Path)
    ap.add_argument("-o", "--out", type=Path, default=Path("output"))
    ap.add_argument("--bars", type=int, default=16, help="bars per scene in the set (default 16)")
    ap.add_argument("--transition", type=int, default=None,
                    help="bars from the new melody starting until its kick has taken over "
                         "(multiple of 4, default: half of --bars)")
    ap.add_argument("--bpm", type=int, default=None,
                    help="tempo for every scene (default: the median of what the images suggest)")
    ap.add_argument("--order", choices=("arc", "given"), default="arc",
                    help="set order: energy arc (default) or the order given on the command line")
    ap.add_argument("--chaos", type=float, default=0.35,
                    help="randomness 0..1: wandering melody, ghost notes, fills, bass variations "
                         "(default 0.35)")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    scenes, taken = [], set()
    for path in args.images:
        try:
            f = analyse(path)
        except Exception as e:  # not an image, unreadable, ...
            print(f"skip {path}: {e}", file=sys.stderr)
            continue
        scenes.append({"name": scene_name(path, taken), "f": f, "m": decide(f)})
        scenes[-1]["m"]["chaos"] = round(max(0.0, min(1.0, args.chaos)), 2)
    if not scenes:
        sys.exit("no readable images")

    # One tempo and one set of notes for everything, so scenes can overlap.
    bpm = args.bpm or round(float(np.median([s["m"]["bpm"] for s in scenes])))
    for s in scenes:
        s["m"]["bpm"] = bpm
    key_name = share_key(scenes) if len(scenes) > 1 else None

    for s in scenes:
        f, m = s["f"], s["m"]
        dest = args.out / f"{s['name']}.rb"
        dest.write_text(render_single(s["name"], render_scene(s["name"], f, m)))
        print(f"{Path(f['path']).name:<22} {f['key']:<7} {root_note(m)[:-1].upper():<2} {m['scale']:<11} "
              f"pad {m['pad']:<13} lead {m['lead']:<7} sharp {f['sharpness']:.2f} -> {m['drum_label']:<20} {dest}")

    if len(scenes) > 1:
        bars = max(4, args.bars)
        transition = args.transition if args.transition is not None else bars // 2
        step = max(1, min(transition, bars) // 4)
        dest = args.out / "set.rb"
        dest.write_text(render_set(scenes, bars, step, key_name, args.order))
        print(f"\n{bpm} bpm, {key_name}, {bars} bars per scene, {step * 4}-bar handover"
              f"\nset: {dest}\nIn Sonic Pi, run:  run_file \"{dest.resolve()}\"")


if __name__ == "__main__":
    main()
