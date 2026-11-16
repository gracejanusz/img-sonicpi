# ── IMG_5070.JPG ────────────────────────────────────────────────
# colour : blue 47%, gray 19%, black 17%, purple 7%
#          blue leads -> calm, depth, melancholy -> A minor, 66 bpm
# lines  : sharpness 0.27, density 0.01 -> percussion: a soft pulse
# light  : brightness 0.38, saturation 0.27
define :scene_img_5070 do |bars = 8, fade = 1|
  use_bpm 66
  use_random_seed 380
  root  = :a3
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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_img_5070 do
  scene_img_5070 8, 0
end
