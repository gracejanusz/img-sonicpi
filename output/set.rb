# ═══ Live set ═════════════════════════════════════════════════════════
# 10 images, 84 bpm throughout, all on the notes of G major.
# 16 bars per scene, about 8:00.0 in total.
#
# How one scene hands over to the next (bars counted from the new scene's start):
#   -4   old melody starts fading out, old drums keep going
#    0   new melody starts fading in (4 bars)
#   +4   hats switch to the new scene
#   +6   snare switches
#   +8   kick switches - the new scene has fully arrived
# The first scene builds up the same way and the last one strips back
# hats -> snare -> kick while its melody fades.
#
# Running order (edit the list at the bottom to rearrange):
#    1.  0:00.0  scene_scream_blurr         blue   E  minor       drums: a soft pulse
#    2.  0:45.7  scene_night                black  E  minor       drums: steady backbeat
#    3.  1:31.4  scene_kid_grace            brown  A  dorian      drums: driving
#    4.  2:17.1  scene_dragon               green  G  major       drums: very active
#    5.  3:02.9  scene_recordlibrary        brown  A  dorian      drums: very active
#    6.  3:48.6  scene_glitchcore           green  G  major       drums: very active
#    7.  4:34.3  scene_cicado               green  G  major       drums: busy, syncopated
#    8.  5:20.0  scene_texture              gray   E  minor       drums: very active
#    9.  6:05.7  scene_audiogram            purple A  dorian      drums: driving
#   10.  6:51.4  scene_snow_laying          black  E  minor       drums: steady backbeat

# ── the player: shared by every scene ───────────────────────────
# s is a scene's settings. Fades are in bars.
define :scene_fade do |vol, bars, fade_in, fade_out|
  sleep 0.01
  control vol, amp: 1, amp_slide: fade_in * 4
  sleep (bars - fade_out) * 4 - 0.01
  control vol, amp: 0, amp_slide: fade_out * 4 if fade_out > 0
  sleep fade_out * 4
end

# pads + melody (+ drone)
define :scene_tune do |s, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed] + get(:take).to_i
  c     = s[:chaos]
  root  = note(s[:root])
  notes = scale(root + 12, s[:mode], num_octaves: 3)
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :reverb, room: s[:room], mix: s[:reverb] do
      in_thread do  # harmony - colour mood
        bars.times do |b|
          ch = chord_degree(s[:chords][b], root, s[:mode], 3)
          ch = invert_chord(ch, [1, -1].choose) if rand < c * 0.6  # random voicing
          synth s[:pad], notes: ch,
            attack: s[:pad_attack], sustain: [3.5 - s[:pad_attack], 0.5].max, release: 2,
            cutoff: s[:cutoff] + rrand(-10, 10) * c, amp: 0.6
          sleep 4
        end
      end
      in_thread do  # melody - the image read left to right, on a soft pad voice
        with_fx :lpf, cutoff: s[:lead_lpf] do
          (bars * 8).times do |i|
            if s[:holds][i] > 0
              d = s[:steps][i]
              d = [d + [-1, 1].choose, 0].max if rand < c * 0.4  # wander to a neighbour
              d += 7 if rand < c * 0.12                          # jump up an octave
              synth s[:lead], note: notes[d], attack: s[:lead_attack],
                sustain: s[:holds][i] * 0.5 - s[:lead_attack], release: s[:lead_release],
                amp: s[:lead_amp] * rrand(0.8, 1), pan: rrand(-0.4, 0.4)
            end
            sleep 0.5
          end
        end
      end
      if s[:drone]  # soft lines leave room for air
        in_thread do
          (bars / 2.0).ceil.times do
            synth :dark_ambience, note: root - 12, attack: 3, sustain: 2, release: 3, amp: 0.5
            sleep 8
          end
        end
      end
    end
    scene_fade vol, bars, fade_in, fade_out
  end
end

