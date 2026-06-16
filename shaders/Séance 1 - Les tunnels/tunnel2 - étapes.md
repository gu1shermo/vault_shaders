
# Tunnel 2 — décomposition en 15 étapes

Chaque étape contient un shader **complet** copiable tel quel dans Shadertoy. On part de zéro et on arrive au shader original en ajoutant **une notion par étape**.

---

## Étape 1 — Caméra look-at + visualisation des rayons

**Notion :** caméra "look-at" via 3 vecteurs orthonormés (forward / left / up). On affiche `rd` en couleur pour vérifier l'orientation.

```glsl
#define PI acos(-1.)
#define TAU 6.283185

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    fragColor = vec4(rd*.5 + .5, 1.);
}
```

---

## Étape 2 — Raymarching d'un cylindre solide

**Notion :** la macro `cyl(p, r, h)` est la SDF d'un cylindre fini (intersection d'un disque et d'une dalle). On l'oriente sur l'axe Y en passant `p.xzy` (swizzle = permutation des composantes). Vue de l'extérieur.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)

float SDF(vec3 p)
{
    return cyl(p.xzy, 2., 4.); // rayon 2, hauteur ±4 sur Y
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(8., 4., 8.);
    vec3 rd = getcam(ro, vec3(0., 0., 0.), uv);

    vec3 p = ro;
    float t = -1.;
    for (float i = 0.; i < 64.; i++) {
        float d = SDF(p);
        if (d < .001) { t = distance(ro, p); break; }
        p += rd * d;
    }

    vec3 col = (t > 0.) ? vec3(1. - t * .05) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 3 — Tunnel intérieur + iter shading

**Notions :**
- on **inverse le signe** de la SDF → l'intérieur du cylindre devient "plein" pour le raymarcher, donc le rayon heurte la paroi vue depuis l'intérieur ;
- la caméra est placée à l'intérieur (`ro = (0,0,3)`) et regarde vers le bas du tunnel ;
- **shading par nombre d'itérations** : plus le rayon rame avant de converger, plus le pixel est sombre. C'est un faux AO gratuit qui révèle les coins.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.

float SDF(vec3 p)
{
    return -cyl(p.xzy, 10., 1e10);
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    for (float i = 0.; i < ITER; i++) {
        float d = SDF(p);
        if (d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * d;
    }

    vec3 col = hit ? vec3(1. - shad) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 4 — Trous percés dans la paroi

**Notion :** différence booléenne entre deux SDF.

1. on plie l'axe Y avec `mod()` → on travaille dans une cellule de 10m
2. cylindre traversant (axe Z) inversé
3. `max(holes, td)` creuse le tunnel là où le cylindre passe

Sans rotation par segment, tous les trous sont alignés sur la même verticale → effet "fenêtres en colonne".

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.

float SDF(vec3 p)
{
    float td = -cyl(p.xzy, 10., 1e10);

    float per = 10.;
    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);

    return max(holes, td);
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    for (float i = 0.; i < ITER; i++) {
        float d = SDF(p);
        if (d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * d;
    }

    vec3 col = hit ? vec3(1. - shad) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 5 — Animation : on s'enfonce dans le tunnel

**Notion :** au lieu de bouger la caméra, on **bouge le monde** dans la SDF avec `p.y -= dt(speed) * 60.`.

`dt(speed)` = `fract(time*speed)` → onde en dents de scie qui revient brutalement à 0. La période vaut `1/speed` secondes ; multiplié par 60, le décalage va de 0 à 60. Comme `60 = 6 × per` (la période du tunnel = 10), le saut est invisible : on a un défilement infini parfaitement loopé.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.

#define time iTime
#define dt(speed) fract(time*speed)

float SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.; // animation : on s'enfonce dans le tunnel

    float td = -cyl(p.xzy, 10., 1e10);

    float per = 10.;
    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);
    return max(holes, td);
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    for (float i = 0.; i < ITER; i++) {
        float d = SDF(p);
        if (d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * d;
    }

    vec3 col = hit ? vec3(1. - shad) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 6 — Rotation par segment (torsion progressive)

**Notion :** `floor(p.y / per)` donne l'**index** du segment courant. On tourne XZ d'un angle proportionnel à cet `id` → chaque tranche de 10m est pivotée différemment. Les trous suivent la rotation : torsion en escalier.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

float SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;

    float td = -cyl(p.xzy, 10., 1e10);

    float per = 10.;
    float id  = floor(p.y / per);

    p.xz *= rot((TAU/6.) * id); // chaque segment tourne différemment

    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);
    return max(holes, td);
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    for (float i = 0.; i < ITER; i++) {
        float d = SDF(p);
        if (d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * d;
    }

    vec3 col = hit ? vec3(1. - shad) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 7 — Anneaux autour des trous

**Notion :** `abs(p.z) - 10` crée **deux zones miroir** autour du centre de la cellule. Dans ces zones on dessine un fin disque (`cyl` rayon 1.8, hauteur 0.5). `max(holes, rings)` ne garde l'anneau que là où le trou existe → l'anneau encadre la fenêtre.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

float SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;

    float td = -cyl(p.xzy, 10., 1e10);

    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);

    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);

    return min(td, max(holes, rings));
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    for (float i = 0.; i < ITER; i++) {
        float d = SDF(p);
        if (d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * d;
    }

    vec3 col = hit ? vec3(1. - shad) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 8 — Heightmap procédurale sur la paroi

**Notion :** on perturbe le rayon du tunnel par une **texture procédurale 2D**. On déroule la paroi en UV (`atan(p.x, p.z)` pour l'angle, `p.y` pour la hauteur), puis on évalue une `heightmap()` à base de `fract` + `abs` + `smoothstep` qui produit un motif périodique lisse. On retire ce déplacement au rayon du cylindre → le mur a un léger relief.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;     // tile sur [-.5, .5]
    uv = abs(uv);            // miroir
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

float SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;

    // UV de paroi : angle * échelle, hauteur * échelle
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);

    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);

    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);

    return min(td, max(holes, rings));
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    for (float i = 0.; i < ITER; i++) {
        float d = SDF(p);
        if (d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * d;
    }

    vec3 col = hit ? vec3(1. - shad) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 9 — Système d'objets (struct obj) + pipes radiaux

**Notion :** pour avoir plusieurs matériaux, `struct obj { float d; int mat_id; }`. `minobj()` compare les distances et garde l'objet le plus proche **avec son ID**.

Pipes par symétrie radiale :
- `moda(p.xz, 4.)` → 4 secteurs angulaires repliés sur l'origine (un seul pipe répété 4 fois)
- `p.x -= 10.` → décale le pipe contre la paroi
- `crep(p.z, 0.6, 2.)` → répétition **bornée** (limitée à ±2 cellules)

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

void moda(inout vec2 p, float rep)
{
    float per = TAU / rep;
    float a = mod(atan(p.y, p.x), per) - per*.5;
    p = vec2(cos(a), sin(a)) * length(p);
}

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b)
{
    if (a.d < b.d) return a;
    return b;
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);

    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);

    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);
    td = min(td, max(holes, rings));

    return obj(td, 1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy, 0.2, 1e10);
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x -= 10.;
    crep(p.z, 0.6, 2.);
    return obj(pipe(p), 2);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    return minobj(tunnel(p), pipes(p));
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    obj O;
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        if (O.mat_id == 1) col = vec3(1.) * (1. - shad);
        if (O.mat_id == 2) col = vec3(.7, 0., 0.) * (1. - shad);
    }
    fragColor = vec4(col, 1.);
}
```

---

## Étape 10 — Plateformes perforées

**Notion :** plateforme = grosse boîte fine + petite sphère centrale + grille de trous.
- `mo(p.xz, vec2(.2,.1))` → symétrie miroir + permutation diagonale
- `box(p, c)` SDF de pavé centré
- `crep(p.xz, 0.3, vec2(30.,2.))` → grille répétée bornée
- `max(-box(...), d)` → soustraction booléenne (perforations)
- on ajoute aussi une petite sphère `length(p) - .5` au centre (sera utilisée à l'étape suivante pour le glow)

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

void moda(inout vec2 p, float rep)
{
    float per = TAU / rep;
    float a = mod(atan(p.y, p.x), per) - per*.5;
    p = vec2(cos(a), sin(a)) * length(p);
}

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b)
{
    if (a.d < b.d) return a;
    return b;
}

float box(vec3 p, vec3 c)
{
    vec3 q = abs(p) - c;
    return min(0., max(q.x, max(q.y, q.z))) + length(max(q, 0.));
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);

    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;

    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);

    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);
    td = min(td, max(holes, rings));

    return obj(td, 1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy, 0.2, 1e10);
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x -= 10.;
    crep(p.z, 0.6, 2.);
    return obj(pipe(p), 2);
}

float platform(vec3 p)
{
    p.xz *= rot(TAU/6.);

    float s = length(p) - .5;          // sphère centrale (servira au glow)

    mo(p.xz, vec2(.2, .1));            // symétrie diagonale

    float d = box(p, vec3(10., 0.2, 1.));   // dalle horizontale

    crep(p.xz, 0.3, vec2(30., 2.));         // grille bornée
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d); // perforations

    d = min(d, s);                          // ajoute la sphère
    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*.5, per) - per*.5; // décalage per/2 → entre les segments
    return obj(platform(p), 3);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    obj so = minobj(tunnel(p), pipes(p));
    return minobj(so, platforms(p));
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    obj O;
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        if (O.mat_id == 1) col = vec3(1.) * (1. - shad);
        if (O.mat_id == 2) col = vec3(.7, 0., 0.) * (1. - shad);
        if (O.mat_id == 3) col = vec3(.9, .1, .1) * (1. - shad);
    }
    fragColor = vec4(col, 1.);
}
```

