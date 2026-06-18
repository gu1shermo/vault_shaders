
# Refract diamant — décomposition en 15 étapes

Chaque étape contient un shader **complet** copiable tel quel dans Shadertoy. On part d'un fond uni et on arrive à un diamant raymarché, glossy + réfractant + absorbant, éclairé par une cubemap, post-processé en feedback temporel et flou directionnel.



> ⚠️ **Channels Shadertoy** (à binder au fur et à mesure des étapes) :
> - **iChannel0** : `Noise Medium` (utilisé pour le `_seed` à partir de l'étape 11, et comme source du blur post à l'étape 15)
> - **iChannel1** : la passe **Image** elle-même (feedback) — étape 14
> - **iChannel2** : `Noise Medium` (réutilisé comme roughness map) — étape 10
> - **iChannel3** : `Cubemap` (par ex. `Forest Blurred`, `Uffizi Gallery`, `Basilica`) — étape 8
>
> Le multi-pass n'apparaît qu'à l'étape 14. Avant ça, tout tient en passe **Image** seule, sans `Common` — pour copier-coller direct.

---

## Étape 1 — Caméra "look-at" : ro, ta, base orthonormée

**Notion :** jusqu'ici on calculait `rd` directement à partir des UV (`normalize(vec3(uv, 1.))`). Limite immédiate : la caméra regarde toujours `+z`. Pour orbiter, cadrer un point précis ou animer un travelling, on construit une **caméra look-at** :
- `ro` (ray origin) = position de la caméra dans le monde.
- `ta` (target) = point regardé.
- `forward = normalize(ta - ro)`.
- `right = normalize(cross(forward, worldUp))`.
- `up = normalize(cross(forward, right))` (recalculé pour rester orthogonal).

Les UV deviennent les coordonnées **dans ce repère** : `rd = normalize(forward + fov * (right * uv.x + up * uv.y))`.

```glsl
#define PI 3.14159265

// Construit la direction du rayon pour une caméra qui regarde "rd"
// rd : direction "forward" déjà calculée (= normalize(ta - ro))
// uv : coords écran centrées (~ -1..1 sur la verticale)
vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;                                   // facteur d'ouverture (plus grand = + télé, + petit = + grand-angle)
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));  // axe "droite" : ⊥ à forward et au worldUp
    vec3 u = normalize(cross(rd, r));                 // axe "haut" caméra : ⊥ à forward et à right
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(3., 2., -3.);   // caméra placée en arrière-haut
    vec3 ta = vec3(0., 0., 0.);    // regarde l'origine
    vec3 rd = normalize(ta - ro);  // forward

    rd = getCam(rd, uv);

    // Visualisation : on affiche la direction du rayon comme couleur (debug)
    fragColor = vec4(rd * 0.5 + 0.5, 1.);
}
```

> **À retenir :** l'ordre des `cross` détermine la chiralité. Si vous obtenez l'image inversée gauche-droite, échangez les arguments du premier `cross`. Le `fov = 1.` est un raccourci ; pour une vraie ouverture en degrés, prenez `fov = tan(radians(angle) * 0.5)`.

> **Cas dégénéré :** si `forward` est colinéaire à `worldUp` (caméra qui regarde droit en haut/bas), `cross` renvoie `vec3(0)` → division par zéro après `normalize`. Pas géré ici ; en prod on chooserait dynamiquement un `worldUp` non colinéaire.

---

## Étape 2 — Caméra orbitale animée

**Notion :** on anime maintenant `ro` sur une orbite autour de l'origine. `(sin(t)*d, h, cos(t)*d)` trace un cercle horizontal de rayon `d`. On ajoute une oscillation verticale **à fréquence différente** pour que la trajectoire ne se referme jamais → animation infinie sans répétition perçue (figure de Lissajous).

```glsl
#define PI 3.14159265

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5.;                              // rayon d'orbite
    float t = iTime * 0.4;                     // vitesse de rotation horizontale
    vec3 ro = vec3(
        sin(t) * d,                            // x : orbite
        sin(iTime * 0.33) * d,                 // y : oscillation verticale (fréq différente)
        cos(t) * d                             // z : orbite
    );
    vec3 ta = vec3(0.);
    vec3 rd = normalize(ta - ro);

    rd = getCam(rd, uv);

    fragColor = vec4(rd * 0.5 + 0.5, 1.);
}
```

> **Pourquoi des fréquences différentes (0.4 et 0.33) ?** Si `ro.y` était `cos(t) * d` (même `t`), la caméra suivrait un cercle dans un plan unique → ennuyeux et géométriquement plat. Deux fréquences **incommensurables** (rapport irrationnel) donnent une trajectoire qui ne se boucle jamais → animation infinie sans répétition perçue.

---

## Étape 3 — Premier objet : SDF cube + raymarching

**Notion :** la SDF du cube axes-alignés en 3D : `max(max(|x|-sx, |y|-sy), |z|-sz)`. Géométriquement on prend la plus grande distance signée parmi les 3 axes → ça définit l'extérieur de l'**intersection** des 3 dalles infinies (chacune épaisse de `2*si` selon son axe). Très efficace, base de plein de combinaisons.

```glsl
#define PI 3.14159265

float _cube(vec3 p, vec3 s)
{
    vec3 l = abs(p) - s;
    return max(l.x, max(l.y, l.z));
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

vec2 map(vec3 p)
{
    vec2 acc = vec2(10000., -1.);
    acc = _min(acc, vec2(_cube(p, vec3(1.)), 0.));   // cube unité au centre, matID 0
    return acc;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 ta = vec3(0.);
    vec3 rd = getCam(normalize(ta - ro), uv);

    // Raymarching standard
    vec3 p = ro;
    vec3 col = vec3(0.);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01) { col = vec3(1.); break; }    // hit → blanc
        p += rd * res.x * 0.5;                          // pas réduit (anti-overshoot)
        if (distance(p, ro) > 50.) break;               // garde-fou
    }

    fragColor = vec4(col, 1.);
}
```

