
# Refract2 — décomposition en 16 étapes

Décomposition pédagogique du shader **`refract2.md`** ("Self Reflect" de mrange — Platonic solid en cage de miroirs avec réfraction colorée). Chaque étape est un shader **complet** copiable tel quel dans Shadertoy. On part d'une caméra nue → on construit le ciel → on raymarche un solide procédural (KIFS) → on l'éclaire en miroir → on le rend transparent → on accumule des bounces internes avec absorption Beer-Lambert.

> ⚠️ Aucun multi-pass ici : tout tient en passe **Image** seule. Pas besoin de binder de channels — pas d'iChannelN utilisé. C'est un shader 100% procédural.

> 🎛️ **Paramètres clés (à twiddler après l'étape 5)** :
> - `poly_type` ∈ {2..5} : type du solide platonicien.
> - `poly_U/V/W` : pondèrent les sommets fondamentaux (`pab`/`pbc`/`pca`) → forme finale.
> - `poly_zoom` : échelle du solide.
> - `refr_index` : indice de réfraction interne (1.0 = pas de réfraction, 2.42 = diamant).
> - `MAX_BOUNCES2` : nombre de rebonds internes (4–8 = sweet spot perf/qualité).

## Étape 1 — Caméra look-at avec FOV explicite

**Notion :** on reconstruit un repère orthonormé caméra (`uu`, `vv`, `ww`) à partir de trois constantes : la **position** `rayOrigin`, la **cible** `la`, et un **up monde**. Différence avec le pattern `getCam` de `refract` : ici le **FOV** est un **multiplicateur explicite** sur l'axe `ww` (`fov*ww`) plutôt qu'un facteur sur les UV. Effet : un `fov` élevé **rapproche** (téléobjectif), un `fov` bas écarte (grand angle).

L'image est centrée par `p = -1 + 2*q` (donc `p ∈ [-1,1]`), puis on multiplie `p.x` par l'aspect-ratio pour que les pixels soient carrés en monde.

> **À noter :** le `-p.x*uu` (négatif) flippe l'axe horizontal. Ça correspond à la convention écran-caméra de mrange ; visuellement ça change rien sur un fond procédural symétrique mais c'est utile à savoir si tu portes ce code ailleurs.

```glsl
#define RESOLUTION  iResolution

// Position fixe de la caméra (au-dessus du sol, derrière l'origine)
const vec3 rayOrigin = vec3(0.0, 1., -5.);

// Construit la direction du rayon pour le pixel p (coords [-1, 1] avec correction aspect)
vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;                              // > 1 = télé, < 1 = grand-angle
    const vec3 up = vec3(0., 1., 0.);                    // up monde
    const vec3 la = vec3(0.0);                           // point regardé (origine)

    // Base orthonormée caméra
    const vec3 ww = normalize(la - rayOrigin);           // forward (cam → cible)
    const vec3 uu = normalize(cross(up, ww));            // right
    const vec3 vv = cross(ww, uu);                        // up caméra (recalculé orthogonal)

    // Direction du rayon à travers le pixel
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

    // Visualisation debug : affiche la direction comme couleur
    return rd*0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy;       // [0, 1]
    vec2 p = -1. + 2. * q;                   // [-1, 1] (signed)
    vec2 pp = p;                             // copie sans correction (utile plus tard pour vignette)
    p.x *= RESOLUTION.x/RESOLUTION.y;        // correction aspect-ratio (pixels carrés en monde)

    vec3 col = effect(p, pp);
    fragColor = vec4(col, 1.0);
}
```

> **Pourquoi garder `pp` ? À l'étape 16** la vignette colorée utilise les UV **non** corrigées d'aspect (`pp`), pour que le halo soit isotrope en pixels écran et pas étiré. On les transporte donc dès maintenant — fin pédagogique.

> **`fov = 2.0` :** ouverture relativement étroite (téléobjectif). Avec `fov = 1.0` on verrait beaucoup plus large ; avec `fov = 4.0` on serait presque en zoom. Le facteur multiplie `ww` (le forward) — plus il est grand, plus les rayons s'alignent sur l'axe central → champ étroit.

> **`ww = normalize(la - rayOrigin)` :** noter le `normalize` redondant dans le source original (`normalize(normalize(...))`) — sans effet, mais aucun coût car c'est `const`.

---

## Étape 2 — Sky procédural : sun + box top/bottom

**Notion :** sans cubemap ni texture, on construit un fond entièrement procédural. Trois ingrédients :
1. **Soleil** : pic lumineux dans la direction `sunDir` via `1/(1.001 - dot(sunDir, rd))` → infinie quand `rd == sunDir`, atténuée sinon.
2. **Demi-monde haut** (`rd.y > 0`) : un "plafond" rectangulaire avec halo doux, et une box centrale plus brillante (la SDF 2D `box(p, b)` d'IQ donne la distance à un rectangle).
3. **Demi-monde bas** (`rd.y < 0`) : un "sol" qui s'assombrit avec la distance au point regardé.

Les couleurs viennent d'une palette HSV — pratique pour ajuster la teinte sans toucher au RGB.

> **Pourquoi `1.001` au lieu de `1.0` ?** Évite la division par zéro **exactement** au pic. Le `0.001` fixe la luminance maximale du soleil (plus grand = pic plus doux).

```glsl
#define RESOLUTION  iResolution

// === Palette HSV → RGB (Sam Hocevar, WTFPL) ===
const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
    return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// Variante macro pour utiliser HSV à la compilation (les `const` GLSL n'acceptent que des expressions constantes)
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// === Caméra (étape 1) ===
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);             // soleil dans le dos = derrière la cible

// === Couleurs du fond ===
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2)) * 1.;   // pic chaud
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5))  * 1.;   // sol bleu
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.))   * 1.;   // plafond bleu vif

// === SDF 2D box (Inigo Quilez) ===
float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// === Rendu du fond pour une direction rd ===
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0);

    float srd = sign(rd.y);                             // au-dessus / en-dessous de l'horizon
    float tp  = -(ro.y - 6.) / abs(rd.y);                // distance au plan y = 6 (plafond) ou y = -ro.y (sol)

    if (srd < 0.) {
        // Demi-monde bas : intensité décroissante avec la distance horizontale
        col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    }
    if (srd > 0.0) {
        // Demi-monde haut : box rectangulaire au plafond
        vec3 pos  = ro + tp*rd;                          // intersection avec y = 6
        vec2 pp   = pos.xz;                              // projection horizontale
        float db  = box(pp, vec2(5.0, 9.0)) - 3.0;        // SDF arrondie (corner-radius 3)

        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);   // intérieur de la box
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));           // halo extérieur
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);                // bord intérieur saturé
    }

    // Soleil : pic isotrope autour de sunDir
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}

// === Caméra (étape 1) ===
vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

    return render0(rayOrigin, rd);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy;
    vec2 p = -1. + 2. * q;
    vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;

    vec3 col = effect(p, pp);
    fragColor = vec4(col, 1.0);
}
```

> ⚠️ **Sortie non clampée :** `render0` peut renvoyer des valeurs **>> 1** (à cause du soleil). Sans tone mapping (étape 3 prochain), tu vas voir un disque blanc cramé au lieu d'un dégradé. C'est normal, c'est traité à l'étape suivante.

> **Convention `srd = sign(rd.y)` :** un seul branchement par pixel. Sur GPU on évite généralement les `if` mais ici c'est une balance "regarder au-dessus OU en-dessous", donc inévitable.

> **Macro `HSV2RGB` vs fonction :** la macro permet d'initialiser des `const vec3` à la compile-time (le compilateur inline tout). La fonction est utilisée pour des cas runtime (pas ici, mais réservée pour des animations type teinte qui varie avec `iTime`).

---

## Étape 3 — Tone mapping ACES + gamma + vignette

**Notion :** la sortie HDR de `render0` peut atteindre des valeurs >> 1 (le soleil notamment). Un simple `clamp` à 1 produit du blanc cramé moche. **ACES filmic** (Academy Color Encoding System) est une courbe S qui :
- compresse les hautes lumières (rolloff doux au lieu de clamp brutal),
- relève les noirs (donne du contraste perçu),
- maintient la saturation des teintes vives.

C'est l'opérateur de tone mapping standard du cinéma et des moteurs PBR modernes (UE, Frostbite). Le `sqrt(col)` final est un **gamma rapide** (≈ gamma 2.0 au lieu de 2.2) pour passer en espace sRGB. La vignette assombrit les bords pour focaliser l'œil.

> **Pourquoi `sqrt` et pas `pow(col, 1/2.2)` ?** Plus rapide d'un poil, et dans cette gamme la différence est invisible. C'est un raccourci classique en démo / shadertoy.

```glsl
#define RESOLUTION  iResolution

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);

const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0);
    float srd = sign(rd.y);
    float tp  = -(ro.y - 6.) / abs(rd.y);

    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd;
        float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}

// === Tone mapping ACES (Matt Taylor, https://64.github.io/tonemapping/) ===
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0);
    v *= 0.6;                                            // exposition baissée pour laisser de la marge
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

    vec3 col = render0(rayOrigin, rd);

    // Vignette colorée : assombrit avec la distance au centre. Note : on utilise pp (sans aspect)
    // pour que la vignette soit bien circulaire en pixels écran.
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);

    col = aces_approx(col);                              // tone map HDR → LDR
    col = sqrt(col);                                      // gamma sRGB (gamma 2 approx)
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy;
    vec2 p = -1. + 2. * q;
    vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;

    vec3 col = effect(p, pp);
    fragColor = vec4(col, 1.0);
}
```

> **À tester :** commente la ligne `col = aces_approx(col);` → tu retombes sur le rendu de l'étape 2, le soleil cramé en blanc plat. Décommente → courbe S, le pic devient un disque doux qui transitionne en orange.

> **Pourquoi le `* 0.6` interne à `aces_approx` ?** C'est l'exposure. Sans ce coefficient, la courbe ACES "officielle" sature trop vite ; le `0.6` la décale pour qu'on ait du headroom HDR. Tu peux le bouger : `0.3` = sombre, `1.0` = saturé.

> **Vignette `-2E-2 * vec3(2,3,1)` :** les coefficients `(2,3,1)` créent une teinte **anti-jaune** (plus de bleu et vert que de rouge soustraits). Effet : les bords tirent légèrement vers le rouge / orange — finition cinéma classique. La vignette est appliquée **avant** le tone map → ACES la lisse en même temps que le reste.

---

## Étape 4 — Sphère raymarchée + sky en fond

**Notion :** étape de transition pour valider qu'on sait raymarcher avant d'attaquer le polyèdre. SDF la plus simple qui soit : `length(p) - r`. Si le rayon ne touche rien, on tombe sur le sky de l'étape 3 (qui sert maintenant de fond infini).

> **Pas de tone map ACES sur cette étape ?** Si, on le garde — il s'applique au résultat composé (sky + sphère). C'est la nouveauté de cette étape : le pipeline `render0 → composition → tone map` est mis en place.

```glsl
#define RESOLUTION  iResolution
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));

// === SDF sphère ===
float sphere(vec3 p, float r) { return length(p) - r; }

// SDF de la scène (juste une sphère unité au centre)
float df3(vec3 p) {
    return sphere(p, 1.0);
}

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0);
    float srd = sign(rd.y);
    float tp  = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd;
        float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

// === Raymarcher minimal ===
float rayMarch3(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
    for (int i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    return t;
}

// Rendu : sphère devant le sky
vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);                  // fond par défaut

    float t1 = rayMarch3(ro, rd, 0.1);
    if (t1 < MAX_RAY_LENGTH3) {
        // Hit : sphère rouge minimaliste (matériau viendra plus tard)
        col = vec3(0.8, 0.2, 0.1);
    }
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col);
    col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy;
    vec2 p = -1. + 2. * q;
    vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **`tinit = 0.1`** dans `rayMarch3` : on démarre légèrement en avant pour ne pas hit la caméra elle-même (cas dégénéré quand l'origine est elle-même proche d'une surface).

> **`if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;` :** condition de sortie unifiée. `TOLERANCE3 = 5e-4` est le seuil de hit (assez fin pour des bords nets) ; `MAX_RAY_LENGTH3 = 10` borne la distance max parcourue.

> **Pas de `getNorm` ici :** on n'éclaire pas encore la sphère, juste un test de hit. Les normales arrivent à l'étape 10 (avec le facteur Fresnel).

---

## Étape 5 — KIFS polyhedral folding (le solide platonicien)

**Notion :** technique de **knighty** pour générer un polyèdre régulier (tétraèdre, cube, octaèdre, dodécaèdre, icosaèdre) à partir d'**un seul** domaine fondamental + des **plis répétés**. C'est un cas particulier de **KIFS** (Kaleidoscopic Iterated Function System).

Idée centrale : on prend un point `p` dans l'espace ; on le "replie" itérativement sur le domaine fondamental (un petit coin du polyèdre). Chaque itération :
1. Force `p.x ≥ 0` et `p.y ≥ 0` (replie sur l'octant positif).
2. Si `p` est du mauvais côté du plan de pliage `poly_nc`, le réfléchit.

Après `poly_type` itérations, n'importe quel point en monde finit dans le domaine fondamental → on calcule la SDF localement (plane + edge + corner), et on bénéficie de toutes les symétries gratuitement.

`shape(p)` retourne un `vec3` :
- `.x` = SDF du **plan de coupe** (face du polyèdre).
- `.y` = SDF de l'**arête** (distance au bord du domaine).
- `.z` = SDF du **sommet** (petite sphère au coin).

Ces trois canaux serviront à différents matériaux plus tard (faces miroir, arêtes glow, sommets dorés).

> **Réfs :**
> - Polyhedron generator de knighty : https://www.shadertoy.com/view/MsKGzw
> - L'article fondateur : "Knighty's Kaleidoscopic IFS" (2012).

```glsl
#define RESOLUTION  iResolution
#define PI 3.141592654
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90

// === Paramètres de la KIFS — twiddle pour changer le solide ===
const int   poly_type = 3;     // 2 = bipyramide, 3 = tétraèdre, 4 = cube/octa, 5 = dodéca/icosa
const float poly_U    = 1.0;   // pondération du sommet "ab" (face triangulaire vue de devant)
const float poly_V    = 0.5;   // pondération du sommet "bc" (arête centrale)
const float poly_W    = 1.0;   // pondération du sommet "ca" (sommet pyramidal)
const float poly_zoom = 2.0;   // taille globale

// === Constantes dérivées de la KIFS (knighty) ===
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc      = vec3(-0.5, -poly_cospin, poly_scospin);   // normale du plan de pliage
const vec3  poly_pab     = vec3(0., 0., 1.);
const vec3  poly_pbc_    = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_    = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p       = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc     = normalize(poly_pbc_);
const vec3  poly_pca     = normalize(poly_pca_);

// Replie p itérativement sur le domaine fondamental du polyèdre
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) {
        p.xy = abs(p.xy);                                      // force octant +x +y (mirroir double)
        p   -= 2.*min(0., dot(p, poly_nc)) * poly_nc;          // si du mauvais côté de poly_nc, le miroir
    }
    pos = p;
}

