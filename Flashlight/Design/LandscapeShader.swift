// Metal source compiled at runtime, so the project needs no offline Metal toolchain.
// Parameter layout is documented in Scenery.swift.
let landscapeShaderSource = #"""
#include <metal_stdlib>
using namespace metal;

// Procedural landscape: sky, stars, milky way, aurora, moon/sun, clouds, layered terrain with
// atmospheric perspective, water with reflections. Parameters arrive packed in one float array
// (layout documented in Scenery.swift).

// MARK: - Noise

static float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

static float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < octaves; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + float2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

static float ridged(float x, float seed, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float f = 1.0;
    for (int i = 0; i < octaves; i++) {
        float n = vnoise(float2(x * f + seed * 13.7, seed * 3.1 + float(i) * 7.3));
        n = 1.0 - abs(2.0 * n - 1.0);
        v += a * n * n;
        f *= 2.1;
        a *= 0.5;
    }
    return v;
}

// MARK: - Terrain

// Ridged multifractal, normalised to 0...1 (typical values 0.1 - 0.6).
static float mountain(float x, float seed, int octaves, float sharp) {
    float h = 0.0;
    float a = 1.0;
    float f = 0.8;
    float norm = 0.0;
    for (int i = 0; i < octaves; i++) {
        float n = vnoise(float2(x * f + seed * 7.13, seed * 1.7 + float(i) * 5.1));
        float r = pow(1.0 - abs(2.0 * n - 1.0), sharp);
        h += a * r;
        norm += a;
        a *= 0.48;
        f *= 2.05;
    }
    return h / norm;
}

// Normalised silhouette height (about 0...1) of one layer at horizontal position x.
static float layerHeight(int kind, float x, float seed, float amp) {
    if (kind == 1) {                      // jagged rock
        float h = mountain(x * 5.0, seed, 5, 2.0);
        return smoothstep(0.18, 0.8, h);
    }
    if (kind == 2) {                      // sharp snow peaks
        float h = mountain(x * 4.0, seed, 6, 2.4);
        return pow(smoothstep(0.2, 0.78, h), 1.1);
    }
    if (kind == 3) {                      // conifer forest on rolling ground
        float n = 2.0 / max(amp, 0.04);
        float g = x * n + seed * 5.0;
        float cell = floor(g);
        float tree = 0.35 + 0.65 * hash11(cell + seed);
        float tooth = 1.0 - abs(fract(g) * 2.0 - 1.0);
        float hills = fbm(float2(x * 2.6 + seed, seed), 3);
        return clamp(hills * 0.45 + tree * pow(tooth, 0.9) * 0.62, 0.0, 1.0);
    }
    if (kind == 4) {                      // dunes: soft crests, sharper lee side
        float s = sin(x * 13.0 + seed + 0.9 * sin(x * 5.0 + seed * 2.0));
        float d = 0.5 + 0.5 * s;
        float ripple = 0.015 * sin(x * 90.0 + seed);
        return clamp(pow(d, 1.7) + ripple, 0.0, 1.0);
    }
    if (kind == 5) {                      // soft hills
        return clamp(fbm(float2(x * 3.4 + seed * 3.0, seed), 4) * 1.7 - 0.25, 0.0, 1.0);
    }
    if (kind == 6) {                      // meadow: hills plus grass blades
        float g = x * 110.0 + seed * 9.0;
        float blade = pow(1.0 - abs(fract(g) * 2.0 - 1.0), 1.8);
        float tall = hash11(floor(g) + seed);
        float hills = fbm(float2(x * 3.2 + seed * 3.0, seed), 3);
        return clamp(hills * 0.4 + 0.6 * tall * blade, 0.0, 1.0);
    }
    return 0.0;
}

