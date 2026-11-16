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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_line do
  scene_line 8, 0
end
