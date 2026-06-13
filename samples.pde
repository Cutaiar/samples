/*
 * Emergence Visualizer revisited for Aesthetics project.
 *
 * Now called Emergence Visuals.
 *
 * An array of particles is updated to reflect the samples of audio — either
 * a file or live input. On macOS, set a virtual audio device (e.g. BlackHole)
 * as the system input to visualize system/app audio instead of the microphone.
 * Emerging properties of the system are visible as it executes.
 *
 * Creative Code / Aesthetics
 * Dillon Cutaiar
 * 4/13/19
 *
 * Revisited 6/13/26
 */

//--------------- Imports ---------------------------

import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.signals.*;
import ddf.minim.spi.*;
import ddf.minim.ugens.*;
import peasy.*;

//--------------- Globals ---------------------------

Minim minim;
AudioInput input;
FilePlayer filePlayer;
AudioOutput out;
TickRate rateControl;
AudioMetaData meta;
AudioSource activeSource; // points to either input (live) or out (file)

PeasyCam camera;

// The size of every buffer
static final int BUFFER_SIZE = 512;

// The time in milliseconds for the camera to reset
static final int CAMERA_RESET_TIME = 200;

// The angle cameraSpin function calls should rotate the camera each frame
// 0.005 - 0.05 is good
static final float CAMERA_ROTATE_SPEED = 0.007;

// The length of the axis
static final int AXIS_LENGTH = 100;

// The amplitude of the wave
int amp = 520;

// The size of the z thickness
int z_thickness = 75;

// Distance to draw lines within and a factor to control it
float line_thresh = 35;

// An array of particles to draw
Particle[] particles;

// An origin point
PVector origin;

// Booleans to control playback and visualization
boolean isLiveMode = false;
boolean recording = false;
boolean drawBG = true;
boolean update = true;
boolean drawElements = false;
boolean drawLines = true;
boolean isAxis = true;
boolean isShowingMetaData = true;
boolean isDoingCameraSpinX = false;
boolean isDoingCameraSpinY = false;
boolean isDoingCameraSpinZ = false;

// Flash state for key press visualization in the HUD
char flashKey = 0;
int flashKeyCode = -1;
int flashUntil = 0;
static final int FLASH_MS = 150;

// Left padding for the entire HUD
static final int HUD_PAD_LEFT = 10;

// Fixed x offset for the label column in the HUD (must clear the widest hint e.g. "z / x")
static final int HINT_COL_W = 60;

// Temporary variables for x, y, and z updates to particles
float xt;
float yt;
float zt;
float zloc;

//--------------- Setup ---------------------------

void setup() {
    background(0);
    //size(1920, 1080, P3D);
    fullScreen(P3D);

    //Set up camera
    camera = new PeasyCam(this, 1000);
    camera.lookAt(0,0,0);
    camera.setWheelScale(0.1); // Only for iMac

    // Set origin
    origin = new PVector(0, 0, 0);

    // Create minim object
    minim = new Minim(this);
    selectInput("Select an audio file (cancel for live input):", "fileSelected");
}

void fileSelected(File selection) {
    if (selection == null) {
        switchToLiveMode();
        return;
    }

    // Null first so draw() shows the waiting screen while we switch
    activeSource = null;
    if (input != null) { input.close(); input = null; }

    filePlayer = new FilePlayer(minim.loadFileStream(selection.getAbsolutePath(), BUFFER_SIZE, true));
    out = minim.getLineOut(2, BUFFER_SIZE);
    meta = filePlayer.getMetaData();
    rateControl = new TickRate(1.f);
    filePlayer.patch(rateControl).patch(out);
    rateControl.setInterpolation(true);

    isLiveMode = false;
    initParticles(out);  // particles ready before draw() can see activeSource
    activeSource = out;
    filePlayer.play();
}

void switchToLiveMode() {
    // Null first so draw() shows the waiting screen while we switch
    activeSource = null;
    if (filePlayer != null) {
        filePlayer.close();
        filePlayer = null;
        meta = null;
        rateControl = null;
    }
    if (out != null) { out.close(); out = null; }

    input = minim.getLineIn(Minim.STEREO, BUFFER_SIZE);
    isLiveMode = true;
    update = true;
    initParticles(input);  // particles ready before draw() can see activeSource
    activeSource = input;
}