static float3 drawLayers(float3 c, float2 uv, float aspect, float time,
                         constant float *P, bool foreground) {
    float wH = P[8];
    float fog = P[3];
    float3 fogC = float3(P[24], P[25], P[26]);
    float3 celC = float3(P[21], P[22], P[23]);
    float2 cel = float2(P[4] * aspect, P[5]);
    float x = uv.x * aspect;

    for (int k = 0; k < 4; k++) {
        int o = 27 + k * 7;
        int kind = int(P[o] + 0.5);
        if (kind == 0) continue;
        float base = P[o + 1];
        float amp = P[o + 2];
        float seed = P[o + 3];
        float3 col = float3(P[o + 4], P[o + 5], P[o + 6]);

        bool isForeground = wH > 0.0 && base > wH + 0.02;
        if (isForeground != foreground) continue;
        if (uv.y < base - amp * 1.15) continue;

        float hN = layerHeight(kind, x, seed, amp);
        float top = base - amp * hN;
        if (uv.y < top) continue;

        float e = 0.003;
        float h1 = layerHeight(kind, x + e, seed, amp);
        float h0 = layerHeight(kind, x - e, seed, amp);
        float slope = -amp * (h1 - h0) / (2.0 * e);
        float2 n = normalize(float2(slope, -1.0));
        float2 L = normalize(cel - float2(x, top));
        float lam = clamp(dot(n, L) * 0.5 + 0.5, 0.0, 1.0);

        float depthK = float(k) / 3.0;
        float below = uv.y - top;
        float far = 1.0 - depthK;

        float edgeK = 1.0 - smoothstep(0.0, 0.26 * amp + 0.02, below);
        float lamEff = mix(0.6, lam, edgeK * 0.35);
        float3 lit = col * (0.5 + 0.9 * lamEff);
        lit += celC * col * 0.35 * lamEff;
        if (kind == 1 || kind == 2) {
            float gully = fbm(float2(x * 14.0 + seed, uv.y * 11.0), 4);
            lit *= 0.93 + 0.12 * gully;
            lit *= 0.84 + 0.32 * fbm(float2(x * 7.0 + seed * 2.0, uv.y * 4.0), 3);
        }
        lit *= mix(1.0, 0.62, smoothstep(0.0, 0.35, below));
        lit += celC * 0.11 * (1.0 - smoothstep(0.0, 0.006, below)) * (1.0 - depthK * 0.5);

        if (kind == 2) {
            float alt = base - uv.y;
            float grain = fbm(float2(x * 38.0, uv.y * 38.0), 3) - 0.5;
            float line = 0.40 * amp + 0.10 * amp * grain;
            float snow = smoothstep(line, line + 0.05 * amp, alt + 0.15 * amp * grain);
            float tex = fbm(float2(x * 34.0, uv.y * 20.0), 3);
            snow *= 0.7 + 0.5 * tex;
            float3 snowC = mix(float3(0.93, 0.96, 1.0), fogC, 0.3) * (0.6 + 0.5 * lamEff + 0.25 * tex);
            lit = mix(lit, snowC, clamp(snow, 0.0, 1.0));
        }
        if (kind == 4) {
            float grain = vnoise(float2(x * 220.0, uv.y * 220.0));
            lit *= 0.92 + 0.16 * grain;
        }

        lit = mix(lit, fogC, fog * far * 0.6);
        lit = mix(lit, fogC, fog * 0.55 * far * smoothstep(0.02, 0.28, below));
        c = lit;
    }
    return c;
}

// MARK: - Sky

static float stars(float2 p, float time, float density) {
    float s = 0.0;
    for (int layer = 0; layer < 3; layer++) {
        float scale = 55.0 + 65.0 * float(layer);
        float2 g = p * scale + float(layer) * 31.7;
        float2 id = floor(g);
        float2 f = fract(g) - 0.5;
        float h = hash21(id);
        float chance = density * 0.16 / (1.0 + float(layer) * 0.7);
        if (h > 1.0 - chance) {
            float2 off = (float2(hash21(id + 1.3), hash21(id + 7.7)) - 0.5) * 0.6;
            float d = length(f - off);
            float mag = hash21(id + 3.1);
            float tw = 0.7 + 0.3 * sin(time * (1.5 + mag * 3.0) + h * 40.0);
            s += (1.0 - smoothstep(0.0, 0.10 + 0.05 * mag, d)) * (0.3 + 0.7 * mag) * tw;
        }
    }
    return s;
}