# percussion. part = :high (hats), :mid (snare), :low (kick) or :all
# The :dsaw bass rides with the kick (part :low), so it hands over with it.
define :scene_drums do |s, part = :all, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed] + get(:take).to_i
  c   = s[:chaos]
  low = (part == :all || part == :low)
  mid = (part == :all || part == :mid)
  hi  = (part == :all || part == :high)
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :lpf, cutoff: s[:drum_lpf] do
      in_thread do
        (bars * 16).times do |i|
          fill = (i % 64) >= 60 && rand < c  # end of every 4th bar: maybe a fill
          if low
            if s[:kick][i] > 0
              sample s[:kick_s], amp: s[:drum_amp] unless i % 16 > 0 && rand < c * 0.1
            elsif s[:kick_on] && rand < c * 0.06
              sample s[:kick_s], amp: s[:drum_amp] * 0.6       # stray kick
            end
          end
          if mid
            if s[:snare][i] > 0
              sample s[:snare_s], amp: s[:drum_amp] * (s[:snare][i] == 2 ? 0.9 : 0.35)
            elsif s[:snare_on] && (fill || rand < c * 0.08)
              sample s[:snare_s], amp: s[:drum_amp] * rrand(0.15, 0.4)  # ghost note / fill
            end
          end
          if hi
            if s[:hat][i] > 0 ? rand > c * 0.25 : (s[:hat_on] && rand < c * 0.15)
              sample s[:hat_s], amp: s[:drum_amp] * 0.5 * rrand(0.5, 1), finish: 0.2,
                rate: 1 + rrand(-0.06, 0.06) * c, pan: rrand(-0.3, 0.3) * c
            end
          end
          sleep 0.25
        end
      end
    end
    if low
      in_thread do  # bassline - chord roots, held until the next hit
        root = note(s[:root]) - 12
        (bars * 16).times do |i|
          tri = chord_degree(s[:chords][i / 16], root, s[:mode], 3)
          len = s[:bass][i]
          if len > 0
            n = rand < c * 0.35 ? [tri[2], tri[0] + 12].choose : tri[0]
            synth :dsaw, note: n, attack: (len >= 8 ? 0.6 : 0.01),
              sustain: [len * 0.25 - 0.2, 0.05].max, release: (len >= 8 ? 1 : 0.15),
              detune: 0.1 + rrand(0, 0.15) * c, cutoff: s[:bass_lpf] + rrand(-10, 10) * c,
              amp: s[:bass_amp] * rrand(0.85, 1)
          elsif s[:kick_on] && i.odd? && rand < c * 0.1  # passing 16th
            synth :dsaw, note: [tri[0], tri[2]].choose + [0, 12].choose, sustain: 0.05,
              release: 0.1, cutoff: s[:bass_lpf], amp: s[:bass_amp] * 0.6
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