> **Pourquoi `* 0.5` ?** Facteur anti-overshoot pour rester safe quand on combinera des SDF non-isométriques (intersection, déformation par bruit dès l'étape 7). Détails à l'étape 7 de `travel - étapes.md`. Avec un cube pur, `* 1.` marcherait — mais on prend l'habitude.

> **`distance(p, ro) > 50.` :** si le rayon ne touche jamais rien, sans garde-fou la boucle tourne 128 fois pour rien et `p` part à l'infini. C'est aussi un budget de perf : tout ce qui est à plus de 50 unités est ignoré.

---

## Étape 4 — SDF "cube creux" : wireframe procédural

**Notion :** on veut afficher uniquement les **arêtes** d'un cube. Astuce élégante : chaque arête est l'intersection de **2 faces** sur les 3 axes. Pour chaque axe `x/y/z`, on calcule la SDF d'un "tube" carré aligné sur cet axe (intersection des deux **autres** axes épaissis), puis on prend le `min` des 3 → on obtient le wireframe ; on l'intersecte (`max`) avec le cube original pour ne garder l'épaisseur que sur la coque.

```glsl
#define PI 3.14159265

float _cube(vec3 p, vec3 s)
{
    vec3 l = abs(p) - s;
    return max(l.x, max(l.y, l.z));
}

float _cucube(vec3 p, vec3 s, vec3 th)
{
    vec3 l = abs(p) - s;
    float cube = max(max(l.x, l.y), l.z);    // SDF cube standard

    l = abs(l) - th;                          // épaisseur d'arête (th = thickness vec3)
    float x = max(l.y, l.z);                  // tube aligné sur X (intersection y ∩ z)
    float y = max(l.x, l.z);                  // tube aligné sur Y
    float z = max(l.x, l.y);                  // tube aligné sur Z

    // min des 3 tubes = wireframe ; max avec cube = on garde uniquement à la surface du cube
    return max(min(min(x, y), z), cube);
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

vec2 map(vec3 p)
{
    vec2 acc = vec2(10000., -1.);
    acc = _min(acc, vec2(_cucube(p, vec3(1.), vec3(0.05)), 0.));   // cube creux
    return acc;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 ta = vec3(0.);
    vec3 rd = getCam(normalize(ta - ro), uv);

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01) { col = vec3(1.); break; }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **Pourquoi `abs(l)` une seconde fois ?** Après le premier `abs(p) - s`, `l` peut être négatif (à l'intérieur du cube). Reprendre l'absolu permet de mesurer la distance depuis la **surface intérieure** aussi → l'épaisseur d'arête est appliquée des deux côtés. Sans ça, le wireframe ne s'affiche que sur les arêtes externes et casse aux coins.

> Cette technique se généralise à toute SDF "boîtée" (frame de fenêtre, plaque trouée, cage…). Même esprit que l'**onion peeling** d'Inigo Quilez (`abs(d) - thickness`).

> **Note pédagogique :** l'étape suivante n'utilise **pas** `_cucube` (le diamant final est plein, pas en wireframe). On garde quand même `_cucube` ici parce que c'est une combinatoire de SDF instructive et qu'elle sert dans des shaders dérivés. Skippez l'étape 4 si vous voulez aller direct au diamant.

---

## Étape 5 — Composer un diamant par intersection de cubes tournés

**Notion :** un "diamant" géologique = un octaèdre tronqué + biseaux. Plutôt que d'écrire la SDF analytique, on triche : on prend un cube tourné de 45° sur deux axes (forme losange en coupe) et on l'**intersecte** (`max`) avec un autre cube tourné différemment → résultat ressemble à une pierre taillée avec des facettes inclinées.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float _cube(vec3 p, vec3 s)
{
    vec3 l = abs(p) - s;
    return max(l.x, max(l.y, l.z));
}

float _diamond(vec3 p)
{
    vec3 p2 = p;                       // copie pour le cutter
    p.yz *= r2d(PI * 0.25);            // rotation 45° autour de X
    p.xy *= r2d(PI * 0.25);            // rotation 45° autour de Z (composée)
    float diamond = _cube(p, vec3(1.));

    p2.xz *= r2d(PI * 0.23);           // rotation différente pour le cutter (pas .25 → asymétrie)
    float cut = _cube(p2, vec3(1.));

    return max(diamond, cut);          // intersection : on garde ce qui est dans LES DEUX cubes
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

vec2 map(vec3 p)
{
    vec2 acc = vec2(10000., -1.);
    acc = _min(acc, vec2(_diamond(p), 0.));
    return acc;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01) { col = vec3(1.); break; }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **Pourquoi `0.23` au lieu de `0.25` ?** Pour casser la symétrie. Avec `0.25`, les deux cubes seraient simplement orthogonaux et donneraient une forme régulière. Le `0.23` (≈ 41°) crée des facettes non-uniformes → le diamant a l'air "taillé à la main".

> **Booléens SDF :** `max(a, b)` = intersection (être dans `a` ET `b`), `min(a, b)` = union (être dans `a` OU `b`), `max(a, -b)` = soustraction (`a` moins `b`).

> **Limite :** la rotation `p.yz *= r2d(...)` est **isométrique** (matrice de rotation pure) → la SDF reste exacte. L'intersection (`max`) reste aussi exacte tant que les deux SDF sont exactes. On peut donc encore raymarcher sans facteur de sécurité fort. Ce sera moins vrai à l'étape 7 (bruit additif).

---

## Étape 6 — Bruit 3D procédural (value noise via permutations)

**Notion :** on a besoin d'un bruit 3D pour casser la régularité du diamant. La fonction `noise(p)` ci-dessous est une variante du **value noise** de Stefan Gustavson, à base de permutations modulo 289 et d'interpolation cubique. Caractéristiques :
- Pas de texture nécessaire (entièrement procédural).
- Continu et lisse (`d * d * (3 - 2*d)` = smoothstep cubique).
- Période d'environ 289 → safe pour les coordonnées qu'on lui donne.

Code à coller en dehors de toute fonction (juste pour visualisation, on l'appliquera vraiment à l'étape 7) :

```glsl
float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }

