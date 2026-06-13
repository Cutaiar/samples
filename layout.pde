
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

//--------------- Layout Algorithm ---------------------------

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