# ── scream-blurr.JPG ────────────────────────────────────────────
# colour : blue 47%, gray 19%, black 17%, purple 7%
#          blue leads -> calm, depth, melancholy -> E minor
# lines  : sharpness 0.27, density 0.01 -> percussion: a soft pulse
# light  : brightness 0.38, saturation 0.27
define :scene_scream_blurr do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 97050, root: :e3, mode: :minor,
    room: 0.85, reverb: 0.69,
    pad: :hollow, pad_attack: 1.98, cutoff: 77,
    chords: (ring :i, :vii, :iv, :i),
    lead: :tri, lead_attack: 0.34, lead_release: 1.82,
    lead_lpf: 82, lead_amp: 0.26, drone: true,
    steps: (ring 0, 0, 0, 0, 2, 4, 6, 7, 10, 6, 3, 0, 0, 0, 0, 0),
    holds: (ring 0, 0, 2, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    hat:   (ring 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    kick_s: :bd_fat, snare_s: :drum_snare_soft, hat_s: :drum_cymbal_soft,
    drum_amp: 0.48, drum_lpf: 90,
    kick_on: true, snare_on: false, hat_on: false,
    bass: (ring 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),  # steps each bass note is held
    bass_amp: 0.39, bass_lpf: 83,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── night.jpeg ──────────────────────────────────────────────────
# colour : black 82%, yellow 13%, orange 4%
#          black leads -> weight, the unknown -> E minor
# lines  : sharpness 0.60, density 0.42 -> percussion: steady backbeat
# light  : brightness 0.16, saturation 0.48
define :scene_night do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 21494, root: :e3, mode: :minor,
    room: 0.74, reverb: 0.56,
    pad: :dark_ambience, pad_attack: 1.35, cutoff: 69,
    chords: (ring :i, :vii, :iv, :i),
    lead: :sine, lead_attack: 0.24, lead_release: 1.36,
    lead_lpf: 76, lead_amp: 0.35, drone: false,
    steps: (ring 4, 6, 7, 9, 10, 10, 10, 10, 10, 9, 9, 0, 0, 0, 0, 0),
    holds: (ring 1, 1, 1, 1, 5, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 1),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    hat:   (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.71, drum_lpf: 108,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 8, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0),  # steps each bass note is held
    bass_amp: 0.47, bass_lpf: 80,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── kid-grace.jpeg ──────────────────────────────────────────────
# colour : brown 38%, orange 24%, yellow 11%, black 8%
#          brown leads -> earthiness, stability -> A dorian
# lines  : sharpness 0.72, density 0.66 -> percussion: driving
# light  : brightness 0.45, saturation 0.31
define :scene_kid_grace do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 64919, root: :a3, mode: :dorian,
    room: 0.7, reverb: 0.51,
    pad: :dark_ambience, pad_attack: 1.14, cutoff: 80,
    chords: (ring :i, :iv, :i, :v),
    lead: :tri, lead_attack: 0.21, lead_release: 1.2,
    lead_lpf: 84, lead_amp: 0.27, drone: false,
    steps: (ring 0, 0, 6, 6, 7, 7, 7, 9, 9, 10, 10, 6, 0, 7, 0, 0),
    holds: (ring 0, 0, 2, 0, 3, 0, 0, 2, 0, 2, 0, 1, 0, 1, 0, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    hat:   (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.82, drum_lpf: 114,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0),  # steps each bass note is held
    bass_amp: 0.51, bass_lpf: 90,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── dragon.jpg ──────────────────────────────────────────────────
# colour : white 69%, green 22%, black 8%
#          green leads -> nature, balance, growth -> G major
# lines  : sharpness 1.00, density 1.00 -> percussion: very active
# light  : brightness 0.85, saturation 0.09
define :scene_dragon do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 86004, root: :g3, mode: :major,
    room: 0.6, reverb: 0.4,
    pad: :hollow, pad_attack: 0.6, cutoff: 96,
    chords: (ring :i, :iv, :i, :v),
    lead: :sine, lead_attack: 0.12, lead_release: 0.8,
    lead_lpf: 94, lead_amp: 0.29, drone: false,
    steps: (ring 0, 0, 0, 0, 0, 5, 5, 5, 5, 7, 8, 7, 8, 8, 0, 0),
    holds: (ring 0, 0, 0, 0, 0, 4, 0, 0, 0, 1, 1, 1, 2, 0, 0, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0),
    hat:   (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 1.1, drum_lpf: 130,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 2, 0, 2, 0, 2, 0, 1, 3, 0, 0, 2, 0, 2, 0, 2, 0),  # steps each bass note is held
    bass_amp: 0.6, bass_lpf: 105,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── recordlibrary.jpeg ──────────────────────────────────────────
# colour : gray 33%, brown 26%, orange 18%, white 12%
#          brown leads -> earthiness, stability -> A dorian
# lines  : sharpness 0.94, density 1.00 -> percussion: very active
# light  : brightness 0.51, saturation 0.19
define :scene_recordlibrary do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 52288, root: :a3, mode: :dorian,
    room: 0.62, reverb: 0.42,
    pad: :dark_ambience, pad_attack: 0.72, cutoff: 82,
    chords: (ring :i, :iv, :i, :v),
    lead: :hollow, lead_attack: 0.14, lead_release: 0.88,
    lead_lpf: 85, lead_amp: 0.76, drone: false,
    steps: (ring 0, 0, 0, 6, 0, 0, 0, 3, 2, 3, 0, 0, 3, 2, 7, 10),
    holds: (ring 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 2, 0, 1, 1, 1, 1),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0),
    hat:   (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 1.05, drum_lpf: 127,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 2, 0, 2, 0, 2, 0, 1, 3, 0, 0, 2, 0, 2, 0, 2, 0),  # steps each bass note is held
    bass_amp: 0.58, bass_lpf: 95,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── glitchcore.jpeg ─────────────────────────────────────────────
# colour : green 73%, blue 10%, yellow 4%, black 3%
#          green leads -> nature, balance, growth -> G major
# lines  : sharpness 0.97, density 1.00 -> percussion: very active
# light  : brightness 0.40, saturation 0.59
define :scene_glitchcore do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 41036, root: :g3, mode: :major,
    room: 0.61, reverb: 0.41,
    pad: :hollow, pad_attack: 0.66, cutoff: 78,
    chords: (ring :i, :iv, :i, :v),
    lead: :sine, lead_attack: 0.13, lead_release: 0.84,
    lead_lpf: 82, lead_amp: 0.35, drone: false,
    steps: (ring 0, 2, 5, 9, 2, 5, 4, 1, 2, 5, 5, 0, 2, 2, 0, 0),
    holds: (ring 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0, 2, 0, 0, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0),
    hat:   (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 1.08, drum_lpf: 128,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 2, 0, 2, 0, 2, 0, 1, 3, 0, 0, 2, 0, 2, 0, 2, 0),  # steps each bass note is held
    bass_amp: 0.59, bass_lpf: 92,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── cicado.jpeg ─────────────────────────────────────────────────
# colour : green 35%, blue 34%, pink 8%, yellow 7%
#          green leads -> nature, balance, growth -> G major
# lines  : sharpness 0.85, density 1.00 -> percussion: busy, syncopated
# light  : brightness 0.52, saturation 0.88
define :scene_cicado do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 60569, root: :g3, mode: :major,
    room: 0.65, reverb: 0.46,
    pad: :hollow, pad_attack: 0.88, cutoff: 83,
    chords: (ring :i, :iv, :i, :v),
    lead: :sine, lead_attack: 0.16, lead_release: 1.01,
    lead_lpf: 86, lead_amp: 0.41, drone: false,
    steps: (ring 9, 9, 7, 0, 4, 1, 0, 7, 0, 5, 4, 4, 0, 0, 8, 9),
    holds: (ring 2, 0, 1, 1, 1, 1, 0, 1, 0, 1, 2, 0, 2, 0, 1, 1),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    hat:   (ring 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.99, drum_lpf: 122,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 2, 0, 2, 0, 2, 0, 1, 3, 0, 0, 2, 0, 2, 0, 2, 0),  # steps each bass note is held
    bass_amp: 0.56, bass_lpf: 94,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── TEXTURE.jpg ─────────────────────────────────────────────────
# colour : gray 67%, black 32%
#          gray leads -> neutrality, distance -> E minor
# lines  : sharpness 1.00, density 1.00 -> percussion: very active
# light  : brightness 0.35, saturation 0.11
define :scene_texture do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 927, root: :e3, mode: :minor,
    room: 0.6, reverb: 0.4,
    pad: :dark_ambience, pad_attack: 0.6, cutoff: 76,
    chords: (ring :i, :vi, :iii, :vii),
    lead: :hollow, lead_attack: 0.12, lead_release: 0.8,
    lead_lpf: 81, lead_amp: 0.72, drone: false,
    steps: (ring 10, 10, 10, 0, 0, 0, 0, 0, 0, 10, 0, 10, 10, 10, 10, 10),
    holds: (ring 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 5, 0, 0, 0, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0),
    hat:   (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 1.1, drum_lpf: 130,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 2, 0, 2, 0, 2, 0, 1, 3, 0, 0, 2, 0, 2, 0, 2, 0),  # steps each bass note is held
    bass_amp: 0.6, bass_lpf: 91,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── audiogram.png ───────────────────────────────────────────────
# colour : black 51%, purple 25%, blue 15%, pink 8%
#          purple leads -> mystery, dreaminess -> A dorian
# lines  : sharpness 0.79, density 0.44 -> percussion: driving
# light  : brightness 0.16, saturation 0.52
define :scene_audiogram do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 15396, root: :a2, mode: :dorian,
    room: 0.67, reverb: 0.49,
    pad: :dark_ambience, pad_attack: 1.01, cutoff: 68,
    chords: (ring :i, :vii, :iv, :i),
    lead: :hollow, lead_attack: 0.18, lead_release: 1.1,
    lead_lpf: 76, lead_amp: 0.86, drone: false,
    steps: (ring 0, 0, 6, 6, 7, 6, 3, 4, 6, 6, 6, 4, 0, 6, 4, 0),
    holds: (ring 0, 0, 2, 0, 1, 1, 1, 1, 3, 0, 0, 1, 0, 1, 1, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    hat:   (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.82, drum_lpf: 118,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0),  # steps each bass note is held
    bass_amp: 0.51, bass_lpf: 82,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── snow-laying.JPG ─────────────────────────────────────────────
# colour : black 51%, white 21%, gray 16%, yellow 9%
#          black leads -> weight, the unknown -> E minor
# lines  : sharpness 0.60, density 0.21 -> percussion: steady backbeat
# light  : brightness 0.35, saturation 0.29
define :scene_snow_laying do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 4356, root: :e3, mode: :minor,
    room: 0.74, reverb: 0.56,
    pad: :dark_ambience, pad_attack: 1.35, cutoff: 76,
    chords: (ring :i, :vii, :iv, :i),
    lead: :sine, lead_attack: 0.24, lead_release: 1.36,
    lead_lpf: 81, lead_amp: 0.33, drone: false,
    steps: (ring 10, 9, 0, 9, 7, 3, 3, 0, 10, 0, 3, 0, 2, 0, 0, 0),
    holds: (ring 1, 1, 0, 1, 1, 2, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    hat:   (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.68, drum_lpf: 108,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 8, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0),  # steps each bass note is held
    bass_amp: 0.46, bass_lpf: 86,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# ── running order ──────────────────────────────────────────────
# Each line is: name bars, step. `bars` is how long the scene lasts, `step`
# is the pace of the handover (melody fades take 2 steps, then hats, snare
# and kick switch one step apart). Reorder, repeat or delete lines to
# reshape the set; keep `true` on the last line so the ending strips back.
use_bpm 84
set :take, 0  # change this number for a different random take of the whole set

scene_scream_blurr  16, 2
scene_night         16, 2
scene_kid_grace     16, 2
scene_dragon        16, 2
scene_recordlibrary 16, 2
scene_glitchcore    16, 2
scene_cicado        16, 2
scene_texture       16, 2
scene_audiogram     16, 2
scene_snow_laying   16, 2, true