---

## Étape 11 — Glow vert au centre des plateformes

**Notion :** **faux volumetric glow par accumulation**. La fonction `platform()` est appelée à chaque pas du raymarching ; on profite de cette boucle pour cumuler dans une variable globale `g1` une contribution `0.1 / (0.1 + s²)` où `s` est la distance à une petite sphère centrale. Plus le rayon frôle la sphère, plus `g1` grimpe. À la fin on ajoute `g1 * couleur_glow` à l'image.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

void moda(inout vec2 p, float rep)
{
    float per = TAU / rep;
    float a = mod(atan(p.y, p.x), per) - per*.5;
    p = vec2(cos(a), sin(a)) * length(p);
}

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b) { if (a.d < b.d) return a; return b; }

float box(vec3 p, vec3 c)
{
    vec3 q = abs(p) - c;
    return min(0., max(q.x, max(q.y, q.z))) + length(max(q, 0.));
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);
    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;
    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);
    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);
    td = min(td, max(holes, rings));
    return obj(td, 1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy, 0.2, 1e10);
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x -= 10.;
    crep(p.z, 0.6, 2.);
    return obj(pipe(p), 2);
}

float g1 = 0.; // accumulateur de glow

float platform(vec3 p)
{
    p.xz *= rot(TAU/6.);

    float s = length(p) - .5;
    g1 += 0.1 / (0.1 + s*s);  // accumulation : plus on frôle la sphère, plus ça brille

    mo(p.xz, vec2(.2, .1));
    float d = box(p, vec3(10., 0.2, 1.));
    crep(p.xz, 0.3, vec2(30., 2.));
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d);
    d = min(d, s);
    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*.5, per) - per*.5;
    return obj(platform(p), 3);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    obj so = minobj(tunnel(p), pipes(p));
    return minobj(so, platforms(p));
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    obj O;
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        if (O.mat_id == 1) col = vec3(1.) * (1. - shad);
        if (O.mat_id == 2) col = vec3(.7, 0., 0.) * (1. - shad);
        if (O.mat_id == 3) col = vec3(.9, .1, .1) * (1. - shad);
    }
    col += g1 * vec3(0.1, 0.8, 0.2); // glow vert ajouté en post
    fragColor = vec4(col, 1.);
}
```

---

## Étape 12 — Tore + roundpipes (anneaux radiaux)

**Notion :** combinaison `torus + moda(18) + cylindre` :
- `torus(p, vec2(R, r))` → anneau circulaire (R = rayon principal, r = épaisseur)
- `moda(p.xz, 18.)` → 18 secteurs angulaires → 18 petites bornes le long de l'anneau
- `min(torus, cyl)` → l'anneau et les bornes fusionnés en une seule SDF

Répétition tous les 15m → période différente du tunnel pour casser la régularité.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

void moda(inout vec2 p, float rep)
{
    float per = TAU / rep;
    float a = mod(atan(p.y, p.x), per) - per*.5;
    p = vec2(cos(a), sin(a)) * length(p);
}

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b) { if (a.d < b.d) return a; return b; }

float box(vec3 p, vec3 c)
{
    vec3 q = abs(p) - c;
    return min(0., max(q.x, max(q.y, q.z))) + length(max(q, 0.));
}

float torus(vec3 p, vec2 t)
{
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);
    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;
    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);
    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);
    td = min(td, max(holes, rings));
    return obj(td, 1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy, 0.2, 1e10);
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x -= 10.;
    crep(p.z, 0.6, 2.);
    return obj(pipe(p), 2);
}

float g1 = 0.;

float platform(vec3 p)
{
    p.xz *= rot(TAU/6.);
    float s = length(p) - .5;
    g1 += 0.1 / (0.1 + s*s);
    mo(p.xz, vec2(.2, .1));
    float d = box(p, vec3(10., 0.2, 1.));
    crep(p.xz, 0.3, vec2(30., 2.));
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d);
    d = min(d, s);
    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*.5, per) - per*.5;
    return obj(platform(p), 3);
}

float roundpipe(vec3 p)
{
    float rpd = torus(p, vec2(10., .2));   // anneau collé à la paroi
    moda(p.xz, 18.);                        // 18 bornes le long
    p.x -= 10.;
    float bumpd = cyl(p, 0.25, 0.1);
    return min(rpd, bumpd);
}

obj roundpipes(vec3 p)
{
    float per = 15.;
    p.y = mod(p.y, per) - per*.5;
    return obj(roundpipe(p), 4);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    obj so = minobj(tunnel(p), pipes(p));
    so = minobj(so, platforms(p));
    so = minobj(so, roundpipes(p));
    return so;
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    obj O;
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        if (O.mat_id == 1) col = vec3(1.) * (1. - shad);
        if (O.mat_id == 2) col = vec3(.7, 0., 0.) * (1. - shad);
        if (O.mat_id == 3) col = vec3(.9, .1, .1) * (1. - shad);
        if (O.mat_id == 4) col = vec3(.9, .4, 0.) * (1. - shad);
    }
    col += g1 * vec3(0.1, 0.8, 0.2);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 13 — Normales + Ambient Occlusion

**Notion :**
- **Normales** : gradient de la SDF par différences finies.
- **AO multi-échelle** : on échantillonne la SDF à plusieurs pas dans la direction de la normale. Si la SDF retourne moins que le pas, c'est qu'il y a de la géométrie proche → zone occluse (sombre). La somme à plusieurs échelles donne un effet doux qui assombrit coins et jonctions.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define ITER 128.
#define time iTime
#define dt(speed) fract(time*speed)

void moda(inout vec2 p, float rep)
{
    float per = TAU / rep;
    float a = mod(atan(p.y, p.x), per) - per*.5;
    p = vec2(cos(a), sin(a)) * length(p);
}

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b) { if (a.d < b.d) return a; return b; }

float box(vec3 p, vec3 c)
{
    vec3 q = abs(p) - c;
    return min(0., max(q.x, max(q.y, q.z))) + length(max(q, 0.));
}

float torus(vec3 p, vec2 t)
{
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);
    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;
    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);
    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);
    td = min(td, max(holes, rings));
    return obj(td, 1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy, 0.2, 1e10);
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x -= 10.;
    crep(p.z, 0.6, 2.);
    return obj(pipe(p), 2);
}

float g1 = 0.;

float platform(vec3 p)
{
    p.xz *= rot(TAU/6.);
    float s = length(p) - .5;
    g1 += 0.1 / (0.1 + s*s);
    mo(p.xz, vec2(.2, .1));
    float d = box(p, vec3(10., 0.2, 1.));
    crep(p.xz, 0.3, vec2(30., 2.));
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d);
    d = min(d, s);
    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*.5, per) - per*.5;
    return obj(platform(p), 3);
}

float roundpipe(vec3 p)
{
    float rpd = torus(p, vec2(10., .2));
    moda(p.xz, 18.);
    p.x -= 10.;
    return min(rpd, cyl(p, 0.25, 0.1));
}

obj roundpipes(vec3 p)
{
    float per = 15.;
    p.y = mod(p.y, per) - per*.5;
    return obj(roundpipe(p), 4);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    obj so = minobj(tunnel(p), pipes(p));
    so = minobj(so, platforms(p));
    so = minobj(so, roundpipes(p));
    return so;
}

vec3 getnorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(
        SDF(p+e.xyy).d - SDF(p-e.xyy).d,
        SDF(p+e.yxy).d - SDF(p-e.yxy).d,
        SDF(p+e.yyx).d - SDF(p-e.yyx).d
    ));
}

float AO(float eps, vec3 n, vec3 p)
{
    return SDF(p + eps*n).d / eps;
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    obj O;
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .0001) { hit = true; shad = i / ITER; break; }
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        vec3 n = getnorm(p);
        float ao = AO(0.5, n, p) + AO(0.25, n, p) + AO(0.125, n, p);

        if (O.mat_id == 1) col = vec3(1.);
        if (O.mat_id == 2) col = vec3(.7, 0., 0.);
        if (O.mat_id == 3) col = vec3(.9, .1, .1);
        if (O.mat_id == 4) col = vec3(.9, .4, 0.);
        col *= (1. - shad);
        col *= ao / 3.;
    }
    col += g1 * vec3(0.1, 0.8, 0.2);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 14 — Dither pour casser le banding

**Notion :** quand tous les rayons font des pas synchronisés (la SDF), les artefacts d'échantillonnage forment des **bandes** régulières visibles. Astuce : on **multiplie chaque pas par un nombre pseudo-aléatoire par pixel** (`hash21(uv)`). Les rayons avancent désormais à des cadences différentes → le banding se transforme en **grain stochastique**, beaucoup plus naturel à l'œil.

`hash21` est un hash trigonométrique rapide qui retourne `[0, 1]` pour un `vec2`.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define ITER 128.
#define time iTime
#define dt(speed) fract(time*speed)
#define hash21(x) fract(sin(dot(x, vec2(12.4,33.8)))*1247.4)

void moda(inout vec2 p, float rep)
{
    float per = TAU / rep;
    float a = mod(atan(p.y, p.x), per) - per*.5;
    p = vec2(cos(a), sin(a)) * length(p);
}

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b) { if (a.d < b.d) return a; return b; }

float box(vec3 p, vec3 c)
{
    vec3 q = abs(p) - c;
    return min(0., max(q.x, max(q.y, q.z))) + length(max(q, 0.));
}

float torus(vec3 p, vec2 t)
{
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10);
    float per = 10.;
    float id  = floor(p.y / per);
    p.xz *= rot((TAU/6.) * id);
    p.y = mod(p.y, per) - per*.5;
    float holes = -cyl(p, 1.5, 25.);
    td = max(holes, td);
    p.z = abs(p.z) - 10.;
    float rings = cyl(p, 1.8, 0.5);
    td = min(td, max(holes, rings));
    return obj(td, 1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy, 0.2, 1e10);
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x -= 10.;
    crep(p.z, 0.6, 2.);
    return obj(pipe(p), 2);
}

float g1 = 0.;

float platform(vec3 p)
{
    p.xz *= rot(TAU/6.);
    float s = length(p) - .5;
    g1 += 0.1 / (0.1 + s*s);
    mo(p.xz, vec2(.2, .1));
    float d = box(p, vec3(10., 0.2, 1.));
    crep(p.xz, 0.3, vec2(30., 2.));
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d);
    d = min(d, s);
    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*.5, per) - per*.5;
    return obj(platform(p), 3);
}

float roundpipe(vec3 p)
{
    float rpd = torus(p, vec2(10., .2));
    moda(p.xz, 18.);
    p.x -= 10.;
    return min(rpd, cyl(p, 0.25, 0.1));
}

obj roundpipes(vec3 p)
{
    float per = 15.;
    p.y = mod(p.y, per) - per*.5;
    return obj(roundpipe(p), 4);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    obj so = minobj(tunnel(p), pipes(p));
    so = minobj(so, platforms(p));
    so = minobj(so, roundpipes(p));
    return so;
}

vec3 getnorm(vec3 p)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(
        SDF(p+e.xyy).d - SDF(p-e.xyy).d,
        SDF(p+e.yxy).d - SDF(p-e.yxy).d,
        SDF(p+e.yyx).d - SDF(p-e.yyx).d
    ));
}

float AO(float eps, vec3 n, vec3 p) { return SDF(p+eps*n).d / eps; }

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta - ro);
    vec3 l = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = normalize(cross(f, l));
    return normalize(f + l*uv.x + u*uv.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;
    float dither = hash21(uv);

    vec3 ro = vec3(0., 0., 3.);
    vec3 rd = getcam(ro, vec3(0., -10., 0.), uv);

    vec3 p = ro;
    bool hit = false;
    float shad = 0.;
    obj O;
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .0001) { hit = true; shad = i / ITER; break; }
        // Pas multiplié par un bruit blanc → casse le banding
        O.d *= dither * 0.8;
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        vec3 n = getnorm(p);
        float ao = AO(0.5, n, p) + AO(0.25, n, p) + AO(0.125, n, p);
        if (O.mat_id == 1) col = vec3(1.);
        if (O.mat_id == 2) col = vec3(.7, 0., 0.);
        if (O.mat_id == 3) col = vec3(.9, .1, .1);
        if (O.mat_id == 4) col = vec3(.9, .4, 0.);
        col *= (1. - shad);
        col *= ao / 3.;
    }
    col += g1 * vec3(0.1, 0.8, 0.2);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 15 — FINAL : fog atmosphérique

**Notion :** fog exponentiel quadratique `1 - exp(-k * t²)` qui tire les couleurs lointaines vers une teinte gris-bleu foncé. Le glow vert s'ajoute *par-dessus* le fog → il reste visible même dans les zones brumeuses.

Ce code = le shader original.

```glsl
// Fork of "[esgi] pipe14" by hrst4. https://shadertoy.com/view/NfjGD1
// 2026-03-20 03:22:01
// (forks antérieurs omis pour la clarté)