float noise(vec3 p)
{
    vec3 a = floor(p);                  // coin entier de la cellule
    vec3 d = p - a;                     // position locale dans la cellule (0..1)
    d = d * d * (3.0 - 2.0 * d);        // smoothstep cubique → continuité C¹

    // Hashing des 8 coins de la cellule par permutations
    vec4 b  = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c  = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    // Interpolation trilinéaire avec d pondéré par smoothstep
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    // Visualisation 2D du bruit : on regarde une coupe Z = iTime
    float n = noise(vec3(uv * 5., iTime * 0.5));
    fragColor = vec4(vec3(n), 1.);
}
```

> **Pourquoi 8 coins ?** Une cellule cubique a 8 sommets. Pour interpoler une valeur en un point quelconque dans la cellule, on prend les 8 valeurs hashées aux sommets et on interpole trilinéairement. Le `d * d * (3 - 2*d)` est appliqué **avant** l'interpolation pour adoucir les transitions entre cellules (sinon on verrait les arêtes de la grille).

> **Alternative pratique :** en production on préfère `texture(iChannel0, p.xy)` — moins coûteux GPU, qualité supérieure (bruit pré-calculé). On garde le procédural ici pour rester self-contained et exposer la mécanique.

---

## Étape 7 — Bruit appliqué au diamant : bord de coupe + grain de surface

**Notion :** on perturbe le diamant à deux endroits :
- `cut -= noise(p * 3.) * 0.02;` : grignote le bord de la coupe → arête irrégulière.
- `diamond += noise(p * 5.) * 0.01;` : déforme la surface globale → "grain" de pierre.

Les amplitudes restent petites (`0.01`–`0.02`) parce qu'on **viole** la propriété de la SDF en ajoutant du bruit (la distance n'est plus exacte). Trop fort → le raymarcher overshoot et on a des trous noirs ou des bandes.

> ⚠️ **Visualisation :** jusqu'ici on affichait `col = vec3(1.)` au hit → silhouette blanche pure. Avec une perturbation de `0.01`, la silhouette ne bouge **presque pas** ; le bruit reste invisible. On bascule donc dès cette étape sur un affichage des **normales** : `col = n * 0.5 + 0.5;`. Les normales sont calculées par gradient de la SDF (technique standard, on la réutilisera à l'étape 9 pour la réflexion). Chaque micro-variation de la surface change la normale → devient un patch de couleur visible.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s)
{
    vec3 l = abs(p) - s;
    return max(l.x, max(l.y, l.z));
}

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25);
    p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));

    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;       // bord de la coupe perturbé

    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;   // grain global sur la surface
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

vec2 map(vec3 p)
{
    vec2 acc = vec2(10000., -1.);
    acc = _min(acc, vec2(_diamond(p), 0.));
    return acc;
}

// Normale par gradient central de la SDF (cf. travel/tunnel notes)
// On échantillonne map() autour de p sur 3 axes et on en déduit la pente locale.
// Cette pente = direction de variation maximale de la distance = normale à la surface.
vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(
        map(p - e.xyy).x,
        map(p - e.yxy).x,
        map(p - e.yyx).x
    ));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            // === VISUALISATION par les normales ===
            // Sans ce shading, la silhouette blanche masquerait totalement l'effet du bruit.
            // n*.5+.5 remappe une normale (composantes -1..1) en une couleur (0..1) :
            // une face orientée +X devient rouge, +Y vert, +Z bleu, etc.
            vec3 n = getNorm(p, res.x);
            col = n * 0.5 + 0.5;

            // Alternative pédagogique : silhouette pure
            // (commentez les deux lignes au-dessus, décommentez celle-ci pour comparer)
            // col = vec3(1.);
            break;
        }
        p += rd * res.x * 0.5;        // le * 0.5 devient critique ici (cf. anti-overshoot)
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **Comment vraiment voir la diff avant/après le bruit :**
> 1. Avec le shading par normales, **commentez** les deux lignes `cut -= noise(p * 3.) * 0.02;` et `diamond += noise(p * 5.) * 0.01;` dans `_diamond` → la surface devient parfaitement lisse, vous voyez les **facettes plates** du cube intersection (zones de couleur uniforme).
> 2. **Décommentez** → chaque facette se couvre d'un dégradé bruité, et l'arête de la coupe devient irrégulière (visible en silhouette aussi).
> 3. Pour exagérer : multipliez l'amplitude `0.01` par 10. ⚠️ **Attention :** si vous augmentez le bruit, divisez aussi le `* 0.5` du raymarcher (par exemple `* 0.2`), sinon overshoot massif → trous noirs.

> **Anti-overshoot :** le `* 0.5` dans `p += rd * res.x * 0.5;` compense le fait que `res.x` surestime peut-être la vraie distance après l'ajout de bruit. Sans ça, vous verrez des bandes noires ou des trous dans le diamant. Multipliez le `0.02` du bruit par 5 pour observer l'artefact.

> **Pourquoi des fréquences différentes (3 et 5) ?** Le bruit haute-fréquence (`* 5`) crée un grain fin. Le bruit basse-fréquence (`* 3`) crée des ondulations plus larges. Combiner deux échelles donne un look "naturel" sans pattern visible.

> **Sur les normales :** `getNorm` calcule un gradient central : `(map(p) - map(p - ε * axis)) / ε` pour chaque axe, normalisé. Ce gradient pointe vers les **distances croissantes** = vers l'extérieur de la surface = la normale. Le `0.01` est l'epsilon : trop petit → bruit numérique, trop grand → on lisse les détails. Pour un objet à l'échelle 1 unité, `0.01` est un bon compromis.

---

## Étape 8 — Cubemap : skybox via iChannel3

**Notion :** une cubemap est une texture stockée sur les **6 faces d'un cube**. On l'échantillonne avec une **direction** (vec3), pas des UV 2D. Idéale pour :
- Les ciels lointains (la cubemap est "à l'infini" — la position du sample ne compte pas).
- Les reflets (on samplera dans `reflect(rd, n)` à l'étape 9).
- L'éclairage indirect (IBL, hors scope ici).

> **Setup Shadertoy :** dans le panneau **iChannel3**, choisissez **Cubemap** puis n'importe quel preset (`Forest Blurred`, `Uffizi Gallery`, `Basilica`).

> 🚨 **Erreur typique si vous oubliez ce setup :**
> ```
> 'texture' : no matching overloaded function found
> 'xyz'     : field selection requires structure, vector, or interface block on left hand side
> 'return'  : function return is not matching type
> ```
> Trois erreurs en cascade qui viennent d'**une seule** : `iChannel3` est resté en `sampler2D` (texture classique) au lieu de `samplerCube`. L'appel `texture(iChannel3, vec3)` ne matche aucune overload (`texture` 2D attend un `vec2`) → la chaîne `.xyz` puis `return` plante derrière. Bindez `iChannel3` à une **Cubemap** (onglet Cubemaps, pas Textures) et l'erreur disparaît.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

// Sample de la cubemap sur iChannel3
vec3 getEnv(vec3 rd)
{
    // Le * vec3(1., -1., 1.) flippe Y : convention historique des cubemaps OpenGL/WebGL
    return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);     // par défaut on voit la cubemap (pour les rayons qui ne touchent rien)
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01) { col = vec3(1.); break; }   // hit → toujours blanc pour l'instant
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **Pourquoi le flip Y ?** Convention historique : OpenGL (et donc WebGL) stockait les cubemaps avec Y inversé par rapport au reste. Shadertoy hérite de ça. Sans flip, votre ciel serait à l'envers.

> **À tester :** changez la cubemap dans iChannel3, observez le diamant blanc devant des skyboxes différentes. C'est la base ; on va faire en sorte que la surface du diamant **réfléchisse** ces couleurs à l'étape suivante.

---

## Étape 9 — Réflexion miroir parfait

**Notion :** sur un point de surface avec normale `n`, le rayon incident `rd` "rebondit" en `reflect(rd, n) = rd - 2 * dot(rd, n) * n`. Pour un miroir, on échantillonne la cubemap dans cette direction réfléchie. Les normales de la SDF s'obtiennent par gradient (cf. travel/tunnel notes).

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

// Normale par gradient central : on échantillonne map() autour de p
vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);          // direction réfléchie
    vec3 col = getEnv(refl);             // sample cubemap dans cette direction
    col = pow(col, vec3(3.2));           // boost de contraste : assombrit, accentue les pics → look "verre sombre"
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);    // matériau miroir
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **`pow(col, vec3(3.2))` :** trick visuel courant. La cubemap est encodée en sRGB. Élever à une puissance > 1 écrase les valeurs sombres (→ noirs profonds) et préserve les pics → look "verre sombre" dramatique. Joue sur la valeur (1.0 = neutre, 2.2 = gamma, 3+ = stylisé).

> **`reflect(I, N)` :** intégré GLSL. Calcule `I - 2 * dot(N, I) * N`, équivalent à la loi de la réflexion (angle d'incidence = angle de réflexion) en supposant `N` normalisé. Si `N` ne l'est pas, le résultat est faux ; d'où le `normalize` dans `getNorm`.

---

## Étape 10 — Réflexion glossy : roughness map + offset random (sans RNG temporel)

**Notion :** un miroir parfait est lisse. La majorité des matériaux réels diffusent un peu : la **rugosité** (roughness) étale le reflet. Approche bon marché ici : on perturbe la direction de réflexion par un **offset aléatoire** d'amplitude proportionnelle à la roughness échantillonnée sur une texture.

> **Setup :** bind **iChannel2** à une texture de bruit (`Noise Medium`). On l'utilise comme **roughness map** : chaque point de surface a sa propre rugosité.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

// === NOUVEAU : matériau glossy ===
vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);

    // Roughness lue dans la texture de bruit, projetée en planar XY
    float rough = texture(iChannel2, p.xy * 0.3).x;

    // Offset 3D centré sur 0, amplitude = roughness
    // On utilise le bruit procédural à 3 fréquences arbitraires pour avoir 3 valeurs décorrélées
    vec3 offset = (vec3(noise(p * 7.), noise(p * 8.3), noise(p * 9.7)) - 0.5) * rough;

    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **Setup rappel :** **iChannel2** = `Noise Medium` (roughness map), **iChannel3** = `Cubemap` (toujours nécessaire depuis l'étape 8).

> **Pourquoi `p.xy` (et pas `p.xyz`) ?** Approximation : on sample la roughness comme s'il s'agissait d'une texture 2D drapée sur l'objet. Les artefacts de "mapping planaire" sont masqués par le glow et la rotation. Pour une vraie roughness 3D, échantillonnez 3 directions et triplanar-blend (cf. `tunnel2` étape 8).

> **Limite :** chaque pixel obtient le **même** offset (parce que `noise(p * k)` est déterministe en `p`). Pas de bruit temporel → pas d'animation du glossy. À l'étape suivante on remplace par un vrai RNG par pixel et par frame.

> **Lien physique :** ce qu'on fait ici est une approximation **mono-sample** de la BRDF de Cook-Torrance (microfacets). Les vrais shaders PBR samplent N directions importance-pondérées et moyennent. Coûteux. Notre version triche avec 1 sample décorrélé spatialement → bruité mais gratuit. L'étape 14 (feedback) lissera ce bruit en moyennant N frames.

---

## Étape 11 — RNG stateful : `_seed` + `rand()`

**Notion :** pour un effet glossy convaincant, il faut des samples **décorrélés** par pixel ET par frame. On garde un `_seed` global qui s'incrémente à chaque appel de `rand()`, initialisé à partir de `iTime` (décorrélation temporelle) + un sample de bruit dépendant du pixel (décorrélation spatiale).

> **Setup :** **iChannel0** = `Noise Medium` (sert au seed spatial), **iChannel2** = `Noise Medium` (roughness map), **iChannel3** = `Cubemap`.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// === RNG stateful ===
float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

// === NOUVEAU : offset glossy via rand() (décorrélé par pixel ET par frame) ===
vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    // === Init du RNG : décorrélation spatiale (texture) + temporelle (iTime) ===
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> **Pourquoi `iTime + texture(iChannel0, uv).x` ?**
> - **`iTime`** : décorrélation **temporelle** (chaque frame a un seed différent → animation du glossy → grain qui scintille).
> - **`texture(iChannel0, uv).x`** : décorrélation **spatiale** (pixels voisins ont des seeds différents grâce au sample de bruit → les samples ne s'alignent pas en bandes).
>
> Sans le mix des deux, vous obtenez un pattern statique et structuré qui crève l'œil.

> **Une lecture par appel :** `rand()` consomme un seed par appel. 3 appels successifs = 3 valeurs indépendantes (à condition que `hash11` soit suffisamment chaotique). C'est la base de tout le Monte Carlo : multiplier les samples décorrélés et moyenner pour réduire le bruit.

> **Naming convention :** le préfixe `_` (comme `_seed`, `_min`, `_cube`, `_diamond`) est une convention perso qui signale "global mutable" ou "helper bas-niveau". Pas standard GLSL.

> **Limite de `hash11` :** `mod(sin(x) * k, 1.)` produit une distribution **biaisée** (pas uniforme). Suffisant pour du glossy stylisé ; insuffisant pour de la vraie intégration Monte Carlo. En prod, utilisez un PRNG comme PCG ou Xoshiro (cf. https://www.pcg-random.org/).

---

## Étape 12 — Réfraction approximée par raymarching intérieur

**Notion :** la **vraie** réfraction (loi de Snell-Descartes : `refract()`) plie le rayon à l'entrée du verre selon les indices (n1, n2), puis le re-plie à la sortie. Pour la calculer il faut de toute façon **traverser l'objet** pour trouver le point de sortie. Notre approche bon marché garde uniquement cette traversée et **saute le pliage** : on prolonge le rayon `rd` **en ligne droite** à travers le diamant jusqu'à la face arrière. Le cœur de l'astuce tient en un signe : `-_diamond(p)`.

C'est l'étape la plus dense du shader, donc on la **décompose au maximum** en 4 sous-étapes, chacune un shader complet copiable. Pour bien isoler la réfraction, les sous-étapes 12.1→12.3 **mettent de côté le reflet** de l'étape 11 (on le recombine en 12.4).

1. **12.1** — inverser la SDF (`-_diamond`) pour marcher **à l'intérieur** → tentative **naïve** (échoue : sortie immédiate)
2. **12.2** — le **décollage** `p -= n*0.05` qui corrige tout → **carte d'épaisseur** lisible
3. **12.3** — afficher la **normale de la face arrière** atteinte → on voit qu'on traverse vraiment
4. **12.4** — couleur de sortie + **recombinaison avec le reflet** (= état final de l'étape 12)

```
                  diamant
              ┌───────────────┐
   rd  ●──────┼──▶──▶──▶──▶───┼───●   p (sortie, face arrière)
   (vue)      │  bonds =      │
              │  -_diamond(p) │
              └───────────────┘
              op (entrée = point de hit)
