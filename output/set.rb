# ═══ Performance set ══════════════════════════════════════════════════
# 10 images, 8 bars each, shared tonic G, 1-bar crossfades.
# Running order (edit the list at the bottom to rearrange):
#   1. 0:00.0  scene_img_5070                66 bpm  blue    drums: a soft pulse
#   2. 0:25.5  scene_img_3175                86 bpm  black   drums: steady backbeat
#   3. 0:45.0  scene_img_2554                95 bpm  brown   drums: driving
#   4. 1:02.7  scene_line                    81 bpm  green   drums: very active
#   5. 1:23.4  scene_img_7668                92 bpm  brown   drums: very active
#   6. 1:41.7  scene_learning_copy           94 bpm  green   drums: very active
#   7. 1:59.5  scene_img_6854                93 bpm  green   drums: busy, syncopated
#   8. 2:17.6  scene_texture                 81 bpm  gray    drums: very active
#   9. 2:38.4  scene_step1                   83 bpm  purple  drums: driving
#   10. 2:58.6  scene_dsc_0145                77 bpm  black   drums: steady backbeat

# ── IMG_5070.JPG ────────────────────────────────────────────────
# colour : blue 47%, gray 19%, black 17%, purple 7%
#          blue leads -> calm, depth, melancholy -> G minor, 66 bpm
# lines  : sharpness 0.27, density 0.01 -> percussion: a soft pulse
# light  : brightness 0.38, saturation 0.27
define :scene_img_5070 do |bars = 8, fade = 1|
  use_bpm 66
  use_random_seed 380
  root  = :g3
  mode  = :minor
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.83, mix: 0.66 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :vii, :iv, :i)
        bars.times do |b|
          synth :hollow, notes: chord_degree(chords[b], root, mode, 3),
            attack: 1.85, sustain: 1.65, release: 1.5,
            cutoff: 84, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring nil, nil, 2, 0, 3, 6, 7, 9, 13, 7, 3, nil, 0, nil, nil, nil)
        (bars * 8).times do |i|
          d = steps[i]
          synth :piano, note: notes[d], release: 1.39,
            amp: 0.72 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end

      in_thread do  # drone - soft lines leave room for air
        (bars / 2.0).ceil.times do
          synth :dark_ambience, note: root - 12, attack: 3, sustain: 2, release: 3, amp: 0.5
          sleep 8
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      hat   = (ring 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      with_fx :lpf, cutoff: 90 do
        (bars * 16).times do |i|
          sample :bd_fat, amp: 0.48 if kick[i] > 0
          sample :drum_snare_soft, amp: 0.48 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_soft, amp: 0.24 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── IMG_3175.jpeg ───────────────────────────────────────────────
# colour : black 82%, yellow 13%, orange 4%
#          black leads -> weight, the unknown -> G harmonic_minor, 86 bpm
# lines  : sharpness 0.60, density 0.42 -> percussion: steady backbeat
# light  : brightness 0.16, saturation 0.48
define :scene_img_3175 do |bars = 8, fade = 1|
  use_bpm 86
  use_random_seed 35435
  root  = :g2
  mode  = :harmonic_minor
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.68, mix: 0.5 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :vii, :iv, :i)
        bars.times do |b|
          synth :dark_ambience, notes: chord_degree(chords[b], root, mode, 3),
            attack: 1.05, sustain: 2.45, release: 1.5,
            cutoff: 72, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring 6, 7, 9, 11, 11, 13, 13, 13, 13, 11, 11, nil, nil, nil, nil, 0)
        (bars * 8).times do |i|
          d = steps[i]
          synth :pretty_bell, note: notes[d], release: 0.9,
            cutoff: 82, amp: 0.86 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
      hat   = (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0)
      with_fx :lpf, cutoff: 108 do
        (bars * 16).times do |i|
          sample :bd_haus, amp: 0.71 if kick[i] > 0
          sample :sn_dolf, amp: 0.71 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.35 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── IMG_2554.jpeg ───────────────────────────────────────────────