// ============================================================================
// Shader raymarching : tunnel avec pipes répétés
// Basé sur une technique SDF (Signed Distance Field)
// ============================================================================

#define PI acos(-1.)
#define TAU 6.283185

#define time iTime
#define dt(speed) fract(time*speed)

#define ITER 128.

#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)
#define hash21(x) fract(sin(dot(x, vec2(12.4,33.8)))*1247.4)

struct obj
{
    float d;
    int mat_id;
};

void moda(inout vec2 p, float rep)
{
    float per = TAU/rep;
    float a = mod(atan(p.y,p.x), per)-per*.5;
    p = vec2(cos(a), sin(a))*length(p);
}

obj minobj(obj a, obj b)
{
    if(a.d<b.d) return a;
    else return b;
}

float box(vec3 p, vec3 c)
{
    vec3 q = abs(p)-c;
    return min(0.,max(q.x,max(q.y,q.z))) + length(max(q,0.));
}

float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

obj tunnel(vec3 p)
{
    vec2 tuv = vec2(atan(p.x,p.z)*10., p.y*.4);
    float td = -cyl(p.xzy,10.0-heightmap(tuv*1.)*0.1,1e10);

    float per = 10.;
    float id = floor(p.y/per);

    p.xz *= rot((TAU/6.)*(id+.0));

    p.y = mod(p.y,per)-per*.5;

    float holes = -cyl(p,1.5,25.);

    td = max(holes, td);

    p.z = abs(p.z)-10.;

    float rings = cyl(p,1.8,0.5);

    td = min(td, max(holes, rings));

    return obj(td,1);
}

