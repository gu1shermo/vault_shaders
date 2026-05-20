
# Tunnel 3 — décomposition en 21 étapes

Chaque étape contient un shader **complet** copiable tel quel dans Shadertoy. On part de zéro et on arrive au shader original en ajoutant **une notion par étape**.

> **Bindings Shadertoy à prévoir** (utiles à partir de l'étape 12) :
> - `iChannel0` : une texture (ex. *Abstract 1* ou *Organic 4* dans la sidebar Shadertoy)
> - `iChannel1` : une source **Audio** (Sound ou SoundCloud) — alimente la macro `FFT()`
> - `iChannel2` : **Buffer A** — utilisé comme feedback du frame précédent (Buffer A contient le même code que l'onglet *Image*, et lui-même samplé sur son propre `iChannel2`)

---

## Étape 1 — UV centrées + caméra qui glisse en Z

**Notion :** UV normalisées indépendantes de la résolution + caméra "look-at" qui avance dans le temps. On affiche `rd` en couleur pour vérifier l'orientation.

```glsl
// Construit le rayon de la caméra à partir d'une direction "forward" (rd) et d'un uv écran.
// On bâtit une base orthonormée (right, up) autour de rd, puis on ajoute la déviation uv.
vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;                                           // facteur d'ouverture (1 = ~90°)
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));            // right : perpendiculaire à rd et au "up monde"
    vec3 u = normalize(cross(rd, r));                          // up local : perpendiculaire à rd et right
    return normalize(rd + fov*(r*uv.x + u*uv.y));              // rayon final, normalisé
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // uv centré sur [-0.5, 0.5] horizontalement, ratio préservé via /iResolution.xx
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;                                        // vitesse de défilement *2
    vec3 ro = vec3(0., 0., -12.+t);                            // origine caméra : recule de 12 puis avance avec t
    vec3 ta = vec3(0., 0., 0.+t);                              // cible : devant la caméra, avance aussi
    vec3 rd = normalize(ta - ro);                              // direction "forward" brute
    rd = getCam(rd, uv);                                       // rayon final pour ce pixel

    // visualisation de la direction du rayon : (rd*.5+.5) remappe [-1,1] → [0,1]
    fragColor = vec4(rd*.5+.5, 1.);
}
```

---

## Étape 2 — Tube SDF inversé (on est *dans* le tunnel)

**Notion :** un cylindre infini sur Z s'écrit `length(p.xy) - r`. En **inversant le signe**, l'intérieur devient "plein" pour le raymarcher → on heurte la paroi vue depuis l'intérieur. La caméra étant à l'origine de la section, elle est forcément dedans.

```glsl
#define sat(a) clamp(a, 0., 1.)                                // raccourci pour clamp [0,1]

// SDF du tunnel : tube infini d'axe Z, rayon 2. Le SIGNE inversé met l'intérieur "plein"
// pour le raymarcher → on heurte la paroi depuis l'intérieur.
float map(vec3 p)
{
    return -(length(p.xy) - 2.);
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(0., 0., -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd = getCam(rd, uv);

    // Sphere tracing classique : on avance le long de rd par bonds = SDF.
    vec3 p = ro;
    float hit = -1.;
    for (int i = 0; i < 128; i++) {
        float d = map(p);
        if (d < 0.01) { hit = distance(ro, p); break; }       // assez proche → on s'arrête
        p += rd * d * .7;                                      // *.7 : sous-relaxation, typique des SDF inversées
                                                               // (évite de "sauter par-dessus" la paroi)
    }

    vec3 col = (hit > 0.) ? vec3(1.) : vec3(0.);              // hit = blanc, sinon noir
    fragColor = vec4(col, 1.);
}
```

---

## Étape 3 — Shading par distance

**Notion :** on assombrit la couleur en fonction de la distance parcourue → premier sentiment de profondeur sans avoir encore de normales.

```glsl
#define sat(a) clamp(a, 0., 1.)

float map(vec3 p)
{
    return -(length(p.xy) - 2.);
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(0., 0., -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd = getCam(rd, uv);

    vec3 p = ro;
    float hit = -1.;
    for (int i = 0; i < 128; i++) {
        float d = map(p);
        if (d < 0.01) { hit = distance(ro, p); break; }
        p += rd * d * .7;
    }

    vec3 col = vec3(0.);
    // 1 - distance/30 : intensité décroît avec la profondeur, sat() évite les valeurs négatives.
    if (hit > 0.) col = vec3(1. - sat(hit / 30.));
    fragColor = vec4(col, 1.);
}
```

---

## Étape 4 — Le tunnel serpente (centre déplacé par sinusoïdes)

**Notion :** **domain warping**. On déplace le centre du tube avant de calculer la distance : `p.xy -= vec2(sin(p.z+iTime), cos(p.z*.5+iTime))*.5`. Comme le décalage dépend de `p.z` *et* de `iTime`, on a un serpent qui ondule en 3D et défile dans le temps. On ajoute une petite vibration sur Y avec une fréquence plus haute.

```glsl
#define sat(a) clamp(a, 0., 1.)

float map(vec3 p)
{
    // Décalage du centre du tube selon z et le temps :
    //   - sin(p.z+iTime) : oscille en X, longueur d'onde 2π le long du tunnel
    //   - cos(p.z*.5+iTime) : oscille en Y, longueur d'onde 4π (plus lente)
    //   * .5 : amplitude du serpent (la moitié du rayon, donc bien visible)
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    // Vibration verticale haute fréquence (p.z*2.) et faible amplitude → léger frémissement
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2.);
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(0., 0., -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd = getCam(rd, uv);

    vec3 p = ro;
    float hit = -1.;
    for (int i = 0; i < 128; i++) {
        float d = map(p);
        if (d < 0.01) { hit = distance(ro, p); break; }
        p += rd * d * .7;
    }

    vec3 col = (hit > 0.) ? vec3(1. - sat(hit / 30.)) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 5 — Rayon variable selon Z

**Notion :** on ajoute un terme `sin(p.z*.25)` dans le rayon → le tube se rétrécit et s'élargit le long de son axe. Le signe choisi fait que la paroi se rapproche/s'éloigne de la caméra.

```glsl
#define sat(a) clamp(a, 0., 1.)

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    // Rayon effectif = 2 - sin(p.z*.25) ; longueur d'onde 8π → bosses lentes le long du tube.
    // Note : pas de iTime ici, donc les bosses sont fixes dans l'espace (mais on roule à travers).
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(0., 0., -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd = getCam(rd, uv);

    vec3 p = ro;
    float hit = -1.;
    for (int i = 0; i < 128; i++) {
        float d = map(p);
        if (d < 0.01) { hit = distance(ro, p); break; }
        p += rd * d * .7;
    }

    vec3 col = (hit > 0.) ? vec3(1. - sat(hit / 30.)) : vec3(0.);
    fragColor = vec4(col, 1.);
}
```

---

## Étape 6 — Normales + headlamp + gamma

**Notion :**
- **Normales** par gradient de la SDF (différences finies).
- **Lampe attachée à la caméra** (« headlamp ») : `lpos = ro` ; le produit scalaire `dot(normalize(lpos-hp), n)` donne un éclairage diffus qui révèle le relief. On utilise une headlamp ici parce qu'on est dans un tunnel fermé : toute autre lampe serait vite hors champ.
- `pow(col, 3.)` durcit le contraste (gamma inversée pour exagérer la chute lumineuse).

> *Note :* le shader final mettra la lampe à `vec3(0.)` (origine du monde), mais ne sera visible qu'à partir de l'étape 8 quand on aura le **glow accumulé** qui prend le relais.

```glsl
#define sat(a) clamp(a, 0., 1.)

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

// Normale = gradient de la SDF par différences finies (centre = d courant, voisins = map(p-e))
// e.xyy = vec3(0.01,0,0), e.yxy = vec3(0,0.01,0), e.yyx = vec3(0,0,0.01) (swizzle GLSL)
vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(0., 0., -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd = getCam(rd, uv);

    vec3 p = ro;
    float hit = -1.;
    float lastD = 0.;                              // on garde la dernière distance pour la normale
    for (int i = 0; i < 128; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) { hit = distance(ro, p); break; }
        p += rd * d * .7;
    }

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp  = ro + rd*hit;                    // point d'impact
        vec3 n   = getNorm(hp, lastD);             // normale gradient
        vec3 lpos = ro;                            // headlamp : la lampe suit la caméra
        vec3 ldir = normalize(lpos - hp);          // direction point → lampe
        col = sat(dot(ldir, n)) * vec3(1.);        // lambert diffus
        col = pow(col, vec3(3.));                  // gamma "inverse" : durcit le contraste
    }
    fragColor = vec4(col, 1.);
}
```

---

## Étape 7 — Caméra qui tangue (roll / pitch sinusoïdaux)

**Notion :** on perturbe `ro` (translations XY oscillantes) et on fait tourner `rd` dans les plans `xz` et `yz` avec une `mat2` de rotation. La caméra n'avance plus en ligne droite : elle danse autour de l'axe.

```glsl
#define sat(a) clamp(a, 0., 1.)

