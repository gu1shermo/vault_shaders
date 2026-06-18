
# Refract 2 — « Let's self reflect » décomposé (focus réfraction)

Shader d'origine : *Let's self reflect* de **mrange** (CC0). Contrairement à `refract1` (le diamant), celui-ci fait de la **vraie** réfraction : le rayon est **plié** (`refract()`, loi de Snell), il **entre** dans le solide, **rebondit** à l'intérieur jusqu'à 6 fois (les « miroirs intérieurs » du titre), et à chaque rebond une partie **ressort** pour échantillonner le décor.

> **Rappel du contraste avec refract1**
> | | refract1 (diamant) | refract2 (ce shader) |
> |---|---|---|
> | Pliage du rayon (Snell) | ❌ jamais | ✅ entrée + sorties (`refract()`) |
> | Sortie de l'objet | ❌ s'arrête sur la paroi arrière | ✅ ressort à chaque rebond |
> | Rebonds internes | ❌ aucun | ✅ jusqu'à 6 |
> | Transparence | truquée (teinte = épaisseur) | physique (rayons sortants → décor) |
>
> En clair : **refract1 simule l'effet, refract2 simule le transport de lumière.**

## Comment utiliser ces étapes

Le shader est **monolithique**. Plutôt que de tout recopier à chaque étape, on fige une **BASE** (géométrie du polyèdre + décor + raymarching) dans l'onglet **Common** de Shadertoy, **une seule fois**. Chaque étape ne fournit ensuite que l'onglet **Image** : les deux fonctions de réfraction qui évoluent (`render2` = les rebonds intérieurs, `render3` = le rayon primaire) + `mainImage`.

> **Marche à suivre dans Shadertoy :**
> 1. Crée un onglet **Common** (bouton `+`) et colles-y le bloc **BASE** ci-dessous (inchangé pour toutes les étapes).
> 2. Dans l'onglet **Image**, colle le bloc de l'étape voulue.
> 3. Aucun channel ni texture nécessaire (tout est procédural).

La BASE expose deux **prototypes** (`render2`, `render3`) : c'est ce qui permet à `effect()` (dans Common) d'appeler `render3()` alors qu'il n'est défini que dans l'onglet Image. Tant que les deux fonctions sont définies dans l'Image, ça compile.

Le polyèdre lui-même (repli de symétrie de *knighty*) est traité comme une **boîte noire** : on ne le décortique pas ici, on se concentre sur la réfraction.

---

## Le BASE — onglet **Common** (à coller une seule fois)

