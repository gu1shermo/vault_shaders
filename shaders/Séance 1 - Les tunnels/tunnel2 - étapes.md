
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

**Notion :** cette étape introduit **deux idées d'un coup** : la notion d'**`id` de segment** (`floor(p.y / per)`), et la **rotation** appliquée en fonction de cet `id`. On la découpe en **2 sous-étapes** copiables. La première ne touche pas à la géométrie : elle **peint** l'`id` pour le rendre visible. La seconde s'en sert pour tordre le tunnel.

1. **6.1** — `id = floor(p.y / per)` : on **colore** chaque segment selon son index (visualisation)
2. **6.2** — `p.xz *= rot((TAU/6.) * id)` : chaque segment tourne différemment (version finale)

### Étape 6.1 — Visualiser l'`id` des segments

**Notion :** quand on plie l'axe Y avec `mod()` (étape 4), on perd l'information du segment d'origine. `floor(p.y / per)` la récupère : il donne l'**index entier** de la cellule courante (… -1, 0, 1, 2 …). On repart de l'étape 5 (sans rotation) et, au lieu du shading par itérations, on **colorie chaque segment** d'après son `id`. On doit voir des **anneaux de couleurs distinctes** défiler le long du tunnel.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

float SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.; // même défilement qu'à l'étape 5

    float td = -cyl(p.xzy, 10., 1e10);

    float per = 10.;
    p.y = mod(p.y, per) - per*.5; // on replie en cellules de 10 m

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

    vec3 col = vec3(0.);
    if (hit) {
        float per = 10.;
        float py = p.y - dt(1./10.) * 60.;  // MÊME repère que dans SDF()
        float id = floor(py / per);         // index entier du segment touché
        col = .5 + .5*cos(id*1.8 + vec3(0., 2., 4.)); // une couleur par id
        col *= 1. - shad;                   // on garde l'assombrissement de profondeur
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : chaque bande de couleur uniforme = un segment de 10 m, identifié par son `id`. Deux segments voisins ont un `id` qui diffère de 1, donc une couleur différente. C'est exactement cette valeur entière qu'on va injecter dans la rotation à l'étape suivante.

---

### Étape 6.2 — Rotation par segment (version finale)

**Notion :** on multiplie l'angle de rotation par l'`id` : `p.xz *= rot((TAU/6.) * id)`. Le segment 0 ne tourne pas, le segment 1 tourne de 60°, le segment 2 de 120°, etc. → chaque tranche de 10 m est pivotée différemment. Les trous suivent la rotation : **torsion en escalier**. On revient au shading par itérations.

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

**Notion :** cette étape combine **trois idées** pour encadrer chaque fenêtre d'un anneau : un **disque fin** (`cyl`), un **miroir** (`abs(p.z) - 10`) qui le duplique de chaque côté de la paroi, et un **masque** (`max(holes, rings)`) qui creuse le centre du disque pour le transformer en anneau. On découpe en **3 sous-étapes** copiables, chacune partant de l'étape 6.

1. **7.1** — `rings = cyl(p, 1.8, 0.5)` : un disque plein au centre de la cellule (on bouche la fenêtre)
2. **7.2** — `p.z = abs(p.z) - 10.` : le miroir déplace le disque sur la paroi → deux copies à z = ±10
3. **7.3** — `max(holes, rings)` : le trou perce le disque → un vrai anneau qui encadre la fenêtre (version finale)

### Étape 7.1 — Le disque brut

**Notion :** on découvre la brique de base : `cyl(p, 1.8, 0.5)` est un **disque** (cylindre court) de rayon 1.8 et de demi-épaisseur 0.5 le long de z. On l'ajoute au tunnel par `min` (union). Sans miroir ni masque, il se place au **centre de la cellule** (z = 0), pile au milieu de la fenêtre → il la **bouche**. C'est volontaire : on isole d'abord la forme du disque.

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

    float rings = cyl(p, 1.8, 0.5); // disque : rayon 1.8, demi-épaisseur 0.5 sur z
    return min(td, rings);          // union : on ajoute le disque tel quel
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

> 👁️ Lecture : un disque plein apparaît au milieu de chaque fenêtre. On a la forme, pas encore le bon emplacement ni le trou central.

---

### Étape 7.2 — Décaler en miroir avec `abs`

**Notion :** `p.z = abs(p.z) - 10.` est l'**astuce du miroir** : `abs` replie l'axe z sur lui-même, et le `- 10` recentre le résultat sur z = ±10. Une seule formule de disque produit donc **deux copies symétriques**, posées là où la fenêtre traverse la paroi (le tunnel a un rayon de 10). Toujours sans masque : on voit **deux disques pleins** de part et d'autre de chaque ouverture.

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

    p.z = abs(p.z) - 10.;           // miroir : une copie du disque à z = +10 et z = -10
    float rings = cyl(p, 1.8, 0.5);
    return min(td, rings);          // toujours en union : deux disques pleins
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

> 👁️ Lecture : les disques quittent le centre et viennent se plaquer sur la paroi, un de chaque côté de la fenêtre. Il reste à percer leur centre.

---

### Étape 7.3 — Percer le disque → l'anneau (version finale)

**Notion :** au lieu d'unir le disque brut, on l'**intersecte avec `holes`** : `max(holes, rings)`. `holes` est positif partout sauf dans le perçage de rayon 1.5 ; l'intersection garde donc le disque **moins** son centre → un **anneau** de rayon intérieur 1.5 et extérieur 1.8. Combiné au miroir, l'anneau **encadre** exactement la fenêtre de chaque côté.

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

    p.z = abs(p.z) - 10.;              // miroir : deux copies à z = ±10
    float rings = cyl(p, 1.8, 0.5);    // disque rayon 1.8

    return min(td, max(holes, rings)); // max(holes, rings) = disque - trou = anneau
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

**Notion :** on perturbe le rayon du tunnel par une **texture procédurale 2D**. Trois idées s'empilent : la fonction `heightmap()` (`fract` + `abs` + `smoothstep` → un motif périodique lisse), le **dépliage de la paroi en UV** (`atan(p.x, p.z)` pour l'angle, `p.y` pour la hauteur), puis le **déplacement du rayon** du cylindre par cette valeur. On découpe en une **illustration 2D** + **2 sous-étapes** copiables.