```

> **L'idée du signe.** À l'extérieur du diamant `_diamond(p) > 0` (distance jusqu'à la surface). À l'intérieur, `_diamond(p) < 0`. Donc `-_diamond(p)` est **positif quand on est dedans** et vaut la distance jusqu'à la paroi la plus proche : c'est exactement le pas de raymarching dont on a besoin pour avancer dans la matière sans la traverser d'un coup.

> **Setup channels :** ces sous-étapes n'ont besoin que de **iChannel3** = `Cubemap` (pour le fond). Le seed/`rand()` et **iChannel0**/**iChannel2** ne reviennent qu'en **12.4** (avec le reflet glossy).

---

### Étape 12.1 — Inverser la SDF pour marcher à l'intérieur (tentative naïve)

**Notion :** au point de hit (face avant), on lance une **2e boucle** de raymarching, mais cette fois on avance avec `-_diamond(p)` pour rester **à l'intérieur** et trouver la face de sortie. On mesure la **distance parcourue** dans la matière (`thickness`) et on l'affiche en niveaux de gris. ⚠️ Version volontairement **buggée** : on part **pile** du point de hit, sans décollage.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

// On ISOLE la réfraction : pas de reflet ici (recombiné en 12.4)
vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 op = p;                       // point d'ENTRÉE (face avant touchée)

    // 2e raymarching, mais À L'INTÉRIEUR du diamant
    for (float i = 0.; i < 32.; i++)   // budget fixe : ~35 pas suffisent pour traverser
    {
        float dist = -_diamond(p);     // SDF INVERSÉE : >0 dedans = distance jusqu'à la paroi
        if (dist < 0.01) break;        // on a rejoint une paroi → on "sort"
        p += rd * dist;                // rayon NON plié (c'est toute l'approximation)
    }

    float thickness = distance(p, op); // distance parcourue dans la matière
    return vec3(thickness * 0.5);      // visualisation : épaisseur en gris
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);                 // fond = cubemap
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);        // on REMPLACE col : on isole la réfraction
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le diamant est **tout noir** (épaisseur ≈ 0 partout). Au point de hit, `_diamond(p) ≈ 0`, donc `-_diamond(p) ≈ 0 < 0.01` → la boucle `break` **dès la 1re itération** : on "sort" sans avoir avancé. C'est le bug qu'on corrige juste après.

> **Pourquoi une 2e boucle séparée ?** Le 1er raymarching (dans `mainImage`) cherche la **face avant** depuis l'extérieur. Une fois dedans, il faut une logique inverse (rester dans la matière, viser la **face arrière**) : d'où une seconde boucle, dans `getMat`, qui marche sur `-_diamond`.

---

### Étape 12.2 — Le décollage `p -= n*0.05` : la carte d'épaisseur

**Notion :** une seule ligne corrige 12.1 : `p -= n * 0.05;`. On pousse le point de départ **vers l'intérieur**, le long de `-n` (n = normale sortante, donc `-n` rentre). On démarre alors franchement dans la matière (`-_diamond(p)` nettement positif) et la boucle peut avancer jusqu'à la face arrière. La `thickness` devient une vraie **carte d'épaisseur** du diamant.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 op = p;
    p -= n * 0.05;                     // ✅ DÉCOLLAGE : on entre franchement dans le diamant
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01) break;
        p += rd * dist;
    }
    return vec3(distance(p, op) * 0.5);   // carte d'épaisseur
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le diamant s'éclaire en dégradé — **clair au centre** (le rayon traverse beaucoup de matière) et **sombre vers les bords/arêtes** (épaisseur fine). C'est littéralement la longueur de verre traversée par chaque rayon. Cette grandeur va servir de "carburant" à l'absorption colorée de l'étape 13 (Beer-Lambert).

> **Pourquoi `0.05` ?** C'est un compromis : assez grand pour dépasser le bruit du SDF (`±0.03` à cause du `noise`) et le seuil de hit `0.01`, assez petit pour ne pas trouer les détails fins du diamant. Essayez `0.005` → le bug de 12.1 réapparaît par endroits (taches noires). Essayez `0.3` → les arêtes minces disparaissent (on saute par-dessus).

> **`-n` pointe bien vers l'intérieur ?** Oui : `getNorm` renvoie le gradient de la SDF, qui pointe vers les distances **croissantes** = vers l'**extérieur**. Donc `-n` rentre dans l'objet. C'est la même convention que pour décoller un rayon de réflexion (`+n`) — ici on fait l'inverse.

---

### Étape 12.3 — Voir la face arrière : normale de sortie

**Notion :** pour prouver que la boucle atteint bien la **paroi opposée** (et pas n'importe quoi), on affiche la **normale du point de sortie** au lieu de l'épaisseur. À la fin de la boucle, `p` est sur une facette arrière : `getNorm(p, map(p).x)` donne sa normale, qu'on remappe `-1..1 → 0..1` en couleur. On voit alors les **facettes du fond** du diamant, vues "à travers" la pierre.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    p -= n * 0.05;
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01) break;
        p += rd * dist;
    }
    // p est maintenant sur la face ARRIÈRE : on affiche sa normale
    vec3 nb = getNorm(p, map(p).x);
    return nb * 0.5 + 0.5;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** des **plages de couleurs franches** apparaissent dans le diamant : ce sont les facettes de la **paroi opposée**, chacune avec une orientation (donc une couleur) différente. Comparez avec l'étape 9 (normales de la face **avant**) : ici on regarde le **dos** de la pierre, atteint en la traversant. La preuve visuelle que la traversée fonctionne.

> **Limite assumée :** le rayon n'étant **pas plié**, ces facettes arrière sont vues "tout droit", sans la déformation en lentille d'une vraie réfraction. C'est acceptable parce qu'à l'étape suivante on ne **montre pas** vraiment le fond : on le remplace par une couleur d'absorption.

---

### Étape 12.4 — Couleur de sortie + recombinaison avec le reflet (état final)

**Notion :** on ne garde de la face arrière qu'une **couleur de sortie** (verte fixe pour l'instant — l'étape 13 la rendra colorée et absorbante), et on la **rajoute au reflet** de l'étape 11 (`col += transp`). On réintroduit donc le matériau glossy complet : retour de `rand()`/`_seed` (**iChannel0**) et de la roughness map (**iChannel2**). C'est le shader complet de l'étape 12.

> **Setup :** **iChannel0** = `Noise Medium`, **iChannel2** = `Noise Medium`, **iChannel3** = `Cubemap`.

```glsl
#define PI 3.14159265

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    // --- Réflexion (étape 11) ---
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    // --- Réfraction approximée (12.1 → 12.3) ---
    vec3 op = p;                        // point d'entrée (mémorisé pour l'épaisseur, étape 13)
    p -= n * 0.05;                      // décollage vers l'intérieur

    vec3 transp = vec3(0.);             // couleur "vue à travers"
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);      // SDF inversée : distance à la paroi depuis l'intérieur
        if (dist < 0.01)
        {
            transp = vec3(0.2, 0.85, 0.65);   // couleur de sortie fixe (verte) ; étape 13 la rendra absorbante
            break;
        }
        p += rd * dist;                  // rayon NON plié → approximation
    }
    col += transp;                       // on AJOUTE la transparence par-dessus le reflet
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le diamant combine maintenant le **reflet** de la cubemap (sur les facettes face caméra) et une **lueur verte** intérieure (la couleur de sortie additionnée). Comme `col += transp` est **additif**, le vert éclaircit la pierre sans masquer le reflet — un look "gemme lumineuse". L'étape 13 remplace ce vert plat par une couleur qui dépend de l'épaisseur (12.2) → vrai effet d'absorption.