```glsl
// ===== Paramètres du solide (knighty) =====
const float rotation_speed= 0.25;
const float poly_U        = 1.;
const float poly_V        = 0.5;
const float poly_W        = 1.0;
const int   poly_type     = 3;
const float poly_zoom     = 2.0;
const float inner_sphere  = 1.;
const float refr_index    = 0.9;   // indice de réfraction (entrée). <1 = look artistique
#define MAX_BOUNCES2        6      // nb de rebonds internes max

#define TIME        iTime
#define RESOLUTION  iResolution
#define PI          3.141592654
#define TAU         (2.0*PI)

const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

#define TOLERANCE2          0.0005
#define MAX_RAY_MARCHES2    50
#define NORM_OFF2           0.005
#define BACKSTEP2

#define TOLERANCE3          0.0005
#define MAX_RAY_LENGTH3     10.0
#define MAX_RAY_MARCHES3    90
#define NORM_OFF3           0.005

const vec3 rayOrigin    = vec3(0.0, 1., -5.);
const vec3 sunDir       = normalize(-rayOrigin);

const vec3 sunCol       = HSV2RGB(vec3(0.06 , 0.90, 1E-2))*1.;
const vec3 bottomBoxCol = HSV2RGB(vec3(0.66, 0.80, 0.5))*1.;
const vec3 topBoxCol    = HSV2RGB(vec3(0.60, 0.90, 1.))*1.;
const vec3 glowCol0     = HSV2RGB(vec3(0.05 , 0.7, 1E-3))*1.;
const vec3 glowCol1     = HSV2RGB(vec3(0.95, 0.7, 1E-3))*1.;
const vec3 beerCol      = -HSV2RGB(vec3(0.15+0.5, 0.7, 2.));
const float rrefr_index = 1./refr_index;   // indice inverse (sortie)

const float poly_cospin   = cos(PI/float(poly_type));
const float poly_scospin  = sqrt(0.75-poly_cospin*poly_cospin);
const vec3  poly_nc       = vec3(-0.5, -poly_cospin, poly_scospin);
const vec3  poly_pab      = vec3(0., 0., 1.);
const vec3  poly_pbc_     = vec3(poly_scospin, 0., 0.5);
const vec3  poly_pca_     = vec3(0., poly_scospin, poly_cospin);
const vec3  poly_p        = normalize((poly_U*poly_pab+poly_V*poly_pbc_+poly_W*poly_pca_));
const vec3  poly_pbc      = normalize(poly_pbc_);
const vec3  poly_pca      = normalize(poly_pca_);

mat3 g_rot;     // rotation courante du solide (posée par mainImage)
vec2 g_gd;      // "glow distance" : min des distances frôlées (posée par les df)

// rotation amenant z sur d (Inigo Quilez)
mat3 rot(vec3 d, vec3 z) {
  vec3  v = cross( z, d );
  float c = dot( z, d );
  float k = 1.0/(1.0+c);
  return mat3( v.x*v.x*k + c,     v.y*v.x*k - v.z,    v.z*v.x*k + v.y,
               v.x*v.y*k + v.z,   v.y*v.y*k + c,      v.z*v.y*k - v.x,
               v.x*v.z*k - v.y,   v.y*v.z*k + v.x,    v.z*v.z*k + c    );
}

// tonemap ACES (Matt Taylor)
vec3 aces_approx(vec3 v) {
  v = max(v, 0.0); v *= 0.6;
  float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
  return clamp((v*(a*v+b))/(v*(c*v+d)+e), 0.0, 1.0);
}

float sphere(vec3 p, float r) { return length(p) - r; }
float box(vec2 p, vec2 b) { vec2 d = abs(p)-b; return length(max(d,0.0)) + min(max(d.x,d.y),0.0); }

// --- Polyèdre de knighty (boîte noire) ---
void poly_fold(inout vec3 pos) {
  vec3 p = pos;
  for(int i = 0; i < poly_type; ++i){
    p.xy  = abs(p.xy);
    p    -= 2.*min(0., dot(p,poly_nc)) * poly_nc;
  }
  pos = p;
}
float poly_plane(vec3 pos) {
  float d0 = dot(pos, poly_pab);
  float d1 = dot(pos, poly_pbc);
  float d2 = dot(pos, poly_pca);
  return max(max(d0, d1), d2);
}
float poly_corner(vec3 pos) { return length(pos) - .0125; }
float dot2(vec3 p) { return dot(p, p); }
float poly_edge(vec3 pos) {
  float dla = dot2(pos-min(0., pos.x)*vec3(1., 0., 0.));
  float dlb = dot2(pos-min(0., pos.y)*vec3(0., 1., 0.));
  float dlc = dot2(pos-min(0., dot(pos, poly_nc))*poly_nc);
  return sqrt(min(min(dla, dlb), dlc))-2E-3;
}
// renvoie (plan, arête, coin) du solide au point pos
vec3 shape(vec3 pos) {
  pos *= g_rot;
  pos /= poly_zoom;
  poly_fold(pos);
  pos -= poly_p;
  return vec3(poly_plane(pos), poly_edge(pos), poly_corner(pos))*poly_zoom;
}

// --- Décor (sol + plafond + soleil) échantillonné par une direction ---
vec3 render0(vec3 ro, vec3 rd) {
  vec3 col = vec3(0.0);
  float srd  = sign(rd.y);
  float tp   = -(ro.y-6.)/abs(rd.y);
  if (srd < 0.) {
    col += bottomBoxCol*exp(-0.5*(length((ro + tp*rd).xz)));
  }
  if (srd > 0.0) {
    vec3 pos  = ro + tp*rd;
    vec2 pp = pos.xz;
    float db = box(pp, vec2(5.0, 9.0))-3.0;
    col += topBoxCol*rd.y*rd.y*smoothstep(0.25, 0.0, db);
    col += 0.2*topBoxCol*exp(-0.5*max(db, 0.0));
    col += 0.05*sqrt(topBoxCol)*max(-db, 0.0);
  }
  col += sunCol/(1.001-dot(sunDir, rd));
  return col;
}

// --- Champ INTÉRIEUR (coque vue de dedans + sphère interne) : pour les rebonds ---
float df2(vec3 p) {
  vec3 ds = shape(p);
  float d2 = ds.y-5E-3;
  float d0 = min(-ds.x, d2);
  float d1 = sphere(p, inner_sphere);
  g_gd = min(g_gd, vec2(d2, d1));
  return min(d0, d1);
}
float rayMarch2(vec3 ro, vec3 rd, float tinit) {
  float t = tinit;
  vec2 dti = vec2(1e10,0.0);
  int i;
  for (i = 0; i < MAX_RAY_MARCHES2; ++i) {
    float d = df2(ro + rd*t);
    if (d<dti.x) { dti=vec2(d,t); }
    if (d < TOLERANCE2) break;   // coque fermée : on finit toujours par toucher
    t += d;
  }
  if(i==MAX_RAY_MARCHES2) { t=dti.y; }
  return t;
}
vec3 normal2(vec3 pos) {
  vec2 eps = vec2(NORM_OFF2,0.0);
  vec3 nor;
  nor.x = df2(pos+eps.xyy) - df2(pos-eps.xyy);
  nor.y = df2(pos+eps.yxy) - df2(pos-eps.yxy);
  nor.z = df2(pos+eps.yyx) - df2(pos-eps.yyx);
  return normalize(nor);
}

// --- Champ EXTÉRIEUR (surface du solide) : pour le rayon primaire ---
float df3(vec3 p) {
  vec3 ds = shape(p);
  g_gd = min(g_gd, ds.yz);
  float d0 = ds.x;
  d0 = min(d0, ds.y);
  d0 = min(d0, ds.z);
  return d0;
}
float rayMarch3(vec3 ro, vec3 rd, float tinit, out int iter) {
  float t = tinit;
  int i;
  for (i = 0; i < MAX_RAY_MARCHES3; ++i) {
    float d = df3(ro + rd*t);
    if (d < TOLERANCE3 || t > MAX_RAY_LENGTH3) break;
    t += d;
  }
  iter = i;
  return t;
}
vec3 normal3(vec3 pos) {
  vec2 eps = vec2(NORM_OFF3,0.0);
  vec3 nor;
  nor.x = df3(pos+eps.xyy) - df3(pos-eps.xyy);
  nor.y = df3(pos+eps.yxy) - df3(pos-eps.yxy);
  nor.z = df3(pos+eps.yyx) - df3(pos-eps.yyx);
  return normalize(nor);
}

// === PROTOTYPES : définis dans l'onglet Image (ils évoluent à chaque étape) ===
vec3 render2(vec3 ro, vec3 rd, float db);
vec3 render3(vec3 ro, vec3 rd);

// --- Caméra + post-traitement (fixe) ---
vec3 effect(vec2 p, vec2 pp) {
  const float fov = 2.0;
  const vec3 up = vec3(0., 1., 0.);
  const vec3 la = vec3(0.0);
  const vec3 ww = normalize(normalize(la-rayOrigin));
  const vec3 uu = normalize(cross(up, ww));
  const vec3 vv = cross(ww, uu);
  vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

  vec3 col = render3(rayOrigin, rd);     // ← appelle le render3 de l'onglet Image
  col -= 2E-2*vec3(2.,3.,1.)*(length(p)+0.25);   // vignette
  col = aces_approx(col);                // tonemap HDR → LDR
  col = sqrt(col);                       // gamma
  return col;
}
```