// Rotation 2D : mat2 paramétrée par un angle. Utilisable sur n'importe quel swizzle vec2 (.xz, .yz...).
mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    // Caméra qui flotte : petites translations sinusoïdales en X et Y autour du chemin.
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    // Tangage / roulis : on tord la direction du rayon dans les plans xz et yz.
    rd.xz *= r2d(sin(iTime*.5)*.15);               // pitch (haut/bas)
    rd.yz *= r2d(sin(iTime + .5)*.15);             // yaw (gauche/droite), légèrement déphasé
    rd = getCam(rd, uv);

    vec3 p = ro;
    float hit = -1.;
    float lastD = 0.;
    for (int i = 0; i < 128; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) { hit = distance(ro, p); break; }
        p += rd * d * .7;
    }

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        vec3 ldir = normalize(ro - hp);            // headlamp (toujours sur la caméra)
        col = sat(dot(ldir, n)) * vec3(1.);
        col = pow(col, vec3(3.));
    }
    fragColor = vec4(col, 1.);
}
```

---

## Étape 8 — Glow par accumulation (faux volumetric)

**Notion :** trick classique. À chaque pas du raymarching, plus le rayon **frôle** la paroi (`res.x` petit), plus on cumule de la lumière dans une variable globale `accCol`. La couleur du glow varie avec `p.z`. Quand le pixel touche enfin la paroi, on ajoute `accCol` au shading → l'air semble lumineux à proximité du métal.

> *On en profite pour revenir à la lampe d'origine du shader final* (`lpos = vec3(0.)`). Elle est rapidement hors champ, donc son apport diffus tombe à zéro — mais ce n'est plus grave : c'est désormais le **glow accumulé** qui éclaire la scène.

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;                                       // ← variable globale d'accumulation du glow

// trace classique mais qui accumule, à chaque pas, une contribution lumineuse
// proportionnelle à la "proximité" du rayon avec la paroi.
float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        // pow(1 - d/.7, 30) : courbe très "pointue" → ne brille qu'à très courte distance.
        // Couleur : rose-orangé qui varie en B selon p.z (sin(p.z)*.5+.5 ∈ [0,1])
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);         // 256 pas pour avoir un glow bien intégré

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        // Retour à la lampe à l'origine (lpos=vec3(0.) → ldir=hp).
        // À ce stade dot(normalize(hp), n) ≈ 0 (lampe loin derrière), mais
        // c'est OK : le glow ci-dessous fait tout le boulot d'éclairage.
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;                             // ← glow ajouté APRÈS le shading diffus
        col = pow(col, vec3(3.));                  // gamma applique aussi au glow → punch
    }
    fragColor = vec4(col, 1.);
}
```

---

## Étape 9 — UV cylindriques de la paroi (visualisation)