> **Pourquoi additif (`+=`) et pas un `mix` ?** Un `mix(reflet, transp, k)` simulerait une surface **opaque** teintée. Le `+=` simule un milieu **translucide** qui laisse passer le reflet ET émet/transmet sa propre couleur — physiquement plus proche d'un cristal éclairé de l'intérieur. C'est un choix stylistique, pas une loi.

> **`op` mémorisé pour rien... encore.** Ici `op` ne sert pas (la couleur de sortie est fixe). On le garde parce que l'étape 13 en a besoin : `distance(p, op)` = l'épaisseur traversée (la carte de 12.2) pilote l'absorption Beer-Lambert.

> **Budget de 32 itérations :** un diamant unité a une diagonale de ~3.5 unités ; avec un pas moyen de ~0.1 on ressort en ~35 itérations max. 32 suffit en pratique ; au-delà, c'est qu'on est coincé sur une SDF dégénérée → sortir silencieusement de la boucle vaut mieux qu'un freeze.

---

## Étape 13 — Absorption volumétrique colorée

**Notion :** dans un volume coloré (vitrail, eau, cristal, jade), plus la lumière voyage dans la matière, plus elle est absorbée — typiquement plus dans certaines longueurs d'onde (loi de **Beer-Lambert** : `I = I0 · exp(-σ · d)`). À l'étape 12 la couleur de sortie était une **constante verte** ; ici on la rend vivante. On part de **12.4** et on empile **4 idées**, une par sous-étape, toutes localisées dans le **bloc de sortie** de la boucle de réfraction :

1. **13.1** — **Beer-Lambert** : la couleur de sortie vire vers le magenta selon l'**épaisseur traversée** (la carte de 12.2 devient de la couleur)
2. **13.2** — **couleur de base variable** : veines vert↔bleu pilotées par la roughness map
3. **13.3** — **faux GI** : on assombrit le **bas** du diamant
4. **13.4** — **réfraction floue** : on perturbe le rayon **interne** (verre dépoli) → shader final

```
1 - exp(-d * 0.25)   (poids d'absorption en fonction de l'épaisseur d traversée)

 1 ┤                         ____________------------
   │                ___-----
   │           __---
   │        _--
   │      _-
   │    _-
 0 ┤__--
   └────────────────────────────────────────────────▶ d
   0   épaisseur fine (bords)        épaisseur forte (centre)
```

> **Lecture de la courbe :** au point de sortie immédiat (`d ≈ 0`) le poids vaut 0 → on garde la couleur de base. Plus le rayon a traversé de verre, plus le poids monte vers 1 → la couleur "absorbée" (magenta) domine. C'est exactement la **carte d'épaisseur de 12.2** transformée en gradient de couleur.

> **Setup :** **iChannel0** = `Noise Medium`, **iChannel2** = `Noise Medium`, **iChannel3** = `Cubemap` (idem 12.4).

---

### Étape 13.1 — Beer-Lambert : absorption pilotée par l'épaisseur

**Notion :** on garde la **couleur de base verte unique** de 12.4, mais au lieu de la sortir telle quelle, on la **mélange vers du magenta** par `mix(base, magenta, 1 - exp(-d·0.25))`, où `d = distance(p, op)` est l'épaisseur traversée. Un seul `mix` ajouté → la pierre se colore par l'intérieur selon son volume.

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    // --- Réflexion (étapes 10-11) ---
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    // --- Réfraction (étape 12) + absorption Beer-Lambert (NOUVEAU) ---
    vec3 op = p;                        // point d'entrée → sert à mesurer l'épaisseur
    p -= n * 0.05;                      // décollage vers l'intérieur

    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = vec3(0.2, 0.85, 0.65);                  // couleur de base UNIQUE (verte), comme en 12.4
            // Beer-Lambert : plus l'épaisseur traversée est grande, plus on tire vers le magenta "absorbé"
            transp = mix(transp, vec3(1., 0., 1.),
                         1. - exp(-distance(p, op) * 0.25)); // poids : 0 si épaisseur nulle → 1 si très épais
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(sat(col), 1.);   // clamp final : le magenta additif peut dépasser 1
}
```

> 👁️ **Lecture :** comparé à 12.4 (vert plat partout), la pierre est maintenant **verte sur les bords fins** et **magenta au centre épais**. C'est la carte d'épaisseur de 12.2 traduite en couleur. Réglez le `0.25` : à `0.1` la pierre reste verte (absorption lente), à `1.0` elle vire magenta presque partout.

> **Pourquoi `1 - exp(-d·k)` et pas une rampe linéaire ?** La courbe exponentielle est la vraie loi d'absorption (Beer-Lambert) : démarre à 0, monte vite, sature en douceur. Une rampe linéaire produirait des cassures visibles aux discontinuités d'épaisseur (arêtes du diamant). Le `0.25` est la "longueur d'absorption" inverse : plus grand = opaque plus vite.

> **`sat(col)` en sortie :** comme `col += transp` est additif et que le magenta vaut `(1,0,1)`, la somme avec le reflet peut dépasser 1 dans le rouge/bleu. Le `sat` final borne à `[0,1]` pour éviter les artefacts de saturation (et l'emballement du feedback à l'étape 14).

---

### Étape 13.2 — Couleur de base variable : les veines vert↔bleu

**Notion :** on remplace le vert constant par un **mélange vert↔bleu** dont le facteur est lu dans la roughness map (`texture(iChannel2, p.xy*0.2).x`). Comme ce facteur varie d'un point de sortie à l'autre, la pierre se couvre de **veines** colorées sous l'absorption magenta.

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    vec3 op = p;
    p -= n * 0.05;

    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            // Couleur de base VARIABLE : veines vert↔bleu pilotées par la roughness map
            transp = mix(vec3(0.200, 0.851, 0.655),          // vert
                         vec3(0.106, 0.294, 0.804),          // bleu
                         texture(iChannel2, p.xy * 0.2).x);  // facteur de mix variable selon le point de sortie
            transp = mix(transp, vec3(1., 0., 1.),
                         1. - exp(-distance(p, op) * 0.25));
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(sat(col), 1.);
}
```