> **À retenir :** tout ce qui précède ne bouge plus. Les étapes ne touchent qu'à `render2`/`render3` (onglet Image). `df3`/`rayMarch3` = la surface du solide (rayon primaire) ; `df2`/`rayMarch2` = l'intérieur de la coque + la sphère centrale (les rebonds).

---

## Étape 1 — Le décor seul (`render0`)

**Notion :** avant tout objet, on regarde le **décor** que les rayons réfléchis/réfractés iront échantillonner. `render0(ro, rd)` ne dépend que d'une **direction** : un sol (bas), un plafond encadré (haut) et un **soleil** (pic spéculaire). C'est l'"environnement" de ce shader — l'équivalent de la cubemap de refract1, mais **procédural**.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) { return vec3(0.0); }   // pas encore utilisé

vec3 render3(vec3 ro, vec3 rd) {
  return render0(ro, rd);                                        // on affiche juste le décor
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** un fond sombre dégradé avec un halo de soleil. Pas encore de solide. `mainImage` est **identique pour toutes les étapes** (il pose `g_rot` = la rotation animée du solide) — on ne le recommentera plus.

---

## Étape 2 — Le solide (raymarching + normales)

**Notion :** on lance le **rayon primaire** sur la surface du solide via `rayMarch3` (champ `df3`). Au point d'impact `p1`, on calcule la **normale** `n1` et on l'affiche en couleur (`n*.5+.5`) pour révéler la géométrie facettée du polyèdre.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) { return vec3(0.0); }

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    col = n1*0.5 + 0.5;                  // normales en couleur
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** un solide facetté tourne au centre. Les plages de couleur = les faces (chaque orientation → une couleur). `g_gd = vec2(1E3)` réinitialise l'accumulateur de glow avant le march (on s'en servira plus tard).