**Notion :** pour pouvoir peindre des motifs sur la paroi du tunnel, il faut d'abord **paramétrer cette paroi en 2D**. Comme c'est un cylindre, on utilise les **coordonnées cylindriques** du point d'impact :
- coordonnée horizontale = **angle autour de l'axe Z** : `an = atan(hp.y, hp.x)` ∈ ]-π, π]
- coordonnée verticale = **position le long de l'axe** : `hp.z` (qu'on décale par `iTime` pour que la texture défile)

On stocke ces deux valeurs dans `luv = vec2(an, hp.z + iTime)`, puis on les **visualise** directement en couleur pour vérifier qu'elles forment bien un dépliage de la paroi : l'angle donne un dégradé qui fait le tour, et z donne des bandes qui défilent.

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        // ── coordonnées cylindriques du point d'impact ──
        float an  = atan(hp.y, hp.x);              // angle autour de l'axe Z, ∈ ]-π, π]
        vec2 luv  = vec2(an, hp.z + iTime);        // UV "déroulées" de la paroi (+iTime = défilement)

        // Visualisation : R = angle remappé en [0,1], G = z mod 1 (rayures)
        vec3 vis  = vec3(an*.5/3.14 + .5,          // angle → bandes verticales en dégradé
                         fract(luv.y*.5),           // z   → bandes horizontales qui défilent
                         0.);
        col = mix(col, vis, .6);                   // mix 60% pour garder un peu de relief
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** en regardant à l'intérieur du tunnel, l'angle (R) crée une transition rouge ↔ noir qui fait le tour de la paroi, et z (G) crée des bandes horizontales qui défilent vers nous. C'est notre "feuille" 2D sur laquelle on va dessiner aux étapes suivantes.

---

## Étape 10 — Tile par `mod` centré (visualisation des cellules)

**Notion :** on a nos UV cylindriques `luv`. Pour dessiner un motif **répété** partout sur la paroi, on **tile** cette feuille 2D en cellules de taille `rep`. Le trick s'appelle **mod centré** :

1. `id = floor((luv + .5*rep) / rep)` → **index entier** de la cellule (un id par cellule, on s'en servira pour différencier les rangées à l'étape suivante).
2. `luv = mod(luv + .5*rep, rep) - .5*rep` → ramène `luv` dans `[-rep/2, +rep/2]` autour du **centre** de la cellule courante. Sans le `+.5*rep` au début, l'origine serait au coin et la SDF qu'on poserait ensuite serait coupée en quatre — d'où le « centré ».

À ce stade on ne dessine encore rien : on **visualise** les cellules pour vérifier que le tile marche :
- **R** = position locale X dans la cellule (dégradé qui repart de 0 à chaque cellule)
- **G** = position locale Y dans la cellule
- **B** = damier alterné via la parité de `id.x + id.y`

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        // ── 1. UV cylindriques (comme étape 9) ──
        float an = atan(hp.y, hp.x);
        vec2 luv = vec2(an, hp.z + iTime);

        // ── 2. Tile en cellules de taille rep ──
        vec2 rep = vec2(.9, .5);                   // largeur .9 (angulaire), hauteur .5 (selon z)
        vec2 id  = floor((luv + .5*rep) / rep);    // index entier de cellule
        luv = mod(luv + .5*rep, rep) - .5*rep;     // mod centré : luv ∈ [-rep/2, +rep/2]

        // ── 3. Visualisation des cellules ──
        //   R = luv.x normalisé en [0,1]    (dégradé local horizontal qui repart à chaque cellule)
        //   G = luv.y normalisé en [0,1]    (dégradé local vertical)
        //   B = damier  (1 ou 0 selon parité de id.x + id.y)
        float damier = mod(id.x + id.y, 2.);
        vec3 vis = vec3(luv.x/rep.x + .5, luv.y/rep.y + .5, damier);
        col = mix(col, vis, .7);
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** la paroi du tunnel découpée en **cases régulières**. Chaque case montre un dégradé jaune-vert local (R et G) sur fond bleu/noir alterné en damier. Si les cases se cassent ou défilent bizarrement, c'est que `rep`, le mod centré ou les UV cylindriques sont incorrects — c'est *avant* de poser un dessin dedans qu'il faut vérifier ça.

---

## Étape 11 — Rectangle SDF dans chaque cellule (bandes lumineuses)

**Notion :** maintenant que les cellules sont bien posées, on dessine une **SDF rectangle** dans chacune avec `_sqr`. Un rectangle SDF, c'est `vec2 l = abs(p) - s; max(l.x, l.y)` → négatif dedans, positif dehors. Avec `s = vec2(.4, .05)` on obtient une **bande horizontale fine** (large mais peu épaisse).

Puis on **peint en blanc** à l'intérieur du rectangle :
```glsl
col = mix(col, vec3(1.), 1. - sat(shape*50.));
```
- `1 - sat(shape*50)` vaut ~1 quand `shape < 0` (dedans la forme), ~0 quand on est loin (dehors).
- Le facteur `*50` règle la **pente d'antialiasing** sur les bords (plus c'est grand, plus le bord est franc).

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

// SDF rectangle 2D centré : <0 dedans, >0 dehors.
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        // ── UV cylindriques + tile (étapes 9 et 10) ──
        float an = atan(hp.y, hp.x);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 rep = vec2(.9, .5);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv = mod(luv + .5*rep, rep) - .5*rep;

        // ── SDF rectangle dans chaque cellule ──
        float shape = _sqr(luv, vec2(.4, .05));    // bande horizontale fine

        // ── Peint en blanc à l'intérieur ──
        col = mix(col, vec3(1.), 1. - sat(shape*50.));
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** des **bandes blanches régulièrement espacées** sur la paroi, qui défilent vers nous (grâce au `+iTime` dans `luv.y`). C'est la grille de néons de base — on va l'animer et la colorer dans les étapes suivantes.

---

## Étape 12 — Faire glisser le motif dans les cellules (décalage uniforme)

