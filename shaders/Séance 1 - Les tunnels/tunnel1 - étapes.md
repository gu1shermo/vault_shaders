
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

### Illustration 2D du `mod` + `abs` (shader à coller dans Shadertoy)

**Notion :** la version minimale. On applique `mod` puis `abs` à `uv.x` et on sort `cut` directement dans le canal rouge. On voit des **bandes répétées** : `mod` crée la répétition, `abs` fait le motif en V dans chaque cellule.

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;     // coords écran 0..1

    vec2 uvc = uv;
    float rep = 0.5;                          // période de répétition
    // mod centré : ramène uvc.x dans [-rep/2, +rep/2], répété tous les "rep"
    uvc.x = mod(uvc.x + rep * .5, rep) - rep * .5;

    float cut = abs(uvc.x);                   // abs -> 0 au centre, max aux bords

    fragColor = vec4(cut, 0., 0., 1.0);       // on visualise cut dans le rouge
}
```

**Comment lire l'image :** chaque cellule de largeur `rep = 0.5` montre le même dégradé rouge — **noir au centre** (`uvc.x = 0`, donc `abs = 0`) et **rouge aux bords** (`abs` maximal). C'est exactement `mod` (la répétition) + `abs` (le V), isolés. Le `- .1` du vrai shader décalerait ce dégradé pour créer le seuil de la « rondelle ».

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

## Étape 10 — Finitions : courbure, roll, réflexions, brouillard

Cette dernière étape empilait **4 notions** d'un coup. On les sépare en **4 sous-étapes**, chacune un shader complet copiable. On repart de l'étape 9 (avec le glow) et on ajoute **une notion à la fois**.

1. **10.1** — `offset(z)` : le tunnel **ondule** (et la caméra suit pour rester centrée)
2. **10.2** — **roll caméra** : balancement par `rot(sin(iTime))` appliqué aux UV
3. **10.3** — **réflexions** : un 2e `trace()` lancé depuis le point d'impact
4. **10.4** — **brouillard** : fondu vers le violet par `exp(-dist)` (= shader original)

---

### Étape 10.1 — Courbure : le tunnel ondule

**Notion :** on ajoute `offset(z) = vec2(sin(z*.1), 0.)` et, dans `map`, `p.xy += offset(p.z)` : tout l'espace est décalé latéralement selon Z → le tunnel **serpente en S**. Pour ne pas se cogner aux parois, la caméra `ro` suit la même courbe (`ro.xy = offset(-iTime*2.)`), donc elle reste **au centre** du tunnel.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s) { vec2 l = abs(uv) - s; return max(l.x, l.y); }
vec2 _min(vec2 a, vec2 b) { return (a.x < b.x) ? a : b; }

// NOUVEAU : décalage XY en fonction de Z -> le tunnel ondule
vec2 offset(float z) { return vec2(sin(z * .1), 0.); }

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);

    p.z += iTime * 2.;
    p.xy += offset(p.z);          // NOUVEAU : on courbe l'espace selon Z

    vec3 pt2 = p; pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;
    vec3 pt3 = p; pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    vec3 pc = p; float rep = 1.;
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
        map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 accCol;
vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro; accCol = vec3(0.);
    for (float i = 0.; i < 512.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
        accCol += getMat(p, vec3(0.), d) * (1. - sat(d.x / .5)) * .05;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;

    // NOUVEAU : la caméra suit la courbe -> elle reste au centre du tunnel
    vec3 ro = vec3(offset(-iTime * 2.), -.5);
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
    col += accCol;
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : le couloir n'est plus rectiligne, il ondule doucement de gauche à droite, mais tu restes toujours au milieu.

---

### Étape 10.2 — Roll caméra (balancement)

**Notion :** une seule ligne, dans `mainImage` : `uv *= rot(sin(iTime) * .4)`. On fait **tourner les UV** autour du centre de l'écran → l'image tangue (roll) au rythme de `sin(iTime)`, comme un roulis. C'est purement caméra : la géométrie ne change pas.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s) { vec2 l = abs(uv) - s; return max(l.x, l.y); }
vec2 _min(vec2 a, vec2 b) { return (a.x < b.x) ? a : b; }

vec2 offset(float z) { return vec2(sin(z * .1), 0.); }

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);

    p.z += iTime * 2.;
    p.xy += offset(p.z);

    vec3 pt2 = p; pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;
    vec3 pt3 = p; pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    vec3 pc = p; float rep = 1.;
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
        map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 accCol;
vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro; accCol = vec3(0.);
    for (float i = 0.; i < 512.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
        accCol += getMat(p, vec3(0.), d) * (1. - sat(d.x / .5)) * .05;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;
    uv *= rot(sin(iTime) * .4);   // NOUVEAU : roll (balancement) de la caméra

    vec3 ro = vec3(offset(-iTime * 2.), -.5);
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
    col += accCol;
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : l'horizon penche d'un côté puis de l'autre — l'image roule comme une caméra à l'épaule.

---

### Étape 10.3 — Réflexions (second rayon)

**Notion :** au point d'impact `p`, on calcule la direction **réfléchie** `reflect(rd, n)` et on relance un `trace()` depuis `p` (légèrement décollé par `+ n*.01` pour ne pas se toucher soi-même). La couleur trouvée par ce 2e rayon est **ajoutée** → les parois renvoient un reflet des objets voisins. ⚠️ `trace()` réécrit la globale `accCol` : on **sauvegarde** le glow du rayon primaire dans `acc1` avant de relancer.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a + vec4(0., 11., 33., 0.)))
#define PI 3.1415

float sqr(vec2 uv, vec2 s) { vec2 l = abs(uv) - s; return max(l.x, l.y); }
vec2 _min(vec2 a, vec2 b) { return (a.x < b.x) ? a : b; }

vec2 offset(float z) { return vec2(sin(z * .1), 0.); }

vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);

    p.z += iTime * 2.;
    p.xy += offset(p.z);

    vec3 pt2 = p; pt2.xy *= rot(pt2.z);
    float tube2 = length(pt2.xy - vec2(0., .5)) - .05;
    vec3 pt3 = p; pt3.xy *= rot(pt2.z + 2.4);
    float tube3 = length(pt3.xy - vec2(0., .5)) - .05;

    vec3 pc = p; float rep = 1.;
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
        map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 accCol;
vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro; accCol = vec3(0.);
    for (float i = 0.; i < 512.; ++i) {
        vec2 d = map(p);
        if (d.x < .001) return vec2(distance(ro, p), d.y);
        p += rd * d.x;
        accCol += getMat(p, vec3(0.), d) * (1. - sat(d.x / .5)) * .05;
    }
    return vec2(-1., -1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.xx;
    uv *= rot(sin(iTime) * .4);

    vec3 ro = vec3(offset(-iTime * 2.), -.5);
    vec3 rd = normalize(vec3(uv, 1.));

    vec2 res = trace(ro, rd);
    vec3 col = vec3(0.);
    if (res.x > 0.) {
        vec3 p = ro + rd * res.x;
        vec3 acc1 = accCol;               // on sauve le glow du rayon primaire
        vec3 n = getNorm(p);
        vec3 L = normalize(vec3(.3, .8, -.3));
        float lambert = max(dot(n, L), 0.) * .7 + .3;
        col = getMat(p, n, res) * lambert;

        // NOUVEAU : réflexion = 2e trace depuis le point d'impact
        vec3 refl = reflect(rd, n);
        vec3 rorefl = p + n * .01;         // décollé de la surface
        vec2 resr = trace(rorefl, refl);
        if (resr.x > 0.) {
            vec3 pr = rorefl + refl * resr.x;
            col += getMat(pr, getNorm(pr), resr) * .5;  // couleur du reflet
            col += acc1;                                // glow primaire restauré
        }
    }
    col += accCol;                         // glow du dernier rayon tracé
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : les facettes du tunnel se renvoient mutuellement des taches de couleur (le bleu des câbles, le rouge…).

---

### Étape 10.4 — Brouillard (version finale = shader original)

**Notion :** dernière touche, le **brouillard** : on mélange la couleur vers un violet par `mix(col, violet, exp(-dist*.1))` → plus un point est loin, plus il se fond dans la brume. C'est le shader original complet (structure `render()`, légèrement différente des sous-étapes mais équivalente).

Ce code = le shader original.

```glsl
// Fork of "Tunnel raymarching glow" by avgilles. https://shadertoy.com/view/WXs3Df
// 2026-03-25 05:11:02

