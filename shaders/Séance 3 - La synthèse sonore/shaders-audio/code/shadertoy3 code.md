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


// ========== PAD ==========

vec2 padSynth(float f, float t, float tt)
{
    vec2 sig = vec2(0);
    // body
    sig += FM(f, f+vec2(-1.,1.62), 1.) * 0.03;
    sig += FM(f+2., f+vec2(1.,-1.62), 1.) * 0.02;
    // personality
    float fc = f*round(2000./f);
    float iom = 1000./f;
    sig += FM(fc, f+vec2(0.7,-2.), iom * (1. - 0.5*sin(1.9*tt))) * 0.01;
    sig += FM(fc-2., f+vec2(-1.,1.6), iom * (1. + 0.5*sin(3.*tt))) * 0.007;
    
    float env = smoothstep(0., 0.3, t);
    return sig * env;
}

vec2 padChord(vec4 fs, float t, float tt)
{
    vec2 sig = vec2(0);
    sig += padSynth(fs.x, t, tt) * vec2(0.8,0.3);
    sig += padSynth(fs.y, t, tt-1.) * vec2(1., 0.1);
    sig += padSynth(fs.z, t, tt+1.) * vec2(0.1, 1.);
    sig += padSynth(fs.w, t, tt-2.) * vec2(0.3, 0.8);
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
        (t < 14.*beatdur) ? vec4(-5., 2., 4., 7.) :
                            vec4(-5., -1., 2., 4.);
    float t_cur = mod(t, 4.*beatdur);
    float env = smoothstep(4.*beatdur, 3.99*beatdur, t_cur);
    return padChord(N(chord), t_cur, t) * env;
}

vec2 padChordPatternVerb(float t)
{
    return padChordPattern(t)
    //+ padChordPattern(t-0.01).yx * 0.8 * vec2(-1,1)
    + padChordPattern(t-0.75*beatdur) * 0.8
    + padChordPattern(t-1.5*beatdur) * 0.5
    + padChordPattern(t-3.62*beatdur) * 0.5;
}

// ========== LEAD SYNTH ==========

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

// ========== BASS ==========

float filteredSaw(float f, float fc, float t)
{
    // f frequency
    // fc cutoff frequency
    // t time
    float x = f*t;
    float w = 0.5*f/fc;
    w = min(w, 0.5);
    x -= round(x);
    return mix(-2.*x-1., -2.*x+1., smoothstep(-w, w, x));
}

vec2 bassSynth(float f, float t)
{
    // Classic 80's "saw stab" bass
    vec2 sig = vec2(0);
    float fc = 15000.*exp(-80.*t) +100.; // cutoff envelope of the sub
    float fc2 = 15000.*exp(-40.*t) +100.; // cutoff envelope of the higher components
    //float fc = 5000.;
    sig += 0.1*filteredSaw(f/2., fc, t); // filtered sub-oscillator
    sig += 0.05*sin(TWOPI*fract(f/2.*t)); // some more sub
    sig += 0.1*filteredSaw(f+1.618, fc2, t+1.) * vec2(1.,0.2); // higher components
    sig += 0.1*filteredSaw(f-1., fc2, t+1.7) * vec2(0.2,1.); // with stereo + detuning
    return sig;
}

vec2 bassSynthPattern(float t)
{
    // Classic 80's bass pattern: just play eighth notes!
    t = max(t, 0.);
    t = mod(t, 16.*beatdur);
    float nn = 
        (t < 4.*beatdur) ?-3. :
        (t < 8.*beatdur) ? 2. :
        (t < 12.*beatdur) ? 5. :
        (t < 14.*beatdur) ? 0. :
                            -5.;
    float f = N(nn)/2.;
    t = mod(t, 0.5*beatdur);
    return bassSynth(f, t);
}

// ========== WAH LEAD ==========

