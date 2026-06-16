
```glsl
// Sound code by Alexis THIBAULT

/*
This work is licensed under a Creative Commons Attribution-NonCommercial 4.0 International License.
https://creativecommons.org/licenses/by-nc/4.0/

You are free to:

    Share — copy and redistribute the material in any medium or format
    Adapt — remix, transform, and build upon the material

    The licensor cannot revoke these freedoms as long as you follow the license terms.

Under the following terms:

    Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

    NonCommercial — You may not use the material for commercial purposes.

    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
*/


#define TWOPI (2.*3.1415926)

#define bpm 100.
#define beatdur (60./bpm)

// Frequency Modulation

// f(t) instantaneous frequency
// sig = sin(phase(t))
// phase'(t) = TWOPI*f(t)
// phase(t) = integral of TWOPI*f(t) dt

// Constant frequency
// f(t) = f0
// phase'(t) = TWOPI*f0
// phase(t) = TWOPI*f0*t + c
// sig(t) = sin(TWOPI*f0*t + c)

// Sinusoidal variation
// carrier frequency fc
// modulation frequency fm
// frequency deviation df
// f(t) = fc + df * cos(TWOPI*fm*t)
// phase'(t) = TWOPI*fc + TWOPI*df * cos(TWOPI*fm*t))
// phase(t) = TWOPI*fc*t + df/fm * sin(TWOPI*fm*t)
// sig(t) = sin(TWOPI*fc*t + df/fm * sin(TWOPI*fm*t))

// index of modulation iom = df/fm


#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define FM2(pc, pm, iom) sin(mod(pc,TWOPI) + (iom)*sin(mod(pm,TWOPI)))

#define N(nn) 440.*exp2(((nn)-9.)/12.)

// Center frequency = fc
// Audible sidebands : abs(fc +- n*fm) for n <= ~iom
// Negative frequencies get reflected back


vec2 padSynth(float f, float t)
{
    vec2 sig = vec2(0);
    // body
    sig += FM(f, f+vec2(-1.,1.62), 1.) * 0.03;
    sig += FM(f+2., f+vec2(1.,-1.62), 1.) * 0.02;
    // personality
    float fc = f*round(2000./f);
    float iom = 1000./f;
    sig += FM(fc, f+vec2(0.7,-2.), iom * (1. - 0.5*sin(1.9*t))) * 0.01;
    sig += FM(fc-2., f+vec2(-1.,1.6), iom * (1. + 0.5*sin(3.*t))) * 0.007;
    
    float env = smoothstep(0., 0.3, t);
    return sig * env;
}

vec2 padChord(vec4 fs, float t)
{
    vec2 sig = vec2(0);
    sig += padSynth(fs.x, t) * vec2(0.8,0.3);
    sig += padSynth(fs.y, t) * vec2(1., 0.1);
    sig += padSynth(fs.z, t) * vec2(0.1, 1.);
    sig += padSynth(fs.w, t) * vec2(0.3, 0.8);
    return sig;
}

vec2 padChordPattern(float t)
{
    t = max(t, 0.);
    t = mod(t, 16.*beatdur);
    vec4 chord = 
        (t < 4.*beatdur) ? vec4(-3., -1., 0., 4.) :
        (t < 8.*beatdur) ? vec4(-3., 0., 2., 5.) :
        (t < 12.*beatdur) ? vec4(-7., -3., 0., 7.) :
        (t < 14.*beatdur) ? vec4(-5., 0., 2., 4.) :
                            vec4(-5., -1., 2., 4.);
    float t_cur = mod(t, 4.*beatdur);
    float env = smoothstep(4.*beatdur, 3.5*beatdur, t_cur);
    return padChord(N(chord), t_cur) * env;
}

vec2 padChordPatternVerb(float t)
{
    return padChordPattern(t)
    + padChordPattern(t-0.01).yx * 0.3 * vec2(-1,1)
    + padChordPattern(t-beatdur) * 0.25;
}

// Lead Synth

float vibratoPhase(float f0, float semitones, float vibHz, float t)
{
    float df = 0.06*f0*semitones;
    float phase = TWOPI*f0*t + df/vibHz*sin(TWOPI*vibHz*t);
    return phase;
}

vec2 leadSynth(float f, float t)
{
    vec2 sig = vec2(0);
    
    t = max(t, 0.); // To avoid problems with the exponential envelope
    
    // Vibrato
    // WRONG
    // f += 5.*sin(TWOPI*5.*t);
    // phase(t) = f(t)*t
    // phase'(t) = f(t) + f'(t)*t
    
    // RIGHT
    // f(t) = f0 + df*cos(TWOPI*fm*t)
    // phase(t) = TWOPI*f0*t + df/fm*sin(TWOPI*fm*t)
    // fm = 5 Hz
    // df = epsilon*f0
    float vibEnv = smoothstep(0., 0.5, t);
    float phase = vibratoPhase(f, 0.2*vibEnv, 5., t);
    float tpt = TWOPI*t;
    
    // body
    sig += FM2(phase, phase, 1.) * 0.05;
    sig += FM2(phase+5.*tpt, phase+vec2(-1.,0.8)*tpt, 3.) * 0.02;
    
    // presence
    float ratio = round(5000./f);
    float iom = 1500./f;
    sig += FM2(ratio*phase, phase, iom) * 0.01;
    sig += FM2(ratio*phase+5.*tpt, phase+vec2(3.,-3.)*tpt, iom) * 0.01;
    
    // attack
    float fc = f*round(10000./f);
    iom = 10000./f;
    sig += FM(fc, f, iom) * 0.05 * exp(-30.*t);
    
    float env = 1.;
    // Fake compression
    env *= 0.7*(1.+smoothstep(0.02,0.,t) + 0.3*smoothstep(0.,0.5,t));
    
    return sig * env;
}

vec2 leadSynthPattern(in float t)
{
    vec2 sig = vec2(0);
    t -= 1.75*beatdur;
    t = max(t, 0.);
    t = mod(t, 8.*beatdur);
    
    //#define P(nn, b) if(t>0. && t<(b)*beatdur) { sig += leadSynth(N(nn), t) * smoothstep((b)*beatdur, (b)*beatdur-0.01, t);  } t -= (b)*beatdur;
    #define P(nn, b) sig += leadSynth(N(nn), t) * step(0., t) * smoothstep((b)*beatdur, (b)*beatdur-0.01, t); t -= (b)*beatdur;
    
    P(7., 0.25);
    P(9., 0.5);
    P(7., 1.);
    P(9., 1.);
    P(9.+12., 0.5);
    P(16., 0.5);
    P(14., 1.);
    P(12., 0.5);
    P(9., 0.25);
    P(7., 0.25);
    P(9., 1.5);
    
    #undef P
    
    return sig;
}

vec2 leadSynthPatternVerb(float t)
{
    return leadSynthPattern(t)
    + leadSynthPattern(t-0.005).yx * vec2(0.3,0.7)
    + leadSynthPattern(t-0.75*beatdur) * 0.5 * vec2(-1,1)
    + leadSynthPattern(t-1.5*beatdur) * 0.25 * vec2(-1,-1);
}

vec2 mainSound( int samp, float t )
{
    vec2 sig = vec2(0);
    sig += padChordPatternVerb(t);
    //sig += leadSynth(440., t);
    sig += leadSynthPatternVerb(t);
    return sig;
}

```