**Notion :** notre rectangle est dessiné à partir de la coordonnée **locale** `luv` (celle après le `mod` centré). Donc si on **modifie `luv.x` AVANT le `mod`**, on déplace effectivement le rectangle horizontalement dans chaque cellule.

Premier test, le plus simple : décalage uniforme, **même vitesse pour toutes les cellules** : `luv.x += iTime*2.`. Toutes les bandes glissent ensemble vers la gauche/droite.

Subtilité importante : on calcule `id = floor(...)` **avant** d'appliquer ce décalage. Du coup `id` reste l'index *original* de la cellule — il ne bouge pas avec l'animation. (Sinon on aurait des sauts visuels à chaque traversée de cellule.)

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);    // id figé AVANT animation
        luv.x += iTime * 2.;                       // ← décalage uniforme (toutes les bandes ensemble)
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(.4, .05));
        col = mix(col, vec3(1.), 1. - sat(shape*50.));
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** toutes les bandes glissent **dans le même sens à la même vitesse** autour du tunnel. Joli, mais un peu monotone — on va briser cette uniformité à l'étape suivante.

---

## Étape 13 — Visualiser `sin(id.y*.5)` : la graine par ligne

**Notion :** avant d'animer chaque ligne séparément, on **regarde** la valeur qu'on s'apprête à utiliser. `sin(id.y*.5)` est une expression simple, mais elle a deux propriétés capitales qu'il faut bien voir :

1. **Stable à l'intérieur d'une ligne** : `id.y` ne change pas tant qu'on reste dans la même cellule verticale → toute la ligne aura la même valeur.
2. **Variable d'une ligne à l'autre** : `id.y = 0, 1, 2, …` donne `sin(0)=0, sin(.5)≈.48, sin(1)≈.84, sin(1.5)≈1, sin(2)≈.91, sin(2.5)≈.60, sin(3)≈.14, sin(3.5)≈-.35, …`

On la visualise avec un code couleur signé : **rouge si positive, bleu si négative**. À l'étape suivante, cette même valeur deviendra la **vitesse** de défilement de la ligne → les rouges glisseront à droite, les bleues à gauche.

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);

        // ── la graine qu'on va utiliser pour animer chaque ligne ──
        float seed = sin(id.y * .5);               // ∈ [-1, +1], stable par ligne

        // Visualisation signée :
        //   R = max(seed, 0)  → rouge si seed > 0
        //   B = max(-seed, 0) → bleu  si seed < 0
        //   G = 0
        vec3 vis = vec3(sat(seed), 0., sat(-seed));
        col = mix(col, vis, .7);
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** la paroi est striée de **larges bandes horizontales** uniformes — chacune correspond à une valeur de `id.y`. Certaines sont rougeâtres (graine positive), d'autres bleutées (graine négative), quelques unes presque noires (graine proche de 0). C'est cette palette qu'on va transformer en *vitesses de défilement* à l'étape suivante.

---

## Étape 14 — Décalage **par ligne** : `id.y` comme graine pseudo-aléatoire

**Notion :** maintenant qu'on sait décaler `luv.x` pour animer, on remplace le décalage constant par un terme qui **dépend de la ligne** :

```glsl
luv.x += sin(id.y*.5) * iTime * 2.;
```

Pourquoi ça marche ? `id.y` est l'index vertical de la cellule, **constant pour toutes les positions à l'intérieur d'une même ligne** et **différent d'une ligne à l'autre**. Donc :
- `sin(id.y*.5)` donne une **valeur stable par ligne** (entre -1 et +1)
- ligne 0 → `sin(0)=0` → ne bouge pas
- ligne 1 → `sin(.5)≈0.48` → glisse vers la droite à ~vitesse 0.96
- ligne 2 → `sin(1.)≈0.84` → glisse vers la droite à ~vitesse 1.68
- ligne 7 → `sin(3.5)≈-0.35` → glisse vers la **gauche**

→ chaque rangée défile à une vitesse (et un sens) différents = effet "pluie de néons".

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        // sin(id.y*.5) : valeur pseudo-aléatoire MAIS STABLE par ligne ∈ [-1, 1]
        // → chaque rangée a sa vitesse / son sens propre
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(.4, .05));
        col = mix(col, vec3(1.), 1. - sat(shape*50.));
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** les bandes ne défilent plus en bloc. Chaque ligne a sa propre vitesse, certaines même partent dans le sens opposé → effet "pluie de néons", très typique des shaders cyberpunk.

---

## Étape 15 — Color shifting dynamique (swap canaux + mélange par Z)

**Notions :**
- `col.zyx` permute B↔R → vire en cyan/orange.
- `mix(col, col.zyx, sin(iTime + p.z*.1)*.5+.5)` fait *respirer* le swap dans le temps et selon la profondeur → bandes de couleur qui se propagent le long du tunnel.
- second mix `mix(col, halo, sin(iTime*5. + p.z*.5)*.5+.5)` pour faire pulser les bandes lumineuses en intensité.

```glsl
#define sat(a) clamp(a, 0., 1.)

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    return -(length(p.xy) - 2. + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(.4, .05));

        // rgb = version "avec bandes blanches" ; col = version "sans bandes"
        vec3 rgb = mix(col, vec3(1.), 1. - sat(shape*50.));
        // 1er mix : fait pulser l'apparition des bandes (haute fréquence en p.z et iTime)
        col = mix(col, rgb, sin(iTime*5. + hp.z*.5)*.5+.5);
        // 2ème mix : swap des canaux R↔B en vagues lentes le long du tunnel
        col = mix(col, col.zyx, sin(iTime + hp.z*.1)*.5+.5);
    }
    fragColor = vec4(col, 1.);
}
```

---

## Étape 16 — Visualiser le spectre audio (`iChannel1`)

**Notion :** Shadertoy expose la musique sous forme d'une **texture** dans `iChannel1`. Cette texture est mise à jour à chaque frame et encode le **spectre fréquentiel** du son qui joue :

