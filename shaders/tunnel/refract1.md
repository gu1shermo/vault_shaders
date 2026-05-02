 ## common
```glsl
#define GLOW_SAMPLES 8
#define GLOW_DISTANCE 0.05
#define GLOW_POW 1.5
#define GLOW_OPACITY .36

#define sat(a) clamp(a, 0., 1.)
#define PI 3.14159265
#define TAU (PI*2.0)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
float hash11(float seed)
{
    return mod(sin(seed*123.456789)*123.456,1.);
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd+fov*(r*uv.x+u*uv.y));
}

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x)
        return a;
    return b;
}

float _cucube(vec3 p, vec3 s, vec3 th)
{
    vec3 l = abs(p)-s;
    float cube = max(max(l.x, l.y), l.z);
    l = abs(l)-th;
    float x = max(l.y, l.z);
    float y = max(l.x, l.z);
    float z = max(l.x, l.y);
    
    return max(min(min(x, y), z), cube);
}

float _cube(vec3 p, vec3 s)
{
    vec3 l = abs(p)-s;
    return max(l.x, max(l.y, l.z));
}
```
 ## buffer A
 ```glsl
 
float _seed;
float rand()
{
    _seed++;
    return hash11(_seed);
}
float _grid(vec3 p, vec3 sp, float sz)
{
    p = mod(p+sp*.5,sp)-sp*.5;
    return min(length(p.xy)-sz, min(length(p.xz)-sz, length(p.yz)-sz));
}
float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}


float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI*.25);
    p.xy *= r2d(PI*.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI*.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p*3.)*.02;
    diamond = max(diamond, cut);
    diamond += noise(p*5.)*.01;
    return diamond;
}

vec2 map(vec3 p)
{
    vec2 acc = vec2(10000.,-1.);

    float diamond = _diamond(p);
    acc = _min(acc, vec2(diamond, 0.));
    
    return acc;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d)-vec3(map(p-e.xyy).x, map(p-e.yxy).x, map(p-e.yyx).x));
}

vec3 trace(vec3 ro, vec3 rd, int steps)
{
    vec3 p = ro;
    for (int i = 0; i < steps && distance(p, ro) < 50.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
            return vec3(res.x, distance(p, ro), res.y);
        p+=rd*res.x*.5;
    }
    return vec3(-1.);
}

vec3 getEnv(vec3 rd)
{
    return texture(iChannel3, rd*vec3(1.,-1.,1.)).xyz;
}

vec3 getMat(vec3 p, vec3 n, vec3 rd, vec3 res)
{
    // Reflection
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy*.3).x;
    vec3 offset = (vec3(rand(), rand(), rand())-.5)*rough;
    refl = normalize(refl+offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));
    
    
    // Transparency
    float roughtrans = texture(iChannel2, p.xy*5.1).x;
    rd = normalize(rd+((vec3(rand(), rand(), rand())-.5)*.5*roughtrans));
    vec3 transp = vec3(0.);
    vec3 op = p;
    p -= n*0.05;
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = mix(vec3(0.200,0.851,0.655), 
            vec3(0.106,0.294,0.804), 
            texture(iChannel2, p.xy*.2).x)*sat(sat(-p.y+.5)+.3);
            transp = mix(transp, vec3(1.,0.,1.), 1.-exp(-distance(p, op)*0.25));
            break;
        }
        p += rd*dist;
    }
    col += transp;
    return col;
}

vec3 rdr(vec2 uv)
{
    vec3 col = vec3(0.);
    
    float d = 5.;
    float t = iTime*.4;
    vec3 ro = vec3(sin(t)*d,sin(iTime*.33)*d,cos(t)*d);
    vec3 ta = vec3(0.,0.,0.);
    vec3 rd = normalize(ta-ro);
    
    rd = getCam(rd, uv);
    vec3 res = trace(ro, rd, 128);
    float depth = 100.;
    if (res.y > 0.)
    {
        depth = res.y;
        vec3 p = ro+rd*res.y;
        vec3 n = getNorm(p, res.x);
        col = n*.5+.5;
        col = getMat(p, n, rd, res);
    }
    //col = mix(col, vec3(.5), 1.-exp(-depth*0.017));
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 ouv = (fragCoord)/iResolution.xy;
    vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.xx;
    _seed = iTime+texture(iChannel0, uv).x;
    //vec2 off = .75*(vec2(rand(), rand())-.5)*2.*1./iResolution.x;
    vec3 col = rdr(uv);
        col = sat(col);
    vec2 off = vec2(1., -1.)/(iResolution.x*1.5);

    /*if (true)//diff > 0.3) // Not so cheap antialiasing
    {
        //col = vec3(1.,0.,0.);
        vec3 acc = col;
        acc += rdr(uv+off.xx);
        acc += rdr(uv+off.xy);
        acc += rdr(uv+off.yy);
        acc += rdr(uv+off.yx);
        col = acc/5.;
        
    }*/
    //col *= 1.9/(col+1.);
    //col = pow(col, vec3(1.2));
    col = sat(col);
    col = mix(col, texture(iChannel1, fragCoord/iResolution.xy).xyz, .5);
    fragColor = vec4(col,1.0);
}
```
 ## buffer B
 ```glsl
 // This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0
// Unported License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ 
// or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
// =========================================================================================================

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;

    const int steps = GLOW_SAMPLES;
    vec3 col = vec3(0.);
    
    for (int i = 0; i< steps; ++i)
    {
        float f = float(i)/float(steps);
        f = (f -.5)*2.;
        float factor = GLOW_DISTANCE;
        vec2 nuv = uv+vec2(f*factor, 0.);
        col += texture(iChannel0, uv+vec2(f*factor,0.)).xyz/float(steps);
    }
    fragColor = vec4(col,1.0);
}
```
 ## Image
 ```glsl
 // This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0
// Unported License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ 
// or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
// =========================================================================================================

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;

    const int steps = GLOW_SAMPLES;
    vec3 col = vec3(0.);
    
    for (int i = 0; i< steps; ++i)
    {
        float f = float(i)/float(steps);
        f = (f -.5)*2.;
        float factor = GLOW_DISTANCE;
        vec2 nuv = uv+vec2(f*factor, 0.);
        col += texture(iChannel0, uv+vec2(f*factor,0.)).xyz/float(steps);
    }
    fragColor = vec4(col,1.0);
}
```