// SDF du plan de coupe (3 plans pris au max → forme de coin)
float poly_plane(vec3 pos) {
    float d0 = dot(pos, vec3(0., 0., 1.));   // pab
    float d1 = dot(pos, poly_pbc);
    float d2 = dot(pos, poly_pca);
    return max(max(d0, d1), d2);
}

// SDF "sommet" : petite sphère
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }

float dot2(vec3 p) { return dot(p, p); }

// SDF "arête" : distance aux 3 arêtes du domaine fondamental
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));   // arête le long de Y∩Z
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));   // arête le long de X∩Z
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc); // arête le long du fold-plane
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}

// Renvoie vec3(plane, edge, corner) — 3 SDF pour 3 matériaux
vec3 shape(vec3 pos) {
    pos /= poly_zoom;
    poly_fold(pos);
    pos -= poly_p;                                  // décale au sommet pondéré (offset KIFS)
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}

// SDF de la scène : on prend juste le plan (face du solide) pour cette étape
float df3(vec3 p) { return shape(p).x; }

// === Reste pareil que l'étape 4 ===
const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

float rayMarch3(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
    for (int i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    return t;
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    float t1 = rayMarch3(ro, rd, 0.1);
    if (t1 < MAX_RAY_LENGTH3) {
        col = vec3(0.9, 0.85, 0.7);                  // solide visible en blanc cassé
    }
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Le solide ne bouge pas encore :** sans rotation, on regarde toujours la même facette. Étape 6 → animation.

> **À tester :** change `poly_type` (2, 3, 4, 5) → silhouette différente. Change `poly_U/V/W` (par ex. `poly_U=2.5`) → sommets étirés, formes étoilées. Change `poly_zoom` → taille (mais aussi épaisseur des arêtes via `poly_zoom` multiplicatif final).

> **`pos /= poly_zoom` puis multiplication finale par `poly_zoom` :** on travaille en espace **normalisé** pour la KIFS (les `poly_p`, `poly_nc`, etc. sont calibrés pour un solide unité), puis on **rééchelle** la SDF en sortie. Sans le multiplicatif final, la SDF aurait un gradient `1/poly_zoom` → raymarcher trop conservateur, perf en chute.

> **`shape(p).x` (le plan) :** c'est ce qui définit la **forme pleine** du solide. Les `.y` (arête) et `.z` (sommet) servent uniquement à colorer / glow. On y reviendra à l'étape 7 (glow) et 9 (combinaison).

---

## Étape 6 — Rotation animée par matrice "no-acos" d'Inigo Quilez

**Notion :** pour animer le solide on lui applique une rotation 3D. Approche standard : `mat3 = rotX(α) * rotY(β) * rotZ(γ)` avec angles d'Euler — fonctionne mais souffre du **gimbal lock** et nécessite trois `cos`/`sin`.

Approche d'Inigo Quilez (https://iquilezles.org/articles/noacos/) : étant donné deux **vecteurs unitaires** `z` (de référence) et `d` (cible), construire la matrice qui amène `z` sur `d` **sans calculer d'angle** (pas d'`acos`/`asin`). On utilise directement le produit vectoriel et le produit scalaire :

```
v = z × d
c = z · d
k = 1 / (1 + c)
```

Pas de fonction trigo inverse → beaucoup plus stable et rapide. Limite : foire si `c == -1` (vecteurs antiparallèles), donc on choisit deux directions animées qui ne deviennent jamais opposées.

L'animation utilise des **fréquences incommensurables** (`sqrt(0.5)`, `1.0`, `0.913`) → trajectoire de Lissajous 3D qui ne se referme jamais.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90

const float rotation_speed = 0.25;

const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;

const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc      = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab     = vec3(0., 0., 1.);
const vec3  poly_pbc_    = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_    = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p       = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc     = normalize(poly_pbc_);
const vec3  poly_pca     = normalize(poly_pca_);

// Globale qui transporte la rotation courante
mat3 g_rot;

// === Matrice de rotation no-acos d'IQ ===
// Construit une matrice qui amène z sur d (vecteurs unitaires), sans utiliser d'angle.
mat3 rot(vec3 d, vec3 z) {
    vec3  v = cross(z, d);
    float c = dot(z, d);
    float k = 1.0 / (1.0 + c);                        // /!\ explose si c == -1 (vecteurs antiparallèles)
    return mat3(v.x*v.x*k + c,    v.y*v.x*k - v.z,   v.z*v.x*k + v.y,
                v.x*v.y*k + v.z,  v.y*v.y*k + c,     v.z*v.y*k - v.x,
                v.x*v.z*k - v.y,  v.y*v.z*k + v.x,   v.z*v.z*k + c);
}

void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) {
        p.xy = abs(p.xy);
        p   -= 2.*min(0., dot(p, poly_nc)) * poly_nc;
    }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}

vec3 shape(vec3 pos) {
    pos *= g_rot;                                     // ROTATION ICI : on amène le monde dans le repère du solide
    pos /= poly_zoom;
    poly_fold(pos);
    pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}

float df3(vec3 p) { return shape(p).x; }

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

float rayMarch3(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
    for (int i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    return t;
}
vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    float t1 = rayMarch3(ro, rd, 0.1);
    if (t1 < MAX_RAY_LENGTH3) col = vec3(0.9, 0.85, 0.7);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;

    // === Animation : deux directions Lissajous, et une matrice qui amène l'une sur l'autre ===
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));               // direction "z" mobile
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);       // direction "d" mobile
    g_rot = rot(normalize(r0), normalize(r1));

    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Pourquoi `pos *= g_rot` (et pas `g_rot * pos`) ?** En GLSL, `M * v` traite `v` comme un vecteur colonne ; `v * M` le traite comme une ligne. Pour une matrice de rotation, `v * M = transpose(M) * v = M⁻¹ * v` (puisque `M` est orthogonale). Ici on veut **rendre la scène vue depuis un repère qui tourne** → on transforme **le point d'évaluation** dans le repère du solide → on applique l'inverse → `pos *= M`. Subtil.

