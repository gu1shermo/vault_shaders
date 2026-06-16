
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

**Notion :** percer des "fenêtres" régulières dans la paroi. On y va en **4 sous-étapes**, chacune copiable telle quelle dans Shadertoy. Les deux premières ne touchent pas à la géométrie : elles **peignent** les grandeurs intermédiaires pour les rendre visibles. Les deux suivantes découpent réellement.

1. **8.1** — replier l'axe Z avec `mod()` → cellules répétées (visualisation)
2. **8.2** — construire `cut = abs(pc.z) - .1` → rondelles tous les 1 m (visualisation)
3. **8.3** — `max(tube, cut)` = intersection → la paroi est percée (fenêtres)
4. **8.4** — `min(cut, p.y + .3)` = sol continu (version finale)

---

### Étape 8.1 — Replier l'axe Z avec `mod` (voir les cellules)

**Notion :** `mod()` ramène un axe infini dans **une seule cellule** de longueur `rep`, répétée à l'infini. On ne coupe rien encore : on **colore** la coordonnée locale de cellule sur la paroi lisse (issue de l'étape 7). On doit voir apparaître des **bandes** qui défilent tous les 1 m.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s) { vec2 l = abs(uv) - s; return max(l.x, l.y); }
vec2 _min(vec2 a, vec2 b) { return (a.x < b.x) ? a : b; }

// Tunnel LISSE de l'étape 7 — aucune découpe pour l'instant
vec2 map(vec3 p)
{
    p.z += iTime * 2.;

    vec3 pt2 = p; pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;
    vec3 pt3 = p; pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));

    vec2 acc = _min(vec2(tube, 1.), vec2(tube2, 2.));
    acc = _min(acc, vec2(tube3, 3.));
    return acc;
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
        float zc = p.z + iTime * 2.;     // MÊME repère que dans map()
        // coordonnée locale de cellule : rampe 0→1 tous les 1 m
        col = vec3(fract(zc));
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : chaque dégradé noir→blanc = une cellule de `mod`. Les centres de cellule (`z` entier) sont là où on placera les rondelles.

---

### Étape 8.2 — Construire `cut` : les rondelles (voir les trous)

**Notion :** `abs(pc.z) - .1` est la SDF d'une **dalle** centrée sur chaque cellule : négative dans une bande de ±0,1 m (la *rondelle*), positive ailleurs (le futur *trou*). Toujours sans couper : on peint en **blanc la matière gardée**, en **noir les trous**. On voit alors des **anneaux** tous les 1 m.

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s) { vec2 l = abs(uv) - s; return max(l.x, l.y); }
vec2 _min(vec2 a, vec2 b) { return (a.x < b.x) ? a : b; }

vec2 map(vec3 p)
{
    p.z += iTime * 2.;

    vec3 pt2 = p; pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;
    vec3 pt3 = p; pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));

    vec2 acc = _min(vec2(tube, 1.), vec2(tube2, 2.));
    acc = _min(acc, vec2(tube3, 3.));
    return acc;
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
        float zc = p.z + iTime * 2.;
        float pcz = mod(zc + .5, 1.) - .5;  // mod CENTRÉ → [-0.5, +0.5]
        float cut = abs(pcz) - .1;          // dalle : <0 dans la rondelle
        col = vec3(step(cut, 0.));          // blanc = gardé, noir = trou
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : les anneaux blancs (0,2 m de large) sont ce qui restera de la paroi ; les bandes noires (0,8 m) deviendront les fenêtres à l'étape suivante.

---

### Étape 8.3 — `max()` = intersection : la paroi est percée

**Notion :** on injecte enfin `cut` dans la géométrie. `max(tube, cut)` = **intersection** (ET booléen sur SDF) : la paroi du tunnel n'existe **que** là où `cut` l'autorise (les rondelles). Entre les rondelles, le rayon traverse → on voit le fond : ce sont les **fenêtres**. ⚠️ Pas encore de sol → il y a des trous sous les pieds (corrigé en 8.4).

```glsl
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s) { vec2 l = abs(uv) - s; return max(l.x, l.y); }
vec2 _min(vec2 a, vec2 b) { return (a.x < b.x) ? a : b; }

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);
    p.z += iTime * 2.;

    vec3 pt2 = p; pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;
    vec3 pt3 = p; pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    // 1) replier Z   2) rondelles
    vec3 pc = p; float rep = 1.;
    pc.z = mod(pc.z + rep * .5, rep) - rep * .5;
    float cut = abs(pc.z) - .1;          // (pas encore de sol)

    float tube = -sqr(p.xy * rot(PI * .25), vec2(1.));

    // 3) intersection : la paroi n'existe QUE dans les rondelles
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
        vec3 L = normalize(vec3(.3, .8, -.3));
        float lambert = max(dot(n, L), 0.) * .7 + .3;
        col = getMat(p, n, res) * lambert;
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : tu traverses une suite d'**arceaux** ; entre eux, du noir (le fond) là où la paroi a été retirée — mais aussi sous toi : c'est le problème que 8.4 règle.

---

### Étape 8.4 — `min()` = ajouter un sol (version finale)

**Notion :** `min(cut, p.y + .3)` = **union** de la zone gardée avec un **plan de sol** (à `y = -0.3`). Résultat : le bas du tunnel reste plein **en continu** entre les rondelles → on ne tombe plus. Bonus : `sin(p.x*100 + p.z*100)*.00005` ajoute un micro-relief gratuit. C'est le shader complet de l'étape 8.

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

> **Rappel SDF :** `min(a,b)` = union (OU), `max(a,b)` = intersection (ET). Toute la découpe de cette étape tient dans ces deux opérations + le pliage `mod`.

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
- roll caméra : `rot(sin(iTime)*.4)` appliqué aux UV → balancement2

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
