
# Tunnel raymarché — décomposition en 10 étapes

Chaque étape contient un shader **complet** copiable tel quel dans Shadertoy. On part d'un écran vide et on arrive au shader final, en ajoutant **une notion par étape**.

---

## Étape 1 — UV normalisées centrées

**Notion :** transformer les pixels en coordonnées centrées sur l'écran, indépendantes de la résolution. R = X, G = Y.

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 col = vec3(uv, 0.);

    fragColor = vec4(col, 1.);
}
```

---

## Étape 2 — Raymarching d'une sphère

**Notion :** sphere tracing. `map()` = SDF (signed distance function), `trace()` avance le long du rayon par bonds égaux à la distance signée.

```glsl
float map(vec3 p)
{
    // Sphère de rayon 0.5 placée 2 unités devant la caméra
    return length(p - vec3(0., 0., 2.)) - .5;
}

float trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 128.; ++i) {
        float d = map(p);
        if (d < .001) return distance(ro, p);
        p += rd * d;
    }
    return -1.;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., 0.);
    vec3 rd = normalize(vec3(uv, 1.));

    float d = trace(ro, rd);
    vec3 col = (d > 0.) ? vec3(1.) : vec3(0.);

    fragColor = vec4(col, 1.);
}
```

---

## Étape 3 — De la sphère au tunnel (SDF carré inversée)

**Notion :** `sqr()` est une SDF de carré 2D. On l'extrude implicitement selon Z (map ne dépend que de `p.xy`). Le signe inversé met l'intérieur "plein" → on est *dans* le tunnel. `rot(PI*.25)` tourne la section de 45°.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

float map(vec3 p)
{
    return -sqr(p.xy * rot(PI * .25), vec2(1.));
}

float trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 128.; ++i) {
        float d = map(p);
        if (d < .001) return distance(ro, p);
        p += rd * d;
    }
    return -1.;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    float d = trace(ro, rd);
    // Profondeur → couleur (plus c'est loin, plus c'est sombre)
    vec3 col = (d > 0.) ? vec3(1. - d * .05) : vec3(0.);

    fragColor = vec4(col, 1.);
}
```

---

## Étape 4 — Faire défiler le tunnel (animation)

**Notion :** au lieu de bouger la caméra, on bouge le monde dans `map()` avec `iTime`. Visuellement équivalent, plus simple à coder.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

float map(vec3 p)
{
    p.z += iTime * 2.;  // défilement
    return -sqr(p.xy * rot(PI * .25), vec2(1.));
}

float trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 128.; ++i) {
        float d = map(p);
        if (d < .001) return distance(ro, p);
        p += rd * d;
    }
    return -1.;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    float d = trace(ro, rd);
    vec3 col = (d > 0.) ? vec3(1. - d * .05) : vec3(0.);

    fragColor = vec4(col, 1.);
}
```

---

## Étape 5 — Normales par gradient

**Notion :** la normale d'une SDF = son gradient. On l'approche par différences finies sur un epsilon. On l'affiche en couleur (`n*.5+.5` pour passer de [-1,1] à [0,1]).

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

float map(vec3 p)
{
    p.z += iTime * 2.;
    return -sqr(p.xy * rot(PI * .25), vec2(1.));
}

vec3 getNorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(map(p)) - vec3(
        map(p - e.xyy),
        map(p - e.yxy),
        map(p - e.yyx)
    ));
}

float trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 128.; ++i) {
        float d = map(p);
        if (d < .001) return distance(ro, p);
        p += rd * d;
    }
    return -1.;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    float d = trace(ro, rd);
    vec3 col = vec3(0.);
    if (d > 0.) {
        vec3 p = ro + rd * d;
        vec3 n = getNorm(p);
        col = n * .5 + .5;
    }

    fragColor = vec4(col, 1.);
}
```

---

## Étape 6 — Système de matériaux (map retourne vec2)

**Notion :** `map()` renvoie maintenant `vec2(distance, matID)`. `_min` compare la distance et garde l'ID du plus proche. `getMat()` traduit ID → couleur. On prépare le terrain pour ajouter plein d'objets différents.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

vec2 _min(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

vec2 map(vec3 p)
{
    p.z += iTime * 2.;
    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));
    return vec2(tube, 1.);  // matID 1 = tunnel
}