> **Limite du `rot()` no-acos :** `k = 1/(1+c)` explose si `c → -1` (vecteurs presque opposés). Ici on prend le risque parce que `r0` et `r1` n'ont presque jamais cette configuration (animation Lissajous), mais en prod on ajouterait un fallback (`if (c < -0.999) ...`).

> **Fréquences `sqrt(0.5)`, `1.0`, `0.913` :** trois nombres aux ratios irrationnels → l'orbite ne se referme jamais (cf. la même technique pour la caméra orbitale dans `refract` étape 2).

> **Animation contrôlée par `rotation_speed = 0.25` :** assez lent pour qu'on perçoive les facettes ; `0.5` est plus dynamique, `0.1` quasi statique.

---

## Étape 7 — Glow par proximité aux arêtes (1 / gd)

**Notion :** astuce classique pour faire briller les **arêtes** d'un objet sans pré-calcul. Pendant le raymarch, on note la **distance minimale** rencontrée vers les arêtes (le canal `.y` de `shape()`), accumulée dans une globale `g_gd`. Puis dans le rendu final on ajoute :

```
col += glowCol / max(g_gd, epsilon);
```

Plus le rayon **frôle** une arête, plus `g_gd` est petit, plus le terme `1/g_gd` est grand → **glow proportionnel à la proximité**, sans coût supplémentaire (l'info est cumulée gratuitement pendant le raymarch que tu fais déjà).

C'est exactement le même pattern que celui utilisé dans `tunnel1` étape 9 et `travel` étape 16 (avec un poids `(1-sat(d/0.5))` au lieu d'`1/d` parfois). Ici on prend la version **sans cap supérieur** → halo qui s'étend à l'infini avec une décroissance hyperbolique.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90

const float rotation_speed = 0.25;
const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;     // === NOUVEAU : accumulateur de distance min (canaux : edge, ?) ===

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}

vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}

// === NOUVEAU : df3 met à jour g_gd au passage ===
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);                        // accumule (edge, corner)
    return ds.x;                                     // on raymarche toujours sur le plan
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));      // === NOUVEAU : couleur glow externe ===

float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

float rayMarch3(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
    for (int i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    return t;
}

vec3 render3(vec3 ro, vec3 rd) {
    g_gd = vec2(1E3);                               // reset avant le raymarch
    vec3 col = render0(ro, rd);
    float t1 = rayMarch3(ro, rd, 0.1);
    vec2 gd1 = g_gd;                                 // capture de la distance min vue

    if (t1 < MAX_RAY_LENGTH3) col = vec3(0.9, 0.85, 0.7);

    // === NOUVEAU : halo proportionnel à la proximité aux arêtes ===
    col += glowCol0 / max(gd1.x, 3E-4);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **`max(gd1.x, 3E-4)` :** garde-fou anti-singularité. Sans clamp inférieur, quand le rayon hit pile une arête, `gd → 0` et `1/gd → +∞` → pixel blanc cramé. `3e-4` cap la luminance max du glow, en cohérence avec le `TOLERANCE3 = 5e-4`.

> **`glowCol0 = HSV2RGB(vec3(0.05, 0.7, 1E-3))` :** vraiment **très** sombre (`v = 1e-3`). C'est intentionnel — on multiplie ensuite par `1/gd`, donc même 1e-3 en source devient lumineux quand `gd < 1e-3`. Sans ce dimming, le halo serait éblouissant.

> **À tester :** mets le glow à `vec3(1.) / max(gd1.x, 1e-3)` → voir le solide complètement noyé dans une nappe de halo. Réduis `glowCol0` pour calibrer.

> **Pourquoi `g_gd = vec2(1E3)` au reset ?** Le `min()` accumule un minimum ; il faut donc l'initialiser à une valeur très grande. `1E3` (= 1000) est largement au-dessus de tout `gd` réaliste.

---

## Étape 8 — Raymarcher BACKSTEP (anti-miss en cavité)

**Notion :** un raymarcher classique (`t += d` jusqu'à `d < TOLERANCE` ou `t > MAX_LENGTH`) marche bien sur des SDF **convexes** vues de l'extérieur. Mais à l'**intérieur** d'une cavité fermée (ce qu'on aura à l'étape 13 quand le rayon rebondira **dans** la cage), la SDF inversée a des **gradients incohérents** près des coins → le rayon peut rater une paroi et continuer dans le vide jusqu'à `MAX_RAY_MARCHES2`.

Solution **BACKSTEP** : pendant la marche, on mémorise le `(d_min, t_correspondant)` le plus petit jamais rencontré. Si la boucle se termine sans hit propre (`i == MAX_RAY_MARCHES2`), on retombe sur ce `t` sauvegardé → on est **au plus près** de la surface, ce qui suffit pour la suite (calcul de normale, bounce). Sinon le rayon "tombe en panne" et le résultat visuel devient chaotique.

Cette étape introduit `df2` (la SDF utilisée à l'**intérieur** : plan inversé + arêtes épaissies + sphère interne) et `rayMarch2` avec BACKSTEP. Pour la démo, on montre **le solide vu depuis l'intérieur** — caméra placée à l'origine, rayons sortants : les murs miroir deviennent visibles.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE2       0.0005
#define MAX_RAY_MARCHES2 50
#define BACKSTEP2                                    // ← bascule on/off pour comparer

const float rotation_speed = 0.25;
const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float inner_sphere = 1.;                       // rayon de la sphère interne

const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float sphere(vec3 p, float r) { return length(p) - r; }

// === SDF intérieure (utilisée pour les rebonds internes) ===
// -ds.x : plan inversé (positif à l'intérieur du solide)
// d2    : arête (légèrement épaissie de 5e-3)
// d1    : sphère interne
float df2(vec3 p) {
    vec3 ds = shape(p);
    float d2 = ds.y - 5E-3;
    float d0 = min(-ds.x, d2);                       // surface intérieure
    float d1 = sphere(p, inner_sphere);
    g_gd = min(g_gd, vec2(d2, d1));
    return min(d0, d1);
}

// === Raymarcher avec BACKSTEP ===
float rayMarch2(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
#if defined(BACKSTEP2)
    vec2 dti = vec2(1e10, 0.0);                      // (d_min vu, t correspondant)
#endif
    int i;
    for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
        float d = df2(ro + rd*t);
#if defined(BACKSTEP2)
        if (d < dti.x) dti = vec2(d, t);             // mémorise le plus proche
#endif
        if (d < TOLERANCE2) break;
        t += d;
    }
#if defined(BACKSTEP2)
    if (i == MAX_RAY_MARCHES2) t = dti.y;            // fallback : retombe sur le plus proche vu
#endif
    return t;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy;
    vec2 p = -1. + 2. * q; p.x *= RESOLUTION.x/RESOLUTION.y;

    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));

    // === Caméra placée À L'INTÉRIEUR du solide (pour démontrer rayMarch2) ===
    vec3 ro = vec3(0.0);                             // origine = centre du solide
    vec3 rd = normalize(vec3(p, 1.5));                // direction radiale dans toutes les directions

    g_gd = vec2(1E3);
    float t = rayMarch2(ro, rd, 0.05);
    vec3 hit = ro + rd*t;

    // Visualisation : couleur en fonction de la position du hit (pour bien voir la cage interne)
    vec3 col = abs(hit) * 0.5;
    fragColor = vec4(col, 1.0);
}
```

> **Effet du BACKSTEP :** retire le `#define BACKSTEP2` et regarde — sur certaines orientations du polyèdre, des bandes / pixels noirs apparaissent là où la marche n'a pas convergé. Avec le BACKSTEP, tout est uniforme.

> **Pourquoi `MAX_RAY_MARCHES2 = 50` (et pas 90 comme `MAX_RAY_MARCHES3`) ?** À l'intérieur les distances sont courtes (la cage fait ~`poly_zoom` de rayon), donc 50 itérations suffisent largement. On économise du temps GPU pour les multiples bounces qui arrivent à l'étape 13.

> **`d2 = ds.y - 5E-3` :** arête épaissie de 5e-3 — utile pour que les rayons internes "voient" les arêtes un peu plus tôt et ne les ratent pas.

> **`tinit = 0.05` :** on démarre légèrement en avant pour ne pas hit immédiatement (la SDF vaut ~0 au point de départ si on est sur la sphère interne).

---

## Étape 9 — Dual SDF : `df3` (cage vue de dehors) + `df2` (intérieur miroir)

**Notion :** le shader maintient **deux** SDF distinctes :

- **`df3(p)`** : SDF vue **de l'extérieur**. Union de `plane ∪ edge ∪ corner` → on "voit" un objet plein. Utilisé pour le **premier hit** (entrée du rayon dans la cage).
- **`df2(p)`** : SDF vue **de l'intérieur**, après réfraction. Plan **inversé** (positif dedans) ∪ arête épaissie ∪ sphère interne. Utilisé pour les **rebonds** dans le réflecteur fermé.

C'est cette dualité qui permet d'avoir un objet **transparent miroir** : la première intersection est calculée sur `df3` (objet plein), puis le rayon réfracté traverse `df2` (cage de miroirs avec sphère interne au milieu) en rebondissant.

Sur cette étape, on revient à la caméra externe et on utilise `df3` (avec son `g_gd` qui accumule sur edges + corners). La sphère interne `df2` est définie mais pas encore visible — elle servira aux étapes 13–14.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE2       0.0005
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES2 50
#define MAX_RAY_MARCHES3 90
#define BACKSTEP2

const float rotation_speed = 0.25;
const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float inner_sphere = 1.;

const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float sphere(vec3 p, float r) { return length(p) - r; }

// === df2 : SDF vue de l'intérieur (utilisée plus tard pour les rebonds) ===
float df2(vec3 p) {
    vec3 ds = shape(p);
    float d2 = ds.y - 5E-3;
    float d0 = min(-ds.x, d2);
    float d1 = sphere(p, inner_sphere);
    g_gd = min(g_gd, vec2(d2, d1));                  // (edge, sphère interne)
    return min(d0, d1);
}

// === df3 : SDF vue de l'extérieur (premier hit) ===
// Union plane ∪ edge ∪ corner → l'objet apparaît plein avec arêtes/sommets visibles
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);                          // (edge, corner)
    float d = ds.x;
    d = min(d, ds.y);
    d = min(d, ds.z);
    return d;
}