---

## Étape 3 — Reflet extérieur (miroir) + Fresnel

**Notion :** premier vrai matériau : le solide **réfléchit** le décor. `r1 = reflect(rd, n1)`, et on échantillonne `render0` dans cette direction. On pondère par le terme de **Fresnel** `fre1 = (1 + dot(rd,n1))²` : ~0 de face, ~1 en incidence rasante → les bords réfléchissent plus que le centre (comme tout diélectrique réel).

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) { return vec3(0.0); }

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1 = reflect(rd, n1);
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;     // Fresnel (Schlick-like)
    col = render0(p1, r1)*(0.5 + 0.5*fre1);          // miroir de l'environnement
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** le solide devient **chromé** : il renvoie le sol, le plafond, le soleil. Les arêtes (incidence rasante) brillent plus fort que les faces de face (Fresnel). Toujours **opaque** : on ne voit pas à travers.

---

## Étape 4 — Réfraction d'ENTRÉE : le rayon est plié et entre (le « vrai » refract)

**Notion :** voici **la** différence avec refract1. On calcule `rr1 = refract(rd, n1, refr_index)` : la **loi de Snell** plie le rayon à la surface selon l'indice (0.9). Pour l'instant, au lieu de suivre ce rayon dans le solide, on échantillonne **directement** le décor dans sa direction → effet "boule de verre" : on voit l'arrière-plan **déformé à travers** l'objet. C'est exactement ce que refract1 **ne faisait pas** (il s'arrêtait sur la paroi arrière avec une teinte).

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) { return vec3(0.0); }

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1  = reflect(rd, n1);
    vec3 rr1 = refract(rd, n1, refr_index);          // ← le rayon est PLIÉ et entre (Snell)
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;
    col  = render0(p1, r1 )*(0.5 + 0.5*fre1);         // reflet
    col += render0(p1, rr1)*(1.  - 0.75*fre1);        // réfraction : décor vu À TRAVERS
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** le solide devient **translucide** : on voit le décor déformé à travers, et le reflet par-dessus. Reflet **fort sur les bords**, réfraction **forte au centre** (les deux sont complémentaires via Fresnel : `0.5+0.5*fre1` vs `1-0.75*fre1`).

> **Le point clé :** `refract(I, N, eta)` renvoie la direction transmise (ou `vec3(0)` en cas de **réflexion totale interne**). Ici on n'a qu'**une** réfraction (entrée) et on regarde tout de suite le fond. Les étapes suivantes remplacent ce "regard direct" par un vrai **voyage à l'intérieur**.

---

## Étape 5 — Le monde intérieur (`render2`, premier contact)