vec3 getMat(vec3 p, vec3 n, vec2 res)
{
    if (res.y == 1.) return vec3(.30, .35, .45);   // tunnel (assez clair pour qu'on voie la géométrie)
    if (res.y == 2.) return vec3(.239, .259, .780); // bleu (futur)
    if (res.y == 3.) return vec3(1., 0., 0.);       // rouge (futur)
    return vec3(0.);
}

vec3 getNorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(map(p).x) - vec3(
        map(p - e.xyy).x,
        map(p - e.yxy).x,
        map(p - e.yyx).x
    ));
}

vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 128.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    vec2 res = trace(ro, rd);
    vec3 col = vec3(0.);
    if (res.x > 0.) {
        vec3 p = ro + rd * res.x;
        vec3 n = getNorm(p);
        // Lambert basique pour rendre la géométrie lisible
        vec3 L = normalize(vec3(.3, .8, -.3));
        float lambert = max(dot(n, L), 0.) * .7 + .3;
        col = getMat(p, n, res) * lambert;
    }

    fragColor = vec4(col, 1.);
}
```

---

## Étape 7 — Câbles en spirale (domain warping)

**Notion :** deux fins tubes qui s'enroulent en hélice autour de l'axe. Astuce : tourner XY en fonction de Z (`rot(p.z)`) avant de mesurer une distance à un point fixe → trajectoire hélicoïdale.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

vec2 _min(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);

    p.z += iTime * 2.;

    // Câble 1 : hélice
    vec3 pt2 = p;
    pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;

    // Câble 2 : même hélice, décalée de 2.4 rad
    vec3 pt3 = p;
    pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));

    acc = _min(vec2(tube, 1.), vec2(tube2, 2.));
    acc = _min(acc, vec2(tube3, 3.));
    return acc;
}

vec3 getMat(vec3 p, vec3 n, vec2 res)
{
    if (res.y == 1.) return vec3(.30, .35, .45);
    if (res.y == 2.) return vec3(.239, .259, .780);
    if (res.y == 3.) return vec3(1., 0., 0.);
    return vec3(0.);
}

vec3 getNorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(map(p).x) - vec3(
        map(p - e.xyy).x,
        map(p - e.yxy).x,
        map(p - e.yyx).x
    ));
}

vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 256.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    vec2 res = trace(ro, rd);
    vec3 col = vec3(0.);
    if (res.x > 0.) {
        vec3 p = ro + rd * res.x;
        vec3 n = getNorm(p);
        // Lambert basique pour rendre la géométrie lisible
        vec3 L = normalize(vec3(.3, .8, -.3));
        float lambert = max(dot(n, L), 0.) * .7 + .3;
        col = getMat(p, n, res) * lambert;
    }

    fragColor = vec4(col, 1.);
}
```

---

## Étape 8 — Découper le tunnel (répétition modulaire + intersection)

**Notion :** des "fenêtres" régulières dans la paroi.

1. répéter Z avec `mod()` → bandes infinies tous les `rep` mètres
2. intersecter le tunnel avec ces bandes via `max()` (= AND booléen sur SDF)
3. garder un sol en intersectant avec `p.y + .3`

Bonus : on perturbe la surface avec un `sin(p.x*100)` pour un micro-relief gratuit.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

vec2 _min(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);

    p.z += iTime * 2.;

    vec3 pt2 = p;
    pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;

    vec3 pt3 = p;
    pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    // Répétition Z : on plie l'axe en cellules de longueur rep
    vec3 pc = p;
    float rep = 1.;
    pc.z = mod(pc.z + rep * .5, rep) - rep * .5;

    // Bandes verticales fines + sol
    float cut = abs(pc.z) - .1;
    cut = min(cut, p.y + .3);

    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));
    tube -= sin(p.x * 100. + p.z * 100.) * .00005; // micro-relief

    // Intersection : on ne garde le tunnel QUE là où cut est valide
    vec2 tube_m1 = vec2(max(tube, cut), 1.);

    acc = _min(tube_m1, vec2(tube2, 2.));
    acc = _min(acc, vec2(tube3, 3.));
    return acc;
}

vec3 getMat(vec3 p, vec3 n, vec2 res)
{
    if (res.y == 1.) return vec3(.30, .35, .45);
    if (res.y == 2.) return vec3(.239, .259, .780);
    if (res.y == 3.) return vec3(1., 0., 0.);
    return vec3(0.);
}

