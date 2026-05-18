
```glsl
#define TWOPI 6.2831

float sinPluck(float f, float t)
{
    return sin(TWOPI*f*t)*exp(-3.*t) * 0.1;
}

float squarePluck(float f, float t)
{
    return sign(sin(TWOPI*f*t))*exp(-3.*t) * 0.1;
}

float sawPluck(float f, float t)
{
    return (mod(t*f, 1.)*2. -1.)*exp(-3.*t) * 0.1;
}

float FM(float fc, float fm, float iom, float t)
{
    return sin(TWOPI*fc*t + iom*sin(TWOPI*fm*t));
}

vec2 fmPluck(float f, float t)
{
    float fc = f; // carrier freq
    float fm = f; // modulation freq
    float iom = 1.; // index of modulation
    
    float env = exp(-3.*t) * 0.1;
    vec2 sig = vec2(0);
    
    sig.x += FM(f+1., f+1., 1., t) * env;
    sig.y += FM(f-1., f-1., 1., t) * env;
    sig += FM(f, f, 15., t) * exp(-20.*t) * 0.03;
    
    return sig;
}

vec2 pan(float pos)
{
    vec2 e = vec2(1.-pos, 1.+pos);
    return normalize(e);
}

float interval(float semitones)
{
    return pow(2., semitones/12.);
}

const float notes[] = float[6](-12., -5., 2., -5., 3., 5.);

vec2 jingle(float t)
{
    vec2 sig = vec2(0);
    for(int i=0; i<6; i++)
    {
        float nn = notes[i];
        float fi = 440.*interval(nn);
        float t0i = 0.25*float(i);
        float ti = mod(t-t0i, 2.);
        float pos = float((i+1)%3) - 1.;
        
        sig += fmPluck(fi, ti) * pan(pos);
    }
    return sig;
}

vec2 mainSound( int samp, float t )
{
    vec2 sig = vec2(0);
    
    /*
    sig += fmPluck(440., mod(t, 1.)) * pan(-0.5);
    sig += fmPluck(660., mod(t - 0.25, 1.))  * pan(0.5);
    */
    
    sig += jingle(t);
    
    
    return sig;
}

```