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

// Temporary variables for x, y, and z updates to particles
float xt;
float yt;
float zt;
float zloc;

//--------------- Setup ---------------------------

void setup() {
    background(0);
    fullScreen(P3D);

    camera = new PeasyCam(this, 1000);
    camera.lookAt(0, 0, 0);
    camera.setWheelScale(0.1); // Only for iMac

    origin = new PVector(0, 0, 0);

    minim = new Minim(this);
    selectInput("Select an audio file (cancel for live input):", "fileSelected");
}

void fileSelected(File selection) {
    if (selection == null) {
        switchToLiveMode();
        return;
    }
    if (input != null) { input.close(); input = null; }

    filePlayer = new FilePlayer(minim.loadFileStream(selection.getAbsolutePath(), BUFFER_SIZE, true));
    out = minim.getLineOut(2, BUFFER_SIZE);
    meta = filePlayer.getMetaData();
    rateControl = new TickRate(1.f);
    filePlayer.patch(rateControl).patch(out);
    rateControl.setInterpolation(true);

    isLiveMode = false;
    activeSource = out;
    initParticles();
    filePlayer.play();
}

void switchToLiveMode() {
    if (filePlayer != null) {
        filePlayer.close();
        filePlayer = null;
        meta = null;
        rateControl = null;
    }
    if (out != null) { out.close(); out = null; }

    input = minim.getLineIn(Minim.MONO, BUFFER_SIZE);
    isLiveMode = true;
    activeSource = input;
    update = true;
    initParticles();
}

void initParticles() {
    particles = new Particle[activeSource.bufferSize()];
    for (int i = 0; i < activeSource.bufferSize(); i++) {
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

    // Main loop through buffer
    for (int i = 0; i < activeSource.bufferSize(); i++) {
        if (update) {
            xt = origin.x + activeSource.left.get(i) * amp;
            yt = origin.y + activeSource.right.get(i) * amp;
            zt = origin.z + calculateZ(1, i);
            zloc += .1;
            particles[i].update(3, xt, yt, zt);
        }
    }

    // A main loop through each particle (in relation to every other)
    for (Particle a : particles) {
        if (drawElements) a.show();
        for (Particle b : particles) {
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
    case 0: return origin.z + (sin(zloc) + cos(zloc)) * amp;
    case 1: return origin.z + (sin(zloc) + cos(zloc)) * z_thickness;
    case 2: return amp / 10;
    case 3: return noise(activeSource.mix.get(i)) * amp;
    default: return 0;
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
    int y = yi;
    fill(255);
    stroke(255);

    if (isLiveMode) {
        text("Mode: Live input", 5, y);
    } else {
        text("Mode: File -- " + meta.fileName(), 5, y);
        text("Length: " + meta.length() + "ms   Title: " + meta.title() + "   Author: " + meta.author(), 5, y+=yi);
        text("a/s: Position: " + filePlayer.position(), 5, y+=yi);
        text("Spacebar: Toggle playback: " + filePlayer.isPlaying(), 5, y+=yi);
    }

    text("Buffersize: " + activeSource.bufferSize(), 5, y+=yi);
    text("m: Switch mode (currently " + (isLiveMode ? "live" : "file") + ")", 5, y+=yi);
    text("/: Toggle this panel", 5, y+=yi);
    text("z/x: Amplitude: " + amp, 5, y+=yi);
    text("q/w: Distance Threshold: " + line_thresh, 5, y+=yi);
    text("b/n: Z_Thickness: " + z_thickness, 5, y+=yi);
    text("e: Toggle elements: " + drawElements, 5, y+=yi);
    text("d: Toggle lines: " + drawLines, 5, y+=yi);
    text("c: Toggle background: " + drawBG, 5, y+=yi);
    text("t: Toggle axis: " + isAxis, 5, y+=yi);
    if (isLiveMode) text("Spacebar: Freeze update: " + !update, 5, y+=yi);
    text("p: Write out to file", 5, y+=yi);
    text("RIGHT: Camera spin X: " + isDoingCameraSpinX, 5, y+=yi);
    text("DOWN: Camera spin Y: " + isDoingCameraSpinY, 5, y+=yi);
    text("UP: Camera spin Z: " + isDoingCameraSpinZ, 5, y+=yi);
    text(".: Reset Camera", 5, y+=yi);
    text(",: Recording: " + recording, 5, y+=yi);
    text("Framerate: " + frameRate, 5, y+=yi);
    camera.endHUD();
}

/*
 * Allow control of the visualization with key presses
 */
void keyPressed() {

    // Toggle info panel
    if (key == '/') isShowingMetaData = !isShowingMetaData;

    // Toggle recording
    if (key == ',') recording = !recording;

    // Camera spin
    if (keyCode == RIGHT) isDoingCameraSpinX = !isDoingCameraSpinX;
    if (keyCode == DOWN)  isDoingCameraSpinY = !isDoingCameraSpinY;
    if (keyCode == UP)    isDoingCameraSpinZ = !isDoingCameraSpinZ;
    if (key == '.') camera.reset(CAMERA_RESET_TIME);

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

    // Amplitude
    if (key == 'x') amp += 100;
    if (key == 'z') amp -= 100;

    // File skip (file mode only)
    if (!isLiveMode && filePlayer != null) {
        if (key == 's') filePlayer.skip(1000);
        if (key == 'a') filePlayer.skip(-1000);
    }

    // Line distance threshold
    if (key == 'w') line_thresh += 15;
    if (key == 'q') line_thresh -= 15;

    // Z thickness
    if (key == 'n') z_thickness += 15;
    if (key == 'b') z_thickness -= 15;

    // Toggles
    if (key == 'e') drawElements = !drawElements;
    if (key == 't') isAxis = !isAxis;
    if (key == 'd') drawLines = !drawLines;
    if (key == 'c') drawBG = !drawBG;

    // Write out
    if (key == 'p') writeOutObj();
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