- **axe X** de la texture = **fréquence**, mappée de **0 (graves)** à **1 (aigus)**
- **valeur du pixel** = **amplitude** de cette fréquence à cet instant (0 = silence, 1 = max)
- on ne lit que la **première ligne** (y=0) : c'est de la donnée 1D, pas une vraie image

C'est exactement ce qu'on appelle une **FFT** (Fast Fourier Transform) en audio : on découpe le signal sonore continu en « bandes » de fréquences, et on lit l'énergie de chaque bande. Shadertoy fournit en général ~512 bandes, qu'on échantillonne par interpolation.

D'où la macro :

```glsl
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x
```

`FFT(0.)` = niveau des **graves** (kicks, basse).
`FFT(.5)` = niveau des **médiums** (voix, instruments principaux).
`FFT(.9)` = niveau des **aigus** (cymbales, sifflements).

**Avant d'utiliser** cette donnée pour piloter le tunnel, on lui consacre une **étape didactique plein écran** : on coupe tout le reste et on n'affiche **que** l'égaliseur. La hauteur de chaque colonne = `FFT(ouv.x)` directement — pas de mise à l'échelle, pas de zone réservée. On voit le spectre dans toute sa résolution.

> **Bind :** clique sur `iChannel1` dans Shadertoy → onglet **Music** ou **SoundCloud** → un morceau. Sans ça, `FFT()` renvoie 0 partout et l'égaliseur reste plat.