**Notion :** au lieu d'échantillonner le décor avec `rr1`, on **suit** ce rayon réfracté dans le solide : `render2(p1, rr1, gd1.x)`. `render2` raymarche le champ **intérieur** `df2` (la coque vue de dedans + une **sphère centrale**) et, pour l'instant, affiche la **normale du premier contact** intérieur.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) {
  g_gd = vec2(1E3);
  float t2 = rayMarch2(ro, rd, min(db+0.05, 0.3));   // on entre, on cherche la 1re paroi interne
  vec3 p2 = ro + rd*t2;
  vec3 n2 = normal2(p2);
  return n2*0.5 + 0.5;                                // normale intérieure en couleur
}

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  vec2 gd1 = g_gd;                                    // capturé AVANT normal3 (qui écrase g_gd)
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1  = reflect(rd, n1);
    vec3 rr1 = refract(rd, n1, refr_index);
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;
    col = render0(p1, r1)*(0.5 + 0.5*fre1);
    vec3 icol = render2(p1, rr1, gd1.x);             // ← on suit le rayon réfracté DEDANS
    if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.))
      col += icol*(1. - 0.75*fre1);
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** à l'intérieur apparaissent les **parois internes** de la coque et la **sphère centrale** (via leurs normales). `render3` ne change quasiment plus jusqu'à l'étape 10 : tout le travail se passe désormais dans `render2`.

> **`min(db+0.05, 0.3)` :** point de départ du march intérieur, légèrement décollé de la surface d'entrée (`db` = distance frôlée par le rayon primaire). Même idée que le `p -= n*0.05` de refract1, mais piloté par la distance.

---

## Étape 6 — Un rebond interne (la lumière qui ressort)

**Notion :** on transforme `render2` en **boucle de rebonds** — d'abord **un seul**. À chaque contact interne : on calcule la **réflexion** `r2` (le rayon qui continue de rebondir) et la **réfraction de sortie** `rr2`. La part réfractée **ressort** et échantillonne le décor (`render0(p2, rr2)`). C'est le premier "rayon sortant" — impossible dans refract1.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) {
  vec3 agg = vec3(0.0);
  for (int bounce = 0; bounce < 1; ++bounce) {        // UN rebond pour l'instant
    g_gd = vec2(1E3);
    float t2 = rayMarch2(ro, rd, min(db+0.05, 0.3));
    vec3 p2 = ro + rd*t2;
    vec3 n2 = normal2(p2);
    vec3 r2  = reflect(rd, n2);
    vec3 rr2 = refract(rd, n2, rrefr_index);          // réfraction de SORTIE (indice inverse)
    agg += render0(p2, rr2);                          // la lumière qui RESSORT regarde le décor
    ro = p2; rd = r2; db = g_gd.x;                    // on prépare le rebond suivant (rayon réfléchi)
  }
  return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  vec2 gd1 = g_gd;
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1  = reflect(rd, n1);
    vec3 rr1 = refract(rd, n1, refr_index);
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;
    col = render0(p1, r1)*(0.5 + 0.5*fre1);
    vec3 icol = render2(p1, rr1, gd1.x);
    if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.))
      col += icol*(1. - 0.75*fre1);
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** l'intérieur montre maintenant un **morceau de décor** transmis par la première face interne. `r2` (réflexion) et `rr2` (réfraction) cohabitent : `r2` continuera à rebondir (étape 7), `rr2` est ce qui s'échappe **ici**.

---

## Étape 7 — N rebonds : les miroirs intérieurs (`MAX_BOUNCES2`)

