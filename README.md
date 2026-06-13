# samples

<p align="center">
  <img src="/extra/Sample.gif" />
</p>

`samples` is a music visualization project written in [Processing](https://processing.org/). It uses [minim](https://code.compartmental.net/minim/) to read the samples of a given mp3 or wav, distributes points in 3 dimensions based off of the properties of those samples, and draws lines between them. Ideally, it does this 60 frames per second. However, depending on the machine you are running on, the frame rate can slow and sections of the song be skipped, creating an unintended but beautiful, choppy performance.

Additionally, I've built in some authoring tools which allow me to pause a song and inspect a still form rather than a sporadic one. An example of one of these "moments in a song" is above. You can see more in this [video](https://youtu.be/DPmrovfai_k).

## Prerequisites

1. Install [Processing](https://processing.org/download)
2. Install the following libraries via the Processing package manager (**Sketch → Import Library → Manage Libraries**):
   - **Minim** — audio playback and input
   - **PeasyCam** — 3D camera control
3. Optionally install the `processing-java` CLI via **Tools → Install "processing-java" command line tool** in the Processing IDE

## Running

```
processing-java --sketch=/path/to/samples --run
```

On launch, a file picker appears. Pick an audio file (mp3 or wav) to visualize it, or **cancel** to go straight to live audio input mode. Press **m** at any time to switch between the two modes.

## Live audio input (system audio)

By default, live input mode uses your Mac's selected input device (e.g. the microphone). To visualize system audio — music, a video, anything playing on your Mac — use [BlackHole](https://existential.audio/blackhole/), a free virtual audio driver.

**Install BlackHole:**

```
brew install blackhole-2ch
```

After installing, macOS may block it. Go to **System Settings → Privacy & Security**, scroll to the bottom, and allow the software from "Existential Audio". A restart is required after approving.

**Route system audio into BlackHole:**

BlackHole acts as a loopback device. To hear audio through your speakers *and* feed it into `samples` simultaneously, create a Multi-Output Device:

1. Open **Audio MIDI Setup** (find it with Spotlight)
2. Click `+` → **Create Multi-Output Device**
3. Check both **BlackHole 2ch** and your speakers or headphones
4. Set this Multi-Output Device as your output in **System Settings → Sound → Output**
5. Set **BlackHole 2ch** as your input in **System Settings → Sound → Input**

Now any audio playing on your Mac will drive the visualization.

> **Note:** When you're done, switch your output back to your speakers/headphones and your input back to the microphone. The Multi-Output Device has no volume control, so keyboard and menu bar volume keys won't work while it's active.

**AirPlay / wifi speakers:** AirPlay devices don't appear in Audio MIDI Setup and can't be added to a Multi-Output Device. If you want to visualize audio playing on an AirPlay speaker, [Loopback](https://rogueamoeba.com/loopback/) by Rogue Amoeba ($99) can capture per-app audio and route it to BlackHole regardless of where the app is sending its output.
