
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

```glsl
// Hash 1D simple (qualité moyenne, suffit pour du glossy)
float hash11(float seed) { return mod(sin(seed * 123.456789) * 123.456, 1.); }

// Globale mutable + générateur incrémental
float _seed;
float rand() { _seed++; return hash11(_seed); }

// Dans mainImage, AVANT tout autre calcul :
//     _seed = iTime + texture(iChannel0, uv).x;

// Dans getMat, on remplace l'offset précédent :
vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;   // 3 samples indépendants par pixel et par frame
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));
    return col;
}
```

Et dans `mainImage`, ajouter au début :

```glsl
_seed = iTime + texture(iChannel0, uv).x;
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

**Notion :** la **vraie** réfraction (loi de Snell-Descartes : `refract()`) plie le rayon à l'entrée selon les indices de réfraction (n1, n2), puis le re-plie à la sortie. Coût : il faut traverser l'objet pour trouver le point de sortie. Approche bon marché ici : on **ne plie pas** le rayon, on raymarche juste **l'intérieur** du diamant pour trouver la face arrière, en utilisant `-_diamond(p)` (SDF inversée → positive à l'intérieur).

```glsl
vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    // === Réflexion (étape 11) ===
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    // === Réfraction approximée ===
    vec3 op = p;                        // origine pour mesurer la distance traversée plus tard
    p -= n * 0.05;                      // on se décolle de la surface entrante (sinon on ressort tout de suite)

    vec3 transp = vec3(0.);             // accumulateur de la couleur "vue à travers"
    for (float i = 0.; i < 32.; i++)
    {
        float dist = -_diamond(p);      // SDF inversée : positive à l'intérieur, négative à l'extérieur
        if (dist < 0.01)
        {
            // On vient de sortir de l'autre côté
            transp = vec3(0.2, 0.85, 0.65);   // couleur fixe pour l'instant (verte) ; étape 13 raffinera
            break;
        }
        p += rd * dist;                  // on avance dans l'objet le long de rd (rayon NON plié → c'est l'approximation)
    }
    col += transp;                       // on ajoute la couleur transparente par dessus le reflet
    return col;
}
```

> **Pourquoi `p -= n * 0.05;` ?** Au point de hit, `_diamond(p) ≈ 0`. Si on raymarche tout de suite en utilisant `-_diamond`, le test `dist < 0.01` se déclenche immédiatement (le SDF flotte autour de 0). En se décollant légèrement vers l'intérieur (le long de `-n`), on garantit qu'on est franchement dans l'objet avant de chercher la sortie.

> **Pas besoin de `rand()` ici dans la boucle :** on pourrait perturber `rd` aussi avec une roughness "interne" pour simuler une réfraction floue (effet "verre dépoli"). C'est ce que fait le shader original avec `roughtrans = texture(iChannel2, p.xy * 5.1).x;` — ajoutez-le après les premières expériences.

> **Approximation :** sans `refract()`, on perd l'effet "lentille" (déformation de l'arrière-plan vu à travers). Pour un caillou opaque ou semi-transparent stylisé, c'est invisible. Pour un cristal très clair, ça fait défaut. À l'étape 13 on compense visuellement par une absorption volumétrique colorée.

> **Pourquoi un budget fixe de 32 itérations ?** Un diamant unité a une diagonale de ~3.5 unités. Avec un step moyen de 0.1, on ressort en ~35 itérations max. 32 suffit ; au-delà, c'est qu'on est coincé sur une SDF dégénérée (sortir de la boucle silencieusement vaut mieux qu'un freeze).

---

## Étape 13 — Absorption volumétrique colorée

**Notion :** dans un volume coloré (vitrail, eau, cristal, jade), plus la lumière voyage dans la matière, plus elle est absorbée — typiquement plus dans certaines longueurs d'onde (loi de Beer-Lambert : `I = I0 * exp(-σ * d)`). Ici on stylise :
1. Choisir une teinte de base variant spatialement (mix entre vert et bleu, modulée par la roughness map → veines colorées).
2. Assombrir le bas du diamant (faux GI).
3. **Tirer** la couleur vers une teinte "absorbée" (magenta saturé) avec une courbe Beer-Lambert exponentielle de la **distance traversée** dans l'objet.

```glsl
vec3 getMat(vec3 p, vec3 n, vec3 rd)
{
    // === Réflexion ===
    vec3 refl = reflect(rd, n);
    float rough = texture(iChannel2, p.xy * 0.3).x;
    vec3 offset = (vec3(rand(), rand(), rand()) - 0.5) * rough;
    refl = normalize(refl + offset);
    vec3 col = getEnv(refl);
    col = pow(col, vec3(3.2));

    // === Réfraction + absorption ===
    // Roughness "interne" pour fluer un peu rd dans l'objet (verre dépoli)
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
            // Couleur de base : mix vert↔bleu modulé par la roughness map (veines colorées)
            transp = mix(
                vec3(0.200, 0.851, 0.655),                   // vert
                vec3(0.106, 0.294, 0.804),                   // bleu
                texture(iChannel2, p.xy * 0.2).x             // mix variable par échantillon
            ) * sat(sat(-p.y + 0.5) + 0.3);                  // assombrit le bas du diamant (faux GI)

            // Beer-Lambert : la couleur de base se "remplit" de magenta avec la distance traversée
            transp = mix(
                transp,
                vec3(1., 0., 1.),                            // couleur "absorbée" (= ce qui reste après absorption massive)
                1. - exp(-distance(p, op) * 0.25)            // courbe exponentielle : 0 à d=0, →1 à d→∞
            );
            break;
        }
        p += rd * dist;
    }
    col += transp;
    return col;
}
```

`sat` : penser à `#define sat(a) clamp(a, 0., 1.)` en début de shader.