**Notion :** on déroule la boucle jusqu'à `MAX_BOUNCES2` (6). À chaque tour, le rayon **réfléchi** `r2` repart pour un rebond ; une part **ressort**. On introduit `ragg` (énergie restante) : la **sphère centrale** renvoie surtout (on coupe l'énergie de moitié), les **parois** laissent fuir une part (`ragg *= 0.8`). C'est l'effet "**self reflect**" : la lumière ricoche dans le solide.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) {
  vec3 agg = vec3(0.0);
  float ragg = 1.0;                                   // énergie restante
  for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
    if (ragg < 0.1) break;                            // plus assez d'énergie → on arrête
    g_gd = vec2(1E3);
    float t2 = rayMarch2(ro, rd, min(db+0.05, 0.3));
    vec2 gd2 = g_gd;                                  // capturé AVANT normal2
    vec3 p2 = ro + rd*t2;
    vec3 n2 = normal2(p2);
    vec3 r2  = reflect(rd, n2);
    vec3 rr2 = refract(rd, n2, rrefr_index);
    vec3 ocol = render0(p2, rr2);                     // lumière sortante
    if (gd2.y <= TOLERANCE2) {                        // touché la SPHÈRE interne → surtout réfléchi
      ragg *= 0.5;
    } else {                                          // touché une PAROI → une part s'échappe
      agg  += ocol*ragg;
      ragg *= 0.8;
    }
    ro = p2; rd = r2; db = gd2.x;                     // rebond : on suit le rayon réfléchi
  }
  return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  vec2 gd1 = g_gd;
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1  = reflect(rd, n1);
    vec3 rr1 = refract(rd, n1, refr_index);
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;
    col = render0(p1, r1)*(0.5 + 0.5*fre1);
    vec3 icol = render2(p1, rr1, gd1.x);
    if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.))
      col += icol*(1. - 0.75*fre1);
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** l'intérieur se **complexifie** : on voit des reflets imbriqués, le décor répété par les rebonds successifs sur la coque et la sphère. C'est le cœur de l'effet. `ragg` empêche l'explosion combinatoire en éteignant les rayons trop fatigués.

> **`gd2.y` = distance à la sphère interne** (posée par `df2` dans `g_gd.y`). Quand le rebond se produit dessus, on garde l'énergie en réflexion (miroir) ; sur une paroi, on en laisse fuir.

---

## Étape 8 — Absorption Beer-Lambert le long du trajet

**Notion :** plus le rayon voyage **dans** la matière, plus il est absorbé/teinté. On accumule la longueur de trajet `tagg` (somme des `t2`) et on applique `beer = ragg * exp(0.2 * beerCol * tagg)`. Contrairement à refract1 (1 seule traversée), l'absorption suit ici le **vrai chemin rebondi**.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) {
  vec3 agg = vec3(0.0);
  float ragg = 1.0;
  float tagg = 0.0;                                   // longueur totale parcourue dans la matière
  for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
    if (ragg < 0.1) break;
    g_gd = vec2(1E3);
    float t2 = rayMarch2(ro, rd, min(db+0.05, 0.3));
    vec2 gd2 = g_gd;
    tagg += t2;
    vec3 p2 = ro + rd*t2;
    vec3 n2 = normal2(p2);
    vec3 r2  = reflect(rd, n2);
    vec3 rr2 = refract(rd, n2, rrefr_index);
    vec3 beer = ragg*exp(0.2*beerCol*tagg);          // Beer-Lambert sur le trajet rebondi
    vec3 ocol = 0.2*beer*render0(p2, rr2);           // la sortie est teintée par l'absorption
    if (gd2.y <= TOLERANCE2) {
      ragg *= 0.5;
    } else {
      agg  += ocol;
      ragg *= 0.8;
    }
    ro = p2; rd = r2; db = gd2.x;
  }
  return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  vec2 gd1 = g_gd;
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1  = reflect(rd, n1);
    vec3 rr1 = refract(rd, n1, refr_index);
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;
    col = render0(p1, r1)*(0.5 + 0.5*fre1);
    vec3 icol = render2(p1, rr1, gd1.x);
    if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.))
      col += icol*(1. - 0.75*fre1);
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** l'intérieur prend une **teinte** qui se renforce avec la profondeur des rebonds (les trajets longs sont plus colorés/sombres). `beerCol` est volontairement **négatif** (`-HSV2RGB(...)`) : combiné à `exp`, ça produit une atténuation colorée plutôt qu'un gain.

---

## Étape 9 — Fresnel interne + glow (= `render2` final)

