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
  use_random_seed s[:seed]
  root  = note(s[:root])
  notes = scale(root + 12, s[:mode], num_octaves: 2)
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :reverb, room: s[:room], mix: s[:reverb] do
      in_thread do  # harmony - colour mood
        bars.times do |b|
          synth s[:pad], notes: chord_degree(s[:chords][b], root, s[:mode], 3),
            attack: s[:pad_attack], sustain: [3.5 - s[:pad_attack], 0.5].max, release: 2,
            cutoff: s[:cutoff], amp: 0.6
          sleep 4
        end
      end
      in_thread do  # melody - the image read left to right, on a soft pad voice
        with_fx :lpf, cutoff: s[:lead_lpf] do
          (bars * 8).times do |i|
            if s[:holds][i] > 0
              synth s[:lead], note: notes[s[:steps][i]], attack: s[:lead_attack],
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
define :scene_drums do |s, part = :all, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed]
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :lpf, cutoff: s[:drum_lpf] do
      in_thread do
        (bars * 16).times do |i|
          if (part == :all || part == :low) && s[:kick][i] > 0
            sample s[:kick_s], amp: s[:drum_amp]
          end
          if (part == :all || part == :mid) && s[:snare][i] > 0
            sample s[:snare_s], amp: s[:drum_amp] * (s[:snare][i] == 2 ? 0.9 : 0.35)
          end
          if (part == :all || part == :high) && s[:hat][i] > 0
            sample s[:hat_s], amp: s[:drum_amp] * 0.5 * rrand(0.6, 1), finish: 0.2
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
    kick_s: :bd_haus, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.68, drum_lpf: 108
  }, bars, step, last)
end

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_snow_laying do
  scene_snow_laying 8
end
