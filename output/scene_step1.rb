# ── step1.png ───────────────────────────────────────────────────
# colour : black 51%, purple 25%, blue 15%, pink 8%
#          purple leads -> mystery, dreaminess -> F dorian, 83 bpm
# lines  : sharpness 0.79, density 0.44 -> percussion: driving
# light  : brightness 0.16, saturation 0.52
define :scene_step1 do |bars = 8, fade = 1|
  use_bpm 83
  use_random_seed 23182
  root  = :f2
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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_step1 do
  scene_step1 8, 0
end
