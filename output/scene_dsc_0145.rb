# ── DSC_0145.JPG ────────────────────────────────────────────────
# colour : black 51%, white 21%, gray 16%, yellow 9%
#          black leads -> weight, the unknown -> C harmonic_minor, 77 bpm
# lines  : sharpness 0.60, density 0.21 -> percussion: steady backbeat
# light  : brightness 0.35, saturation 0.29
define :scene_dsc_0145 do |bars = 8, fade = 1|
  use_bpm 77
  use_random_seed 42411
  root  = :c3
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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_dsc_0145 do
  scene_dsc_0145 8, 0
end