# colour : brown 38%, orange 24%, yellow 11%, black 8%
#          brown leads -> earthiness, stability -> G dorian, 95 bpm
# lines  : sharpness 0.72, density 0.66 -> percussion: driving
# light  : brightness 0.45, saturation 0.31
define :scene_img_2554 do |bars = 8, fade = 1|
  use_bpm 95
  use_random_seed 9726
  root  = :g3
  mode  = :dorian
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.63, mix: 0.44 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :iv, :i, :v)
        bars.times do |b|
          synth :fm, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.78, sustain: 2.72, release: 1.5,
            cutoff: 88, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring nil, nil, 7, 9, 10, 9, 10, 10, 11, 13, 13, 9, nil, 10, nil, nil)
        (bars * 8).times do |i|
          d = steps[i]
          synth :pluck, note: notes[d], release: 0.73,
            amp: 0.76 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
      hat   = (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0)
      with_fx :lpf, cutoff: 114 do
        (bars * 16).times do |i|
          sample :bd_haus, amp: 0.82 if kick[i] > 0
          sample :sn_dolf, amp: 0.82 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.41 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── LINE.jpg ────────────────────────────────────────────────────
# colour : white 69%, green 22%, black 8%
#          green leads -> nature, balance, growth -> G major, 81 bpm
# lines  : sharpness 1.00, density 1.00 -> percussion: very active
# light  : brightness 0.85, saturation 0.09
define :scene_line do |bars = 8, fade = 1|
  use_bpm 81
  use_random_seed 5106
  root  = :g3
  mode  = :major
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.5, mix: 0.3 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :iv, :i, :v)
        bars.times do |b|
          synth :hollow, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.1, sustain: 3.4, release: 1.5,
            cutoff: 111, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring nil, nil, nil, nil, nil, 7, 7, 7, 8, 8, 9, 9, 11, 11, nil, nil)
        (bars * 8).times do |i|
          d = steps[i]
          synth :pretty_bell, note: notes[d], release: 0.3,
            cutoff: 121, amp: 0.69 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0)
      hat   = (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
      with_fx :lpf, cutoff: 130 do
        (bars * 16).times do |i|
          sample :bd_tek, amp: 1.1 if kick[i] > 0
          sample :sn_dolf, amp: 1.1 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.55 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── IMG_7668.jpeg ───────────────────────────────────────────────
# colour : gray 33%, brown 26%, orange 18%, white 12%
#          brown leads -> earthiness, stability -> G dorian, 92 bpm
# lines  : sharpness 0.94, density 1.00 -> percussion: very active
# light  : brightness 0.51, saturation 0.19
define :scene_img_7668 do |bars = 8, fade = 1|
  use_bpm 92
  use_random_seed 66420
  root  = :g3
  mode  = :dorian
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.53, mix: 0.33 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :iv, :i, :v)
        bars.times do |b|
          synth :fm, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.25, sustain: 3.25, release: 1.5,
            cutoff: 92, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring nil, nil, nil, 7, nil, nil, nil, 4, 2, 3, 0, 0, 4, 3, 9, 13)
        (bars * 8).times do |i|
          d = steps[i]
          synth :piano, note: notes[d], release: 0.39,
            amp: 0.7 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0)
      hat   = (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
      with_fx :lpf, cutoff: 127 do
        (bars * 16).times do |i|
          sample :bd_tek, amp: 1.05 if kick[i] > 0
          sample :sn_dolf, amp: 1.05 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.53 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── LEarning copy.jpeg ──────────────────────────────────────────
# colour : green 73%, blue 10%, yellow 4%, black 3%
#          green leads -> nature, balance, growth -> G major, 94 bpm
# lines  : sharpness 0.97, density 1.00 -> percussion: very active
# light  : brightness 0.40, saturation 0.59
define :scene_learning_copy do |bars = 8, fade = 1|
  use_bpm 94
  use_random_seed 56457
  root  = :g3
  mode  = :major
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.51, mix: 0.32 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :iv, :i, :v)
        bars.times do |b|
          synth :hollow, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.17, sustain: 3.33, release: 1.5,
            cutoff: 85, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring nil, 4, 7, 12, 4, 7, 4, 2, 4, 7, 7, nil, 4, 4, nil, nil)
        (bars * 8).times do |i|
          d = steps[i]
          synth :piano, note: notes[d], release: 0.35,
            amp: 0.85 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0)
      hat   = (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
      with_fx :lpf, cutoff: 128 do
        (bars * 16).times do |i|
          sample :bd_tek, amp: 1.08 if kick[i] > 0
          sample :sn_dolf, amp: 1.08 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.54 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── IMG_6854.jpeg ───────────────────────────────────────────────
# colour : green 35%, blue 34%, pink 8%, yellow 7%
#          green leads -> nature, balance, growth -> G major, 93 bpm
# lines  : sharpness 0.85, density 1.00 -> percussion: busy, syncopated
# light  : brightness 0.52, saturation 0.88
define :scene_img_6854 do |bars = 8, fade = 1|
  use_bpm 93
  use_random_seed 31459
  root  = :g3
  mode  = :major
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.57, mix: 0.37 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :iv, :i, :v)
        bars.times do |b|
          synth :hollow, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.45, sustain: 3.05, release: 1.5,
            cutoff: 92, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring 12, 12, 8, 0, 5, 1, nil, 8, nil, 7, 5, 5, 0, 0, 11, 12)
        (bars * 8).times do |i|
          d = steps[i]
          synth :piano, note: notes[d], release: 0.52,
            amp: 1.03 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
      hat   = (ring 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1)
      with_fx :lpf, cutoff: 122 do
        (bars * 16).times do |i|
          sample :bd_tek, amp: 0.99 if kick[i] > 0
          sample :sn_dolf, amp: 0.99 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.49 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── TEXTURE.jpg ─────────────────────────────────────────────────