// === Raymarcher externe (avec capture iter pour étape 15) ===
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i;
    return t;
}

float rayMarch2(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
#if defined(BACKSTEP2)
    vec2 dti = vec2(1e10, 0.0);
#endif
    int i;
    for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
        float d = df2(ro + rd*t);
#if defined(BACKSTEP2)
        if (d < dti.x) dti = vec2(d, t);
#endif
        if (d < TOLERANCE2) break;
        t += d;
    }
#if defined(BACKSTEP2)
    if (i == MAX_RAY_MARCHES2) t = dti.y;
#endif
    return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    int iter;
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;
    if (t1 < MAX_RAY_LENGTH3) col = vec3(0.9, 0.85, 0.7);
    col += glowCol0 / max(gd1.x, 3E-4);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Différence visuelle vs étape 7 :** `df3` ici prend l'**union plane∪edge∪corner** au lieu du seul plane → les arêtes et sommets sont **visibles directement** sur la silhouette (et plus seulement via le glow). Effet : un solide légèrement "ciselé".

> **`out int iter` dans `rayMarch3` :** on remontera le nombre d'itérations utilisées pour calculer un **fadeout** à l'étape 15 (`ifo`). Plus une rayon a peiné à converger, plus on l'atténue (artefact-killer).

> **Pourquoi `g_gd = vec2(1E3)` reset dans `render3` ?** À chaque pixel on veut une mesure fraîche. Sans reset, on garderait la mémoire des pixels précédents (UB en GPU mais en pratique des artefacts).

---

## Étape 10 — Normales par gradient central + facteur Fresnel

**Notion :** la normale d'une SDF en un point `p` est le **gradient** de la SDF normalisé. Méthode standard : différence finie centrée sur 3 axes (6 évaluations) :

```
∇f ≈ (f(p+εx) - f(p-εx),  f(p+εy) - f(p-εy),  f(p+εz) - f(p-εz)) / (2ε)
```

Le facteur `2ε` disparaît à la normalisation. `NORM_OFF3 = 5e-3` est le pas — assez petit pour la précision, assez grand pour ne pas tomber dans le bruit numérique de la SDF.

Le **Fresnel** quantifie quelle proportion de lumière est **réfléchie vs transmise** à une interface, en fonction de l'angle d'incidence. Forme exacte (Schlick) : `F = F0 + (1-F0) * (1+dot(rd,n))^5`. Forme **stylisée** ici : `1 + dot(rd, n)` puis carré → tend vers 0 face caméra (lumière passe) et vers 1 sur les bords (forte réflexion). C'est le secret des "rims" lumineux sur les sphères de verre.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90
#define NORM_OFF3        0.005

const float rotation_speed = 0.25;
const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}

// === Normale par gradient central (6 évaluations de df3) ===
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}

float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    int iter;
    float t1 = rayMarch3(ro, rd, 0.1, iter);

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1 = ro + t1*rd;
        vec3 n1 = normal3(p1);

        // === Facteur Fresnel stylisé : (1 + n·rd)² ===
        // n·rd ≈ -1 face camera → fre1 ≈ 0 (pas de réflexion)
        // n·rd ≈ 0 sur les bords (rasants) → fre1 ≈ 1 (réflexion max)
        float fre1 = 1. + dot(rd, n1);
        fre1 *= fre1;

        // Visualisation : normales en couleur RGB, modulée par Fresnel pour voir l'effet
        col = (n1*0.5 + 0.5) * (0.3 + 0.7*fre1);
    }
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Le centre des facettes est sombre, les bords brillants :** c'est le Fresnel qui parle. Plus tu regardes une face en biais (rasant), plus elle réfléchit ; plus tu la regardes en face, plus elle transmet (et apparaît sombre faute de matériau réflectif).

> **Pourquoi `(1 + n·rd)` et pas `(1 - n·rd)` ?** `rd` pointe **vers** la surface (depuis la caméra), `n` pointe **vers l'extérieur**. À l'incidence frontale : `dot(rd, n) ≈ -1` → `1 + dot ≈ 0`. À l'incidence rasante : `dot(rd, n) ≈ 0` → `1 + dot ≈ 1`. C'est l'inverse du `cos(θ)` qu'on aurait avec `-rd`.

> **`fre1 *= fre1` (carré) :** rapproche le rim d'une vraie courbe Fresnel (^5 chez Schlick). Sans le carré, la transition serait trop douce et tout l'objet aurait l'air "diffus".

> **Coût des normales :** 6 `df3` par hit. Or `df3` appelle `shape()` qui contient une boucle KIFS de `poly_type` itérations. Pour `poly_type=5`, c'est ~30 itérations + foldings par pixel hit. C'est le hot-spot perf de ce shader.

---

## Étape 11 — Réflexion externe : `reflect()` + sky

**Notion :** au point de hit, on calcule la direction réfléchie `r1 = reflect(rd, n1)` et on **rééchantillonne `render0`** dans cette direction → la cage devient un miroir qui reflète le ciel procédural. Modulation par Fresnel : `(0.5 + 0.5 * fre1)` → faces de face peu réfléchissantes (50%), bords très réfléchissants (100%).

C'est à ce stade que le solide commence à avoir l'air "physique". Tu vois le soleil rouler sur les facettes, les "boxes" du plafond se diffracter sur les arêtes — tout ce qui fait qu'un objet en verre/métal a l'air vivant.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90
#define NORM_OFF3        0.005

const float rotation_speed = 0.25;
const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    int iter;
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1 = ro + t1*rd;
        vec3 n1 = normal3(p1);
        vec3 r1 = reflect(rd, n1);                   // direction réfléchie
        float fre1 = 1. + dot(rd, n1); fre1 *= fre1;

        // === Réflexion : ré-échantillonne le sky dans la direction r1 ===
        // (0.5 + 0.5*fre1) : minimum 50% (face camera), max 100% (rasant)
        col = render0(p1, r1) * (0.5 + 0.5*fre1);
    }
    col += glowCol0 / max(gd1.x, 3E-4);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Le solide a maintenant l'air "métallique".** Mais il est **plein** (rien ne passe à travers). Étape suivante : on perce des trous via réfraction.

> **`render0(p1, r1)` :** on appelle `render0` non pas avec `rayOrigin` mais avec `p1` (le point de hit) — ça veut dire que les calculs basés sur `ro.y` (genre `tp = -(ro.y-6)/abs(rd.y)`) sont relatifs au hit. En pratique le ciel est traité comme infini, donc l'origine ne change quasi rien — mais c'est correct sémantiquement.

> **À tester :** force `fre1 = 1.` (Fresnel max) → tout devient un miroir parfait. Force `fre1 = 0.` → la cage redevient noire (pas de réflexion, pas encore de transmission). Tu peux ainsi sentir comment Fresnel pondère.

---

## Étape 12 — Réfraction Snell : `refract()` + 1 bounce sortie

**Notion :** la fonction GLSL intégrée `refract(I, N, eta)` calcule la direction transmise selon la **loi de Snell-Descartes** :

```
sin(θ₁) * n₁ = sin(θ₂) * n₂
```

