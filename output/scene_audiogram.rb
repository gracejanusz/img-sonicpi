# ── the player: shared by every scene ───────────────────────────
# s is a scene's settings. Fades are in bars.
#
# Mix (loudest to quietest): melody, pad, chord stabs, drums, bass.
# Scenes with a backbeat get the techno treatment: four-on-the-floor kick,
# off-beat open hats and bass, a sidechain-style pump on the pad, and
# echoed chord stabs.
define :scene_fade do |vol, bars, fade_in, fade_out|
  sleep 0.01
  control vol, amp: 1, amp_slide: fade_in * 4
  sleep (bars - fade_out) * 4 - 0.01
  control vol, amp: 0, amp_slide: fade_out * 4 if fade_out > 0
  sleep fade_out * 4
end

# a chord squeezed into the octave above `lo`, so it sits between the bass
# (an octave below the root) and the melody (from an octave above the root)
define :mid_voicing do |degree, root, mode, size, lo|
  chord_degree(degree, root, mode, size).to_a.map { |n| lo + (n - lo) % 12 }.sort
end

# pads + chord stabs + melody (+ drone)
define :scene_tune do |s, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed] + get(:take).to_i
  c     = s[:chaos]
  root  = note(s[:root])
  notes = scale(root + 12, s[:mode], num_octaves: 3)
  techno = s[:snare_on]
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :reverb, room: s[:room], mix: s[:reverb] do
      in_thread do  # harmony - colour mood, pumping with the kick in techno scenes
        with_fx :slicer, phase: 1, wave: 0, amp_min: 0.3, smooth: 0.04, mix: (techno ? 0.6 : 0) do
          bars.times do |b|
            lo = root - 5 + (rand < c * 0.6 ? [-2, 2].choose : 0)  # random voicing
            synth s[:pad], notes: mid_voicing(s[:chords][b], root, s[:mode], 3, lo),
              attack: s[:pad_attack], sustain: [3.5 - s[:pad_attack], 0.5].max, release: 2,
              cutoff: s[:cutoff] + rrand(-10, 10) * c, amp: 0.65
            sleep 4
          end
        end
      end
      in_thread do  # chords - 7th chords between bass and melody, rhythm from the drums
        hits = if !s[:hat_on] then [[0, 2], [2, 2]]                  # ambient: half notes
               elsif !techno then [[0, 1.5], [1.5, 1.5], [3, 1]]    # sparse: 3+3+2
               else [[0.5, 0.25], [1.5, 0.25], [2.5, 0.25], [3.5, 0.25]]  # off-beat stabs
               end
        with_fx :echo, phase: 0.75, decay: 3, mix: (techno ? 0.3 : 0.15) do
          bars.times do |b|
            ch = mid_voicing(s[:chords][b], root, s[:mode], 4, root - 2)
            t = 0
            hits.each do |at, len|
              sleep at - t
              t = at
              next if rand < c * 0.15
              synth :prophet, notes: ch, attack: (len >= 1 ? 0.2 : 0.005),
                sustain: len * 0.6, release: (len >= 1 ? len * 0.5 : 0.2),
                cutoff: s[:cutoff] - 4 + rrand(-6, 6) * c, res: 0.2, amp: 0.4
            end
            sleep 4 - t
          end
        end
      end
      in_thread do  # melody - the image read left to right, on a soft pad voice
        # high notes: quieter the higher they go, a gentle high-shelf cut, and a
        # compressor that squashes the loud peaks so nothing pierces
        with_fx :compressor, threshold: 0.25, slope_above: 0.4, clamp_time: 0.01,
            relax_time: 0.15, pre_amp: 1, amp: 1.1 do
          with_fx :eq, high_shelf: -0.4, high_shelf_note: 84 do
            with_fx :echo, phase: 0.75, decay: 2, mix: 0.18 do
              with_fx :lpf, cutoff: s[:lead_lpf] do
                (bars * 8).times do |i|
                  if s[:holds][i] > 0
                    d = s[:steps][i]
                    d = [d + [-1, 1].choose, 0].max if rand < c * 0.4  # wander to a neighbour
                    d += 7 if rand < c * 0.12                          # jump up an octave
                    n = notes[d]
                    tame = 1 - [[(n - root - 17) * 0.035, 0].max, 0.4].min  # -3.5% per semitone above the 5th
                    synth s[:lead], note: n, attack: s[:lead_attack],
                      sustain: s[:holds][i] * 0.5 - s[:lead_attack], release: s[:lead_release],
                      amp: s[:lead_amp] * 1.5 * tame * rrand(0.8, 1), pan: rrand(-0.4, 0.4)
                  end
                  sleep 0.5
                end
              end
            end
          end
        end
      end
      if s[:drone]  # soft lines leave room for air
        in_thread do
          (bars / 2.0).ceil.times do
            synth :dark_ambience, note: root - 12, attack: 3, sustain: 2, release: 3, amp: 0.35
            sleep 8
          end
        end
      end
    end
    scene_fade vol, bars, fade_in, fade_out
  end
end