static float3 milkyWay(float2 p, float amount) {
    float2 d = p - float2(0.5, 0.32);
    float a = 0.55;
    float2 q = float2(cos(a) * d.x - sin(a) * d.y, sin(a) * d.x + cos(a) * d.y);
    float band = exp(-q.y * q.y / 0.018);
    float structure = fbm(float2(q.x * 5.0, q.y * 14.0), 5);
    float dust = smoothstep(0.45, 0.72, fbm(q * float2(4.0, 22.0) + 9.0, 4));
    float mw = band * (0.25 + structure) * (1.0 - 0.75 * dust);
    float3 tint = mix(float3(0.55, 0.64, 0.9), float3(0.95, 0.82, 0.7), structure * 0.6);
    return tint * mw * 0.32 * amount;
}

static float3 aurora(float2 uv, float aspect, float time, float amount) {
    float x = uv.x * aspect;
    float warp = sin(x * 2.2 + time * 0.12) * 0.12 + sin(x * 5.1 - time * 0.2) * 0.04;
    float curtain = fbm(float2(x * 3.0 + warp * 6.0, time * 0.03), 4);
    float streak = pow(clamp(curtain * 1.4, 0.0, 1.0), 2.2);
    float band = smoothstep(0.06, 0.2, uv.y) * (1.0 - smoothstep(0.38, 0.62, uv.y + warp * 0.2));
    float rays = 0.65 + 0.35 * vnoise(float2(x * 90.0, uv.y * 6.0));
    float3 green = float3(0.18, 1.0, 0.55);
    float3 cyan = float3(0.15, 0.75, 0.95);
    float3 violet = float3(0.7, 0.25, 0.85);
    float h = smoothstep(0.1, 0.5, uv.y);
    float3 col = mix(green, cyan, h);
    col = mix(violet, col, smoothstep(0.08, 0.2, uv.y));
    return col * streak * band * rays * amount * 0.85;
}

static float3 skyColor(float2 uv, float aspect, float time, constant float *P) {
    float3 zenith = float3(P[12], P[13], P[14]);
    float3 mid = float3(P[15], P[16], P[17]);
    float3 horizon = float3(P[18], P[19], P[20]);
    float3 celC = float3(P[21], P[22], P[23]);
    float2 p = float2(uv.x * aspect, uv.y);
    float2 cel = float2(P[4] * aspect, P[5]);
    float celR = P[6];
    int celKind = int(P[7] + 0.5);

    float h = uv.y;
    float3 sky = mix(zenith, mid, smoothstep(0.0, 0.5, h));
    sky = mix(sky, horizon, pow(smoothstep(0.3, 0.9, h), 1.5));

    float starAmt = P[0];
    if (starAmt > 0.0) {
        float fade = (1.0 - smoothstep(0.35, 0.8, h));
        float d = length(p - cel);
        float moonMask = celKind == 1 ? smoothstep(celR * 2.0, celR * 10.0, d) : 1.0;
        float tw = stars(p, time, starAmt);
        float3 starTint = mix(float3(0.8, 0.9, 1.0), float3(1.0, 0.9, 0.78), hash21(floor(p * 90.0)));
        sky += starTint * tw * fade * moonMask * clamp(starAmt, 0.0, 1.0);
        if (starAmt > 0.55) sky += milkyWay(p, starAmt - 0.4) * fade * moonMask;
    }

    if (P[1] > 0.0) sky += aurora(uv, aspect, time, P[1]);

    if (celKind > 0) {
        float d = length(p - cel);
        if (celKind == 1) {
            float glow = exp(-d / (celR * 4.5)) * 0.35 + exp(-d / (celR * 16.0)) * 0.14;
            sky += celC * glow;
            float disk = 1.0 - smoothstep(celR * 0.94, celR, d);
            float2 mp = (p - cel) / celR;
            float maria = fbm(mp * 2.2 + 3.0, 4);
            float limb = 0.88 + 0.12 * sqrt(max(0.0, 1.0 - dot(mp, mp)));
            float3 moon = celC * (0.78 + 0.35 * maria) * limb;
            sky = mix(sky, moon, disk);
        } else {
            float glow = exp(-d / (celR * 5.0)) * 0.9 + exp(-d / (celR * 20.0)) * 0.35;
            sky += celC * glow;
            float disk = 1.0 - smoothstep(celR * 0.9, celR, d);
            sky = mix(sky, mix(celC, float3(1.0, 0.97, 0.9), 0.5) * 1.35, disk);
        }
    }

    float cloudAmt = P[2];
    if (cloudAmt > 0.0) {
        float2 cp = float2(p.x * 1.3 + time * 0.004, p.y * 3.0);
        float warp = fbm(cp * 1.5 + 3.0, 3);
        float cl = fbm(cp + warp * 1.4, 5);
        float density = smoothstep(1.0 - cloudAmt * 0.75, 1.0 - cloudAmt * 0.75 + 0.25, cl);
        density *= 1.0 - smoothstep(0.1, 0.7, h);
        float lightK = exp(-length(p - cel) * 1.6);
        float3 cloudC = mix(mid * 0.6, celC * 0.9, clamp(lightK * 1.4, 0.0, 1.0));
        sky = mix(sky, cloudC, density * 0.62);
    }
    return sky;
}