> 👁️ **Lecture :** le fond vert uni de 13.1 devient un **camaïeu vert/bleu** : des plages bleutées apparaissent là où la roughness map est élevée. L'absorption magenta reste pilotée par l'épaisseur — les deux effets se superposent.

> **Fréquence `0.2` :** basse → grandes plages douces (veines larges). Montez à `2.0` pour un marbrage fin, ou échangez `iChannel2` pour une autre texture afin de changer le motif des veines.

---

### Étape 13.3 — Faux GI : assombrir la base du diamant

**Notion :** une pierre posée reçoit plus de lumière par le haut (ciel) que par le bas (sol/ombre). On simule ça d'un trait : on **multiplie la couleur de base** par `sat(sat(-p.y + 0.5) + 0.3)`, qui vaut ~1 en haut et descend vers ~0.3 en bas. Pur trucage, mais ça "pose" le diamant au lieu de le laisser flotter, uniformément lumineux.

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    vec3 op = p;
    p -= n * 0.05;

    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = mix(vec3(0.200, 0.851, 0.655),
                         vec3(0.106, 0.294, 0.804),
                         texture(iChannel2, p.xy * 0.2).x)
                   * sat(sat(-p.y + 0.5) + 0.3);             // NOUVEAU : faux GI, assombrit le bas
            transp = mix(transp, vec3(1., 0., 1.),
                         1. - exp(-distance(p, op) * 0.25));
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(sat(col), 1.);
}
```

> 👁️ **Lecture :** le **bas** de la pierre s'éteint, le **haut** reste lumineux → la gemme paraît posée et éclairée d'en haut. Subtil mais ça change la lecture du volume.

> **Décomposer `sat(sat(-p.y + 0.5) + 0.3)` :** `-p.y + 0.5` est grand en haut (`p.y` négatif), petit en bas. Premier `sat` → borne `[0,1]`. `+ 0.3` relève le plancher (le bas ne tombe jamais à 0 noir). Second `sat` → re-borne. Résultat : un facteur ∈ `[0.3, 1]` qui décroît du haut vers le bas. C'est de la triche assumée : aucun rayon d'occlusion réel n'est lancé.

---

### Étape 13.4 — Réfraction floue (verre dépoli) = shader final

**Notion :** dernière touche. Avant de traverser la pierre, on **perturbe légèrement `rd`** par un offset aléatoire d'amplitude `roughtrans` (lue à haute fréquence `5.1` → petites inclusions). Le rayon interne n'est plus droit mais "dispersé" → le fond de la pierre devient **dépoli** au lieu de net. C'est le shader complet de l'étape 13.

> **Setup :** **iChannel0** = `Noise Medium`, **iChannel2** = `Noise Medium`, **iChannel3** = `Cubemap`.

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    // --- Réflexion ---
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    // --- Réfraction floue : on disperse rd à l'entrée (verre dépoli) ---
    float roughtrans = texture(iChannel2, p.xy * 5.1).x;     // grain interne haute fréquence
    rd = normalize(rd + (vec3(rand(), rand(), rand()) - 0.5) * 0.5 * roughtrans);

    // --- Réfraction + absorption Beer-Lambert ---
    vec3 op = p;
    p -= n * 0.05;

    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = mix(vec3(0.200, 0.851, 0.655),
                         vec3(0.106, 0.294, 0.804),
                         texture(iChannel2, p.xy * 0.2).x)
                   * sat(sat(-p.y + 0.5) + 0.3);
            transp = mix(transp, vec3(1., 0., 1.),
                         1. - exp(-distance(p, op) * 0.25));
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    fragColor = vec4(sat(col), 1.);
}
```

> 👁️ **Lecture :** le fond de la pierre, net en 13.3, devient **granuleux/dépoli** : chaque pixel disperse son rayon interne différemment, donc trouve une face de sortie légèrement différente → l'épaisseur (et donc la teinte d'absorption) fourmille. Ça **scintille** image par image, parce que `rand()` change à chaque frame. C'est ce grain que l'**étape 14** (feedback temporel) va lisser en moyennant plusieurs frames.

> **Pourquoi perturber `rd` *avant* la boucle (et pas dedans) ?** Une seule perturbation à l'entrée = un rayon dévié mais **droit** dans la pierre (un seul échantillon de réfraction floue). Le perturber à chaque pas simulerait une diffusion volumétrique (sous-surface), bien plus coûteuse et instable. Ici on reste mono-sample, à la manière de la réflexion glossy de l'étape 10.

> **Amplitude `0.5` :** plage de dispersion. À `0.` on retombe sur 13.3 (réfraction nette). Au-delà de `~1.`, le rayon part dans tous les sens → la couleur de sortie devient un bruit illisible (l'épaisseur n'a plus de sens géométrique).

> **`roughtrans` à fréquence `5.1`** (vs `0.3` pour la roughness externe) : beaucoup plus haute → grain interne fin, façon "petites inclusions". À ajuster selon la cubemap utilisée.

#### Mieux voir l'effet : comparatif net / dépoli (split-screen)

**Notion :** dans le shader ci-dessus l'effet est presque invisible, pour **deux** raisons : (1) c'est **un seul échantillon par frame** → du grain qui scintille, pas un flou lisible ; (2) le **reflet** le recouvre. Ce shader de diagnostic corrige les deux : on **isole la transparence** (pas de reflet), on **amplifie** la dispersion, et surtout on **moyenne 16 échantillons** par pixel pour transformer le bruit en vrai flou. À **gauche** = réfraction **nette** (amplitude 0). À **droite** = réfraction **floue** (amplitude exagérée, moyennée).

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