#define sat(a) clamp(a, 0., 1.)                       // raccourci clamp [0,1]
#define rot(a) mat2(cos(a+vec4(0., 11., 33. ,0.)))    // matrice de rotation 2D (astuce vec4)
#define PI 3.1415

// SDF d'un carré (box 2D) de demi-taille s : <0 dedans, 0 sur le bord, >0 dehors
float sqr(vec2 uv, vec2 s)
{
    vec2 l = abs(uv)-s;
    return max(l.x, l.y);
}

// Décalage latéral du tunnel selon Z -> il ondule en S
vec2 offset(float z)
{
    return vec2(sin(z*.1), 0.);
}

// Union de deux SDF taggées (distance, id) : on garde la plus proche
vec2 _min(vec2 a, vec2 b)
{
    if(a.x < b.x)
        return a;
    return b;
}


// Carte de la scène : renvoie (distance signée, id matériau) au point p
vec2 map(vec3 p)
{
    vec2 acc = vec2(1000., -1.);                 // accumulateur : très loin, aucun id

    p.z += iTime *2.;                            // on avance dans le tunnel avec le temps
    p.xy += offset(p.z);                         // courbure : décale XY selon Z

    vec3 pt2 = p;                                // copie pour le câble 1
    pt2.xy *= rot(pt2.z*1.);                      // vrille la section selon Z -> spirale
    float tube2 = length(pt2.xy-vec2(0., .5))-.05; // cylindre fin (rayon .05) décentré

    vec3 pt3 = p;                                // copie pour le câble 2
    pt3.xy *= rot(pt2.z*1.+2.4);                  // même vrille, déphasée de 2.4 rad
    float tube3 = length(pt3.xy-vec2(0., .5))-.05; // 2e câble en spirale

    vec3 pc = p;                                 // copie pour la découpe
    float rep = 1.;                              // période de répétition (1 m)
    pc.z = mod(pc.z+rep*.5, rep)-rep*.5;          // mod centré -> cellules répétées en Z

    float cut = abs(pc.z)-.1;                     // "rondelle" : dalle gardée de ±.1
    cut = min(cut, p.y+.3);                       // union avec le plan de sol (y=-.3)


    float tube = -sqr(p.xy*rot(PI*.25), vec2(1.)); // tube : carré tourné 45°, signe inversé (on est dedans)
    tube -= sin(p.x*100. + p.z*100.)*.00005;       // micro-relief cosmétique sur la paroi
    //return length(p)-.1;                          // (debug : une simple sphère)
    vec2 tube_m1 = vec2(max(tube, cut), 1.);       // intersection paroi ∩ découpe -> id 1
    acc = _min(tube_m1, vec2(tube2, 2.));          // ajoute le câble 1 (id 2)
    //return min(min(, tube2), tube3);              // (ancienne version)
    acc = _min(acc, vec2(tube3, 3.));              // ajoute le câble 2 (id 3)

    return acc;
}