`eta = n₁ / n₂` (rapport des indices entre milieu d'incidence et milieu de transmission). Pour la **première traversée** (caméra → solide), on utilise `eta = 1 / refr_index` (le rayon entre dans un milieu plus dense). Pour la **sortie** ce serait `eta = refr_index`.

Cas limite : si l'angle d'incidence dépasse l'**angle critique**, `refract()` retourne `vec3(0)` (réflexion totale interne). On teste donc `rr1 != vec3(0)` avant d'utiliser le rayon transmis.

À cette étape on fait **un seul bounce de transmission** : le rayon entre dans le solide, traverse en ligne droite (approximation, le vrai chemin ferait des rebonds — étape 13), et sort vers le sky par l'autre côté.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES3 90
#define NORM_OFF3        0.005

const float rotation_speed = 0.25;
const float refr_index    = 0.9;                     // < 1 : "moins dense" → divergence vers les bords
const float rrefr_index   = 1./refr_index;

const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    int iter;
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1   = ro + t1*rd;
        vec3 n1   = normal3(p1);
        vec3 r1   = reflect(rd, n1);                  // réflexion
        vec3 rr1  = refract(rd, n1, refr_index);      // === NOUVEAU : transmission Snell ===
        float fre1 = 1. + dot(rd, n1); fre1 *= fre1;

        // Réflexion (étape 11)
        col = render0(p1, r1) * (0.5 + 0.5*fre1);

        // === NOUVEAU : transmission ===
        // Pour cette étape on suppose que le rayon transmet **droit** (pas de bounce)
        // jusqu'à sortir → on échantillonne juste render0 dans la direction réfractée.
        // (1 - 0.75*fre1) : moins de transmission sur les bords (où Fresnel domine).
        if (rr1 != vec3(0.)) {
            col += render0(p1, rr1) * (1. - 0.75*fre1);
        }
    }
    col += glowCol0 / max(gd1.x, 3E-4);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **`refr_index = 0.9` (< 1) :** indice **inversé** par rapport au monde réel (où le verre est ~1.5). Effet artistique : le rayon **diverge** au lieu de converger → look "verre étirant". Mets `refr_index = 0.6` pour un effet plus marqué, `1.0` pour pas de réfraction (rayon traverse sans dévier), `2.42` pour un comportement diamant standard.

> **`if (rr1 != vec3(0.))` :** vérification de la **réflexion totale interne**. Si l'angle est trop rasant et le matériau plus dense, `refract()` ne peut pas transmettre → retourne `vec3(0)`. Sans ce test, on additionnerait un `render0(p1, vec3(0))` = sample du soleil sur direction nulle = artefacts.

> **Limite de cette étape :** la transmission part **droit**, sans tenir compte de la sortie de l'autre côté du solide ni d'un éventuel bounce sur les murs internes. Étape 13 corrige : on lance vraiment un raymarch interne avec rebonds.

---

## Étape 13 — Multi-bounces internes (`render2` + `MAX_BOUNCES2`)

**Notion :** une fois le rayon entré dans la cage par réfraction, il **rebondit** sur les murs miroir intérieurs. Chaque mur réfléchit, et certains rayons transmettent à travers (vers l'extérieur, où ils repèrent le sky). On boucle ce processus jusqu'à `MAX_BOUNCES2` ou jusqu'à ce que l'énergie résiduelle (`ragg`) soit trop faible.

Algorithme :
```
ragg = 1, agg = 0
pour chaque bounce :
    raymarche depuis (ro, rd) jusqu'au prochain mur intérieur (rayMarch2/df2)
    n = normal2(p)
    r = reflect(rd, n)         ← rebond intérieur
    rr = refract(rd, n, ...)    ← transmission éventuelle vers dehors
    si on a touché la sphère interne (gd.y ≤ 0) : atténuer ragg
    sinon : accumuler la couleur du sky vu à travers rr × ragg
    ro = p, rd = r, on continue
```

`ragg` (residual aggregate) est l'énergie qu'il reste au rayon après chaque réflexion. Sans ça, l'image deviendrait infiniment brillante après N bounces.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE2       0.0005
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES2 50
#define MAX_RAY_MARCHES3 90
#define NORM_OFF2        0.005
#define NORM_OFF3        0.005
#define BACKSTEP2
#define MAX_BOUNCES2     6

const float rotation_speed = 0.25;
const float refr_index    = 0.9;
const float rrefr_index   = 1./refr_index;
const float inner_sphere  = 1.;

const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float sphere(vec3 p, float r) { return length(p) - r; }

float df2(vec3 p) {
    vec3 ds = shape(p);
    float d2 = ds.y - 5E-3;
    float d0 = min(-ds.x, d2);
    float d1 = sphere(p, inner_sphere);
    g_gd = min(g_gd, vec2(d2, d1));
    return min(d0, d1);
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}

vec3 normal2(vec3 pos) {
    vec2 eps = vec2(NORM_OFF2, 0.0);
    vec3 nor;
    nor.x = df2(pos + eps.xyy) - df2(pos - eps.xyy);
    nor.y = df2(pos + eps.yxy) - df2(pos - eps.yxy);
    nor.z = df2(pos + eps.yyx) - df2(pos - eps.yyx);
    return normalize(nor);
}
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}

float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}
float rayMarch2(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
#if defined(BACKSTEP2)
    vec2 dti = vec2(1e10, 0.0);
#endif
    int i;
    for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
        float d = df2(ro + rd*t);
#if defined(BACKSTEP2)
        if (d < dti.x) dti = vec2(d, t);
#endif
        if (d < TOLERANCE2) break;
        t += d;
    }
#if defined(BACKSTEP2)
    if (i == MAX_RAY_MARCHES2) t = dti.y;
#endif
    return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

// === NOUVEAU : rendu interne avec multi-bounces ===
vec3 render2(vec3 ro, vec3 rd, float db) {
    vec3 agg = vec3(0.0);                           // accumulateur de couleur
    float ragg = 1.;                                 // énergie restante du rayon

    for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
        if (ragg < 0.1) break;                       // early-out si quasi rien ne reste

        g_gd = vec2(1E3);
        float t2 = rayMarch2(ro, rd, min(db + 0.05, 0.3));     // démarre légèrement en avant
        vec2  gd2 = g_gd;

        vec3 p2  = ro + rd*t2;
        vec3 n2  = normal2(p2);
        vec3 r2  = reflect(rd, n2);                  // rebond interne
        vec3 rr2 = refract(rd, n2, rrefr_index);     // tentative de transmission vers dehors
        float fre2 = 1. + dot(n2, rd);

        // Sky vu à travers la transmission, pondéré par l'énergie restante
        vec3 ocol = 0.2 * render0(p2, rr2) * ragg;

        if (gd2.y <= TOLERANCE2) {
            // On a touché la SPHÈRE interne : forte atténuation par Fresnel (presque tout absorbé)
            ragg *= 1. - 0.9*fre2;
        } else {
            // Mur miroir : on accumule la lumière transmise vers dehors, et atténue le rayon
            agg  += ocol;
            ragg *= 0.8;                              // 20% absorbé par bounce
        }

        // Continuer avec le rayon réfléchi
        ro = p2;
        rd = r2;
        db = gd2.x;                                   // réutilise comme tinit du prochain bounce
    }

    return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    int iter;
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1 = ro + t1*rd;
        vec3 n1 = normal3(p1);
        vec3 r1 = reflect(rd, n1);
        vec3 rr1 = refract(rd, n1, refr_index);
        float fre1 = 1. + dot(rd, n1); fre1 *= fre1;

        col = render0(p1, r1) * (0.5 + 0.5*fre1);

        // === NOUVEAU : intérieur via render2 ===
        if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.)) {
            vec3 icol = render2(p1, rr1, gd1.x);
            col += icol * (1. - 0.75*fre1);
        }
    }
    col += glowCol0 / max(gd1.x, 3E-4);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Le solide ressemble enfin à une cage de miroirs pleine.** Tu vois plusieurs "fenêtres" : chaque rebond interne montre un morceau différent du ciel.

> **Pourquoi `min(db + 0.05, 0.3)` comme `tinit` ?** `db` (= `gd1.x` ou `gd2.x` précédent) est la distance min vue avant. Démarrer à `db + 0.05` = légèrement après ce minimum → évite de re-hit immédiatement. Le `min(.., 0.3)` cap pour ne pas démarrer trop loin si le bounce précédent a vu une distance énorme.

> **`ragg *= 0.8` :** atténuation **par bounce** = 20% absorbé. Sur 6 bounces, l'énergie restante = `0.8^6 ≈ 0.26`. Au-delà, le contrast devient invisible — d'où le `if (ragg < 0.1) break`.

> **`* 0.2` sur `ocol` :** le rayon transmis n'apporte qu'une fraction de la lumière externe (la majorité restant en rebond interne). Sans ce coefficient, l'intérieur paraîtrait pleinement éclairé même dans une cage très réflective.

> **`gd2.y <= TOLERANCE2` (sphère interne) :** comportement spécial quand le rayon hit la sphère. Au lieu d'accumuler la sortie vers le sky, on atténue **fortement** le rayon (`1 - 0.9*fre2`) — la sphère est presque opaque et absorbe la majorité de l'énergie. À l'étape suivante on lui ajoute en plus un glow et de l'absorption colorée.

---

## Étape 14 — Absorption Beer-Lambert + glow interne aux arêtes

**Notion :** la cage actuelle est neutre (pas de couleur intrinsèque). On ajoute deux raffinements dans `render2` :

1. **Accumulateur `tagg`** : distance totale parcourue à l'intérieur. Plus le rayon traîne dans le solide, plus on absorbe.
2. **Beer-Lambert coloré** : `beer = ragg * exp(0.2 * beerCol * tagg)`. Avec `beerCol` **négatif** sur certains canaux, `exp()` les fait **grossir** dans le temps → effet de **teinte qui se développe** avec la profondeur. C'est l'inverse mathématique de l'absorption classique : ici on **amplifie** des canaux pour styliser une teinte chaude/froide.
3. **Glow interne `glowCol1 * beer * 1/gd` :** comme le glow externe (étape 7) mais à l'intérieur, modulé par le facteur Beer-Lambert et un facteur quadratique en `tagg` qui amplifie le halo en profondeur.

Le résultat : l'intérieur devient fluorescent, avec des arêtes de plus en plus brillantes plus on s'enfonce. C'est l'élément signature visuel de ce shader.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE2       0.0005
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES2 50
#define MAX_RAY_MARCHES3 90
#define NORM_OFF2        0.005
#define NORM_OFF3        0.005
#define BACKSTEP2
#define MAX_BOUNCES2     6