# colour : gray 67%, black 32%
#          gray leads -> neutrality, distance -> G minor, 81 bpm
# lines  : sharpness 1.00, density 1.00 -> percussion: very active
# light  : brightness 0.35, saturation 0.11
define :scene_texture do |bars = 8, fade = 1|
  use_bpm 81
  use_random_seed 927
  root  = :g3
  mode  = :minor
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.5, mix: 0.3 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :vi, :iii, :vii)
        bars.times do |b|
          synth :dark_ambience, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.1, sustain: 3.4, release: 1.5,
            cutoff: 83, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring 13, 13, 13, nil, nil, nil, nil, nil, nil, 13, nil, 13, 13, 13, 13, 13)
        (bars * 8).times do |i|
          d = steps[i]
          synth :piano, note: notes[d], release: 0.3,
            amp: 0.65 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 2, 0, 0, 1, 0, 1, 0, 0, 2, 0, 1, 0)
      hat   = (ring 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
      with_fx :lpf, cutoff: 130 do
        (bars * 16).times do |i|
          sample :bd_tek, amp: 1.1 if kick[i] > 0
          sample :sn_dolf, amp: 1.1 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.55 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── step1.png ───────────────────────────────────────────────────
# colour : black 51%, purple 25%, blue 15%, pink 8%
#          purple leads -> mystery, dreaminess -> G dorian, 83 bpm
# lines  : sharpness 0.79, density 0.44 -> percussion: driving
# light  : brightness 0.16, saturation 0.52
define :scene_step1 do |bars = 8, fade = 1|
  use_bpm 83
  use_random_seed 23182
  root  = :g2
  mode  = :dorian
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.6, mix: 0.41 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :vii, :iv, :i)
        bars.times do |b|
          synth :dark_ambience, notes: chord_degree(chords[b], root, mode, 3),
            attack: 0.61, sustain: 2.89, release: 1.5,
            cutoff: 71, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring nil, nil, 7, 9, 9, 7, 3, 6, 7, 7, 7, 6, nil, 7, 6, nil)
        (bars * 8).times do |i|
          d = steps[i]
          synth :hollow, note: notes[d], release: 0.62,
            cutoff: 81, amp: 0.8 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
      hat   = (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0)
      with_fx :lpf, cutoff: 118 do
        (bars * 16).times do |i|
          sample :bd_haus, amp: 0.82 if kick[i] > 0
          sample :sn_dolf, amp: 0.82 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.41 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── DSC_0145.JPG ────────────────────────────────────────────────
