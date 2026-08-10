# SteadyCore

Background music where nothing unexpected happens, and the tools to make it.

Most focus music is designed to be interesting. This one is designed not to be.

No vocals. No drums. No build-ups, no drops, no sections. The volume stays the
same from the first second to the last, and the high frequencies are turned
down. Nothing surprises you, because there is nothing left in it that can.

Made for people who find ordinary study music unusable. In Swedish that group
is called NPF. In English it is closest to ADHD, autism and neurodivergent.

**Listen first:** [45 minutes on YouTube](https://www.youtube.com/watch?v=mZBXpt6Aj1A)

---

## What is in here

| File | What it does |
|---|---|
| `npf-calm-bed.json` | The ComfyUI workflow. This is the main thing. |
| `make_workflow.py` | Rebuilds that JSON if you want to change the prompt or the settings. |
| `loopa.sh` | Turns a finished track into one that loops with no seam. |
| `NPF-song.json` | Example workflow you can play with. |

No audio files. The music lives on YouTube so the repo stays small.

---

## What you need

**ComfyUI** and an ACE-Step model. ComfyUI is the program that actually makes
the music. It is free and it runs on your own computer.

- ComfyUI: https://github.com/comfyanonymous/ComfyUI
- ACE-Step models: https://huggingface.co/Comfy-Org/ACE-Step_1.5_ComfyUI

A graphics card helps a lot but is not required. On a processor alone it works,
it is just slower.

**sox** for the looping. It is a command line audio tool that has been around
since the eighties and is not installed by default on most systems.

```bash
sudo apt install sox libsox-fmt-all bc
```

`libsox-fmt-all` is easy to miss and without it sox cannot read FLAC files.
`bc` does the arithmetic inside the loop script.

That is the whole list. If you already have ComfyUI running you are most of the
way there.

---

## Making a track

1. Open ComfyUI.
2. Drag `npf-calm-bed.json` onto the canvas. The whole graph appears.
3. Click the model name in the first box and pick whichever ACE-Step file you
   downloaded. It will not match my filename, and that is fine.
4. Press Run.
5. The finished audio lands in your ComfyUI `output` folder.

First run takes longer because the model has to load. After that it is quick.

---

## Three things to know

**Lock the seed.** In the KSampler box there is a setting next to the seed
number, usually set to `randomize`. Change it to `fixed`. If you leave it on
randomize you get a different piece of music every single time, and when you
finally hit one you like you will not be able to get back to it. Lock it first,
then experiment.

**Keep it under 150 seconds.** The length is set in the box that says seconds.
Longer than about 150 and the model loses the thread and starts adding sections,
which is exactly what this music is not supposed to do. Make something short and
loop it instead. A loop cannot surprise you, which is the entire point.

**Do not touch the negative prompt.** This is the important one. The negative
prompt is the box of things you are telling the model to avoid, and it is doing
more work than the positive one. Words like `crescendo`, `build up`, `drop`,
`dynamic change` and `sudden entrance` are what stop the model from being
helpful in the way that ruins this music. Remove them and you get ordinary
ambient music that swells and fades. It might sound nicer. It will not do the
job.

---

## What you can change freely

The sampler and scheduler in the KSampler box. Try different ones and see what
you get. The character of the sound changes quite a bit and it stays usable,
so this is the good place to experiment.

Steps and CFG too. If you are using a Turbo model, set CFG to 1.0 and steps to
around 8. For the base model, 4.0 and 50 works.

And the positive prompt, within reason. Change the key, the tempo, swap the
instruments. Just leave the negative prompt alone.

---

## Making it loop

If you want music that plays for an hour without anyone pressing anything, you
need a track that meets itself with no seam. `gorloop.sh` folds the end of the
track over the beginning so it does.

```bash
chmod +x gorloop.sh
./gorloop.sh mytrack.flac
```

Out comes `loop.flac`, which is seamless, and `lektion.flac`, which is that
loop repeated twenty times for about 45 minutes. Your original is never touched.

Listen to the join:

```bash
sox loop.flac -d repeat 2
```

If the music seems to lose body right at the join, that is phase cancellation.
Two parts of the same track are overlapping and partly cancelling each other
out. Try a different crossfade length:

```bash
./gorloop.sh mytrack.flac 8
./gorloop.sh mytrack.flac 18
```

One of them usually sits clean. You cannot calculate which one, you have to
listen.

**If you are not on an English system:** the script sets `LC_ALL=C` for a
reason. Swedish, German and most other locales use a comma as the decimal
separator, and `bc` expects a dot. Without that line the arithmetic fails in a
way that is very hard to work out.

---

## Om NPF, och varför jag gör det här

NPF står för neuropsykiatriska funktionsnedsättningar. Adhd, autism och det
som ligger i närheten. Ingen engelsk förkortning betyder riktigt samma sak,
så resten av det här dokumentet säger adhd och autism i stället.

Det finns forskning som säger att barn med adhd läser bättre med lugn
bakgrundsmusik, medan jämnåriga utan adhd läser sämre av exakt samma musik.
Samtidigt har en stor del av autistiska personer förhöjd ljudkänslighet. Har
man bägge blir tystnad obehaglig medan oväntat ljud blir för mycket.

Det låter som en omöjlig kravlista tills man byter ut ett ord. Musiken ska
inte vara lugn. Den ska vara förutsägbar. Då faller resten på plats av sig
själv, och det är därför den här musiken är så tråkig som den är. Tråkigheten
är funktionen.

Jag föddes med grunden till multisjukdom och med asperger. Jag var alltid
annorlunda. Datorer förstod jag direkt.

Fyrtio år i teknik senare hör jag saker i ljud som andra inte reagerar på. Det
har mest varit ett besvär. Vanlig pluggmusik byter spår, bygger upp och
släpper, och uppmärksamheten går dit varje gång.

Så jag gjorde något som inte gör det. Efter tjugo minuter fick jag anstränga
mig för att höra att den spelade. Då visste jag att den satt.

Jag har levt ett liv som få har levt. Nu vill jag att det ska bli till nytta
för någon annan.

Verktygen fanns redan. Ingen hade riktat dem hit.

---

## Licens

MIT. Använd det till vad du vill.

Om du gör något bra av det, hör gärna av dig.
