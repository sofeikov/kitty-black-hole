#language slang 2026
// A black hole that drifts back and forth along the top of the window.
// Text near it is pulled in, twisted and swallowed by the event horizon.
// Colours are linear RGB; coordinates are UV with the origin at the bottom left.

import kitty_custom_shader_types;

static const float HOLE_RADIUS = 0.03;   // event horizon radius, as a fraction of window height
static const float INFLUENCE = 0.22;     // distance from the hole over which text is affected
static const float PULL = 0.45;          // how strongly text is dragged in (keep at or below 0.5)
static const float SWIRL = 2.2;          // twist of the text near the hole, in radians
static const float ROAM = 0.38;          // how far the hole drifts sideways from the centre (fraction of width)
static const float TOP_MARGIN = 0.07;    // distance of the hole from the top edge (fraction of height)
static const float3 GLOW = float3(0.35, 0.8, 1.0); // colour of the accretion disk

static const float TAU = 6.2831853;

// The motion repeats every 30 s (sideways) and 6 s (bob), so the 60 s wrapped
// time used below never causes a visible jump.
float2
hole_center(float T) {
    float x = 0.5 + ROAM * sin(TAU * T / 30.0);
    float y = 1.0 - TOP_MARGIN + 0.015 * sin(TAU * T / 6.0);
    return float2(x, y);
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float T = d.wrapped_time(60u);

    // Work in a space where one unit is the window height, so the hole is round.
    float2 pixels = float2(d.viewport_size_pixels) * t.viewport.zw;
    float2 scale = float2(pixels.x / pixels.y, 1.0);

    float2 c = hole_center(T);
    float2 delta = (t.pos - c) * scale;
    float r = length(delta);

    // 0 outside the area of influence, 1 at the centre of the hole.
    float w = saturate(1.0 - r / INFLUENCE);
    w = w * w;

    // Sample the text from further out and rotated, so it looks dragged in and twisted.
    float src_r = r + PULL * INFLUENCE * w;
    float ang = SWIRL * w;
    float s = sin(ang);
    float co = cos(ang);
    float2 dir = delta / max(r, 0.00001);
    float2 rot = float2(dir.x * co - dir.y * s, dir.x * s + dir.y * co);
    float2 src = c + rot * src_r / scale;
    float3 base = t.backbuffer.Sample(src).rgb;

    // Text fades to black as it reaches the event horizon.
    base *= smoothstep(HOLE_RADIUS, HOLE_RADIUS * 3.0, r);

    // Bright ring just outside the horizon.
    float ring_r = HOLE_RADIUS * 1.12;
    float ring_x = (r - ring_r) / (HOLE_RADIUS * 0.12);
    float ring = exp(-ring_x * ring_x);

    // Soft halo that fades away from the horizon.
    float halo = exp(-max(r - HOLE_RADIUS, 0.0) / (HOLE_RADIUS * 1.5)) * 0.35;
    halo *= step(HOLE_RADIUS, r);

    // Thin accretion disk seen edge-on, with ripples moving outwards.
    float disk_y = delta.y / (HOLE_RADIUS * 0.15);
    float disk = exp(-disk_y * disk_y);
    disk *= smoothstep(HOLE_RADIUS * 3.5, HOLE_RADIUS * 1.05, abs(delta.x));
    disk *= 0.6 + 0.4 * sin(6.0 * abs(delta.x) / HOLE_RADIUS - TAU * T);

    float3 glow = GLOW * (1.5 * ring + halo + 1.2 * disk);
    return float4(base + glow, color.a);
}