// Normale par gradient : différences finies de la SDF autour de p
vec3 getNorm(vec3 p){
    vec2 e = vec2(0.001, 0.);                      // pas d'échantillonnage
    return normalize(
        //vec3(map(p+e.xyy), map(p+e.yxy), map(p+e.yyx))-  // (variante centrée)
        vec3(map(p).x)-                            // distance au centre
        vec3(map(p-e.xyy).x,map(p-e.yxy).x, map(p-e.yyx).x) // moins distances décalées en x,y,z

        );

}

// Couleur de base selon l'id matériau
vec3 getMat(vec3 p, vec3 n, vec2 res)
{
    vec3 col = vec3(0.);

    if (res.y == 1.)                              // paroi du tunnel
        col = vec3(0.000,0.000,0.000);            // noire (n'apparaît que via glow/reflet)

    if (res.y == 3.)                              // câble 2
        col = vec3(1.,  0. , 0. );                // rouge

    if (res.y == 2.)                              // câble 1
        col = vec3(0.239,0.259,0.780);            // bleu
    return col;
}

vec3 accCol;                                       // glow accumulé (globale, lue après trace)
// Sphere tracing : avance le long du rayon, renvoie (distance, id) au 1er contact
vec2 trace(vec3 ro, vec3 rd)
{
    vec3 p = ro;                                   // on part de l'origine du rayon
    accCol = vec3(0.);                             // reset du glow à chaque trace
    for (float i=.0; i<512.;++i){                  // jusqu'à 512 pas
            vec2 dist = map(p);                    // distance à la scène

            if (dist.x <.001)                      // assez proche -> on a touché
            {
                return vec2(distance(ro, p), dist.y); // (distance parcourue, id)
            }
            p += rd*dist.x;                        // sinon on avance de "dist" (pas sûr)
            accCol += getMat(p,vec3(0.), dist)*(1.-sat(dist.x / 0.5))*.05; // glow : + on frôle, + on cumule
        }
        return vec2(-1., -1.);                     // rien touché
}




