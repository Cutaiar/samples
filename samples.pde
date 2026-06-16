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

// Set to false to run in a window instead of fullscreen
static final boolean FULLSCREEN = false;

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
boolean isMonoInput = true; // Mono = microphone, Stereo = system audio (e.g. BlackHole)
boolean isLiveMode = false;
boolean recording = false;
boolean drawBG = true;
boolean update = true;
boolean drawElements = false;
boolean drawLines = true;
boolean isAxis = true;
int boundsMode = 0; // 0=off, 1=dynamic, 2=max
int zMode = 1;      // 0=wave*amp, 1=wave*z_thickness, 2=flat, 3=noise
boolean isShowingMetaData = true;

// Running max extents for bounds max mode — reset on audio restart
float maxBoundsMinX, maxBoundsMaxX;
float maxBoundsMinY, maxBoundsMaxY;
float maxBoundsMinZ, maxBoundsMaxZ;
boolean isDoingCameraSpinX = false;
boolean isDoingCameraSpinY = false;
boolean isDoingCameraSpinZ = false;

// Temporary variables for x, y, and z updates to particles
float xt;
float yt;
float zt;
float zloc;

//--------------- Setup ---------------------------

void settings() {
    if (FULLSCREEN) {
        fullScreen(P3D);
    } else {
        size(1920, 1080, P3D);
    }
}

void setup() {
    background(0);

    //Set up camera
    camera = new PeasyCam(this, 1000);
    camera.lookAt(0,0,0);
    camera.setWheelScale(0.1); // Only for iMac

    // Set origin
    origin = new PVector(0, 0, 0);

    // Create minim object
    minim = new Minim(this);
    switchToLiveMode();
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

    input = minim.getLineIn(isMonoInput ? Minim.MONO : Minim.STEREO, BUFFER_SIZE);
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
        input = minim.getLineIn(isMonoInput ? Minim.MONO : Minim.STEREO, BUFFER_SIZE);
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
    resetMaxBounds();
}

void resetMaxBounds() {
    maxBoundsMinX = Float.MAX_VALUE;  maxBoundsMaxX = -Float.MAX_VALUE;
    maxBoundsMinY = Float.MAX_VALUE;  maxBoundsMaxY = -Float.MAX_VALUE;
    maxBoundsMinZ = Float.MAX_VALUE;  maxBoundsMaxZ = -Float.MAX_VALUE;
}

//--------------- Main draw loop ---------------------------

void draw() {
    if (activeSource == null) {
        camera.beginHUD();
        fill(255);
        text("Initializing audio...", width/2 - 80, height/2);
        text("Press m to load a file.", width/2 - 80, height/2 + 20);
        camera.endHUD();
        return;
    }
    if (drawBG) background(0);
    if (isShowingMetaData) printMetaData();
    if (isAxis) showAxis();
    if (boundsMode > 0) showBounds();
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
            zt = origin.z + calculateZ(zMode, i);
            zloc+=.1;
            particles[i].update(3, xt, yt, zt);
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
    if (keyCode == DOWN) {
        isDoingCameraSpinY = !isDoingCameraSpinY;
    }
    if (keyCode == UP) {
        isDoingCameraSpinZ = !isDoingCameraSpinZ;
    }

    if (key == '.') camera.reset(CAMERA_RESET_TIME);

    // Toggle mono/stereo input channels and restart audio
    if (key == 'i' && isLiveMode) {
        isMonoInput = !isMonoInput;
        restartAudio();
    }

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
    if (key == ']') line_thresh += 15;
    if (key == '[') line_thresh -= 15;

    // Adjust Z Thickness
    if (key == 'n') z_thickness += 15;
    if (key == 'b') z_thickness -= 15;

    // Cycle Z algorithm
    if (key == 'k') zMode = (zMode + 1) % 4;

    // Toggle Element draw
    if (key == 'e') {
        drawElements = !drawElements;
    }

    // Toggle Axis draw
    if (key == 't') {
        isAxis = !isAxis;
    }

    // Cycle bounds box: off → dynamic → max → off
    if (key == 'f') {
        boundsMode = (boundsMode + 1) % 3;
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