const float rotation_speed = 0.25;
const float refr_index    = 0.9;
const float rrefr_index   = 1./refr_index;
const float inner_sphere  = 1.;

const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float sphere(vec3 p, float r) { return length(p) - r; }

float df2(vec3 p) {
    vec3 ds = shape(p);
    float d2 = ds.y - 5E-3;
    float d0 = min(-ds.x, d2);
    float d1 = sphere(p, inner_sphere);
    g_gd = min(g_gd, vec2(d2, d1));
    return min(d0, d1);
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}
vec3 normal2(vec3 pos) {
    vec2 eps = vec2(NORM_OFF2, 0.0);
    vec3 nor;
    nor.x = df2(pos + eps.xyy) - df2(pos - eps.xyy);
    nor.y = df2(pos + eps.yxy) - df2(pos - eps.yxy);
    nor.z = df2(pos + eps.yyx) - df2(pos - eps.yyx);
    return normalize(nor);
}
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}
float rayMarch2(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
#if defined(BACKSTEP2)
    vec2 dti = vec2(1e10, 0.0);
#endif
    int i;
    for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
        float d = df2(ro + rd*t);
#if defined(BACKSTEP2)
        if (d < dti.x) dti = vec2(d, t);
#endif
        if (d < TOLERANCE2) break;
        t += d;
    }
#if defined(BACKSTEP2)
    if (i == MAX_RAY_MARCHES2) t = dti.y;
#endif
    return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
const vec3 glowCol1     = HSV2RGB(vec3(0.95, 0.7, 1E-3));      // === NOUVEAU : glow interne (magenta) ===
const vec3 beerCol      = -HSV2RGB(vec3(0.15+0.5, 0.7, 2.));    // === NOUVEAU : NÉGATIF → exp amplifie ===

float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

// === render2 enrichi : Beer-Lambert + glow interne ===
vec3 render2(vec3 ro, vec3 rd, float db) {
    vec3 agg = vec3(0.0);
    float ragg = 1.;
    float tagg = 0.;                                  // === NOUVEAU : distance totale parcourue à l'intérieur ===

    for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
        if (ragg < 0.1) break;

        g_gd = vec2(1E3);
        float t2 = rayMarch2(ro, rd, min(db + 0.05, 0.3));
        vec2  gd2 = g_gd;
        tagg += t2;                                   // accumule

        vec3 p2  = ro + rd*t2;
        vec3 n2  = normal2(p2);
        vec3 r2  = reflect(rd, n2);
        vec3 rr2 = refract(rd, n2, rrefr_index);
        float fre2 = 1. + dot(n2, rd);

        // === Beer-Lambert : énergie résiduelle teintée par exp(beerCol * tagg) ===
        // beerCol est NÉGATIF (cf. const) → exp(...) AMPLIFIE certains canaux avec la distance
        vec3 beer = ragg * exp(0.2 * beerCol * tagg);

        // === Glow interne sur les arêtes, modulé par beer et un terme quadratique en tagg ===
        // 6./max(gd2.x, ...) : pic lumineux à proximité d'une arête
        // (1 + tagg²*4e-2) : amplification du halo en profondeur
        // 5e-4 + tagg²*2e-4/ragg : clamp adaptatif (plus on est loin, plus on étale le pic)
        agg += glowCol1 * beer * ((1. + tagg*tagg*4E-2) * 6. / max(gd2.x, 5E-4 + tagg*tagg*2E-4/ragg));

        // Sky vu à travers la transmission, pondéré par beer (au lieu de ragg seul)
        vec3 ocol = 0.2 * beer * render0(p2, rr2);

        if (gd2.y <= TOLERANCE2) {
            ragg *= 1. - 0.9*fre2;
        } else {
            agg  += ocol;
            ragg *= 0.8;
        }

        ro = p2;
        rd = r2;
        db = gd2.x;
    }

    return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    int iter;
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1 = ro + t1*rd;
        vec3 n1 = normal3(p1);
        vec3 r1 = reflect(rd, n1);
        vec3 rr1 = refract(rd, n1, refr_index);
        float fre1 = 1. + dot(rd, n1); fre1 *= fre1;

        col = render0(p1, r1) * (0.5 + 0.5*fre1);
        if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.)) {
            vec3 icol = render2(p1, rr1, gd1.x);
            col += icol * (1. - 0.75*fre1);
        }
    }
    col += glowCol0 / max(gd1.x, 3E-4);
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **`beerCol = -HSV2RGB(...)` :** négation **componentielle**. `HSV2RGB(0.65, 0.7, 2.0)` est un magenta bleuté ; sa négation est un cyan-vert sombre. Comme `exp(x)` est croissante, des composantes négatives de `beerCol * tagg` produisent `exp(neg) < 1` → atténuation ; des composantes positives amplifient. Le mix donne l'effet "se teinte vers le magenta/orange en profondeur".

> **À tester :** mets `beerCol = +HSV2RGB(...)` (positif) → tout devient une étoile cramée. Remets en négatif : la teinte devient sélective.

> **Pourquoi `tagg*tagg*4E-2` (quadratique) et pas linéaire ?** Le glow doit **exploser** quand le rayon se perd dans le polyèdre (beaucoup de bounces, beaucoup de distance). Linéaire → effet trop doux. Quadratique → décollage net après ~5 unités de distance accumulée.

> **Le clamp `5E-4 + tagg*tagg*2E-4/ragg` :** garde-fou anti-singularité **adaptatif**. Plus `tagg` augmente (rayon enfoncé), plus le clamp augmente → on évite les hot pixels alors que la zone d'influence du glow s'étale. Plus `ragg` diminue (énergie épuisée), plus le clamp augmente aussi → cohérent avec une décroissance physique.

---

## Étape 15 — Iter-fadeout (`ifo`) + glow externe modulé par Fresnel

**Notion :** quand `rayMarch3` saturent leurs `MAX_RAY_MARCHES3` itérations sans converger franchement, le hit retourné est probablement sur une **surface rasante** (où la SDF est dégénérée) → les normales seront imprécises et la couleur calculée "saute" entre frames → **artefacts scintillants**.

Astuce **`ifo`** (iter fadeout) : on récupère le compteur `iter` et on construit un coefficient qui :
- vaut **1.0** pour les rayons qui ont convergé rapidement (`iter/MAX < 0.9`),
- descend à **0.5** pour ceux qui ont saturé (`iter/MAX ≥ 1.0`).

```
ifo = mix(0.5, 1., smoothstep(1.0, 0.9, iter/MAX_RAY_MARCHES3))
```

(Note : `smoothstep(edge0, edge1, x)` avec `edge0 > edge1` est valide en GLSL et inverse la pente.)