static float3 world(float2 uv, float aspect, float time, constant float *P) {
    float3 c = skyColor(uv, aspect, time, P);
    return drawLayers(c, uv, aspect, time, P, false);
}

static float3 waterColor(float2 uv, float aspect, float time, constant float *P) {
    float wH = P[8];
    float dy = uv.y - wH;
    float x = uv.x * aspect;
    float ripple = (fbm(float2(x * 22.0, dy * 140.0 - time * 0.25), 3) - 0.5) * 0.035 * (0.3 + dy * 3.0);
    float2 ruv = float2(uv.x + ripple, wH - dy * 0.9);
    float3 refl = world(ruv, aspect, time, P);

    float3 zenith = float3(P[12], P[13], P[14]);
    float3 horizon = float3(P[18], P[19], P[20]);
    float3 deep = mix(zenith, horizon, 0.18) * 0.5;
    float fresnel = mix(0.82, 0.3, smoothstep(0.0, 0.4, dy));
    float3 c = mix(deep, refl, fresnel);

    int celKind = int(P[7] + 0.5);
    if (celKind > 0) {
        float3 celC = float3(P[21], P[22], P[23]);
        float x0 = P[4] * aspect;
        float width = 0.02 + dy * 0.2;
        float streak = exp(-pow((x - x0) / width, 2.0));
        float bars = smoothstep(0.5, 0.9, fbm(float2(x * 70.0, dy * 220.0 + time * 0.4), 3));
        c += celC * streak * (0.15 + bars) * 0.85 * (1.0 - smoothstep(0.0, 0.45, dy));
    }
    float far = float3(P[24], P[25], P[26]).x;
    c = mix(c, float3(P[24], P[25], P[26]), P[3] * 0.25 * (1.0 - smoothstep(0.0, 0.1, dy)));
    return c + far * 0.0;
}

// MARK: - Entry

struct VOut { float4 pos [[position]]; };

vertex VOut landscapeVertex(uint vid [[vertex_id]]) {
    float2 p = float2(float((vid << 1) & 2u), float(vid & 2u));
    VOut o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

fragment half4 landscapeFragment(VOut in [[stage_in]],
                                 constant float2 &size [[buffer(0)]],
                                 constant float &time [[buffer(1)]],
                                 constant float *P [[buffer(2)]]) {
    float2 position = in.pos.xy;
    float aspect = size.x / size.y;
    float2 uv = position / size;
    float wH = P[8];

    float3 c;
    if (wH > 0.0 && uv.y > wH) {
        c = waterColor(uv, aspect, time, P);
    } else {
        c = world(uv, aspect, time, P);
    }
    if (wH > 0.0) c = drawLayers(c, uv, aspect, time, P, true);

    // Vignette and a touch of grain to break up banding.
    float2 vc = (uv - 0.5) * float2(1.0, 1.25);
    c *= 1.0 - 0.28 * dot(vc, vc);
    c += (hash21(position + fract(time) * 91.0) - 0.5) * (2.0 / 255.0);
    return half4(half3(clamp(c, 0.0, 1.0)), 1.0h);
}
"""#