float pipe(vec3 p)
{
    float pd = cyl(p.xzy,0.2,1e10);
    float per = 1.;
    p.y = mod(p.y, per)-per*.5;
    pd = min(pd, cyl(p.xzy, 0.25,0.1));
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);
    p.x-=10.;
    crep(p.z,0.6,2.);
    float psd = pipe(p);
    return obj(psd,2);
}

float g1=0.;

float platform(vec3 p)
{
    p.xz *= rot(TAU/6.);

    float s = length(p)-.5;

    g1 += 0.1/(0.1+s*s);

    mo(p.xz, vec2(.2,.1));

    float d = box(p, vec3(10.,0.2,1.));

    crep(p.xz, 0.3, vec2(30.,2.));

    d = max(-box(p, vec3(0.11,0.5,0.1)), d);

    d = min(d,s);

    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*0.5, per) - per*0.5;
    float pld = platform(p);
    return obj(pld,3);
}

float torus(vec3 p, vec2 t)
{
    vec2 q = vec2(length(p.xz)-t.x, p.y);
    return length(q)-t.y;
}

float roundpipe(vec3 p)
{
    float rpd = torus(p, vec2(10., .2));

    moda(p.xz, 18.);

    p.x -= 10.;

    float pipe = cyl(p, 0.25, 0.1);

    rpd = min(rpd, pipe);

    return rpd;
}

