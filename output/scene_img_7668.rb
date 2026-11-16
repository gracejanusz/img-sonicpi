# ── IMG_7668.jpeg ───────────────────────────────────────────────
# colour : gray 33%, brown 26%, orange 18%, white 12%
#          brown leads -> earthiness, stability -> D dorian, 92 bpm
# lines  : sharpness 0.94, density 1.00 -> percussion: very active
# light  : brightness 0.51, saturation 0.19
define :scene_img_7668 do |bars = 8, fade = 1|
  use_bpm 92
  use_random_seed 66420
  root  = :d3
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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_img_7668 do
  scene_img_7668 8, 0
end