// La réfraction SEULE (sans reflet), avec une amplitude de dispersion réglable.
// roughAmp = 0  -> réfraction nette (rd non perturbé)
// roughAmp > 0  -> réfraction floue (rd dispersé par rand())
vec3 refractColor(vec3 p, vec3 n, vec3 rd, float roughAmp)
{
    float roughtrans = texture(iChannel2, p.xy * 5.1).x;
    rd = normalize(rd + (vec3(rand(), rand(), rand()) - 0.5) * roughAmp * roughtrans);

    vec3 op = p;
    p -= n * 0.05;
    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = mix(vec3(0.200, 0.851, 0.655),
                         vec3(0.106, 0.294, 0.804),
                         texture(iChannel2, p.xy * 0.2).x)
                   * sat(sat(-p.y + 0.5) + 0.3);
            transp = mix(transp, vec3(1., 0., 1.),
                         1. - exp(-distance(p, op) * 0.25));
            break;
        }
        p += rd * dist;
    }
    return transp;
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    // 1er raymarching : on cherche la face avant
    vec3 p = ro; bool hit = false; vec3 n = vec3(0., 1., 0.);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01) { hit = true; n = getNorm(p, res.x); break; }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    vec3 col = getEnv(rd);                              // fond cubemap
    if (hit)
    {
        if (fragCoord.x < iResolution.x * 0.5)
        {
            col = refractColor(p, n, rd, 0.0);         // GAUCHE : NET (amplitude 0)
        }
        else
        {
            // DROITE : FLOU exagéré, MOYENNÉ sur 16 tirages → le grain devient un flou lisse
            vec3 acc = vec3(0.);
            for (int s = 0; s < 16; ++s)
                acc += refractColor(p, n, rd, 2.0);    // amplitude 2.0 (vs 0.5 dans le vrai shader)
            col = acc / 16.;
        }
    }

    // trait blanc de séparation au milieu
    if (abs(fragCoord.x - iResolution.x * 0.5) < 1.) col = vec3(1.);

    fragColor = vec4(sat(col), 1.);
}
```

> 👁️ **Lecture :** **à gauche** les facettes arrière et les variations d'épaisseur sont **nettes** (couleurs franches, bords précis). **À droite** tout est **fondu** : les détails internes se diluent, la teinte d'absorption se lisse → l'aspect "verre dépoli / givré". C'est exactement la modification de 13.4, rendue lisible.

> **Le rôle du moyennage (les 16 tirages).** Un seul `refractColor(..., 2.0)` donnerait du **bruit** (un point de sortie aléatoire). En moyennant 16 tirages décorrélés, ce bruit converge vers le **flou** réel de la réfraction floue. C'est précisément ce que fait l'étape 14, mais **dans le temps** (1 tirage/frame moyenné sur N frames) au lieu de **dans le pixel** (16 tirages/frame). Le shader final reste à 1 tirage justement pour laisser le feedback temporel faire le moyennage — moins cher par frame.

> **Pour expérimenter :** passez l'amplitude de droite de `2.0` à `0.5` (la vraie valeur de 13.4) → l'écart gauche/droite devient subtil, comme dans le shader final. Montez le nombre de tirages (`16` → `64`) → le flou de droite devient parfaitement propre (mais 4× plus cher).

---

## Étape 14 — Multi-pass : feedback Image → Buffer A (TAA pauvre)

**Notion :** le glossy (étape 11) + la roughness interne (étape 13) font que chaque frame a du bruit (les samples ne se répètent pas). Pour lisser, on utilise un **feedback temporel** : la passe finale (`Image`) écrit le résultat ; à la frame suivante, `Buffer A` lit cette sortie via `iChannel1` et **mixe à 50%** son rendu courant avec celui d'avant. Effet : moyenne mobile exponentielle des dernières frames → bruit divisé par ~√N, ghosting léger sur les mouvements.

> **Setup Shadertoy :**
> - **Common** : tous les `#define` partagés et les utilitaires (`r2d`, `getCam`, `_min`, `_cube`, `hash11`).
> - **Buffer A** : le shader principal (raymarching + matériau + feedback).
>   - iChannel0 = `Noise Medium` (seed spatial)
>   - iChannel1 = **Image** (feedback de la frame précédente — boutonner sur "Misc → Image")
>   - iChannel2 = `Noise Medium` (roughness map)
>   - iChannel3 = `Cubemap`
> - **Image** : passthrough qui affiche Buffer A. iChannel0 = Buffer A.

### Common

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}
```

### Buffer A

```glsl
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    float roughtrans = texture(iChannel2, p.xy * 5.1).x;
    rd = normalize(rd + (vec3(rand(), rand(), rand()) - 0.5) * 0.5 * roughtrans);

    vec3 op = p;
    p -= n * 0.05;
    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = mix(
                vec3(0.200, 0.851, 0.655),
                vec3(0.106, 0.294, 0.804),
                texture(iChannel2, p.xy * 0.2).x
            ) * sat(sat(-p.y + 0.5) + 0.3);
            transp = mix(transp, vec3(1., 0., 1.), 1. - exp(-distance(p, op) * 0.25));
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    col = sat(col);    // clamp avant le mix pour ne pas propager les saturations
    // FEEDBACK : iChannel1 = Image (frame précédente). mix à 50% → moyenne mobile exponentielle.
    col = mix(col, texture(iChannel1, fragCoord / iResolution.xy).xyz, 0.5);

    fragColor = vec4(col, 1.);
}
```

### Image (passthrough simple — iChannel0 = Buffer A)

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
}
```

> **Pourquoi `0.5` ?** Compromis. Plus haut = plus de lissage mais plus de **ghosting** (les mouvements traînent). Plus bas = plus net mais bruit plus visible. `0.5` donne une queue de ~2-3 frames perceptible — acceptable pour ce shader contemplatif. Pour un jeu, on irait plus bas (0.1-0.2) pour que les mouvements rapides ne traînent pas.

> **Risque saturation :** si `col` courant et `iChannel1` ont des pixels >1.0, leur moyenne reste >1.0 et bourre l'accumulateur. D'où le `sat(col)` avant le mix. En HDR / float-buffers, on n'aurait pas ce problème.

> **Equivalent statistique :** un mix `(1-α) * new + α * old` répété est une **moyenne exponentielle** avec poids `α^k` sur la frame d'âge `k`. Avec `α = 0.5`, le poids tombe à 0.5, 0.25, 0.125 → "souvenir" effectif sur ~log₂(1/seuil) frames. Pour un seuil à 5%, ~4 frames.

> **À observer :** désactivez le `mix` (commentez la ligne) → vous verrez le grain "neige TV" du glossy. Réactivez → ça lisse mais les rotations de caméra laissent des traînées (ghosting).

---

## Étape 15 — Post-process : box blur séparable 2D (H puis V)

**Notion :** un box blur 2D naïf coûte `O(N²)` samples par pixel (`N` rayons par direction). Astuce classique : un box blur est **séparable** → `B(I) = By(Bx(I))`. On enchaîne donc deux passes 1D — `Buffer B` flouté **horizontalement** depuis `Buffer A`, puis `Image` flouté **verticalement** depuis `Buffer B`. Coût `O(2N)`. Combiné au glow latent dans Buffer A, on obtient un halo doux autour des hautes lumières (bloom rectangulaire).

> **Setup Shadertoy :**
> - **Common** : identique à l'étape 14, plus les `#define` du blur. (Bloc complet ci-dessous.)
> - **Buffer A** : identique à l'étape 14 (raymarching + feedback).
>   - iChannel0 = `Noise Medium`, iChannel1 = **Image**, iChannel2 = `Noise Medium`, iChannel3 = `Cubemap`.
> - **Buffer B** : blur **horizontal** de Buffer A. iChannel0 = Buffer A.
> - **Image** : blur **vertical** de Buffer B. iChannel0 = Buffer B.

### Common

```glsl
#define PI 3.14159265
#define sat(a) clamp(a, 0., 1.)

#define GLOW_SAMPLES 8
#define GLOW_DISTANCE 0.05

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }

vec2 _min(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
float _cube(vec3 p, vec3 s) { vec3 l = abs(p) - s; return max(l.x, max(l.y, l.z)); }

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0., 1., 0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov * (r * uv.x + u * uv.y));
}
```

### Buffer A (identique étape 14)