# percussion. part = :high (hats), :mid (snare), :low (kick) or :all
# The bass rides with the kick (part :low), so it hands over with it.
define :scene_drums do |s, part = :all, bars = 8, fade_in = 0, fade_out = 0|
  use_bpm s[:bpm]
  use_random_seed s[:seed] + get(:take).to_i
  c   = s[:chaos]
  techno = s[:snare_on]
  low = (part == :all || part == :low)
  mid = (part == :all || part == :mid)
  hi  = (part == :all || part == :high)
  with_fx :level, amp: (fade_in > 0 ? 0 : 1) do |vol|
    with_fx :lpf, cutoff: s[:drum_lpf] do
      in_thread do
        (bars * 16).times do |i|
          fill = (i % 64) >= 60 && rand < c  # end of every 4th bar: maybe a fill
          if low
            if s[:kick][i] > 0 || (techno && i % 4 == 0)  # techno: four on the floor
              sample s[:kick_s], amp: s[:drum_amp] unless i % 16 > 0 && rand < c * 0.1
            elsif s[:kick_on] && rand < c * 0.06
              sample s[:kick_s], amp: s[:drum_amp] * 0.6       # stray kick
            end
          end
          if mid
            if s[:snare][i] > 0
              sample s[:snare_s], amp: s[:drum_amp] * (s[:snare][i] == 2 ? 0.9 : 0.35)
              sample :perc_snap, amp: s[:drum_amp] * 0.4 if s[:snare][i] == 2  # clap layer
            elsif s[:snare_on] && (fill || rand < c * 0.08)
              sample s[:snare_s], amp: s[:drum_amp] * rrand(0.15, 0.4)  # ghost note / fill
            end
          end
          if hi
            if s[:hat][i] > 0 ? rand > c * 0.25 : (s[:hat_on] && rand < c * 0.15)
              sample s[:hat_s], amp: s[:drum_amp] * 0.5 * rrand(0.5, 1), finish: 0.2,
                rate: 1 + rrand(-0.06, 0.06) * c, pan: rrand(-0.3, 0.3) * c
            end
            if techno && i % 4 == 2  # off-beat open hat
              sample :drum_cymbal_open, amp: s[:drum_amp] * 0.35, finish: 0.12, rate: 1.1
            end
          end
          sleep 0.25
        end
      end
    end
    if low
      in_thread do  # bassline - chord roots
        root = note(s[:root]) - 12
        (bars * 16).times do |i|
          tri = chord_degree(s[:chords][i / 16], root, s[:mode], 3)
          if techno  # rolling off-beat bass between the kicks
            if i % 4 == 2 || (i % 4 == 3 && rand < c * 0.3)
              n = rand < c * 0.3 ? [tri[2], tri[0] + 12].choose : tri[0]
              synth :tb303, note: n, wave: 0, attack: 0, sustain: 0.1, release: 0.15,
                cutoff: s[:bass_lpf] - 8 + rrand(-6, 6) * c, res: 0.3,
                amp: s[:bass_amp] * 0.5 * rrand(0.85, 1)
            end
          else       # held until the next hit
            len = s[:bass][i]
            if len > 0
              n = rand < c * 0.35 ? [tri[2], tri[0] + 12].choose : tri[0]
              synth :dsaw, note: n, attack: (len >= 8 ? 0.6 : 0.01),
                sustain: [len * 0.25 - 0.2, 0.05].max, release: (len >= 8 ? 1 : 0.15),
                detune: 0.1 + rrand(0, 0.15) * c, cutoff: s[:bass_lpf] + rrand(-10, 10) * c,
                amp: s[:bass_amp] * 0.6 * rrand(0.85, 1)
            elsif s[:kick_on] && i.odd? && rand < c * 0.1  # passing 16th
              synth :dsaw, note: [tri[0], tri[2]].choose + [0, 12].choose, sustain: 0.05,
                release: 0.1, cutoff: s[:bass_lpf], amp: s[:bass_amp] * 0.4
            end
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

# ── audiogram.png ───────────────────────────────────────────────
# colour : black 51%, purple 25%, blue 15%, pink 8%
#          purple leads -> mystery, dreaminess -> A dorian
# lines  : sharpness 0.79, density 0.44 -> percussion: driving
# light  : brightness 0.16, saturation 0.52
define :scene_audiogram do |bars = 8, step = 0, last = false|
  play_scene({
    bpm: 84, seed: 15396, root: :a2, mode: :dorian,
    room: 0.67, reverb: 0.49,
    pad: :dark_ambience, pad_attack: 1.01, cutoff: 68,
    chords: (ring :i, :vii, :iv, :i),
    lead: :hollow, lead_attack: 0.18, lead_release: 1.1,
    lead_lpf: 76, lead_amp: 0.86, drone: false,
    steps: (ring 0, 0, 6, 6, 7, 6, 3, 4, 6, 6, 6, 4, 0, 6, 4, 0),
    holds: (ring 0, 0, 2, 0, 1, 1, 1, 1, 3, 0, 0, 1, 0, 1, 1, 0),  # steps each note is held, 0 = rest
    kick:  (ring 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0),
    snare: (ring 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    hat:   (ring 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
    kick_s: :bd_klub, snare_s: :sn_dolf, hat_s: :drum_cymbal_closed,
    drum_amp: 0.82, drum_lpf: 118,
    kick_on: true, snare_on: true, hat_on: true,
    bass: (ring 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0),  # steps each bass note is held
    bass_amp: 0.51, bass_lpf: 82,
    chaos: 0.35  # 0 = plays exactly as written, 1 = very loose
  }, bars, step, last)
end

# Loop this image on its own. Change the 8 to play longer phrases.
live_loop :play_scene_audiogram do
  set :take, tick  # a new random take every pass
  scene_audiogram 8
end