```glsl
// FFT : amplitude de la bande de fréquence "a" (∈ [0,1]) lue dans iChannel1.
// 0 = graves, 1 = aigus, valeur retournée ∈ [0,1].
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 ouv = fragCoord.xy / iResolution.xy;      // ouv.x ∈ [0,1] = fréquence interrogée
                                                    // ouv.y ∈ [0,1] = hauteur écran

    // Lecture du spectre : amplitude à la fréquence ouv.x
    float spectrum = FFT(ouv.x);

    vec3 col = vec3(0.);

    // ── Barre verticale : on est "dedans" si ouv.y est sous le sommet de la barre ──
    if (ouv.y < spectrum) {
        // Dégradé vert (bas) → rouge (haut) : plus c'est fort, plus c'est rouge.
        col = mix(vec3(.2, 1., .3), vec3(1., .2, .2), ouv.y);
    }

    // ── Grille de référence en arrière-plan ──
    // Lignes verticales tous les 10% de fréquence (graves|.1|.2|...|.9|aigus)
    if (fract(ouv.x * 10.) < .005) col += vec3(.08);
    // Lignes horizontales tous les 25% d'amplitude
    if (fract(ouv.y * 4.) < .005)  col += vec3(.05);

    // ── Repères colorés sur l'axe X pour situer graves / médiums / aigus ──
    // Bande très fine en haut de l'écran qui passe du bleu (graves) au rouge (aigus).
    if (ouv.y > .98) col = mix(vec3(.2, .3, 1.), vec3(1., .3, .2), ouv.x);

    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** un égaliseur en barres qui **occupe toute la fenêtre**, pulsant en direct sur la musique. La **moitié gauche** (graves : kicks, basse) bouge sur le rythme. La **moitié droite** (aigus : cymbales, sifflantes) est plus erratique et plus fine. La bande colorée en haut (bleu → rouge) rappelle la convention « gauche = graves, droite = aigus ». À l'étape suivante on prend cette même donnée et on s'en sert pour piloter le tunnel.

---

## Étape 17 — FFT pilote le **rayon du tube** (la paroi respire)

**Notion :** on commence par le branchement le plus spectaculaire et le plus facile à observer : la **forme du tunnel elle-même** est modulée par la musique. Dans `map()`, on ajoute un terme `rad` au rayon :

```glsl
float rad = FFT(abs(p.z*.001)) * .25;
return -(length(p.xy) - 2. - rad + sin(p.z*.25));
```

Deux choses à comprendre :

1. **Pourquoi `abs(p.z*.001)` comme fréquence ?** Chaque tranche du tunnel (chaque valeur de `p.z`) interroge une fréquence FFT différente. Comme la caméra avance en Z, des tranches *différentes* sont sous tes yeux à chaque instant → toute la longueur du tunnel ressemble à une **barre d'égaliseur 3D**. Le `*.001` est l'échelle : il faut que `abs(p.z*.001)` reste dans `[0, 1]` pour balayer le spectre (sinon on tape en dehors de la texture FFT).
2. **Pourquoi `* .25` ?** L'amplitude FFT est dans `[0, 1]`. Sans atténuation, le rayon varierait de 2 à 3 (50 % de plus). Avec `*.25`, il varie de 2 à 2.25 max → effet présent mais pas excessif.

```glsl
#define sat(a) clamp(a, 0., 1.)
// FFT : amplitude de la bande "a" (graves=0, aigus=1) lue dans iChannel1.
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    // ── NEW : rayon modulé par la FFT ──
    // abs(p.z*.001) ∈ [0, 1] → balaye le spectre le long du tunnel.
    // * .25 = amplitude raisonnable (rayon varie de ~2.0 à ~2.25)
    float rad = FFT(abs(p.z*.001)) * .25;
    return -(length(p.xy) - 2. - rad + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        // bandes inchangées par rapport à l'étape 15 (taille constante)
        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(.4, .05));
        vec3 rgb = mix(col, vec3(1.), 1. - sat(shape*50.));
        col = mix(col, rgb, sin(iTime*5. + hp.z*.5)*.5+.5);
        col = mix(col, col.zyx, sin(iTime + hp.z*.1)*.5+.5);
    }
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** la paroi du tunnel **gonfle et se contracte** au rythme de la musique, comme si elle respirait. Quand un kick passe, la paroi se rapproche (rayon plus grand depuis l'intérieur = paroi plus petite). Les bandes lumineuses sont toujours là mais elles ne réagissent pas encore au son : c'est uniquement la **géométrie** qui est animée.

---

## Étape 18 — FFT pilote **la grille** (bandes pulsantes + flash graves + gain global)

**Notion :** maintenant qu'on sait brancher une FFT, on en branche trois autres en même temps — toutes affectent la **couleur** (pas la géométrie) :

1. **Taille des bandes par ligne** : `vec2(5.4 * pow(FFT(abs(id.y*.01)), 5.), .05)`
   - chaque rangée (`id.y`) tape sa propre fréquence
   - `pow(...,5)` exagère les pics : seules les fréquences vraiment fortes étirent la bande, le reste reste fin
   - facteur `5.4` permet à la bande, sur un pic franc, d'occuper presque toute la cellule

2. **Flash graves** : `pow(FFT(.0), 2.) * 2.`
   - `FFT(.0)` = niveau des graves uniquement → flash sur les kicks
   - `pow(..,2)` adoucit (sinon ça flashe en permanence)
   - on ajoute une couleur rose-orangé `vec3(1., .5, …)`, modulée par `(1 - sat(shape*1.))` (s'éteint dans les bandes) et `(1 - sat(length(uv)))` (vignettage : seul le centre flashe)

3. **Gain global** : `col *= 1. + pow(FFT(.1), 1.) * 2.`
   - en toute fin, on multiplie l'image par ~1 à 3 selon les bas-médiums
   - donne l'effet "boost de volume visuel" sur les kicks et la basse

```glsl
#define sat(a) clamp(a, 0., 1.)
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    float rad = FFT(abs(p.z*.001)) * .25;
    return -(length(p.xy) - 2. - rad + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;

        // ── 1. taille des bandes pilotée par la FFT de la ligne ──
        // pow(..,5) : seuls les pics francs étirent la bande
        float shape = _sqr(luv, vec2(5.4 * pow(FFT(abs(id.y*.01)), 5.), .05));
        vec3 rgb = mix(col, vec3(1.), 1. - sat(shape*50.));

        // ── 2. flash graves : seulement au centre, éteint dans les bandes ──
        rgb += pow(FFT(.0), 2.) * 2.
             * vec3(1., .5, sin(hp.z*10.)*.5+.5)
             * (1. - sat(shape*1.))                  // pas par-dessus les bandes
             * (1. - sat(length(uv)));               // vignettage : centre uniquement

        col = mix(col, rgb, sin(iTime*5. + hp.z*.5)*.5+.5);
        col = mix(col, col.zyx, sin(iTime + hp.z*.1)*.5+.5);
    }

    // ── 3. gain global modulé par les bas-médiums (~bande .1) ──
    col *= 1. + pow(FFT(.1), 1.) * 2.;
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** les bandes lumineuses sur la paroi **changent de longueur** par rangée selon la musique (chaque ligne sa fréquence). Sur les **kicks**, un halo rose-orangé apparaît au centre de l'image (flash graves), et toute la luminance globale grimpe d'un coup (gain global). C'est maintenant un vrai shader audio-réactif.

---

## Étape 19 — Texture sur la paroi (`iChannel0`), **sans défilement**

**Notion :** on **plaque une texture 2D** sur la paroi du tunnel. La question essentielle : *comment passer d'un point 3D `hp` à une coordonnée 2D `(U, V)` pour samplé la texture ?* On utilise des **UV cylindriques**, mais avec deux composantes très différentes de celles utilisées pour les bandes :

```glsl
vec2 texUV = vec2(atan(hp.y, hp.x) * 2.,     // U = angle * 2 → 2 répétitions sur le tour
                  length(hp.xy * .1)) * .1;  // V = distance radiale (≈ constante)
col += 0.2 * texture(iChannel0, texUV).xyz;
```

- **U** = `atan(hp.y, hp.x) * 2.` : l'angle autour du tube, multiplié par 2 → la texture fait **2 tours complets** sur la circonférence (sinon elle serait trop étirée). Le `*.1` final fait du zoom.
- **V** = `length(hp.xy * .1)` : la distance radiale. Comme on touche toujours la paroi (rayon ≈ 2), `length(hp.xy*.1) ≈ 0.2` → **V est presque constant**. Donc on ne sample qu'une fine "tranche horizontale" de la texture.
- `* 0.2` : on ajoute la texture *par-dessus* à 20 % d'intensité (sinon elle tue le lighting et les bandes).

**Conséquence à cette étape :** comme V est quasi-fixe, la texture est **figée** sur la paroi — elle tourne avec nous parce que `atan` dépend de la position, mais elle **ne défile pas le long du tunnel**. C'est volontaire : on isole d'abord le concept de mapping, on ajoutera le défilement à l'étape suivante.

> **Bind :** clique sur `iChannel0` → onglet *Misc* ou *Textures* → choisis par exemple *Abstract 1* (texture marbrée).

```glsl
#define sat(a) clamp(a, 0., 1.)
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    float rad = FFT(abs(p.z*.001)) * .25;
    return -(length(p.xy) - 2. - rad + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(5.4 * pow(FFT(abs(id.y*.01)), 5.), .05));

        vec3 rgb = mix(col, vec3(1.), 1. - sat(shape*50.));
        rgb += pow(FFT(.0), 2.) * 2. * vec3(1., .5, sin(hp.z*10.)*.5+.5)
               * (1. - sat(shape*1.)) * (1. - sat(length(uv)));
        col = mix(col, rgb, sin(iTime*5. + hp.z*.5)*.5+.5);

        // ── texture sur la paroi, mapping cylindrique SANS défilement temporel ──
        col += 0.2 * texture(iChannel0,
                             vec2(atan(hp.y, hp.x) * 2.,
                                  length(hp.xy * .1)) * .1).xyz;

        col = mix(col, col.zyx, sin(iTime + hp.z*.1)*.5+.5);
    }

    col *= 1. + pow(FFT(.1), 1.) * 2.;
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** la paroi du tunnel a maintenant une **matière** — un motif marbré (selon la texture choisie). Mais ce motif est **fixe** : il tourne quand on roule autour de l'axe, mais il ne défile pas le long du tunnel quand on avance. À l'étape suivante on le fait glisser.

---

## Étape 20 — Faire défiler la texture le long de l'axe

**Notion :** un simple terme `- .25*iTime` dans la coordonnée V suffit à faire **défiler** la texture vers nous : à chaque frame on sample un peu plus haut dans la texture. Combiné avec le mouvement de la caméra, ça donne une impression de matière qui glisse / coule le long du tunnel.

```glsl
length(hp.xy * .1) - .25 * iTime
```

C'est *exactement* la même technique que pour les bandes lumineuses à l'étape 11 (`luv = vec2(an, hp.z + iTime)`) : décaler une UV dans le temps = animation gratuite.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }
float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

