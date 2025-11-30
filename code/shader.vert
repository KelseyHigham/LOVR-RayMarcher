out vec3 dynamicVertexColor;

Constants {
    float time; // real time
    float scale; // parameter
    vec3 viewOffset; // for flight
};

#define MAX_STEPS 50
#define MAX_DIST 20.

#define SURF_DIST .003 // Could a low precision in the position of the ray be the cause of the jagged lines?

#define ITER 5 // Iteration for the inefficent fractals

// Return distance from a box at positon pBox, of size sizeBox from position p. No rotation
float DEBox(vec3 p, vec3 pBox, vec3 sizeBox) {
    return length(max(abs(p - pBox) - sizeBox, 0.));
}

// Return distance from a sphere at pSphere, radius rSphere, position p
float DESphere(vec3 p, vec3 pSphere, float rSphere) {
    return length(p - pSphere.xyz) - rSphere;
}

// Inefficient but valid Menger sponge
float DEInefficientMengerSponge(vec3 p) {
    float s = 1.;
    float d = 0.;
    for (int m = 0; m < ITER; m++) {
        vec3 a = mod(p * s, 2.) - 1.;
        s *= 3.0;
        vec3 r = abs(1.0 - 3.0 * abs(a));
        float da = max(r.x, r.y);
        float db = max(r.y, r.z);
        float dc = max(r.z, r.x);
        float c = (min(da, min(db, dc)) - 1.0) / s;
        d = max(d, c);
    }
    return d;
}

float DEInefficientPenroseTetrahedron(vec3 z) {
    float r;
    vec3 Offset = vec3(0.5);
    float Scale = 2.;
    int n = 0;
    while (n < ITER) {
        if (z.x + z.y < 0.) z.xy = -z.yx; // fold 1
        if (z.x + z.z < 0.) z.xz = -z.zx; // fold 2
        if (z.y + z.z < 0.) z.zy = -z.yz; // fold 3
        z = z * Scale - Offset * (Scale - 1.0);
        n++;
    }
    return (length(z)) * pow(Scale, -float(n));
}

// Return a psuedo random value in the range [0, 1), seeded via coord
float rand(vec2 coord)
{
    return fract(sin(dot(coord.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float GetDist(vec3 p) {
    float modSpace = 3.; // Size of the mod effect, meters
    // The mod effect starts from (0,0,0) and expands only in positive directions
    float modOffset = modSpace / 2.; // Offset of the mod effect from 0,0,0.
    // The sphere being rendered has position (0,0,0), so an offset is necessary as negative values are removed by the mod
    p.xyz = mod((p.xyz), modSpace) - vec3(modOffset); // Instance on xy-plane
    // The modulo space creates a nauseating movement effect AND inverts flight controls. WHY
    vec3 zero_pos = vec3(0., 0., 0.);
    // vec3 sizeBox = vec3(.5);
    // float box = DEBox(p, zero_pos, sizeBox);
    // zero_pos.x += .5 * sin(0.5*time);
    // zero_pos.y -= .6 * sin(0.4*time);
    float sphere = DESphere(p, zero_pos, .30);
    return sphere;
    // float sponge = DEInefficientMengerSponge(p);
    // return sponge;
    // float penrose = DEInefficientPenroseTetrahedron(p);
    // return penrose;
}

// Main RayMarch loop
vec2 RayMarch(vec3 origin, vec3 direction) {
    float distance = 0.; // Total distance
    int i = 0; // Iterations
    // Over GetDist function until
    for (i = 0; i < MAX_STEPS; i++) {
        vec3 position = origin + direction * distance; // Get new DE center
        float displacement = GetDist(position);
        distance += displacement; // Update distance

        // Stop at max distance or if near enough other entity
        if (distance > MAX_DIST || abs(displacement) < SURF_DIST) break;
    }
    // Return number of steps and distance travelled as a pair of floats
    return vec2(float(i), distance);
}

// Compute normal based on partial derivatives of the distance function
vec3 GetNormal(vec3 p) {
    // Get distance at the point p
    float d = GetDist(p);
    // Offset used to extract a simple partial derivative
    vec2 e = vec2(.001, 0);

    // Compute distances in positions very nearby p, subtract them from the original distance
    vec3 n = d - vec3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    // The result is an approximation of the normal of the surface that was closest.
    // Normalize the result and return
    return normalize(n);
}

// Used to compute lighting effects
float GetLight(vec3 p) {
    vec3 lightPos = vec3(0, 0, 0);
    // Rotate light
    lightPos.xz += vec2(sin(time), cos(time)) * 2.;
    // Get positions of light and surface normal
    vec3 light_vector = normalize(lightPos - p);
    vec3 surface_normal = GetNormal(p);

    // Basic Phong model
    float dif = clamp(dot(surface_normal, light_vector), 0., 1.);
    // float d = RayMarch(p+n*SURF_DIST*2., l);
    // if(d<length(lightPos-p)) dif *= .1;

    return dif;
}

vec3 palette(in float t)
{
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 0.5);
    vec3 d = vec3(0.80, 0.90, 0.30);
    return a + b * cos(6.28318 * (c * t + d));
}

vec4 lovrmain() {
    // Get the camera position as a vec3 by taking the negative of the translation component and transforming it using the rotation component
    vec3 pos = -View[3].xyz * mat3(View);
    vec3 worldPos = (Transform * VertexPosition).xyz;

    vec3 position = pos + viewOffset; // add flight controls
    vec3 direction = normalize(worldPos - position);

    vec2 raymarch_result = RayMarch(position, direction);
    float steps = raymarch_result.x;
    float dist = abs(length(raymarch_result.y));
    vec3 p = position + direction * dist;

    float dif = GetLight(p);
    vec3 ambient_light = vec3(0.09, 0.06, 0.15);
    vec3 direct_light_color = vec3(0.8, 0.95, 0.98);
    vec3 col = dif * direct_light_color + ambient_light;
    col -= 0.85 * float(dist) / float(MAX_DIST) + 0.06 * (float(steps) / float(MAX_STEPS));
    dynamicVertexColor = col;

    // // Visualize vertices, for configuring geometry resolution
    // dynamicVertexColor = vec3(VertexIndex & 1, VertexIndex & 2, VertexIndex & 3);

    return DefaultPosition;
}
