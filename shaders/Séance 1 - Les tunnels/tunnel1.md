
```glsl
// Fork of "Tunnel raymarching glow" by avgilles. https://shadertoy.com/view/WXs3Df
// 2026-03-25 05:11:02

#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a+vec4(0., 11., 33. ,0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv)-s;
    return max(l.x, l.y);
}

vec2 offset(float z)
{
    return vec2(sin(z*.1), 0.);
}

vec2 _min(vec2 a, vec2 b)
{
    if(a.x < b.x)
        return a;
    return b;
}


vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);


    p.z += iTime *2.; 
    p.xy += offset(p.z);
    
    vec3 pt2 = p;
    pt2.xy *= rot(pt2.z*1.);
    float tube2 = length(pt2.xy-vec2(0., .5))-.05;
    
    vec3 pt3 = p;
    pt3.xy *= rot(pt2.z*1.+2.4);
    float tube3 = length(pt3.xy-vec2(0., .5))-.05;
    
    vec3 pc = p;
    float rep = 1.;
    pc.z = mod(pc.z+rep*.5, rep)-rep*.5;
    
    float cut = abs(pc.z)-.1;
    cut = min(cut, p.y+.3);
    
    
    float tube = -sqr(p.xy*rot(PI*.25), vec2(1.));
    tube -= sin(p.x*100. + p.z*100.)*.00005;
    //return length(p)-.1;
    vec2 tube_m1 = vec2(max(tube, cut), 1.);
    acc = _min(tube_m1, vec2(tube2, 2.));
    //return min(min(, tube2), tube3);
    acc = _min(acc, vec2(tube3, 3.));
    
    return acc;
}

vec3 getNorm(vec3 p){
    vec2 e = vec2(0.001, 0.);
    return normalize(
        //vec3(map(p+e.xyy), map(p+e.yxy), map(p+e.yyx))-
        vec3(map(p).x)-
        vec3(map(p-e.xyy).x,map(p-e.yxy).x, map(p-e.yyx).x)
        
        );

}

vec3 getMat(vec3 p, vec3 n, vec2 res)
{
    vec3 col = vec3(0.);
    
    if (res.y == 1.)
        col = vec3(0.000,0.000,0.000);
    
    if (res.y == 3.)
        col = vec3(1.,  0. , 0. );
    
    
    if (res.y == 2.)
        col = vec3(0.239,0.259,0.780);
    return col;
}

vec3 accCol;
vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    accCol = vec3(0.);
    for (float i=.0; i<512.;++i){
            vec2 dist = map(p);

            if (dist.x <.001)
            {
                return vec2(distance(ro, p), dist.y);
            }
            p += rd*dist.x;
            accCol += getMat(p,vec3(0.), dist)*(1.-sat(dist.x / 0.5))*.05;
        }
        return vec2(-1., -1.);
}




vec3 render(vec2 uv){

    vec3 col = vec3(0.);
    
    vec3 ro = vec3(offset(-iTime*2.),  -.5);
    vec3 rd = normalize(vec3(uv, 1.));
    vec3 p = ro;

    vec2 dist = trace(ro, rd);
    float true_dist = 10.;
    if (dist.x >.0){
    
        true_dist = dist.x;
        p = ro + rd*dist.x;
        vec3 acc1 = accCol;
        
        

        vec3 n = getNorm(p);
        col  = n*.5+.5;
        
        col = getMat(p, n, dist);
        
        vec3 refl = reflect(rd, n);
        vec3 rorefl = p + n * 0.01;
        vec2 resrefl = trace(rorefl, refl); 
        if (resrefl.x > 0.)
        {
            vec3 prefl = rorefl + refl * resrefl.x;
            vec3 nref1 = getNorm(prefl);
            col += getMat(prefl, nref1, resrefl);
            col += acc1;
            
        }
    }
    col += accCol;
    col += mix(col, vec3(0.384,0.192,0.667), exp(-true_dist *.1)) * .5;
    return col;

}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (fragCoord-.5 * iResolution.xy)/iResolution.xx;

    // Time varying pixel color
    vec3 col = render(uv *rot(sin(iTime)*.4));

    // Output to screen
    fragColor = vec4(col,1.0);
}
```