float map(vec3 p)
{
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;
    p.y  += sin(p.z*2. + iTime) * .1;
    float rad = FFT(abs(p.z*.001)) * .25;
    return -(length(p.xy) - 2. - rad + sin(p.z*.25));
}

vec3 accCol;

float trace(vec3 ro, vec3 rd, int steps, out float lastD)
{
    accCol = vec3(0.);
    vec3 p = ro;
    lastD = 0.;
    for (int i = 0; i < steps; i++) {
        float d = map(p);
        lastD = d;
        if (d < 0.01) return distance(p, ro);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(d/.7), 30.) * .3;
        p += rd * d * .7;
    }
    return -1.;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    return normalize(vec3(d) - vec3(map(p-e.xyy), map(p-e.yxy), map(p-e.yyx)));
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.xx;

    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);

    float lastD;
    float hit = trace(ro, rd, 256, lastD);

    vec3 col = vec3(0.);
    if (hit > 0.) {
        vec3 hp = ro + rd*hit;
        vec3 n  = getNorm(hp, lastD);
        col = sat(dot(normalize(hp), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        float an = atan(hp.y, hp.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, hp.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(5.4 * pow(FFT(abs(id.y*.01)), 5.), .05));

        vec3 rgb = mix(col, vec3(1.), 1. - sat(shape*50.));
        rgb += pow(FFT(.0), 2.) * 2. * vec3(1., .5, sin(hp.z*10.)*.5+.5)
               * (1. - sat(shape*1.)) * (1. - sat(length(uv)));
        col = mix(col, rgb, sin(iTime*5. + hp.z*.5)*.5+.5);

        // ── texture sur la paroi, AVEC défilement temporel ──
        //   V = length(xy*.1) - .25*iTime → la texture remonte vers nous
        col += 0.2 * texture(iChannel0,
                             vec2(atan(hp.y, hp.x) * 2.,
                                  length(hp.xy * .1) - .25 * iTime) * .1).xyz;

        col = mix(col, col.zyx, sin(iTime + hp.z*.1)*.5+.5);
    }

    col *= 1. + pow(FFT(.1), 1.) * 2.;
    fragColor = vec4(col, 1.);
}
```

> **Ce qu'on doit voir :** la matière de la paroi **glisse maintenant vers nous** comme si on était emporté par un fluide. C'est cette texture animée qui donne au shader son côté "vivant" — sans elle, la paroi paraît métallique et figée.

---

## Étape 21 — FINAL : feedback Buffer A (`iChannel2`)

**Notion :** **feedback temporel**. On mélange l'image courante avec le frame **précédent**, échantillonné via `iChannel2`. Pour que ça marche dans Shadertoy :

1. crée un onglet **Buffer A** et **colle le même code** que dans *Image*.
2. dans *Buffer A*, binder `iChannel0/1/2` aux **mêmes** sources que dans *Image*, **plus** : `iChannel2` ← *Buffer A* lui-même (auto-référence = feedback).
3. dans *Image*, binder `iChannel2` ← *Buffer A*.

Résultat : trails / motion blur audio-réactif, car le coefficient de mélange dépend de `FFT(.2)`. C'est le shader original tel qu'il tourne sur Shadertoy.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define FFT(a) texture(iChannel1, vec2(a, 0.)).x

mat2 r2d(float a) { float c = cos(a), s = sin(a); return mat2(c,-s, s,c); }

// _min / _max : utilitaires pour composer plusieurs SDF avec un "id matériau" (.y).
// Ici on n'a qu'un seul matériau, mais on garde la structure prête pour étendre.
vec2 _min(vec2 a, vec2 b) { if (a.x < b.x) return a; return b; }
vec2 _max(vec2 a, vec2 b) { if (a.x > b.x) return a; return b; }

// map retourne vec2 = (distance, mat_id). Ouvre la porte à plusieurs objets/matériaux.
vec2 map(vec3 p)
{
    vec3 op = p;                                   // sauvegarde des coordonnées d'origine (réservé)
    vec2 acc = vec2(1000., -1.);                   // distance initiale énorme, mat_id "rien"

    float an = atan(p.y, p.x);
    p.xy -= vec2(sin(p.z + iTime), cos(p.z*.5 + iTime)) * .5;   // tunnel qui serpente
    p.y  += sin(p.z*2. + iTime) * .1;                            // vibration verticale
    float rad = FFT(abs(p.z*.001)) * .25;                        // rayon piloté par la FFT
    vec2 tube = vec2(-(length(p.xy) - 2. - rad + sin(p.z*.25)), 0.);  // SDF du tube + mat_id=0
    acc = _min(acc, tube);                         // garde la plus proche
    return acc;
}

vec3 accCol;

// trace renvoie vec3 = (dernière_distance, distance_parcourue, mat_id) si hit,
// ou vec3(-1.) si jamais convergé. La composante .y sert de "hit" booléen (>0).
vec3 trace(vec3 ro, vec3 rd, int steps)
{
    accCol = vec3(0.);
    vec3 p = ro;
    for (int i = 0; i < steps; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
            return vec3(res.x, distance(p, ro), res.y);
        accCol += vec3(1., .5, sin(p.z)*.5+.5) * pow(1. - sat(res.x/.7), 30.) * .3;
        p += rd * res.x * .7;
    }
    return vec3(-1.);
}

vec3 getCam(vec3 rd, vec2 uv)
{
    float fov = 1.;
    vec3 r = normalize(cross(rd, vec3(0.,1.,0.)));
    vec3 u = normalize(cross(rd, r));
    return normalize(rd + fov*(r*uv.x + u*uv.y));
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.01, 0.);
    // .x après chaque map() car map renvoie maintenant vec2 (on prend la distance)
    return normalize(vec3(d) - vec3(map(p-e.xyy).x, map(p-e.yxy).x, map(p-e.yyx).x));
}

float _sqr(vec2 p, vec2 s) { vec2 l = abs(p)-s; return max(l.x, l.y); }

// Le rendu principal isolé dans rdr() pour pouvoir le réutiliser et garder mainImage propre.
vec3 rdr(vec2 uv)
{
    vec3 col = vec3(1.);
    float t = iTime*2.;
    vec3 ro = vec3(sin(iTime)*.15, cos(iTime*.5)*.12, -12.+t);
    vec3 ta = vec3(0., 0., 0.+t);
    vec3 rd = normalize(ta - ro);
    rd.xz *= r2d(sin(iTime*.5)*.15);
    rd.yz *= r2d(sin(iTime + .5)*.15);
    rd = getCam(rd, uv);
    vec3 res = trace(ro, rd, 256);
    if (res.y > 0.)                                // res.y = distance parcourue → >0 = hit
    {
        vec3 p = ro + rd*res.y;
        vec3 n = getNorm(p, res.x);
        col = n*.5 + .5;                           // (vu en debug, remplacé juste après)
        vec3 lpos = vec3(0.);
        vec3 ldir = p - lpos;
        col = sat(dot(normalize(ldir), n)) * vec3(1.);
        col += accCol;
        col = pow(col, vec3(3.));

        // bandes lumineuses + animation par ligne
        float an = atan(p.y, p.x);
        vec2 rep = vec2(.9, .5);
        vec2 luv = vec2(an, p.z + iTime);
        vec2 id  = floor((luv + .5*rep) / rep);
        luv.x += sin(id.y*.5) * iTime * 2.;
        luv = mod(luv + .5*rep, rep) - .5*rep;
        float shape = _sqr(luv, vec2(5.4 * pow(FFT(abs(id.y*.01)), 5.), .05));
        vec3 rgb = mix(col, vec3(1.), 1. - sat(shape*50.));
        rgb += pow(FFT(.0), 2.) * 2. * vec3(1., .5, sin(p.z*10.)*.5+.5)
               * (1. - sat(shape*1.)) * (1. - sat(length(uv*1.)));
        col = mix(col, rgb, sin(iTime*5. + p.z*.5)*.5+.5);

        // texture marbrée sur la paroi
        col += 0.2 * texture(iChannel0,
                             vec2(atan(p.y, p.x)*2., length(p.xy*.1) - .25*iTime)*.1).xyz;

        // swap canaux R↔B en vagues
        col = mix(col, col.zyx, sin(iTime*1. + p.z*.1)*.5+.5);
    }
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 ouv = fragCoord.xy / iResolution.xy;                   // uv [0,1] pour sample du buffer
    vec2 uv  = (fragCoord - vec2(.5)*iResolution.xy) / iResolution.xx;  // uv centré pour le rendu 3D

    vec3 col = rdr(uv);
    col *= 1. + pow(FFT(.1), 1.) * 2.;             // gain global pulsé musique

    // ── FEEDBACK : on mélange l'image actuelle avec le frame précédent ──
    //   - iChannel2 = Buffer A (qui contient ce même rendu au frame N-1)
    //   - coefficient de mélange : .5 de base + boost par FFT(.2) (médiums)
    //   → trails / motion blur audio-réactifs
    col = mix(col, texture(iChannel2, ouv).xyz, .5 + pow(FFT(.2), 2.) * .5);
    fragColor = vec4(col, 1.0);
}
```

---

## Récap des concepts par étape

| # | Concept clé |
|---|---|
| 1 | UV centrées + caméra look-at qui glisse en Z |
| 2 | SDF cylindre **inversé** = on est dans le tube |
| 3 | Shading par distance parcourue |
| 4 | **Domain warping** : centre du tube décalé par sinusoïdes (le tunnel serpente) |
| 5 | Rayon variable selon Z (le tube respire) |
| 6 | Normales par gradient + headlamp + gamma `pow(col, 3.)` |
| 7 | Caméra qui tangue : `r2d` sur `rd.xz` / `rd.yz` |
| 8 | **Glow par accumulation** dans `accCol` pendant le raymarch |
| 9 | UV cylindriques de la paroi (`atan` + `z`) — visualisées |
| 10 | **Tile** par `mod` centré → cellules visualisées (damier + dégradé local) |
| 11 | Rectangle SDF (`_sqr`) dans chaque cellule → bandes blanches |
| 12 | Décalage **uniforme** du motif (`luv.x += iTime*2.`) : toutes les bandes glissent ensemble |
| 13 | Visualiser `sin(id.y*.5)` : graine **stable par ligne**, signe → futur sens |
| 14 | Décalage **par ligne** : `sin(id.y*.5)*iTime*2.` → vitesses différentes par rangée |
| 15 | Color shifting : `mix(col, col.zyx, …)` + pulsation des bandes |
| 16 | **Spectre FFT visualisé plein écran** : égaliseur didactique pur (`iChannel1`) |
| 17 | FFT pilote le **rayon du tube** : la paroi respire avec la musique |
| 18 | FFT pilote la grille : bandes pulsantes (`pow^5`) + flash graves + gain global |
| 19 | Texture sur la paroi en UV cylindriques (`iChannel0`), **sans défilement** |
| 20 | Faire **défiler** la texture : `-.25*iTime` dans la coord V |
| 21 | **Feedback Buffer A** (`iChannel2`) modulé par la FFT = trails audio-réactifs |
