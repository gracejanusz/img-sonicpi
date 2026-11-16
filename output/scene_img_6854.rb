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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_img_6854 do
  scene_img_6854 8, 0
end
