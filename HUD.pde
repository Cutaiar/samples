
//--------------- HUD Globals ---------------------------

// Flash state for key press visualization in the HUD
char flashKey = 0;
int flashKeyCode = -1;
int flashUntil = 0;
static final int FLASH_MS = 150;

// Fixed x offset for the label column in the HUD (must clear the widest hint e.g. "z / x")
static final int HINT_COL_W = 60;

//--------------- HUD Rendering ---------------------------

/*
 * Display important data for the user
 */
void printMetaData() {
    camera.beginHUD();
    int yi = 15;
    int y = 40; // offset clears the window title bar

    // Mode header
    fill(255);
    if (isLiveMode) {
        text("Mode: Live input", 5, y);
    } else {
        text("Mode: File -- " + meta.fileName(), 5, y);
        y += yi; infoLine(y, "Length: " + meta.length() + "ms   Title: " + meta.title() + "   Author: " + meta.author());
        y += yi; ctrlLine(y, "a / s", "Position: " + filePlayer.position(), flashKey == 'a' || flashKey == 's');
        y += yi; ctrlLine(y, "Space", "Toggle playback: " + filePlayer.isPlaying(), flashKey == ' ');
    }

    y += yi; infoLine(y, "Buffersize: " + activeSource.bufferSize() + "   Framerate: " + int(frameRate));
    y += yi; ctrlLine(y, "m",     "Switch mode: " + (isLiveMode ? "live" : "file"),      flashKey == 'm');
    y += yi; ctrlLine(y, "r",     isLiveMode ? "Reconnect input" : "Restart from beginning", flashKey == 'r');
    y += yi; ctrlLine(y, "/",     "Toggle this panel",                               flashKey == '/');
    y += yi; ctrlLine(y, "z / x", "Amplitude: " + amp,                              flashKey == 'z' || flashKey == 'x');
    y += yi; ctrlLine(y, "q / w", "Distance Threshold: " + line_thresh,             flashKey == 'q' || flashKey == 'w');
    y += yi; ctrlLine(y, "b / n", "Z Thickness: " + z_thickness,                   flashKey == 'b' || flashKey == 'n');
    y += yi; ctrlLine(y, "e",     "Elements: " + drawElements,                      flashKey == 'e');
    y += yi; ctrlLine(y, "d",     "Lines: " + drawLines,                            flashKey == 'd');
    y += yi; ctrlLine(y, "c",     "Background: " + drawBG,                          flashKey == 'c');
    y += yi; ctrlLine(y, "t",     "Axis: " + isAxis,                               flashKey == 't');
    if (isLiveMode) {
        y += yi; ctrlLine(y, "Space", "Freeze update: " + !update,                  flashKey == ' ');
    }
    y += yi; ctrlLine(y, "p",  "Write out to file",                                 flashKey == 'p');
    y += yi; ctrlLine(y, "→",  "Camera spin X: " + isDoingCameraSpinX,             flashKeyCode == RIGHT);
    y += yi; ctrlLine(y, "↓",  "Camera spin Y: " + isDoingCameraSpinY,             flashKeyCode == DOWN);
    y += yi; ctrlLine(y, "↑",  "Camera spin Z: " + isDoingCameraSpinZ,             flashKeyCode == UP);
    y += yi; ctrlLine(y, ".",  "Reset Camera",                                      flashKey == '.');
    y += yi; ctrlLine(y, ",",  "Recording: " + recording,                           flashKey == ',');

    camera.endHUD();
}

/*
 * Non-interactive info line — dimmer, no flash
 */
void infoLine(int y, String content) {
    fill(170);
    text(content, 5, y);
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
        rect(0, y - 12, HINT_COL_W + textWidth(label) + 10, 15);
        popStyle();
        fill(255, 220, 80);
        text(hint, 5, y);
        text(label, 5 + HINT_COL_W, y);
    } else {
        fill(140);
        text(hint, 5, y);
        fill(255);
        text(label, 5 + HINT_COL_W, y);
    }
}