**Notion :** deux finitions sur les rebonds. (1) **Fresnel interne** `fre2` : la sphère centrale renvoie d'autant plus que l'incidence est rasante (`ragg *= 1 - 0.9*fre2`, au lieu du `0.5` fixe). (2) **Glow** : on additionne une lueur (`glowCol1`) inversement proportionnelle à la distance frôlée `gd2.x` — les arêtes internes "rayonnent". C'est le `render2` complet de l'original.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) {
  vec3 agg = vec3(0.0);
  float ragg = 1.;
  float tagg = 0.;
  for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
    if (ragg < 0.1) break;
    g_gd      = vec2(1E3);
    float t2  = rayMarch2(ro, rd, min(db+0.05, 0.3));
    vec2 gd2  = g_gd;
    tagg      += t2;
    vec3 p2   = ro+rd*t2;
    vec3 n2   = normal2(p2);
    vec3 r2   = reflect(rd, n2);
    vec3 rr2  = refract(rd, n2, rrefr_index);
    float fre2= 1.+dot(n2,rd);                        // Fresnel interne
    vec3 beer = ragg*exp(0.2*beerCol*tagg);
    // glow : lueur d'arête (plus on frôle de près, plus ça brille)
    agg += glowCol1*beer*((1.+tagg*tagg*4E-2)*6./max(gd2.x, 5E-4+tagg*tagg*2E-4/ragg));
    vec3 ocol = 0.2*beer*render0(p2, rr2);
    if (gd2.y <= TOLERANCE2) {
      ragg *= 1.-0.9*fre2;                            // sphère : réflexion pondérée Fresnel
    } else {
      agg     += ocol;
      ragg    *= 0.8;
    }
    ro = p2; rd = r2; db = gd2.x;
  }
  return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
  vec3 col = render0(ro, rd);
  int iter;
  g_gd = vec2(1E3);
  float t1 = rayMarch3(ro, rd, 0.1, iter);
  vec2 gd1 = g_gd;
  if (t1 < MAX_RAY_LENGTH3) {
    vec3 p1 = ro + t1*rd;
    vec3 n1 = normal3(p1);
    vec3 r1  = reflect(rd, n1);
    vec3 rr1 = refract(rd, n1, refr_index);
    float fre1 = 1. + dot(rd, n1); fre1 *= fre1;
    col = render0(p1, r1)*(0.5 + 0.5*fre1);
    vec3 icol = render2(p1, rr1, gd1.x);
    if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.))
      col += icol*(1. - 0.75*fre1);
  }
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** les **arêtes intérieures s'illuminent** (néon) et la répartition reflet/transmission sur la sphère devient plus crédible (Fresnel). L'intérieur ressemble enfin à un cristal vivant.

---

## Étape 10 — `render3` final : Fresnel primaire, fade d'itérations, glow externe (= shader original)