# colour : black 51%, white 21%, gray 16%, yellow 9%
#          black leads -> weight, the unknown -> G harmonic_minor, 77 bpm
# lines  : sharpness 0.60, density 0.21 -> percussion: steady backbeat
# light  : brightness 0.35, saturation 0.29
define :scene_dsc_0145 do |bars = 8, fade = 1|
  use_bpm 77
  use_random_seed 42411
  root  = :g3
  mode  = :harmonic_minor
  notes = scale(root + 12, mode, num_octaves: 2)
  fade  = [fade, bars / 2.0].min
  with_fx :level, amp: (fade > 0 ? 0 : 1), amp_slide: fade * 4 do |vol|
    with_fx :reverb, room: 0.68, mix: 0.5 do

      in_thread do  # harmony - colour mood
        chords = (ring :i, :vii, :iv, :i)
        bars.times do |b|
          synth :dark_ambience, notes: chord_degree(chords[b], root, mode, 3),
            attack: 1.05, sustain: 2.45, release: 1.5,
            cutoff: 82, amp: 0.6
          sleep 4
        end
      end

      in_thread do  # melody - the image read left to right
        steps = (ring 13, 10, nil, 10, 9, 3, 3, nil, 13, nil, 4, 0, 2, nil, nil, nil)
        (bars * 8).times do |i|
          d = steps[i]
          synth :pretty_bell, note: notes[d], release: 0.9,
            cutoff: 92, amp: 0.79 * rrand(0.7, 1), pan: rrand(-0.4, 0.4) if d
          sleep 0.5
        end
      end
    end

    in_thread do  # percussion - line sharpness
      kick  = (ring 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0)
      snare = (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
      hat   = (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0)
      with_fx :lpf, cutoff: 108 do
        (bars * 16).times do |i|
          sample :bd_haus, amp: 0.68 if kick[i] > 0
          sample :sn_dolf, amp: 0.68 * (snare[i] == 2 ? 0.9 : 0.35) if snare[i] > 0
          sample :drum_cymbal_closed, amp: 0.34 * rrand(0.6, 1), finish: 0.2 if hat[i] > 0
          sleep 0.25
        end
      end
    end

    # fade in, hold, fade out
    sleep 0.01
    control vol, amp: 1
    sleep (bars - fade) * 4 - 0.01
    control vol, amp: 0
    sleep fade * 4
  end
end

# ── running order ──────────────────────────────────────────────
# Each scene is called as: name bars, fade_bars. The sleep is the scene's
# length in seconds minus its last bar, so the next one fades in over it.
# Reorder, repeat or delete pairs of lines to reshape the set.
use_bpm 60

in_thread { scene_img_5070 8, 1 }
sleep 25.45

in_thread { scene_img_3175 8, 1 }
sleep 19.53

in_thread { scene_img_2554 8, 1 }
sleep 17.68

in_thread { scene_line 8, 1 }
sleep 20.74

in_thread { scene_img_7668 8, 1 }
sleep 18.26

in_thread { scene_learning_copy 8, 1 }
sleep 17.87

in_thread { scene_img_6854 8, 1 }
sleep 18.06

in_thread { scene_texture 8, 1 }
sleep 20.74

in_thread { scene_step1 8, 1 }
sleep 20.24

in_thread { scene_dsc_0145 8, 1 }
sleep 21.82
