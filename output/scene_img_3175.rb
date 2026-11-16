# ── IMG_3175.jpeg ───────────────────────────────────────────────
# colour : black 82%, yellow 13%, orange 4%
#          black leads -> weight, the unknown -> C harmonic_minor, 86 bpm
# lines  : sharpness 0.60, density 0.42 -> percussion: steady backbeat
# light  : brightness 0.16, saturation 0.48
define :scene_img_3175 do |bars = 8, fade = 1|
  use_bpm 86
  use_random_seed 35435
  root  = :c2
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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_img_3175 do
  scene_img_3175 8, 0
end