void restartAudio() {
    if (isLiveMode) {
        // Close and reopen so Minim picks up the current system input device
        activeSource = null;
        if (input != null) { input.close(); input = null; }
        input = minim.getLineIn(Minim.STEREO, BUFFER_SIZE);
        initParticles(input);
        activeSource = input;
    } else if (filePlayer != null) {
        filePlayer.rewind();
        filePlayer.play();
        update = true;
    }
}

void initParticles(AudioSource source) {
    particles = new Particle[source.bufferSize()];
    for (int i = 0; i < source.bufferSize(); i++) {
        particles[i] = new Particle();
    }
}

//--------------- Main draw loop ---------------------------

void draw() {
    if (activeSource == null) {
        camera.beginHUD();
        fill(255);
        text("Select an audio file, or cancel to use live input.", width/2 - 170, height/2);
        text("Press m at any time to switch modes.", width/2 - 130, height/2 + 20);
        camera.endHUD();
        return;
    }
    if (drawBG) background(0);
    if (isShowingMetaData) printMetaData();
    if (isAxis) showAxis();
    if (isDoingCameraSpinX) cameraSpinX();
    if (isDoingCameraSpinY) cameraSpinY();
    if (isDoingCameraSpinZ) cameraSpinZ();

    //Main loop through buffer
    for (int i = 0; i < activeSource.bufferSize(); i+= 1) {

        // Update fields based on buffer info
        if (update) {

            // Update particle position and size
            xt = origin.x+activeSource.left.get(i)*amp;
            yt = origin.y+activeSource.right.get(i)*amp;
            zt = origin.z + calculateZ(1, i);
            zloc+=.1;
            particles[i].update(3, xt, yt, zt);



            //// Draw the elements (unused in this loop)
            //if (drawElements) {
            //particles[i].show();
            //}
            //for (Particle b : particles) {

            //// Draw lines
            //if (particles[i] != b && particles[i].loc.dist(b.loc) < thresh && drawLines) {
            //pushStyle();
            //stroke(255, 30);
            ////stroke(mCol, lCol, rCol, 60);
            //line(particles[i].loc.x, particles[i].loc.y, b.loc.x, b.loc.y);
            //popStyle();
            //}
        }
    }


    // A main loop through each particle (in relation to every other)
    for (Particle a : particles) {

        // Draw the elements
        if (drawElements) {
            a.show();
        }
        for (Particle b : particles) {

            // Draw lines
            if (a != b && a.loc.dist(b.loc) < line_thresh && drawLines) {
                pushStyle();
                strokeWeight(2);
                stroke(255, 60);
                line(a.loc.x, a.loc.y, a.loc.z, b.loc.x, b.loc.y, b.loc.z);
                popStyle();
            }
        }
    }

    if (recording) saveFrame("output/render_####.png");
}

/**
 * Depending on mode, calculate the z coordinate of the particle
 */
float calculateZ(int mode, int i) {
    switch (mode) {
    case 0:
        return origin.z + (sin(zloc) + cos(zloc))*amp;
    case 1:
        return origin.z + (sin(zloc) + cos(zloc))*z_thickness;
    case 2:
        return amp/10;
    case 3:
        return noise(activeSource.mix.get(i))*amp;
    default:
        return 0;
    }
}

//--------------- Particle Class ---------------------------

class Particle {
    PVector loc;
    float size;

    Particle() {
        loc = new PVector(0, 0, 0);
        size = 0;
    }

    void update(float sizeIn, float xIn, float yIn, float zIn) {
        size = sizeIn;
        loc.x = xIn;
        loc.y = yIn;
        loc.z = zIn;
    }

    void show() {
        pushStyle();
        fill(255, 0, 0, 80);
        noStroke();
        pushMatrix();
        translate(loc.x, loc.y, loc.z);
        sphere(size);
        popMatrix();
        popStyle();
    }
}


//--------------- Helper functions ---------------------------

/*
 * Write current data out to a obj file
 */