obj roundpipes(vec3 p)
{
    float per = 15.;
    p.y = mod(p.y, per) - per * .5;
    return obj(roundpipe(p), 4);
}

obj SDF(vec3 p)
{
    p.y-=dt(1./10.)*60.;
    obj so =  minobj(tunnel(p), pipes(p));
    so = minobj(so, platforms(p));
    so = minobj(so, roundpipes(p));
    return so;
}

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    vec3 f = normalize(ta-ro);
    vec3 l = normalize(cross(vec3(0.,1.,0.), f));
    vec3 u = normalize(cross(f,l));
    return normalize(f+l*uv.x+u*uv.y);
}

vec3 getnorm(vec3 p)
{
    vec2 e = vec2(0.001,0.);
    return normalize(vec3(
        SDF(p+e.xyy).d - SDF(p-e.xyy).d,
        SDF(p+e.yxy).d - SDF(p-e.yxy).d,
        SDF(p+e.yyx).d - SDF(p-e.yyx).d
    ));
}

float AO(float eps, vec3 n, vec3 p)
{
    return SDF(p+eps*n).d/eps;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord.xy-iResolution.xy)/iResolution.y;

    float dither = hash21(uv);

    vec3 ro = vec3(.00,.00,3.);
    vec3 rd = getcam(ro, vec3(0.,-10.,0.), uv);
    vec3 p = ro;

    vec3 col = vec3(0.);

    float shad;
    bool hit =false;
    obj O;

    for(float i=0.;i<ITER;i++)
    {
        O = SDF(p);
        if(O.d<0.0001)
        {
            hit = true;
            shad = i/ITER;
            break;
        }
        O.d *=0.+dither*0.8;
        p+= rd*O.d;
    }

    float t = length(ro-p);

    if(hit)
    {
        vec3 n = getnorm(p);

        float ao = AO(0.5,n,p) +AO(0.25,n,p)+AO(0.125,n,p);

        if(O.mat_id == 1) col = vec3(1.);
        if(O.mat_id == 2) col = vec3(.7,.0,.0) ;
        if(O.mat_id == 3) col = vec3(.9,.1,.1) ;
        if(O.mat_id == 4) col = vec3(.9,.4,.0) ;
        col *= (1. - shad);

        col *= ao/3.;
    }

    // Fog atmosphérique + glow vert ajouté par-dessus
    col = mix(col, vec3(.0,.05,.1), 1.-exp(-0.001*t*t));
    col += g1*vec3(0.1,0.8,0.2);

    fragColor = vec4(col,1.0);
}
```

---

## Récap des concepts par étape

| # | Concept clé |
|---|---|
| 1 | Caméra look-at (forward / left / up) |
| 2 | SDF cylindre + swizzle d'axe (`p.xzy`) |
| 3 | Inversion intérieur/extérieur, iter shading |
| 4 | Différence booléenne (`max`) + répétition `mod` |
| 5 | **Animation** par défilement `p.y -= dt*60` (loop seamless) |
| 6 | Domain warping par segment (`floor` + `rot`) |
| 7 | Symétrie `abs()` + intersection conditionnelle |
| 8 | Heightmap procédurale (UV de paroi par `atan`) |
| 9 | `struct obj`, `moda` radiale, `crep` bornée |
| 10 | Plateformes : `box` + `mo` + perforations par soustraction |
| 11 | **Glow par accumulation** dans variable globale |
| 12 | Tore + composition `moda + cyl` (anneaux radiaux) |
| 13 | Normales par gradient + AO multi-échelle |
| 14 | Dither stochastique du raymarching (anti-banding) |
| 15 | Fog atmosphérique quadratique + glow par-dessus |
