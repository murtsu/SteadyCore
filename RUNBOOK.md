# RUNBOOK: from ComfyUI to a YouTube track

Start to finish. Follow it in order.

---

## 1. Generate the music

Open ComfyUI. Drag `npf-calm-bed.json` onto the canvas.

Set these before you press anything:

- **Checkpoint**: pick your ACE-Step file from the dropdown. It will not
  match the filename saved in the workflow.
- **Seed**: set `control_after_generate` to **fixed**, not randomize. Do this
  first. If you leave it random you cannot get back to a take you liked.
- **Seconds**: 60 to 150. Never above 150. Longer than that and the model
  starts inventing sections, which is the one thing this music must not do.
- **Negative prompt**: do not touch it. That is where the design lives.

Free to change: sampler, scheduler, steps, CFG, and the positive prompt.
Turbo model wants CFG 1.0 and 8 steps. Base model wants 4.0 and 50.

Press **Run**. Output lands in your ComfyUI `output` folder as FLAC.

Write down the seed and the sampler settings of any take you like. You will
want them again and you will not remember them.

---

## 2. Listen before you go further

Play it once, all the way through, doing something else. You are checking for
one thing only: does anything happen that you did not expect. A swell, a new
instrument, a section change. If yes, regenerate. Do not try to fix it later.

---

## 3. Make it loop

```bash
cd ~/YouTube/<projekt>
./gorloop.sh bed.flac
```

Out come two files:

- `loop.flac` — about 12 seconds shorter than the original, end folded over
  the beginning so it meets itself with no seam
- `lektion.flac` — that loop repeated twenty times, roughly 45 minutes

The original is never touched.

**Check the seam:**

```bash
sox loop.flac -d repeat 2
```

Three passes straight to the speakers. If the music seems to lose body right
where it wraps, that is phase cancellation. Try another crossfade length:

```bash
./gorloop.sh bed.flac 8
./gorloop.sh bed.flac 18
```

One of them usually sits clean. You cannot calculate which, you have to
listen.

**If sox is missing:**

```bash
sudo apt install sox libsox-fmt-all bc
```

`libsox-fmt-all` is the one people forget. Without it sox cannot read FLAC.

---

## 4. Make the cover image

1280×1280 or larger, square. Generate it, then check it at 100 pixels wide.
YouTube Music crops to square on the lock screen and in playlists, so keep
the subject centred and away from the edges.

Dark, flat, narrow tonal range. Someone may have it on screen for 45 minutes.
If it looks striking it is wrong.

---

## 5. Wrap the audio as video

YouTube will not accept audio alone.

```bash
ffmpeg -loop 1 -i cover.png -i lektion.flac \
  -c:v libx264 -tune stillimage -pix_fmt yuv420p -r 2 \
  -c:a aac -b:a 320k -shortest lektion.mp4
```

`-tune stillimage` and `-r 2` are what keep a 45 minute still image down to a
few megabytes instead of a few hundred.

Never make an MP3 on the way. YouTube re-encodes anyway and you want to hand
them the best source you have.

---

## 6. Upload settings

These four matter. The rest is defaults.

**Made for kids: NO.** It is tempting when the audience is students. Do not.
That flag kills playlist saving and background playback, which is the entire
delivery method.

**Category: Music.** Puts it in YouTube Music instead of leaving it as just
another video.

**Language: Swedish.** So it surfaces to the right people.

**Add to the playlist.** Set the playlist ordering to **manual**, not date
added, so it does not reshuffle when you add a track later. Playlist must be
public or it will not show in YouTube Music.

Processing runs in stages. Low resolution plays almost immediately, 1080p can
take another fifteen minutes. If it looks grainy at first, wait before you
share the link.

---

## 7. Title, description, hashtags

Only the first three hashtags appear above the title. Stay under fifteen
total or YouTube ignores all of them.

Put NPF in the first sentence of the description. That is where search reads,
and it is the word the audience actually types.

Check the stated length against the file before you paste:

```bash
soxi -D lektion.flac
```

A wrong number there is the first thing this audience notices.

---

## 8. Last check

Play it from YouTube on your own phone. No headphones, phone speaker only.

That is how it will actually be heard. The bass you mixed on the sound system
is mostly not there on a phone, and this is the only test that tells you
whether anything is left.

---

## Gotchas, collected

- `LC_ALL=C` before anything using `bc`. Swedish locale uses a comma where
  `bc` wants a dot, and the failure is very hard to read. The loop script
  already sets it.
- Lock the seed **before** experimenting, not after.
- Never above 150 seconds in ComfyUI.
- Never edit the negative prompt.
- `libsox-fmt-all` or no FLAC.
- Do not mark as made for kids.
- Keep FLAC as the master. MP3 nowhere in the chain.
