//--------------- HUD Globals ---------------------------

// Flash state for key press visualization in the HUD
char flashKey = 0;
int flashKeyCode = -1;
int flashUntil = 0;
static final int FLASH_MS = 150;

// Left padding for the entire HUD
static final int HUD_PAD_LEFT = 10;

// Fixed x offset for the label column in the HUD (must clear the widest hint e.g. "z / x")
static final int HINT_COL_W = 60;

//--------------- HUD Rendering ---------------------------

/*
 * Display important data for the user
 */
void printMetaData() {
    camera.beginHUD();
    int yi = 15;
    int y = 40 + yi * 2; // offset clears the window title bar, plus top padding

    // Info section
    fill(255);
    if (isLiveMode) {
        text("Mode: Live input", HUD_PAD_LEFT, y);
    } else {
        String fname = meta.fileName();
        fname = fname.substring(fname.lastIndexOf('/') + 1);
        text("Mode: File -- " + fname, HUD_PAD_LEFT, y);
        int totalSec = meta.length() / 1000;
        String duration = int(totalSec / 60) + ":" + nf(totalSec % 60, 2);
        y += yi; fill(170); text("Length", HUD_PAD_LEFT, y); text(duration, HUD_PAD_LEFT + HINT_COL_W, y);
    }
    y += yi; fill(255); text("Buffersize: " + activeSource.bufferSize(), HUD_PAD_LEFT, y);
    y += yi; fill(255); text("Framerate: " + int(frameRate), HUD_PAD_LEFT, y);

    // Controls section
    y += yi;
    y += yi; ctrlLine(y, "m",       "Switch mode: " + (isLiveMode ? "live" : "file"),        flashKey == 'm');
    y += yi; ctrlLine(y, "r",       isLiveMode ? "Reconnect input" : "Restart from beginning", flashKey == 'r');
    if (isLiveMode) {
        y += yi; ctrlLine(y, "i",     "Input: " + (isMonoInput ? "Mono (mic)" : "Stereo (system/BlackHole)"), flashKey == 'i');
    }
    if (!isLiveMode) {
        int posSec = filePlayer.position() / 1000;
        y += yi; ctrlLine(y, "a / s", "Position: " + int(posSec / 60) + ":" + nf(posSec % 60, 2), flashKey == 'a' || flashKey == 's');
    }
    if (isLiveMode) {
        y += yi; ctrlLine(y, "Space", "Freeze update: " + !update,                           flashKey == ' ');
    } else {
        y += yi; ctrlLine(y, "Space", "Toggle playback: " + filePlayer.isPlaying(),          flashKey == ' ');
    }
    y += yi; ctrlLine(y, "/",       "Toggle this panel",                                     flashKey == '/');
    y += yi; ctrlLine(y, "z / x",   "Amplitude: " + amp,                                    flashKey == 'z' || flashKey == 'x');
    y += yi; ctrlLine(y, "w",       "Distance Threshold: " + line_thresh,                   flashKey == 'w');
    y += yi; ctrlLine(y, "b / n",   "Z Thickness: " + z_thickness,                         flashKey == 'b' || flashKey == 'n');
    y += yi; ctrlLine(y, "e",       "Elements: " + drawElements,                            flashKey == 'e');
    y += yi; ctrlLine(y, "d",       "Lines: " + drawLines,                                  flashKey == 'd');
    y += yi; ctrlLine(y, "c",       "Background: " + drawBG,                                flashKey == 'c');
    y += yi; ctrlLine(y, "t",       "Axis: " + isAxis,                                     flashKey == 't');
    y += yi; ctrlLine(y, "p",       "Write out to file",                                    flashKey == 'p');
    y += yi; ctrlLine(y, "→",       "Camera spin X: " + isDoingCameraSpinX,                flashKeyCode == RIGHT);
    y += yi; ctrlLine(y, "↓",       "Camera spin Y: " + isDoingCameraSpinY,                flashKeyCode == DOWN);
    y += yi; ctrlLine(y, "↑",       "Camera spin Z: " + isDoingCameraSpinZ,                flashKeyCode == UP);
    y += yi; ctrlLine(y, ".",       "Reset Camera",                                         flashKey == '.');
    y += yi; ctrlLine(y, ",",       "Recording: " + recording,                              flashKey == ',');
    y += yi; ctrlLine(y, "Esc / q", "Quit",                                                 key == ESC || key == 'q');

    camera.endHUD();
}

/*
 * Non-interactive info line — dimmer, no flash
 */
void infoLine(int y, String content) {
    fill(170);
    text(content, HUD_PAD_LEFT, y);
}

/*
 * Interactive control line — key hint in gray, label in white, flashes yellow on press.
 * Label column is always fixed at HINT_COL_W so all lines stay vertically aligned.
 */
void ctrlLine(int y, String hint, String label, boolean flashing) {
    if (flashing && millis() < flashUntil) {
        pushStyle();
        noStroke();
        fill(255, 220, 80, 50);
        rect(HUD_PAD_LEFT - 5, y - 12, HINT_COL_W + textWidth(label) + 10, 15);
        popStyle();
        fill(255, 220, 80);
        text(hint, HUD_PAD_LEFT, y);
        text(label, HUD_PAD_LEFT + HINT_COL_W, y);
    } else {
        fill(140);
        text(hint, HUD_PAD_LEFT, y);
        fill(255);
        text(label, HUD_PAD_LEFT + HINT_COL_W, y);
    }
}