vec3 getNorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(map(p).x) - vec3(
        map(p - e.xyy).x,
        map(p - e.yxy).x,
        map(p - e.yyx).x
    ));
}

vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    for (float i = 0.; i < 256.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    vec2 res = trace(ro, rd);
    vec3 col = vec3(0.);
    if (res.x > 0.) {
        vec3 p = ro + rd * res.x;
        vec3 n = getNorm(p);
        // Lambert basique pour rendre la géométrie lisible
        vec3 L = normalize(vec3(.3, .8, -.3));
        float lambert = max(dot(n, L), 0.) * .7 + .3;
        col = getMat(p, n, res) * lambert;
    }

    fragColor = vec4(col, 1.);
}
```

---

## Étape 9 — Glow par accumulation le long du rayon

**Notion :** à chaque pas du sphere tracing, le rayon "frôle" plus ou moins les surfaces. Si `dist.x` est petit → on est proche → on accumule un peu de la couleur du matériau le plus proche. Au final on obtient un faux volumetric / glow gratuit. Stocké dans la globale `accCol`.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv) - s;
    return max(l.x, l.y);
}

vec2 _min(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);

    p.z += iTime * 2.;

    vec3 pt2 = p;
    pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;

    vec3 pt3 = p;
    pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    vec3 pc = p;
    float rep = 1.;
    pc.z = mod(pc.z + rep * .5, rep) - rep * .5;

    float cut = abs(pc.z) - .1;
    cut = min(cut, p.y + .3);

    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));
    tube -= sin(p.x * 100. + p.z * 100.) * .00005;

    vec2 tube_m1 = vec2(max(tube, cut), 1.);
    acc = _min(tube_m1, vec2(tube2, 2.));
    acc = _min(acc, vec2(tube3, 3.));
    return acc;
}

vec3 getMat(vec3 p, vec3 n, vec2 res)
{
    if (res.y == 1.) return vec3(.30, .35, .45);
    if (res.y == 2.) return vec3(.239, .259, .780);
    if (res.y == 3.) return vec3(1., 0., 0.);
    return vec3(0.);
}

vec3 getNorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(map(p).x) - vec3(
        map(p - e.xyy).x,
        map(p - e.yxy).x,
        map(p - e.yyx).x
    ));
}

// /!\ globale lue après l'appel à trace()
vec3 accCol;

vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;
    accCol = vec3(0.);
    for (float i = 0.; i < 512.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
        // Plus on frôle un objet (d.x petit), plus on cumule sa couleur
        accCol += getMat(p, vec3(0.), d) * (1. - sat(d.x / .5)) * .05;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    vec2 res = trace(ro, rd);
    vec3 col = vec3(0.);
    if (res.x > 0.) {
        vec3 p = ro + rd * res.x;
        vec3 n = getNorm(p);
        // Lambert basique pour rendre la géométrie lisible
        vec3 L = normalize(vec3(.3, .8, -.3));
        float lambert = max(dot(n, L), 0.) * .7 + .3;
        col = getMat(p, n, res) * lambert;
    }
    col += accCol; // glow ajouté en post

    fragColor = vec4(col, 1.);
}
```

---

## Étape 10 — FINAL : courbure, réflexions, brouillard, roll caméra

**Notions finales :**
- `offset(z)` décale XY selon Z → le tunnel ondule en S
- `ro` suit l'offset inverse → la caméra reste centrée dans le tunnel
- réflexion : un second `trace()` depuis le point d'impact
- brouillard : `mix` vers une couleur violette pondéré par `exp(-dist)`
- roll caméra : `rot(sin(iTime)*.4)` appliqué aux UV → balancement

Ce code = le shader original.

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

---

## Récap des concepts par étape

| # | Concept clé |
|---|---|
| 1 | UV normalisées |
| 2 | Sphere tracing (SDF + boucle) |
| 3 | Inversion intérieur/extérieur, SDF carré |
| 4 | Animation par transformation de l'espace |
| 5 | Normales par gradient |
| 6 | IDs matériaux (`vec2` retour de map) |
| 7 | Domain warping → spirales |
| 8 | Répétition `mod` + intersection `max` |
| 9 | Glow par accumulation |
| 10 | Courbure, réflexions, brouillard, roll caméra |
