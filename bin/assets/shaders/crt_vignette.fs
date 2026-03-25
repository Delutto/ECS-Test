#version 330

// Inputs from raylib's default vertex shader
in  vec2 fragTexCoord;
in  vec4 fragColor;

// Output
out vec4 finalColor;

// Set once per frame from THUDSystem with the current screen resolution
uniform vec2 screenSize;

void main()
{
    // Normalised screen UV — (0,0) = bottom-left, (1,1) = top-right
    vec2 uv = gl_FragCoord.xy / screenSize;

    // Distance from the screen centre in UV space
    vec2  offset   = uv - vec2(0.5, 0.5);

    // Vignette: smoothstep maps length * scale from [0.3, 0.9] -> [0, 1]
    //   vignette = 1  at the centre  (fully lit   => alpha = 0)
    //   vignette = 0  at the corners (fully dark  => alpha = 0.82)
    float vignette = 1.0 - smoothstep(0.3, 1.3, length(offset) * 1.6);

    // Scanlines: very subtle (±4%) horizontal sine banding
    float scanline = 0.96 + 0.04 * sin(gl_FragCoord.y * 3.14159265);

    // Combine into a black overlay whose alpha encodes the effect
    float alpha = (1.0 - vignette * scanline) * 0.82;

    finalColor = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 1.0));
}