void writeOutObj() {
    PrintWriter output = createWriter("testOut2.obj");
    int ac = 1;
    int bc = 1;
    String verts = "";
    String lines = "";
    for (Particle a : particles) {
        verts += "v " + (a.loc.x - origin.x) + " " + (a.loc.y - origin.y) + " " + a.loc.z + "\n";
        for (Particle b : particles) {
            if (a != b && a.loc.dist(b.loc) < line_thresh && drawLines) {
                lines += "l " + ac + " " + bc + "\n";
            }
            bc++;
        }
        ac++;
        bc = 1;
    }
    output.println(verts);
    output.println(lines);
    output.flush();
    output.close();
}

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
        y += yi; ctrlLine(y, "Length", duration, false);
    }
    y += yi; fill(255); text("Buffersize: " + activeSource.bufferSize(), HUD_PAD_LEFT, y);
    y += yi; fill(255); text("Framerate: " + int(frameRate), HUD_PAD_LEFT, y);

    // Controls section
    y += yi;
    y += yi; ctrlLine(y, "m",       "Switch mode: " + (isLiveMode ? "live" : "file"),        flashKey == 'm');
    y += yi; ctrlLine(y, "r",       isLiveMode ? "Reconnect input" : "Restart from beginning", flashKey == 'r');
    if (!isLiveMode) {
        y += yi; ctrlLine(y, "a / s", "Position: " + filePlayer.position(),                  flashKey == 'a' || flashKey == 's');
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

/*
 * Allow control of the visualization with key presses
 */
void keyPressed() {

    // Record which key was pressed so the HUD can flash that line
    flashKey = key;
    flashKeyCode = keyCode;
    flashUntil = millis() + FLASH_MS;

    // Toggle MetaDataPanel
    if (key == '/') {
        isShowingMetaData = !isShowingMetaData;
    }

    // Toggle Recording
    if (key == ',') {
        recording = !recording;
    }

    // Toggle automatic camera rotation
    if (keyCode == RIGHT) {
        isDoingCameraSpinX = !isDoingCameraSpinX;
    }
        // Toggle automatic camera rotation
    if (keyCode == DOWN) {
        isDoingCameraSpinY = !isDoingCameraSpinY;
    }
        // Toggle automatic camera rotation
    if (keyCode == UP) {
        isDoingCameraSpinZ = !isDoingCameraSpinZ;
    }

    if (key == '.') camera.reset(CAMERA_RESET_TIME);

    // Reconnect input (live) or restart from beginning (file)
    if (key == 'r') {
        restartAudio();
    }

    // Switch between live input and file
    if (key == 'm') {
        if (isLiveMode) {
            selectInput("Select an audio file:", "fileSelected");
        } else {
            switchToLiveMode();
        }
    }

    // Spacebar: play/pause in file mode, freeze update in live mode
    if (key == ' ') {
        if (isLiveMode) {
            update = !update;
        } else if (filePlayer != null) {
            if (filePlayer.isPlaying()) { filePlayer.pause(); update = false; }
            else { filePlayer.play(); update = true; }
        }
    }

    // Adjust amplitude
    if (key == 'x') amp += 100;
    if (key == 'z') amp -= 100;

    // Adjust playback (file mode only)
    if (!isLiveMode && filePlayer != null) {
        if ( key == 's' ) filePlayer.skip(1000);
        if ( key == 'a' ) filePlayer.skip(-1000);
    }

    // Adjust Threshold for lines
    if (key == 'w') line_thresh += 15;

    // Adjust Threshold for lines
    if (key == 'n') z_thickness += 15;
    if (key == 'b') z_thickness -= 15;

    // Toggle Element draw
    if (key == 'e') {
        drawElements = !drawElements;
    }

    // Toggle Axis draw
    if (key == 't') {
        isAxis = !isAxis;
    }

    // Write out
    if (key == 'p') {
        writeOutObj();
    }

    // Toggle Line draw
    if (key == 'd') {
        drawLines = !drawLines;
    }

    // Toggle BG draw
    if (key == 'c') {
        drawBG = !drawBG;
    }

    // Quit
    if (key == ESC || key == 'q') {
        key = 0; // prevent Processing's default ESC-stops-sketch from firing twice
        exit();
    }
}

void cameraSpinX() { camera.rotateX(CAMERA_ROTATE_SPEED); }
void cameraSpinY() { camera.rotateY(CAMERA_ROTATE_SPEED); }
void cameraSpinZ() { camera.rotateZ(CAMERA_ROTATE_SPEED); }

void showAxis() {
    stroke(255);
    line(-AXIS_LENGTH, 0, 0, AXIS_LENGTH, 0, 0); //x
    line(0, -AXIS_LENGTH, 0, 0, AXIS_LENGTH, 0); //y
    line(0, 0, -AXIS_LENGTH, 0, 0, AXIS_LENGTH); //z
}
