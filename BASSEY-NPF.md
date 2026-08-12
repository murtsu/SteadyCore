# Bassey NPF

The second workflow. Same rule, with a pulse.

---

## Why this exists

The first tracks worked. The feedback also said something we had not
planned for: adults liked the slow drone, younger listeners wanted
something with more movement in it.

That looks like it contradicts the whole design. It does not.

The rule was never "slow". The rule was that nothing unexpected happens,
and a pulse that never changes is about as predictable as sound gets. A
metronome has never surprised anybody.

---

## What actually makes drums hard

Not the beat. The transients.

A hi-hat, a snare, a cymbal, a rim: all of them are a sharp spike of
energy in the high frequencies, and high frequencies are exactly where
sound sensitivity hurts. A soft kick at 55 Hz is not that. It is a low
thud you feel more than hear.

So the negative prompt does not say "no drums" any more. It names the
things that are actually a problem, and it names more of them than
before:

    hi-hat, cymbals, crash, snare, drum fill, break, stutter, glitch,
    sharp transient, bright percussion, shaker

Take those out and what is left is a pulse. Which was the point.

---

## Two ways we got it wrong first

Worth writing down, because both sound reasonable until you hear them.

**Too empty.** The first attempt asked for a kick and stripped everything
else: minimal melody, low pass filter, muted highs. The model did exactly
that. What came back was a thump and one sustained tone, and it was
unlistenable in a way that is hard to describe. Boring in the sense of
nothing happens is the goal. Boring in the sense of nothing is there is
just empty.

**Too full.** The correction went too far the other way: layered pads in
two octaves, piano, strings, long reverb. It sounded good and the kick had
vanished completely. Everything else was competing for the same space.

The thing that fixed it was asking for a **chord** instead of a melody. A
sustained minor seventh is four notes at once and it still stands
perfectly still. A melody is a sequence of events. A chord is not an
event, it is a state.

That distinction is most of the design.

---

## The prompt

Positive:

    kick drum on every beat, steady pulse, deep sub bass on every beat,
    instrumental, no vocals, sustained pad, sustained minor seventh
    chord, muted strings, medium reverb, quantized, no swing, no fills,
    no melody line, constant dynamics, repetitive, dark, low register,
    96 BPM, F minor, steady, patient

Negative:

    vocals, singing, lyrics, hi-hat, cymbals, crash, snare, drum fill,
    break, stutter, glitch, sharp transient, bright percussion, shaker,
    crescendo, build up, drop, dynamic change, sudden entrance, tempo
    change, fade out, outro, ending, intro, gradual entrance, song
    structure, verse, chorus, sections, orchestral swell, arpeggio,
    thin, sparse, empty, fast, busy

Order matters. ACE-Step weights what comes first, so the kick goes at the
front. Bury it in the middle behind three pad layers and it will quietly
decide not to bother.

Do not edit the negative prompt. Same rule as the drone workflow, and it
matters more here, not less.

---

## Which BPM to use

Two separate questions: which tempos are musically right, and which ones
divide cleanly.

**The maths.** One bar in 4/4 is `240 / BPM` seconds. For a whole number
of bars to fit a 60 second render, BPM has to divide by 4. For it to work
at 60, 90, 120 and 150 seconds alike, BPM has to divide by **8**.

Pick a BPM divisible by 8 and nothing is ever wasted:

| BPM | One bar | Bars in 60 s | Feel |
|-----|---------|--------------|------|
| 64  | 3.750 s | 16 | Barely a pulse. Closest to the drone. |
| 72  | 3.333 s | 18 | Resting heart rate. Very calm. |
| 80  | 3.000 s | 20 | Slow, clearly there. Safe choice. |
| 88  | 2.727 s | 22 | Between calm and moving. |
| 96  | 2.500 s | 24 | Walking pace. What the released track uses. |
| 104 | 2.308 s | 26 | Noticeably more energy. |
| 112 | 2.143 s | 28 | Upper limit before it starts pushing. |
| 120 | 2.000 s | 30 | Dance tempo. Too much for this. |

**80 to 96 is the useful range.** Below that you have made the drone
again with a thud in it. Above 104 it stops being background and starts
asking for attention, which is the thing this music is not allowed to do.

If you use a BPM that does not divide by 8, nothing breaks. `beatloop.sh`
trims to whole bars regardless. You just throw away up to one bar of
material you paid for.

---

## Why looping needed a new tool

`gorloop.sh` folds the end of a track over the beginning with a twelve
second crossfade. For drone that is invisible.

Put a kick on it and you have twelve seconds where two different bar
positions are playing on top of each other. It sounds like a flam, or
like the drummer tripped. It is not a subtle problem.

`beatloop.sh` does the opposite: no crossfade at all. It trims to a whole
number of bars and butt-splices at a downbeat, with a three millisecond
fade at each end so the join does not click. Three milliseconds is short
enough to be inaudible and long enough to prevent a step in the waveform.

Measured on a test file: the sample-to-sample jump at the join was 1,
against 282 for a typical jump inside the file. Quieter than the
signal around it, so there is nothing to hear.

See `RUNBOOK-beatloop.md` for how to drive it.

---

## One thing to watch that the drone never did

A kick plus a sub bass stacks peaks. The drone masters landed around
-23 LUFS with plenty of headroom. The first beat master came out at
-11 LUFS with a true peak of +0.8 dBFS, which is clipping.

The fix is a volume knob, not a normaliser. Loudness range on this
material is about 3 LU, meaning there is essentially no dynamic range to
normalise. A straight reduction does the job and changes nothing else:

    sox lang.flac lang-master.flac gain -3

Measure before and after:

    ffmpeg -i lang.flac -af ebur128=peak=true -f null - 2>&1 | tail -12

Target -14 LUFS integrated and under -1 dBTP. YouTube turns down anything
louder and never turns anything up, so being quiet costs you nothing.
Peaks that already clipped in the file cannot be repaired by anybody.