// Rendu d'un rayon écran (uv) -> couleur
vec3 render(vec2 uv){

    vec3 col = vec3(0.);                            // couleur de départ (fond)

    vec3 ro = vec3(offset(-iTime*2.),  -.5);        // caméra : suit la courbe pour rester centrée
    vec3 rd = normalize(vec3(uv, 1.));              // direction du rayon (vers +Z)
    vec3 p = ro;

    vec2 dist = trace(ro, rd);                      // 1er rayon : la géométrie
    float true_dist = 10.;                          // distance par défaut (rayon dans le vide)
    if (dist.x >.0){                                // si on a touché quelque chose

        true_dist = dist.x;                         // mémorise la profondeur (pour le brouillard)
        p = ro + rd*dist.x;                         // point d'impact
        vec3 acc1 = accCol;                         // on SAUVE le glow du rayon primaire (trace va l'écraser)



        vec3 n = getNorm(p);                        // normale au point
        col  = n*.5+.5;                             // (debug : normales en couleur, écrasé juste après)

        col = getMat(p, n, dist);                   // couleur de base du matériau touché

        vec3 refl = reflect(rd, n);                 // direction réfléchie
        vec3 rorefl = p + n * 0.01;                 // décollée de la surface (anti auto-contact)
        vec2 resrefl = trace(rorefl, refl);         // 2e rayon : la réflexion
        if (resrefl.x > 0.)                         // si le reflet touche un objet
        {
            vec3 prefl = rorefl + refl * resrefl.x; // point touché par le reflet
            vec3 nref1 = getNorm(prefl);            // sa normale
            col += getMat(prefl, nref1, resrefl);   // + couleur du reflet
            col += acc1;                            // + glow primaire restauré

        }
    }
    col += accCol;                                  // + glow du dernier rayon tracé

    // --- BROUILLARD ---
    // t = exp(-d*.1) : poids de distance. t=1 tout PRÈS, t->0 au LOIN (true_dist=10 si rien touché).
    // mix(col, violet, t) = col*(1-t) + violet*t.
    // Comme on fait "+= ... * .5", on développe en :
    //   col_final = col*(1 + .5*(1-t))  +  .5*t*violet
    //   -> PRÈS (t=1) : forte teinte violette ;  LOIN (t=0) : col éclairci x1.5, sans violet.
    col += mix(col, vec3(0.384,0.192,0.667), exp(-true_dist *.1)) * .5;
    return col;

}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // UV centrées et normalisées (aspect ratio préservé via .xx)
    vec2 uv = (fragCoord-.5 * iResolution.xy)/iResolution.xx;

    // Roll caméra : on fait tourner les UV au rythme de sin(iTime)
    vec3 col = render(uv *rot(sin(iTime)*.4));

    // Sortie écran
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