float wahLead(float f, float t)
{
    // A short synth that goes "wah" (or "waw"?)
    float dur = 0.1;
    float env = smoothstep(0.,dur/2., t) * smoothstep(dur, dur/2., t);
    float env2 = smoothstep(0.,dur/4., t) * smoothstep(2.*dur, dur, t);
    float fc = 400.+10000.*env;
    float sig = filteredSaw(f, fc, t) * 0.1;
    return sig * env2;
}

float wahLeadPattern(float t)
{
    // Do a weird rhythm with the "wah" synth
    t = max(0.,t);
    t = mod(t, 16.*beatdur);
    // Notes are taken from the chords
    float nn = 
        (t < 4.*beatdur) ? 4. :
        (t < 8.*beatdur) ? 5. :
        (t < 12.*beatdur) ? 5. :
        (t < 14.*beatdur) ? 4. :
                            2.;
    t = mod(t, 8.*beatdur);
    float t1 = mod(t, 4.*beatdur);
    t1 = mod(t1, 1.75*beatdur);
    t1 = mod(t1, 1.5*beatdur);
    if(2.25*beatdur <= t && t < 4.*beatdur)
    {
        // Jump up an octave now and then
        nn += 12.;
        t -= 2.25*beatdur;
    }
    else
    {
        t = t1;
    }
    return wahLead(N(nn), t);
}

vec2 wahLeadPatternVerb(float t)
{
    // Trippy delay/reverb thing
    vec2 sig = vec2(0);
    sig.x += wahLeadPattern(t);
    sig.y += wahLeadPattern(t - 0.52*beatdur);
    sig += wahLeadPattern(t - 1.54*beatdur) * vec2(-0.5,0.1);
    sig += wahLeadPattern(t - 1.78*beatdur) * vec2(0.1,-0.5);
    return sig;
}

// ========== MARIMBA ==========

float marimba(float f, float t)
{
    // Classic FM "marimba" patch
    // Super simple and effective.
    return FM(f, 7.*f, 1.5*exp(-80.*t)) * exp(-5.*t) * 0.1;
}

vec2 marimbaPattern(float t)
{
    // Pop-ish dotted eighth note pattern
    t = mod(t, 16.*beatdur);
    // Take two notes from the chords
    vec2 nn = 
        (t < 4.5*beatdur) ? vec2(4.,12.) :
        (t < 8.*beatdur) ? vec2(5.,9.) :
        (t < 12.5*beatdur) ? vec2(9.,12.) :
        (t < 14.*beatdur) ? vec2(7.,12.) :
                            vec2(7.,11.);
    t = mod(t, 8.*beatdur); // Make sure we restart the notes every two bars
    t = mod(t, 6.*beatdur);
    t = mod(t, 0.75*beatdur); // and repeat them four times in three beats
    vec2 sig = vec2(0);
    sig += marimba(N(nn.x), t) * vec2(0.7,0.2);
    sig += marimba(N(nn.y), t) * vec2(0.1,0.5);
    return sig;
}



// ========== MAIN SOUND ==========

vec2 mainSound( int samp, float t )
{
    vec2 sig = vec2(0);
    
    // Fake sidechain compression
    // Turn the signal down during the first part of every beat
    float pumping = smoothstep(0.,0.2,mod(t,beatdur)) * smoothstep(beatdur, beatdur-0.01, mod(t,beatdur));
    //float pumping = 1.;
    
    
    //sig += leadSynth(440., t);
    //sig += wahLeadPattern(t) * mix(pumping, 1., 0.5) * 0.7;
    
    
    sig += padChordPatternVerb(t) * mix(pumping, 1., 0.5)*0.7;
    sig += leadSynthPatternVerb(t) * mix(pumping, 1., 0.7) * 0.8;
    sig += wahLeadPatternVerb(t) * mix(pumping, 1., 0.5) * 0.7;
    sig += bassSynthPattern(t) * mix(pumping, 1., 0.2);
    sig += marimbaPattern(t) * mix(pumping, 1., 0.7);
    
    return sig;
}

```