1. **illustration** — voir `heightmap()` seule, en 2D plein écran
2. **8.1** — déplier la paroi et **peindre** la heightmap dessus (sans relief)
3. **8.2** — retirer la heightmap au rayon → vrai **relief** (version finale)

	### Illustration 2D de la heightmap (shader à coller dans Shadertoy)

**Notion :** version minimale, sans raymarching. On sort directement `heightmap(uv)` en niveaux de gris. `fract(uv) - .5` **répète** le motif toutes les 1 unité (centré), `abs` le **reflète** dans chaque cellule, `max(uv.x*.5, uv.y*1.)` dessine une croix asymétrique, et `smoothstep(0.2, 0.27, …)` **seuille** le tout en bandes nettes mais lisses.

```glsl
float heightmap(vec2 uv)
{
    uv = fract(uv) - .5;                          // répète le motif, centré sur 0
    uv = abs(uv);                                 // miroir dans chaque cellule
    float pattern = max(uv.x * 0.5, uv.y * 1.0);  // croix asymétrique
    return smoothstep(0.2, 0.27, pattern);        // seuil net → bandes lisses
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.y;  // coords écran (0 en bas-gauche)
    uv *= 4.;                             // zoom : on voit plusieurs cellules

    float h = heightmap(uv);
    fragColor = vec4(vec3(h), 1.);        // on visualise la heightmap en gris
}
```

> 👁️ Lecture : une grille de motifs répétés. Le `smoothstep` rend l'image quasi binaire (noir/blanc) avec des bords adoucis. C'est cette valeur 0→1 qu'on va plaquer sur la paroi, puis convertir en relief.

---

### Étape 8.1 — Déplier la paroi et peindre la heightmap

**Notion :** pour texturer un cylindre, il faut des **coordonnées de paroi**. `atan(p.x, p.z)` donne l'**angle** autour de l'axe du tunnel (de -π à π), et `p.y` donne la **hauteur**. On en fait un `vec2 tuv` qu'on passe à `heightmap()`. Ici on ne touche **pas** à la géométrie (paroi lisse de l'étape 7) : on **peint** seulement la heightmap au point d'impact pour vérifier que le dépliage est correct.

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
    uv = fract(uv) - .5;
    uv = abs(uv);
    float pattern = max(uv.x * 0.5, uv.y * 1.0);
    return smoothstep(0.2, 0.27, pattern);
}

float SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;

    float td = -cyl(p.xzy, 10., 1e10); // rayon CONSTANT : paroi lisse, pas de relief

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

    vec3 col = vec3(0.);
    if (hit) {
        vec3 q = p;
        q.y -= dt(1./10.) * 60.;                          // MÊME repère que dans SDF()
        // UV de paroi. heightmap() répète le motif tous les 1.0 :
        //   atan ∈ [-π,π] → *10  ⇒ ~63 motifs sur tout le tour
        //   q.y en mètres  → *.4 ⇒ 1 motif tous les 2,5 m de hauteur
        vec2 tuv = vec2(atan(q.x, q.z) * 10., q.y * .4);
        float h = heightmap(tuv);
        col = vec3(h) * (1. - shad);                      // on peint la heightmap (sans relief)
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : le motif de la heightmap apparaît **plaqué** sur le tunnel, qui reste géométriquement lisse. On valide ainsi le dépliage UV avant d'en faire du relief.

---

### Étape 8.2 — Transformer la heightmap en relief (version finale)

**Notion :** au lieu de peindre la heightmap, on la **retire au rayon** du cylindre : `10. - heightmap(tuv) * 0.1`. Là où la heightmap vaut 1, le rayon se réduit de 0,1 m → la paroi rentre légèrement ; là où elle vaut 0, rien ne bouge. Le motif devient un vrai **relief** sur le mur.

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

    // UV de paroi. heightmap() répète le motif tous les 1.0 :
    //   atan ∈ [-π,π] → *10  ⇒ ~63 motifs sur tout le tour
    //   p.y en mètres  → *.4 ⇒ 1 motif tous les 2,5 m de hauteur
    vec2 tuv = vec2(atan(p.x, p.z) * 10., p.y * .4);
    float td = -cyl(p.xzy, 10. - heightmap(tuv) * 0.1, 1e10); // rayon déplacé → relief

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

**Notion :** deux gros chantiers ici : (1) un **système de matériaux** pour colorer différemment chaque pièce, et (2) une nouvelle géométrie, les **pipes**, construite par symétrie radiale. On découpe en **4 sous-étapes** copiables.

1. **9.1** — `struct obj { float d; int mat_id; }` : on attache un **identifiant de matériau** à chaque distance (refactor, rendu identique)
2. **9.2** — `pipe()` + `minobj()` : un **seul tube** plaqué contre la paroi, combiné au tunnel
3. **9.3** — `moda(p.xz, 4.)` : symétrie radiale → le pipe est **répété 4 fois** autour
4. **9.4** — `crep(p.z, 0.6, 2.)` : répétition **bornée** le long de Z → grappe de pipes (version finale)

### Étape 9.1 — Le système d'objets (`struct obj`)

**Notion :** jusqu'ici la SDF renvoyait un simple `float`. Pour colorer plusieurs pièces, on renvoie désormais une `struct obj` qui transporte **la distance ET un `mat_id`**. On ne change pas la géométrie (le tunnel de l'étape 8) : on le **refactore** pour qu'il renvoie `obj(td, 1)`, et `mainImage` choisit la couleur selon `mat_id`. Le rendu est identique à l'étape 8 — on installe juste la tuyauterie.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

struct obj { float d; int mat_id; }; // distance + identifiant de matériau

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

    return obj(td, 1); // le tunnel reçoit le matériau n°1
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    return tunnel(p); // un seul objet pour l'instant
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
    obj O;                              // l'impact transporte maintenant un mat_id
    for (float i = 0.; i < ITER; i++) {
        O = SDF(p);
        if (O.d < .001) { hit = true; shad = i / ITER; break; }
        p += rd * O.d;
    }

    vec3 col = vec3(0.);
    if (hit) {
        if (O.mat_id == 1) col = vec3(1.) * (1. - shad); // matériau 1 = blanc
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : image identique à l'étape 8. Le système d'objets est en place mais ne sert pas encore — il attend un second objet.

---

### Étape 9.2 — Un seul pipe + `minobj`

**Notion :** on ajoute une 2e pièce, le **pipe** : `cyl(p.xzy, 0.2, 1e10)` est un tube fin infini le long de Y, auquel on ajoute un **renflement tous les 1 m** (`mod` + petit cylindre). `p.x -= 10.` le plaque contre la paroi (rayon 10). Pour combiner deux objets, on introduit `minobj()` : il compare les distances et **garde le plus proche avec son `mat_id`**. Le pipe reçoit le matériau 2 (rouge).

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

struct obj { float d; int mat_id; };

obj minobj(obj a, obj b) // garde l'objet le plus proche (avec son mat_id)
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
    float pd = cyl(p.xzy, 0.2, 1e10);    // tube fin infini le long de Y
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;         // une cellule de 1 m
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));  // renflement tous les 1 m
    return pd;
}

