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

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_cicado do
  set :take, tick  # a new random take every pass
  scene_cicado 8
end