**Notion :** on complète le **rayon primaire**. (1) `ifo` atténue les pixels qui ont **ramé** au raymarching (proche du budget d'itérations = silhouette/arêtes incertaines) → anti-artefact. (2) Le reflet et la contribution interne sont pondérés par Fresnel **et** `ifo`. (3) **Glow externe** sur les arêtes du solide (`glowCol0 / gd1.x`). Avec le `render2` de l'étape 9, c'est le **shader complet**.

```glsl
// --- onglet Image ---
vec3 render2(vec3 ro, vec3 rd, float db) {
  vec3 agg = vec3(0.0);
  float ragg = 1.;
  float tagg = 0.;
  for (int bounce = 0; bounce < MAX_BOUNCES2; ++bounce) {
    if (ragg < 0.1) break;
    g_gd      = vec2(1E3);
    float t2  = rayMarch2(ro, rd, min(db+0.05, 0.3));
    vec2 gd2  = g_gd;
    tagg      += t2;
    vec3 p2   = ro+rd*t2;
    vec3 n2   = normal2(p2);
    vec3 r2   = reflect(rd, n2);
    vec3 rr2  = refract(rd, n2, rrefr_index);
    float fre2= 1.+dot(n2,rd);
    vec3 beer = ragg*exp(0.2*beerCol*tagg);
    agg += glowCol1*beer*((1.+tagg*tagg*4E-2)*6./max(gd2.x, 5E-4+tagg*tagg*2E-4/ragg));
    vec3 ocol = 0.2*beer*render0(p2, rr2);
    if (gd2.y <= TOLERANCE2) {
      ragg *= 1.-0.9*fre2;
    } else {
      agg     += ocol;
      ragg    *= 0.8;
    }
    ro = p2; rd = r2; db = gd2.x;
  }
  return agg;
}

vec3 render3(vec3 ro, vec3 rd) {
  int iter;
  vec3 skyCol = render0(ro, rd);
  vec3 col  = skyCol;
  g_gd      = vec2(1E3);
  float t1  = rayMarch3(ro, rd, 0.1, iter);
  vec2 gd1  = g_gd;
  vec3 p1   = ro+t1*rd;
  vec3 n1   = normal3(p1);
  vec3 r1   = reflect(rd, n1);
  vec3 rr1  = refract(rd, n1, refr_index);
  float fre1= 1.+dot(rd, n1);
  fre1 *= fre1;
  // fade des pixels qui ont presque épuisé le budget d'itérations (arêtes incertaines)
  float ifo = mix(0.5, 1., smoothstep(1.0, 0.9, float(iter)/float(MAX_RAY_MARCHES3)));
  if (t1 < MAX_RAY_LENGTH3) {
    col = render0(p1, r1)*(0.5+0.5*fre1)*ifo;          // reflet extérieur
    vec3 icol = render2(p1, rr1, gd1.x);               // contribution intérieure (rebonds)
    if (gd1.x > TOLERANCE3 && gd1.y > TOLERANCE3 && rr1 != vec3(0.)) {
      col += icol*(1.-0.75*fre1)*ifo;                  // ajoutée si réfraction valide
    }
  }
  col += (glowCol0+1.*fre1*(glowCol0))/max(gd1.x, 3E-4); // glow d'arête externe
  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float a = TIME*rotation_speed;
  vec3 r0 = vec3(1.0, sin(vec2(sqrt(0.5), 1.0)*a));
  vec3 r1 = vec3(cos(vec2(sqrt(0.5), 1.0)*0.913*a), 1.0);
  mat3 rot = rot(normalize(r0), normalize(r1));
  g_rot = rot;
  fragColor = vec4(effect(p, pp), 1.0);
}
```

> 👁️ **Lecture :** le rendu final — solide qui tourne, reflets d'environnement, cœur cristallin plein de reflets internes et d'arêtes néon, atténuation Beer colorée. Le tonemap ACES + la vignette + le gamma sont déjà dans `effect()` (BASE). Ce bloc + la BASE = le shader `refract2.md` complet.

> **`rr1 != vec3(0.)` :** garde-fou contre la **réflexion totale interne** — quand `refract()` renvoie `vec3(0)`, il n'y a pas de rayon transmis, donc rien à ajouter en interne.

---

## Récap des étapes (focus réfraction)

| # | Notion clé | Ce qui touche au refract |
|---|---|---|
| 1 | Décor procédural `render0` (sol/plafond/soleil) | — (la cible des rayons) |
| 2 | Rayon primaire + normales (`df3`) | — (la surface du solide) |
| 3 | Reflet d'environnement + Fresnel `fre1` | reflet seul |
| 4 | **Réfraction d'entrée `refract()`** (vue "boule de verre") | ✅ le rayon est plié et entre |
| 5 | Monde intérieur `render2`/`df2` (coque + sphère) | ✅ on suit le rayon réfracté dedans |
| 6 | **1 rebond** → 1er rayon sortant | ✅ `refract()` de sortie → décor |
| 7 | **N rebonds** (`MAX_BOUNCES2`, `ragg`) | ✅ miroirs intérieurs |
| 8 | Absorption Beer-Lambert sur le trajet `tagg` | ✅ absorption du chemin rebondi |
| 9 | Fresnel interne `fre2` + glow → `render2` final | ✅ split reflet/transmission interne |
| 10 | `render3` final : `ifo`, Fresnel, glow externe | ✅ assemblage primaire + intérieur |

## Pour aller plus loin

- **Dispersion (chromatique) :** appeler `refract()` avec un indice différent par canal R/G/B → 3 trajets → arc-en-ciel sur les arêtes.
- **Plus de rebonds :** monter `MAX_BOUNCES2` (coûteux) ; observer le gain décroissant à cause de `ragg`.
- **Indice réaliste :** passer `refr_index` à 1.5 (verre) ou 2.42 (diamant) pour un pliage plus marqué (l'original utilise 0.9, un choix artistique).
- **Comparer à refract1 :** refract1 = 1 traversée, pas de sortie, teinte = épaisseur ; refract2 = vrai transport (entrée pliée + rebonds + sorties). Les deux approches, deux budgets, deux usages.