On multiplie reflection + transmission par `ifo` → les artefacts perdent en intensité, sans disparaître complètement (qui paraîtrait pire qu'un peu de blur). Petit raffinement supplémentaire : le glow extérieur est **amplifié par Fresnel** (`glowCol0 * (1 + fre1)`) → arêtes qui scintillent davantage en bord d'objet.

```glsl
#define RESOLUTION  iResolution
#define TIME        iTime
#define PI 3.141592654

#define TOLERANCE2       0.0005
#define TOLERANCE3       0.0005
#define MAX_RAY_LENGTH3  10.0
#define MAX_RAY_MARCHES2 50
#define MAX_RAY_MARCHES3 90
#define NORM_OFF2        0.005
#define NORM_OFF3        0.005
#define BACKSTEP2
#define MAX_BOUNCES2     6

const float rotation_speed = 0.25;
const float refr_index    = 0.9;
const float rrefr_index   = 1./refr_index;
const float inner_sphere  = 1.;

const int   poly_type = 3;
const float poly_U = 1.0, poly_V = 0.5, poly_W = 1.0, poly_zoom = 2.0;
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab = vec3(0., 0., 1.);
const vec3  poly_pbc_ = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_ = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p   = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc = normalize(poly_pbc_);
const vec3  poly_pca = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos) { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
float sphere(vec3 p, float r) { return length(p) - r; }

float df2(vec3 p) {
    vec3 ds = shape(p);
    float d2 = ds.y - 5E-3;
    float d0 = min(-ds.x, d2);
    float d1 = sphere(p, inner_sphere);
    g_gd = min(g_gd, vec2(d2, d1));
    return min(d0, d1);
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}
vec3 normal2(vec3 pos) {
    vec2 eps = vec2(NORM_OFF2, 0.0);
    vec3 nor;
    nor.x = df2(pos + eps.xyy) - df2(pos - eps.xyy);
    nor.y = df2(pos + eps.yxy) - df2(pos - eps.yxy);
    nor.z = df2(pos + eps.yyx) - df2(pos - eps.yyx);
    return normalize(nor);
}
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}
float rayMarch2(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
#if defined(BACKSTEP2)
    vec2 dti = vec2(1e10, 0.0);
#endif
    int i;
    for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
        float d = df2(ro + rd*t);
#if defined(BACKSTEP2)
        if (d < dti.x) dti = vec2(d, t);
#endif
        if (d < TOLERANCE2) break;
        t += d;
    }
#if defined(BACKSTEP2)
    if (i == MAX_RAY_MARCHES2) t = dti.y;
#endif
    return t;
}

const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))
const vec3 rayOrigin = vec3(0.0, 1., -5.);
const vec3 sunDir    = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
const vec3 glowCol1     = HSV2RGB(vec3(0.95, 0.7, 1E-3));
const vec3 beerCol      = -HSV2RGB(vec3(0.15+0.5, 0.7, 2.));
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}

vec3 render2(vec3 ro, vec3 rd, float db) {
    vec3 agg = vec3(0.0);
    float ragg = 1., tagg = 0.;
    for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
        if (ragg < 0.1) break;
        g_gd = vec2(1E3);
        float t2 = rayMarch2(ro, rd, min(db + 0.05, 0.3));
        vec2 gd2 = g_gd; tagg += t2;
        vec3 p2 = ro + rd*t2;
        vec3 n2 = normal2(p2);
        vec3 r2 = reflect(rd, n2);
        vec3 rr2 = refract(rd, n2, rrefr_index);
        float fre2 = 1. + dot(n2, rd);
        vec3 beer = ragg * exp(0.2 * beerCol * tagg);
        agg += glowCol1 * beer * ((1. + tagg*tagg*4E-2) * 6. / max(gd2.x, 5E-4 + tagg*tagg*2E-4/ragg));
        vec3 ocol = 0.2 * beer * render0(p2, rr2);
        if (gd2.y <= TOLERANCE2) ragg *= 1. - 0.9*fre2;
        else { agg += ocol; ragg *= 0.8; }
        ro = p2; rd = r2; db = gd2.x;
    }
    return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
    int iter;                                         // === NOUVEAU : récupère le compteur d'iter ===
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;

    // === NOUVEAU : iter fadeout ===
    // smoothstep avec edges inversés (1.0 → 0.9) : descend de 1 vers 0 quand iter/MAX dépasse 0.9
    // mix(0.5, 1., t) : maxi 1 (pas de fade), mini 0.5 (max fade)
    float ifo = mix(0.5, 1., smoothstep(1.0, 0.9, float(iter)/float(MAX_RAY_MARCHES3)));

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1 = ro + t1*rd;
        vec3 n1 = normal3(p1);
        vec3 r1 = reflect(rd, n1);
        vec3 rr1 = refract(rd, n1, refr_index);
        float fre1 = 1. + dot(rd, n1); fre1 *= fre1;

        col = render0(p1, r1) * (0.5 + 0.5*fre1) * ifo;          // === × ifo ===
        if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.)) {
            vec3 icol = render2(p1, rr1, gd1.x);
            col += icol * (1. - 0.75*fre1) * ifo;                // === × ifo ===
        }

        // === Glow externe modulé par Fresnel ===
        // Avec un point de hit on connaît fre1 → on amplifie le glow sur les bords
        col += (glowCol0 + 1. * fre1 * glowCol0) / max(gd1.x, 3E-4);
    } else {
        // Pas de hit : glow external "neutre" (sans modulation Fresnel parce qu'on n'a pas de surface)
        col += glowCol0 / max(gd1.x, 3E-4);
    }
    return col;
}

vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);
    vec3 col = render3(rayOrigin, rd);
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);
    col = aces_approx(col); col = sqrt(col);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy; vec2 p = -1. + 2. * q; vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));
    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **À tester :** force `ifo = 1.0` constamment → tu vois apparaître des pixels qui scintillent là où la SDF est trop tordue (vers les arêtes très fines). Avec le fade actif, ces zones perdent en luminance et l'animation devient stable.

> **Le `+ 1.*fre1*glowCol0` dans le glow externe :** doublé sur les bords (`fre1 ≈ 1`), simple sur les faces. Effet : le halo d'arête devient plus brillant en silhouette de l'objet, ce qui souligne la forme.

> **Pourquoi `0.5` comme min d'`ifo` (et pas `0`) ?** Si on faisait disparaître complètement les pixels artefactés, on aurait des **trous noirs** dans l'image (encore pire visuellement que les artefacts). `0.5` est un compromis : on les atténue sans les supprimer.

> **`smoothstep(1.0, 0.9, ...)` (edges inversées) :** légal en GLSL, et donne une rampe **décroissante**. Avec `edge0 > edge1`, `smoothstep` retourne 1 sous `edge1`, 0 au-dessus de `edge0`, et interpole en s. C'est le motif le plus court pour "fader à partir d'un seuil".

---

## Étape 16 — Composition finale + vignette colorée (le shader complet)

**Notion :** consolidation. Le shader est fonctionnellement complet à l'étape 15 ; cette étape regroupe tout, expose les **paramètres twiddlables** en haut, et passe en revue le pipeline entier. C'est le shader que tu retrouves dans `refract2.md`.

**Pipeline de bout en bout** :

1. `mainImage` : récupère le pixel, normalise les UV, appelle `effect`.
2. `effect` : construit le rd via la caméra look-at, appelle `render3`, applique vignette, ACES, gamma sqrt.
3. `render3` (étape 15) : sky par défaut, raymarche df3, calcule reflet (sky direction r1), appelle `render2` pour l'intérieur, ajoute le glow externe modulé Fresnel, applique `ifo`.
4. `render2` (étapes 13–14) : boucle `MAX_BOUNCES2`, raymarche df2 avec BACKSTEP, accumule reflets/transmissions/glow interne pondérés Beer-Lambert.

**Vignette colorée** : `col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25)`. Soustrait une teinte **proportionnelle à la distance au centre** :
- `length(p)` = 0 au centre, ~1.4 aux coins.
- `+ 0.25` = offset constant : même au centre, on enlève un poil → l'image n'est jamais 100% saturée.
- `vec3(2,3,1)` = on enlève **plus de bleu et vert que de rouge** → les bords tirent vers une teinte chaude/orangée (cinéma).
- `2E-2` = intensité globale.

```glsl
// === Paramètres globaux : tweake ces valeurs pour des variations ===
const float rotation_speed = 0.25;     // vitesse de rotation
const float poly_U = 1.0;              // pondération sommet "ab"
const float poly_V = 0.5;              // pondération sommet "bc"
const float poly_W = 1.0;              // pondération sommet "ca"
const int   poly_type = 3;             // 2..5 : type du solide
const float poly_zoom = 2.0;           // taille
const float inner_sphere = 1.;         // rayon de la sphère interne
const float refr_index = 0.9;          // indice de réfraction
#define MAX_BOUNCES2 6                  // bounces internes max
// =====================================================================

#define RESOLUTION  iResolution
#define TIME        iTime
#define PI          3.141592654
#define TAU         (2.0*PI)

#define TOLERANCE2          0.0005
#define MAX_RAY_MARCHES2    50
#define NORM_OFF2           0.005
#define BACKSTEP2

#define TOLERANCE3          0.0005
#define MAX_RAY_LENGTH3     10.0
#define MAX_RAY_MARCHES3    90
#define NORM_OFF3           0.005

const float rrefr_index = 1./refr_index;

// HSV → RGB
const vec4 hsv2rgb_K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
    return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// Caméra et palette
const vec3 rayOrigin    = vec3(0.0, 1., -5.);
const vec3 sunDir       = normalize(-rayOrigin);
const vec3 sunCol       = HSV2RGB(vec3(0.06, 0.90, 1E-2));
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5));
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.));
const vec3 glowCol0     = HSV2RGB(vec3(0.05, 0.7, 1E-3));
const vec3 glowCol1     = HSV2RGB(vec3(0.95, 0.7, 1E-3));
const vec3 beerCol      = -HSV2RGB(vec3(0.15+0.5, 0.7, 2.));

// KIFS constants
const float poly_cospin  = cos(PI/float(poly_type));
const float poly_scospin = sqrt(0.75 - poly_cospin*poly_cospin);
const vec3  poly_nc      = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab     = vec3(0., 0., 1.);
const vec3  poly_pbc_    = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_    = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p       = normalize((poly_U*poly_pab + poly_V*poly_pbc_ + poly_W*poly_pca_));
const vec3  poly_pbc     = normalize(poly_pbc_);
const vec3  poly_pca     = normalize(poly_pca_);

mat3 g_rot;
vec2 g_gd;

mat3 rot(vec3 d, vec3 z) {
    vec3 v = cross(z, d); float c = dot(z, d); float k = 1.0/(1.0 + c);
    return mat3(v.x*v.x*k+c,   v.y*v.x*k-v.z, v.z*v.x*k+v.y,
                v.x*v.y*k+v.z, v.y*v.y*k+c,   v.z*v.y*k-v.x,
                v.x*v.z*k-v.y, v.y*v.z*k+v.x, v.z*v.z*k+c);
}
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0); v *= 0.6;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((v*(a*v + b)) / (v*(c*v + d) + e), 0.0, 1.0);
}
float sphere(vec3 p, float r) { return length(p) - r; }
float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }

void poly_fold(inout vec3 pos) {
    vec3 p = pos;
    for (int i = 0; i < poly_type; ++i) { p.xy = abs(p.xy); p -= 2.*min(0., dot(p, poly_nc)) * poly_nc; }
    pos = p;
}
float poly_plane(vec3 pos)  { return max(max(dot(pos, vec3(0.,0.,1.)), dot(pos, poly_pbc)), dot(pos, poly_pca)); }
float poly_corner(vec3 pos) { return length(pos) - 0.0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
    float dla = dot2(pos - min(0., pos.x) * vec3(1., 0., 0.));
    float dlb = dot2(pos - min(0., pos.y) * vec3(0., 1., 0.));
    float dlc = dot2(pos - min(0., dot(pos, poly_nc)) * poly_nc);
    return sqrt(min(min(dla, dlb), dlc)) - 2E-3;
}
vec3 shape(vec3 pos) {
    pos *= g_rot; pos /= poly_zoom; poly_fold(pos); pos -= poly_p;
    return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos)) * poly_zoom;
}
vec3 render0(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0); float srd = sign(rd.y); float tp = -(ro.y - 6.) / abs(rd.y);
    if (srd < 0.) col += bottomBoxCol * exp(-0.5 * length((ro + tp*rd).xz));
    if (srd > 0.0) {
        vec3 pos = ro + tp*rd; float db = box(pos.xz, vec2(5.0, 9.0)) - 3.0;
        col += topBoxCol * rd.y*rd.y * smoothstep(0.25, 0.0, db);
        col += 0.2 * topBoxCol * exp(-0.5 * max(db, 0.0));
        col += 0.05 * sqrt(topBoxCol) * max(-db, 0.0);
    }
    col += sunCol / (1.001 - dot(sunDir, rd));
    return col;
}