> **Pourquoi `1 - exp(-d * k)` et pas une rampe linéaire ?** La courbe exponentielle est physiquement plausible (loi d'absorption de Beer-Lambert) et reste élégante : démarre à 0 (pas de teinte au point de sortie immédiat), monte rapidement, sature en douceur. Linéaire produirait des transitions visibles aux discontinuités d'épaisseur (cassures aux arêtes du diamant). Le `0.25` règle la "longueur d'absorption" : plus grand = plus opaque vite.

> **`sat(sat(-p.y + 0.5) + 0.3)` :** double-clamp pour simuler un sky-occlusion grossier qui éteint la base du diamant. C'est de la triche pure ; un vrai pipeline calculerait l'AO ou un sky-occlusion via raymarching d'occlusion.

> **`roughtrans` à fréquence `5.1` :** beaucoup plus haute fréquence que la roughness "externe" (`0.3`) pour un grain interne fin → effet "petites inclusions". À ajuster selon la cubemap utilisée.

---

## Étape 14 — Multi-pass : feedback Image → Buffer A (TAA pauvre)

**Notion :** le glossy (étape 11) + la roughness interne (étape 13) font que chaque frame a du bruit (les samples ne se répètent pas). Pour lisser, on utilise un **feedback temporel** : la passe finale (`Image`) écrit le résultat ; à la frame suivante, `Buffer A` lit cette sortie via `iChannel1` et **mixe à 50%** son rendu courant avec celui d'avant. Effet : moyenne mobile exponentielle des dernières frames → bruit divisé par ~√N, ghosting léger sur les mouvements.

> **Setup Shadertoy :**
> - **Common** : tous les `#define` partagés et les utilitaires (`r2d`, `getCam`, `_min`, `_cube`, `noise`…).
> - **Buffer A** : le shader principal (raymarching + matériau).
>   - iChannel0 = `Noise Medium`
>   - iChannel1 = **Image** (feedback de la frame précédente)
>   - iChannel2 = `Noise Medium`
>   - iChannel3 = `Cubemap`
> - **Image** : passe finale qui peut juste afficher Buffer A (`texture(iChannel0, uv)`), ou faire du post (étape 15). iChannel0 = Buffer A.

### Buffer A (modifications sur étape 13)

```glsl
// ... tout le code de l'étape 13 ...

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;
    _seed = iTime + texture(iChannel0, uv).x;

    // ... raymarching + getMat → col ...

    col = sat(col);    // clamp avant le mix pour éviter de propager des saturations

    // FEEDBACK : on récupère le rendu de la frame précédente (iChannel1 = Image) et on mixe à 50%
    col = mix(col, texture(iChannel1, fragCoord / iResolution.xy).xyz, 0.5);

    fragColor = vec4(col, 1.);
}
```

### Image (passthrough simple pour cette étape)

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);   // iChannel0 = Buffer A
}
```

> **Pourquoi `0.5` ?** Compromis. Plus haut = plus de lissage mais plus de **ghosting** (les mouvements traînent). Plus bas = plus net mais bruit plus visible. `0.5` donne une queue de ~2-3 frames perceptible — acceptable pour ce shader contemplatif. Pour un jeu, on irait plus bas (0.1-0.2) pour que les mouvements rapides ne traînent pas.

> **Risque saturation :** si `col` courant et `iChannel1` ont des pixels >1.0, leur moyenne reste >1.0 et bourre l'accumulateur. D'où le `sat(col)` avant le mix. En HDR / float-buffers, on n'aurait pas ce problème.

> **Equivalent statistique :** un mix `(1-α) * new + α * old` répété est une **moyenne exponentielle** avec poids `α^k` sur la frame d'âge `k`. Avec `α = 0.5`, le poids tombe à 0.5, 0.25, 0.125 → "souvenir" effectif sur ~log₂(1/seuil) frames. Pour un seuil à 5%, ~4 frames.

> **À observer :** désactivez le `mix` (commentez la ligne) → vous verrez le grain "neige TV" du glossy. Réactivez → ça lisse mais les rotations de caméra laissent des traînées (ghosting).

---

## Étape 15 — Post-process : box blur horizontal (anamorphic flare)

**Notion :** dans la passe `Image`, on échantillonne `N` pixels alignés horizontalement autour de chaque pixel et on moyenne → **flou directionnel**. Combiné au glow déjà présent dans Buffer A, ça donne un effet "anamorphose lumineuse" : les hautes lumières s'étirent en traînées horizontales. Look cinéma.

```glsl
#define GLOW_SAMPLES 8
#define GLOW_DISTANCE 0.05

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

        vec2 nuv = uv + vec2(f * GLOW_DISTANCE, 0.);   // offset HORIZONTAL uniquement
        col += texture(iChannel0, nuv).xyz / float(steps);   // iChannel0 = Buffer A
    }
    fragColor = vec4(col, 1.);
}
```

> **Pourquoi horizontal seulement ?** Choix esthétique : évoque les **flares anamorphiques** des objectifs cinéma (les optiques anamorphiques étirent le bokeh horizontalement). Pour un glow rond classique, faites une seconde passe verticale (séparable) : Buffer B = blur vertical de Image, ou inversement.

> **Vrai blur 2D séparable :** `B(I) = By(Bx(I))` — un blur horizontal puis un blur vertical donnent un blur 2D rectangulaire avec un coût `O(2N)` au lieu de `O(N²)`. Le shader original chaîne deux blurs **horizontaux** (Buffer B et Image identiques) — c'est probablement un copier-coller. Pour un vrai flare anisotrope 2D, faites Buffer B horizontal + Image vertical.

> **Tests à faire :**
> - `GLOW_SAMPLES = 32`, `GLOW_DISTANCE = 0.1` → flare exagéré.
> - `GLOW_SAMPLES = 4`, `GLOW_DISTANCE = 0.02` → effet subtil.
> - Remplacer `vec2(f * GLOW_DISTANCE, 0.)` par `vec2(0., f * GLOW_DISTANCE)` → flare vertical.
> - Pondérer par une gaussienne au lieu d'une moyenne uniforme : `weight = exp(-f * f * 4.)` puis normaliser → blur de meilleure qualité visuelle.

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
| 12 | Réfraction approximée : raymarching de la SDF inversée |
| 13 | Absorption volumétrique exponentielle (Beer-Lambert stylisé) |
| 14 | Feedback temporel : Image → Buffer A via iChannel1 (mix 0.5) |
| 15 | Post-process : box blur directionnel (anamorphic flare) |

---

## Pour aller plus loin

- **Vraie réfraction Snell :** remplacer la boucle de l'étape 12 par `refract(rd, n, 1./ior)` à l'entrée et un second hit sortant pour replier `refract(rd, -n, ior)`. Indices typiques : eau ≈ 1.33, verre ≈ 1.5, diamant ≈ 2.42.
- **Dispersion (chromatic aberration) :** appliquer un IOR différent par canal R/G/B → 3 raymarchings → arc-en-ciel.
- **Caustiques :** raymarcher depuis une lumière, stocker dans un buffer photon-map, sampler depuis la scène. Coûteux ; voir les shaders d'IQ.
- **TAA propre :** au lieu d'un `mix(0.5)` aveugle, reprojeter la frame précédente avec les vecteurs de mouvement (motion vectors) pour éviter le ghosting → c'est ce que font les TAA modernes (UE, Frostbite).
- **Bloom physique :** au lieu d'un blur uniforme, bloomer uniquement les pixels au-dessus d'un seuil (`max(col - 1., 0.)`) → flare proportionnel à la luminance HDR.