```glsl
float _seed;
float rand() { _seed++; return hash11(_seed); }

float mod289(float x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  mod289(vec4 x)  { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4  perm(vec4 x)    { return mod289(((x * 34.0) + 1.0) * x); }
float noise(vec3 p)
{
    vec3 a = floor(p); vec3 d = p - a; d = d * d * (3.0 - 2.0 * d);
    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy); vec4 k2 = perm(k1.xyxy + b.zzww);
    vec4 c = k2 + a.zzzz; vec4 k3 = perm(c); vec4 k4 = perm(c + 1.0);
    vec4 o1 = fract(k3 * (1.0 / 41.0)); vec4 o2 = fract(k4 * (1.0 / 41.0));
    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);
    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float _diamond(vec3 p)
{
    vec3 p2 = p;
    p.yz *= r2d(PI * 0.25); p.xy *= r2d(PI * 0.25);
    float diamond = _cube(p, vec3(1.));
    p2.xz *= r2d(PI * 0.23);
    float cut = _cube(p2, vec3(1.));
    cut -= noise(p * 3.) * 0.02;
    diamond = max(diamond, cut);
    diamond += noise(p * 5.) * 0.01;
    return diamond;
}

vec2 map(vec3 p) { return _min(vec2(10000., -1.), vec2(_diamond(p), 0.)); }

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x));
}

vec3 getEnv(vec3 rd) { return texture(iChannel3, rd * vec3(1., -1., 1.)).xyz; }

vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    float roughtrans = texture(iChannel2, p.xy * 5.1).x;
    rd = normalize(rd + (vec3(rand(), rand(), rand()) - 0.5) * 0.5 * roughtrans);

    vec3 op = p;
    p -= n * 0.05;
    vec3 transp = vec3(0.);
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);
        if (dist < 0.01)
        {
            transp = mix(
                vec3(0.200, 0.851, 0.655),
                vec3(0.106, 0.294, 0.804),
                texture(iChannel2, p.xy * 0.2).x
            ) * sat(sat(-p.y + 0.5) + 0.3);
            transp = mix(transp, vec3(1., 0., 1.), 1. - exp(-distance(p, op) * 0.25));
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    float d = 5., t = iTime * 0.4;
    vec3 ro = vec3(sin(t) * d, sin(iTime * 0.33) * d, cos(t) * d);
    vec3 rd = getCam(normalize(vec3(0.) - ro), uv);

    vec3 p = ro;
    vec3 col = getEnv(rd);
    for (int i = 0; i < 128; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            vec3 n = getNorm(p, res.x);
            col = getMat(p, n, rd);
            break;
        }
        p += rd * res.x * 0.5;
        if (distance(p, ro) > 50.) break;
    }

    col = sat(col);
    col = mix(col, texture(iChannel1, fragCoord / iResolution.xy).xyz, 0.5);
    fragColor = vec4(col, 1.);
}
```

### Buffer B (blur HORIZONTAL — iChannel0 = Buffer A)

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;

    const int steps = GLOW_SAMPLES;
    vec3 col = vec3(0.);

    for (int i = 0; i < steps; ++i)
    {
        // f va de -1 à +1 (échantillonnage symétrique autour du pixel)
        float f = float(i) / float(steps);
        f = (f - 0.5) * 2.;

        vec2 nuv = uv + vec2(f * GLOW_DISTANCE, 0.);   // offset HORIZONTAL
        col += texture(iChannel0, nuv).xyz / float(steps);
    }
    fragColor = vec4(col, 1.);
}
```

### Image (blur VERTICAL — iChannel0 = Buffer B)

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;

    const int steps = GLOW_SAMPLES;
    vec3 col = vec3(0.);

    for (int i = 0; i < steps; ++i)
    {
        float f = float(i) / float(steps);
        f = (f - 0.5) * 2.;

        // Pour respecter l'aspect-ratio (sinon le halo est ovale en 16:9),
        // on multiplie par iResolution.x/iResolution.y → la même distance en pixels en X et en Y.
        vec2 nuv = uv + vec2(0., f * GLOW_DISTANCE * (iResolution.x / iResolution.y));
        col += texture(iChannel0, nuv).xyz / float(steps);
    }
    fragColor = vec4(col, 1.);
}
```

> **Pourquoi séparable ?** Un box blur 2D plein coûte `N²` samples (ex: 64 pour `N=8`). Deux passes 1D coûtent `2N` (16). Identité mathématique exacte tant que le filtre est séparable (vrai pour box, gaussien, triangulaire). Limite : un disk blur ou un blur orienté ne sont **pas** séparables.

> **Pourquoi le facteur `iResolution.x / iResolution.y` en V ?** Les UV sont normalisées en `[0,1]` sur les deux axes, mais l'écran n'est pas carré. Sans correction, un offset de `0.05` en Y couvre proportionnellement plus de hauteur que le même offset couvre de largeur en X (en 16:9, 0.05 vertical ≈ 0.089 horizontal en pixels). Résultat : halo aplati horizontalement. La compensation rend le blur visuellement isotrope.

> **Look anamorphique** (rebase si tu veux le grand frère cinéma) : retire la passe verticale → flou horizontal seul, traînées style flare anamorphique. C'est la version 1-passe d'avant.

> **Tests à faire :**
> - `GLOW_SAMPLES = 32`, `GLOW_DISTANCE = 0.1` → bloom massif.
> - `GLOW_SAMPLES = 4`, `GLOW_DISTANCE = 0.02` → halo subtil.
> - Pondérer par une gaussienne au lieu d'une moyenne uniforme : `weight = exp(-f * f * 4.)` puis normaliser → meilleure qualité visuelle (pas de "step" perceptible aux extrémités du kernel).
> - Pour un **bloom** "physique" : ne flouter que les pixels dont la luminance dépasse un seuil → `vec3 hi = max(texture(...).xyz - 1., 0.);` puis blur de `hi`, et add au-dessus de la version non-floutée.

---

## Récap des concepts par étape

| #  | Concept clé |
|----|---|
| 1  | Caméra look-at : `ro`, `ta`, base orthonormée (right, up, forward) |
| 2  | Orbite animée par fréquences incommensurables (Lissajous) |
| 3  | SDF cube (`max` des 3 dalles infinies) |
| 4  | Cube creux : wireframe procédural via `min` de tubes `∩ max` avec cube |
| 5  | Composition de SDF par intersection de cubes tournés |
| 6  | Bruit value-noise 3D procédural (perm + smoothstep) |
| 7  | Déformation de SDF par bruit (cut + grain), anti-overshoot |
| 8  | Cubemap : sample par direction, flip Y |
| 9  | Réflexion miroir : `reflect()` + sample cubemap, gamma stylisé |
| 10 | Roughness map → réflexion glossy par offset random (pas de RNG temporel) |
| 11 | RNG stateful (`_seed` + `rand()`), décorrélation spatio-temporelle |
| 12 | Réfraction approximée : raymarching de la SDF inversée (`-_diamond`). 12.1 marche naïve (échoue) · 12.2 décollage `-n*0.05` + carte d'épaisseur · 12.3 normale de sortie · 12.4 couleur + recombinaison reflet |
| 13 | Absorption volumétrique exponentielle (Beer-Lambert stylisé). 13.1 absorption par épaisseur · 13.2 couleur de base à veines vert↔bleu · 13.3 faux GI (assombrit le bas) · 13.4 réfraction floue (verre dépoli) |
| 14 | Feedback temporel : Image → Buffer A via iChannel1 (mix 0.5) |
| 15 | Post-process : box blur 2D séparable (Buffer B horizontal → Image vertical) |

---

## Pour aller plus loin

- **Vraie réfraction Snell :** remplacer la boucle de l'étape 12 par `refract(rd, n, 1./ior)` à l'entrée et un second hit sortant pour replier `refract(rd, -n, ior)`. Indices typiques : eau ≈ 1.33, verre ≈ 1.5, diamant ≈ 2.42.
- **Dispersion (chromatic aberration) :** appliquer un IOR différent par canal R/G/B → 3 raymarchings → arc-en-ciel.
- **Caustiques :** raymarcher depuis une lumière, stocker dans un buffer photon-map, sampler depuis la scène. Coûteux ; voir les shaders d'IQ.
- **TAA propre :** au lieu d'un `mix(0.5)` aveugle, reprojeter la frame précédente avec les vecteurs de mouvement (motion vectors) pour éviter le ghosting → c'est ce que font les TAA modernes (UE, Frostbite).
- **Bloom physique :** au lieu d'un blur uniforme, bloomer uniquement les pixels au-dessus d'un seuil (`max(col - 1., 0.)`) → flare proportionnel à la luminance HDR.