obj pipes(vec3 p)
{
    p.x -= 10.;                 // on plaque le pipe contre la paroi (rayon 10)
    return obj(pipe(p), 2);     // matériau n°2
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    return minobj(tunnel(p), pipes(p)); // tunnel + pipe : on garde le plus proche
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
        if (O.mat_id == 2) col = vec3(.7, 0., 0.) * (1. - shad); // matériau 2 = rouge
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : un unique tube rouge à renflements court le long du tunnel, collé à la paroi côté +X.

---

### Étape 9.3 — Symétrie radiale avec `moda`

**Notion :** `moda(p.xz, 4.)` replie le plan XZ en **4 secteurs angulaires** identiques autour de l'origine. Du coup l'unique pipe défini dans un secteur est **dupliqué 4 fois** tout autour du tunnel — on n'écrit qu'un seul pipe, le repli s'occupe des copies. Important : `moda` vient **avant** `p.x -= 10.`, pour que le décalage s'applique dans chaque secteur.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define ITER 64.
#define time iTime
#define dt(speed) fract(time*speed)

void moda(inout vec2 p, float rep) // replie le plan en "rep" secteurs identiques
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
    moda(p.xz, 4.);             // 4 secteurs → le pipe est répété 4 fois autour
    p.x -= 10.;                 // plaqué contre la paroi dans chaque secteur
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

> 👁️ Lecture : 4 tubes rouges régulièrement répartis autour du tunnel, un par secteur.

---

### Étape 9.4 — Répétition bornée avec `crep`

**Notion :** `crep` mérite qu'on l'isole, car c'est l'outil qui crée la **grappe de pipes**. On le découpe en une **illustration 2D** + **2 sous-étapes** qui ne diffèrent que d'un mot (`clamp`).

Décortiquons la macro `crep(p,c,l)` → `p = p - c * clamp(round(p/c), -l, l)` :
- `round(p/c)` = **l'index** de la cellule la plus proche (… -1, 0, 1, 2 …)
- `clamp(..., -l, l)` = **borne** cet index à `±l` (c'est lui qui limite la copie)
- `p - c * index` = ramène `p` en **coordonnée locale** dans sa cellule

Sans le `clamp`, on aurait une répétition **infinie** (comme `mod`). Le `clamp` la **borne**.

#### Illustration 2D de `crep` (shader à coller dans Shadertoy)

**Notion :** version minimale, sans raymarching. On applique `crep` à l'axe horizontal et on dessine **une barre par centre de cellule**. On doit voir exactement **5 barres** (les indices -2 à +2), puis plus rien : la répétition est bornée. Retire le `clamp` (passe à `round` seul) et les barres rempliraient tout l'écran.

```glsl
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // axe horizontal centré, "dézoomé" pour voir au-delà des bornes
    float x = (2.*fragCoord.x - iResolution.x) / iResolution.y * 4.;

    float c = 0.6;   // période de répétition
    float l = 2.;    // bornes : ±2 cellules
    crep(x, c, l);   // x devient la coordonnée LOCALE de cellule

    // une barre là où la coord locale ≈ 0 (= un centre de cellule)
    float bar = smoothstep(0.10, 0.07, abs(x));
    fragColor = vec4(vec3(bar), 1.);
}
```

> 👁️ Lecture : 5 barres groupées au centre, puis du noir de chaque côté. Chaque barre = un pipe de la future grappe. Avec `round` seul (sans `clamp`), les barres seraient infinies.

---

#### Étape 9.4.1 — Répétition infinie (sans `clamp`)

**Notion :** on branche d'abord la version **non bornée** : `p = p - c*round(p/c)`, c'est-à-dire la macro `crep` **privée de son `clamp`**. Le pipe est alors copié à l'infini le long de Z, ce qui tapisse toute la profondeur du tunnel de tubes. C'est volontairement trop : on verra à l'étape suivante que `clamp` calme le jeu.

```glsl
#define PI acos(-1.)
#define TAU 6.283185
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)
#define crep(p,c,l) p=p-c*round(p/c) // ⚠️ SANS clamp → répétition INFINIE
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
    float pd = cyl(p.xzy, 0.2, 1e10);    // tube fin infini le long de Y
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;         // une cellule de 1 m
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));  // renflement tous les 1 m
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);             // 4 secteurs → pipe répété 4 fois autour
    p.x -= 10.;                 // plaqué contre la paroi
    crep(p.z, 0.6, 2.);         // SANS clamp : copies infinies le long de Z (le 2. est ignoré)
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

> 👁️ Lecture : des tubes rouges partout le long de chaque secteur, sans interruption. Trop dense — on va le borner.

---

#### Étape 9.4.2 — Bornée avec `clamp` (version finale)

**Notion :** on remet le `clamp(round(p/c), -l, l)` : la copie s'arrête à `±2` cellules. Au lieu d'une rangée infinie, on obtient une **grappe de 5 pipes** (indices -2 à +2) par secteur. Seul mot ajouté par rapport à 9.4.1 : `clamp`.

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
    float pd = cyl(p.xzy, 0.2, 1e10);    // tube fin infini le long de Y
    float per = 1.;
    p.y = mod(p.y, per) - per*.5;         // une cellule de 1 m
    pd = min(pd, cyl(p.xzy, 0.25, 0.1));  // renflement tous les 1 m
    return pd;
}

obj pipes(vec3 p)
{
    moda(p.xz, 4.);             // 4 secteurs → pipe répété 4 fois autour
    p.x -= 10.;                 // plaqué contre la paroi
    crep(p.z, 0.6, 2.);         // 5 copies (±2) espacées de 0.6 le long de Z
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

**Notion :** la plateforme empile plusieurs idées : une nouvelle primitive `box`, sa mise en place **entre les segments**, une **grille de perforations** (`crep` 2D + soustraction booléenne), la macro de symétrie `mo`, et enfin une petite **sphère centrale** (qui servira au glow à l'étape 11). On découpe en **4 sous-étapes** copiables, chacune un changement visible.

1. **10.1** — `box` + placement : une **dalle pleine** entre les segments
2. **10.2** — `crep` grille + `max(-box, …)` : on **perfore** la dalle
3. **10.3** — `mo(p.xz, …)` : symétrie diagonale → réaligne le motif des trous
4. **10.4** — sphère centrale `length(p) - .5` : version finale (prépare le glow)

### Étape 10.1 — La dalle (`box` + placement)

**Notion :** on découvre la primitive `box(p, c)` = SDF d'un **pavé centré** de demi-tailles `c`. On en fait une **dalle** fine (large en X, mince en Y) orientée par `rot(TAU/6.)`, et on la pose comme nouvel objet (matériau 3). Le placement se fait dans `platforms()` : `p.y = mod(p.y - per*.5, per) - per*.5` décale d'une **demi-période** pour poser la dalle **entre** les segments du tunnel (et non sur les fenêtres).

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

float box(vec3 p, vec3 c) // SDF d'un pavé centré, demi-tailles c
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
    p.xz *= rot(TAU/6.);                   // oriente la dalle
    float d = box(p, vec3(10., 0.2, 1.));  // dalle : large en X (10), mince en Y (0.2)
    return d;
}

obj platforms(vec3 p)
{
    float per = 10.;
    p.y = mod(p.y - per*.5, per) - per*.5; // une dalle par cellule, décalée de per/2 (entre les segments)
    return obj(platform(p), 3);
}

obj SDF(vec3 p)
{
    p.y -= dt(1./10.) * 60.;
    obj so = minobj(tunnel(p), pipes(p));
    return minobj(so, platforms(p));       // on ajoute les plateformes
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

> 👁️ Lecture : une plaque pleine traverse le tunnel, posée entre deux fenêtres. Pas encore de trous.

---

### Étape 10.2 — Perforer la dalle (`crep` grille + soustraction)

**Notion :** on creuse une **grille de trous**. `crep(p.xz, 0.3, vec2(30., 2.))` répète un repère tous les 0,3 m, borné à `±30` en X et `±2` en Z (le `l` est ici un `vec2`, une borne par axe). Puis `max(-box(...), d)` **soustrait** un petit pavé à la dalle : `-box` est la SDF du *complément* du pavé, et `max` = intersection → la matière est retirée là où le pavé passe. Combiné à la grille, ça perce une rangée régulière de trous.

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

    float d = box(p, vec3(10., 0.2, 1.));      // dalle pleine

    crep(p.xz, 0.3, vec2(30., 2.));            // grille bornée : ±30 en X, ±2 en Z
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d); // soustraction → un trou par maille

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
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : la dalle est maintenant criblée d'une rangée régulière de trous rectangulaires.

---

### Étape 10.3 — Symétrie diagonale (`mo`)

**Notion :** la macro `mo(uv, d)` → `uv = abs(uv) - d; if (uv.y > uv.x) uv = uv.yx;` enchaîne **deux replis** :
- `abs(uv) - d` = **miroir** sur les deux axes (4 quadrants → 1 quadrant) + petit décalage `d`
- `if (uv.y > uv.x) uv = uv.yx` = **permutation diagonale** (repli sur la bissectrice → 1 octant)

Le résultat est une **symétrie en 8** : tout ce qu'on dessine ensuite (la dalle, la grille de trous) est recopié 8 fois. On le démonte en une **illustration 2D** + **2 sous-étapes**.

#### Illustration 2D de `mo` (shader à coller dans Shadertoy)

**Notion :** version minimale. On dessine **un seul disque décentré**, puis on regarde `mo` le **recopier**. Les deux opérations sont écrites en clair (étapes A et B). Commente la ligne B : le disque n'apparaît plus que **4 fois** (miroir seul). Remets-la : il apparaît **8 fois** (la diagonale ajoute le repli supplémentaire).

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord - iResolution.xy) / iResolution.y; // centré sur l'écran

    vec2 q = uv;
    q = abs(q) - vec2(.2, .1);   // A : miroir sur X et Y (+ décalage d)
    if (q.y > q.x) q = q.yx;     // B : permutation diagonale (commente pour comparer)

    // un disque test, placé dans le repère replié
    float disk = length(q - vec2(.5, .3)) - .12;
    vec3 col = (disk < 0.) ? vec3(1.) : vec3(.08);

    // repères : on trace les deux axes en jaune
    col = mix(col, vec3(.4, .4, .0), smoothstep(.006, .0, abs(uv.x)));
    col = mix(col, vec3(.4, .4, .0), smoothstep(.006, .0, abs(uv.y)));

    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : un disque dessiné une seule fois apparaît répété symétriquement. `abs` fait les 4 quadrants, la permutation diagonale double encore → 8 copies. C'est ce repère symétrique que la plateforme utilise pour sa grille de trous.

---

#### Étape 10.3.1 — Le miroir seul (`abs - d`)

**Notion :** on n'applique d'abord que la **première moitié** de `mo` : `p.xz = abs(p.xz) - vec2(.2, .1)`. Le `abs` replie les 4 quadrants du plan XZ sur un seul → la dalle et ses trous deviennent **symétriques par rapport aux deux axes**, mais sans encore le repli diagonal.

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

    p.xz = abs(p.xz) - vec2(.2, .1);          // mo, MOITIÉ A : miroir seul (pas de diagonale)

    float d = box(p, vec3(10., 0.2, 1.));

    crep(p.xz, 0.3, vec2(30., 2.));
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d);

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
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : la grille de trous devient symétrique par rapport au centre, mais le motif n'est pas encore replié sur sa diagonale.

---

#### Étape 10.3.2 — + permutation diagonale (= `mo` complet)

**Notion :** on ajoute la **seconde moitié** : `if (p.z > p.x) p.xz = p.zx`, qui revient à utiliser la macro `mo` complète. Ce repli diagonal échange X et Z au-dessus de la bissectrice → le motif gagne sa symétrie en 8. C'est exactement l'étape 10.3 d'origine.

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

    mo(p.xz, vec2(.2, .1));                    // miroir + permutation diagonale

    float d = box(p, vec3(10., 0.2, 1.));

    crep(p.xz, 0.3, vec2(30., 2.));
    d = max(-box(p, vec3(0.11, 0.5, 0.1)), d);

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
    fragColor = vec4(col, 1.);
}
```

> 👁️ Lecture : le motif de trous devient symétrique et se réaligne. C'est le repère mis en place par `mo` avant la grille.

---

### Étape 10.4 — La sphère centrale (version finale)

**Notion :** on ajoute une petite **sphère** `s = length(p) - .5` au centre de chaque plateforme, fusionnée par `min(d, s)`. Pour l'instant elle n'est qu'un détail géométrique, mais on la calcule **avant** `mo` (sur le `p` non replié) car elle servira de **source de glow** à l'étape 11.

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
