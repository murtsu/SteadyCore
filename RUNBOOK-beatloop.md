# RUNBOOK: beatloop.sh

Turning a generated track with a pulse into something that loops for an
hour without anyone noticing where it wraps.

Read `BASSEY-NPF.md` first if you want to know why this exists rather
than how to run it.

---

## Before you start

```bash
sudo apt install sox libsox-fmt-all bc
```

`libsox-fmt-all` is the one people forget. Without it sox cannot read
FLAC and every command fails with something unhelpful.

`aubio-tools` is optional and only used by `--detect`.

```bash
chmod +x beatloop.sh
```

---

## The short version

If the track starts on the beat and does not fade out:

```bash
./beatloop.sh spar.flac --bpm 96 --min 40
```

If it does either of those things, which it usually does:

```bash
./beatloop.sh spar.flac --bpm 96 --offset auto --end auto --min 40
```

Out come three files:

| File | What it is |
|---|---|
| `loop.flac` | A whole number of bars. This is the one that loops. |
| `lang.flac` | That loop repeated to your target length. |
| `skarv.flac` | Four seconds with the join in the middle. Listen to this. |

Your original is never touched.

---

## Step by step

### 1. Look at the track before you cut it

```bash
./beatloop.sh spar.flac --slag
```

Prints where the first eight beats land and the gap between them.

```
Forsta atta slagen:
  12.500
  13.125
  13.750
  ...
  avstand 0.625 s
  avstand 0.625 s
```

Two things to read off it. The first number is where the pulse starts, so
anything before that is an intro you do not want in the loop. The gap
tells you the real tempo: `60 / gap` is the BPM. A gap of 0.625 means 96,
which is what you asked for.

If the gaps are uneven, the model did not hold the tempo and the track is
not usable for looping. Regenerate.

It finds the beat by low-passing everything above 90 Hz first, because
the kick is the lowest thing in the track. That works even when a pad is
playing through the whole intro.

### 2. Look at the levels

```bash
./beatloop.sh spar.flac --profil
```

One bar per second of the track. Where the bars start shrinking at the
end, the fade-out begins. Where they are short at the start, there is a
quiet intro.

### 3. Cut it

```bash
./beatloop.sh spar.flac --bpm 96 --offset auto --end auto --min 40
```

`--offset auto` jumps to the first beat. `--end auto` finds where the
fade starts and stops there. Both can be given as numbers instead if you
disagree with what it picked:

```bash
./beatloop.sh spar.flac --bpm 96 --offset 12.5 --end 58
```

The output tells you what it did:

```
  langd        60.000 s
  tempo        96 BPM, 4 slag per takt
  en takt      2.5000 s
  hela takter  19  (47.500 s)
  kastas bort  0.000 s
```

**Discarded time means nothing on its own.** It is always between zero and
one bar, because that is what trimming to whole bars does. It is not a
sign anything is wrong.

### 4. Listen to the join

```bash
play skarv.flac
```

Four seconds, the wrap point in the middle. This is the only check that
matters.

- Steady pulse all the way through: done.
- A double hit or a stumble: the downbeat is wrong. Adjust `--offset`.
- A click: raise `--fade` from 3 to 10 milliseconds.
- The music thins out at the join: the tempo is wrong, not the trim.

Then hear it wrap several times:

```bash
play loop.flac repeat 2
```

### 5. Master it

```bash
ffmpeg -i lang.flac -af ebur128=peak=true -f null - 2>&1 | tail -12
```

If the true peak is above -1 dBTP or the integrated loudness is above
-14 LUFS, reduce by the difference:

```bash
sox lang.flac lang-master.flac gain -3
```

Then measure again. Upload `lang-master.flac`.

---

## Every option

| Option | What it does |
|---|---|
| `--bpm N` | The tempo you asked ACE-Step for. Can also be given as a bare second argument. |
| `--beats N` | Beats per bar. Default 4. Use 3 for waltz time. |
| `--offset N` | Start the loop at N seconds. `auto` finds the first beat. |
| `--end N` | Ignore everything after N seconds. `auto` finds the fade. |
| `--min N` | Target length of `lang.flac` in minutes. Default 45. |
| `--fade N` | Fade at each end of the loop, in milliseconds. Default 3. |
| `--slag` | Show where the first beats land, then stop. |
| `--profil` | Show the level second by second, then stop. |
| `--detect` | Guess the tempo, then stop. Needs `aubio-tools`. |

---

## When something goes wrong

**"Filen rymmer inte ens en takt"**
BPM was not read as a number. Almost always a typo in the flag name, or a
BPM passed after another flag that expects a value.

**"Okand flagga"**
It lists the valid ones. There is no `--tempo`.

**"dither clipped N samples"**
Should not happen any more, since every write is guarded. If it does, the
source is running at full scale. Check it:

```bash
sox spar.flac -n stat 2>&1 | grep Maximum
```

Above 0.99 means ACE-Step rendered into the ceiling. Add `loud, loudness
war, maximized, limiter, compressed` to the negative prompt next time.

**Decimal errors, or `bc` complaining about a comma**
The script sets `LC_ALL=C` for exactly this. If you copy pieces of it into
your own commands, set it there too. Swedish and German locales use a
comma where `bc` wants a dot, and the failure is very hard to read.

**The result is not close to the target length**
Check what you actually fed it:

```bash
soxi -D loop.flac
```

Usually `loop.flac` has been overwritten by a later run with different
settings.

---

## Building a longer file from a loop you already have

```bash
export LC_ALL=C
L=$(soxi -D loop.flac)
N=$(echo "scale=6; n=2400/$L; scale=0; (n+0.9999)/1" | bc -l)
sox loop.flac lang.flac repeat $((N-1))
soxi -D lang.flac
```

2400 is the target in seconds. Change it for other lengths.