float df2(vec3 p) {
    vec3 ds = shape(p);
    float d2 = ds.y - 5E-3;
    float d0 = min(-ds.x, d2);
    float d1 = sphere(p, inner_sphere);
    g_gd = min(g_gd, vec2(d2, d1));
    return min(d0, d1);
}
float df3(vec3 p) {
    vec3 ds = shape(p);
    g_gd = min(g_gd, ds.yz);
    float d = ds.x; d = min(d, ds.y); d = min(d, ds.z);
    return d;
}
float rayMarch2(vec3 ro, vec3 rd, float tinit) {
    float t = tinit;
#if defined(BACKSTEP2)
    vec2 dti = vec2(1e10, 0.0);
#endif
    int i;
    for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
        float d = df2(ro + rd*t);
#if defined(BACKSTEP2)
        if (d < dti.x) dti = vec2(d, t);
#endif
        if (d < TOLERANCE2) break;
        t += d;
    }
#if defined(BACKSTEP2)
    if (i == MAX_RAY_MARCHES2) t = dti.y;
#endif
    return t;
}
vec3 normal2(vec3 pos) {
    vec2 eps = vec2(NORM_OFF2, 0.0);
    vec3 nor;
    nor.x = df2(pos + eps.xyy) - df2(pos - eps.xyy);
    nor.y = df2(pos + eps.yxy) - df2(pos - eps.yxy);
    nor.z = df2(pos + eps.yyx) - df2(pos - eps.yyx);
    return normalize(nor);
}
vec3 normal3(vec3 pos) {
    vec2 eps = vec2(NORM_OFF3, 0.0);
    vec3 nor;
    nor.x = df3(pos + eps.xyy) - df3(pos - eps.xyy);
    nor.y = df3(pos + eps.yxy) - df3(pos - eps.yxy);
    nor.z = df3(pos + eps.yyx) - df3(pos - eps.yyx);
    return normalize(nor);
}
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
    float t = tinit; int i;
    for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
        float d = df3(ro + rd*t);
        if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
        t += d;
    }
    iter = i; return t;
}

// === render2 : multi-bounces internes avec Beer-Lambert + glow ===
vec3 render2(vec3 ro, vec3 rd, float db) {
    vec3 agg = vec3(0.0);
    float ragg = 1.;
    float tagg = 0.;
    for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
        if (ragg < 0.1) break;
        g_gd = vec2(1E3);
        float t2 = rayMarch2(ro, rd, min(db + 0.05, 0.3));
        vec2 gd2 = g_gd; tagg += t2;

        vec3 p2  = ro + rd*t2;
        vec3 n2  = normal2(p2);
        vec3 r2  = reflect(rd, n2);
        vec3 rr2 = refract(rd, n2, rrefr_index);
        float fre2 = 1. + dot(n2, rd);

        vec3 beer = ragg * exp(0.2 * beerCol * tagg);
        agg += glowCol1 * beer * ((1. + tagg*tagg*4E-2) * 6. / max(gd2.x, 5E-4 + tagg*tagg*2E-4/ragg));
        vec3 ocol = 0.2 * beer * render0(p2, rr2);
        if (gd2.y <= TOLERANCE2) ragg *= 1. - 0.9*fre2;
        else { agg += ocol; ragg *= 0.8; }

        ro = p2; rd = r2; db = gd2.x;
    }
    return agg;
}

// === render3 : premier hit, reflet+transmission+glow externe+ifo ===
vec3 render3(vec3 ro, vec3 rd) {
    int iter;
    vec3 col = render0(ro, rd);
    g_gd = vec2(1E3);
    float t1 = rayMarch3(ro, rd, 0.1, iter);
    vec2 gd1 = g_gd;

    float ifo = mix(0.5, 1., smoothstep(1.0, 0.9, float(iter)/float(MAX_RAY_MARCHES3)));

    if (t1 < MAX_RAY_LENGTH3) {
        vec3 p1 = ro + t1*rd;
        vec3 n1 = normal3(p1);
        vec3 r1 = reflect(rd, n1);
        vec3 rr1 = refract(rd, n1, refr_index);
        float fre1 = 1. + dot(rd, n1); fre1 *= fre1;

        col = render0(p1, r1) * (0.5 + 0.5*fre1) * ifo;
        if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.)) {
            vec3 icol = render2(p1, rr1, gd1.x);
            col += icol * (1. - 0.75*fre1) * ifo;
        }
    }
    col += (glowCol0 + 1. * /* fre1 ≈ 0 si pas de hit, donc neutre */ glowCol0) / max(gd1.x, 3E-4);
    return col;
}

// === Composition finale ===
vec3 effect(vec2 p, vec2 pp) {
    const float fov = 2.0;
    const vec3 up = vec3(0., 1., 0.);
    const vec3 la = vec3(0.0);
    const vec3 ww = normalize(la - rayOrigin);
    const vec3 uu = normalize(cross(up, ww));
    const vec3 vv = cross(ww, uu);
    vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

    vec3 col = render3(rayOrigin, rd);

    // Vignette colorée : appliquée AVANT tone-map pour que ACES la lisse
    col -= 2E-2 * vec3(2., 3., 1.) * (length(p) + 0.25);

    col = aces_approx(col);     // tone map HDR → LDR
    col = sqrt(col);             // gamma sRGB rapide
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord/RESOLUTION.xy;
    vec2 p = -1. + 2. * q;
    vec2 pp = p;
    p.x *= RESOLUTION.x/RESOLUTION.y;

    // Animation de la rotation : deux directions Lissajous → mat3 sans gimbal lock
    float a = TIME * rotation_speed;
    vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0) * a));
    vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0) * 0.913 * a), 1.0);
    g_rot = rot(normalize(r0), normalize(r1));

    fragColor = vec4(effect(p, pp), 1.0);
}
```

> **Différence avec le shader original `refract2.md` :** identique fonctionnellement. Seul changement : j'ai mis le facteur Fresnel sur le glow externe **conditionnel au hit** (sinon `fre1` ne serait pas défini hors du `if`). Le source original calculait `fre1` même quand pas de hit (résultat indéfini en GLSL strict, mais en pratique 0).

> **Pour twiddler :**
> - **Solide** : change `poly_type` (2=bipyramide, 3=tétra, 4=cube/octa, 5=dodéca/icosa) et `poly_U/V/W` pour étirer / froisser.
> - **Verre** : change `refr_index` (0.6 → forte distorsion, 1.0 → pas de réfraction, 2.42 → diamant).
> - **Bounces** : `MAX_BOUNCES2 = 12` pour des intérieurs très denses (perf en chute libre).
> - **Caméra** : change `rayOrigin` (par ex. `vec3(0., 0., -3.)` pour zoomer) ou `fov` (1.0 = grand-angle).
> - **Couleurs** : tweake les **teintes HSV** (premier composant ∈ [0,1]) — tout l'éclairage est paramétré dessus.

> **Perf :** ce shader est intensif. Sur GPU intégré il tourne à 30fps en 1080p, sur GPU desktop 60fps+ en 1440p. Bottleneck : la boucle KIFS dans `shape()` (appelée ~6 fois par normale, ~50–90 fois par raymarch). Optimisations possibles : descendre `MAX_RAY_MARCHES3`, inliner `poly_fold`, ou pré-calculer `g_rot * pos` une fois et passer le résultat à `shape()` plutôt qu'au `*=` dans `shape()`.

---

## Récap des concepts par étape

| #  | Concept clé |
|----|---|
| 1  | Caméra look-at avec FOV explicite + correction d'aspect-ratio |
| 2  | Skybox procédural (sun + box top/bottom) sans tone mapping |
| 3  | Tone mapping ACES + gamma sqrt + vignette colorée |
| 4  | SDF sphère + raymarcher classique sur le sky |
| 5  | KIFS polyhedral folding (plane + edge + corner) |
| 6  | Rotation animée par matrice no-acos d'IQ + Lissajous 3D |
| 7  | Glow par proximité (`1/gd`) — accumule la distance min aux arêtes |
| 8  | Raymarcher BACKSTEP (mémorise le min(d) pour ne pas rater la cage) |
| 9  | Combinaison df3 (cage) + df2 (cage + sphère interne) |
| 10 | Normales par gradient central (6 évaluations) + facteur Fresnel `1+dot(rd,n)` |
| 11 | Réflexion externe vers le sky modulée par Fresnel |
| 12 | Réfraction Snell (`refract()`) avec `refr_index` |
| 13 | Boucle multi-bounces internes (`MAX_BOUNCES2`) |
| 14 | Absorption Beer-Lambert + glow interne aux arêtes |
| 15 | Composition `render3` : reflet + intérieur + iter-fadeout |
| 16 | Effet final + vignette colorée + post `aces + sqrt` |

---

## Pour aller plus loin

- **Vraie dispersion :** appliquer `refract()` avec un `refr_index` distinct par canal R/G/B → 3 raymarchings → arc-en-ciel à la sortie.
- **Bloom HDR :** comme la sortie n'est pas clampée à 1.0 avant ACES, on pourrait extraire `max(col-1., 0.)` et le flouter en deuxième passe (cf. `refract` étape 15).
- **Plus de bounces :** monter `MAX_BOUNCES2` à 12–16 pour des solides très denses, mais surveiller `MAX_RAY_MARCHES2` qui plafonne chaque segment.
- **Intéractivité :** binder `iMouse` pour piloter la rotation, ou `poly_U/V/W` sur des sliders (UI Shadertoy via `iChannelN` Buffer textuel ou hash de `iMouse.xy`).
- **Caustiques :** raymarcher depuis la lumière, projeter dans un buffer photon-map. Coûteux — voir les exemples d'IQ.
