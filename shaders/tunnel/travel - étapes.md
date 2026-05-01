
# Travel raymarché — décomposition en 20 étapes

Chaque étape contient un shader **complet** copiable tel quel dans Shadertoy. On part d'un écran vide et on arrive au shader final, en ajoutant **une notion par étape**.

> ⚠️ À partir de l'étape 13, il faut binder une texture de bruit (par ex. `Noise Medium` ou `RGBA Noise Medium`) sur `iChannel0` dans Shadertoy.

---

## Étape 1 — UV normalisées centrées

**Notion :** convertir la position en pixels (`fragCoord`) en coordonnées centrées et normalisées. Trois transformations enchaînées :

1. **`fragCoord`** est un `vec2` qui va de `(0, 0)` (coin bas-gauche) à `(iResolution.x, iResolution.y)` (coin haut-droit). C'est en pixels.
2. **`- 0.5 * iResolution.xy`** : on soustrait le centre de l'écran ⟹ l'origine `(0, 0)` passe au milieu. Maintenant les coords vont de `-W/2..+W/2` en X et `-H/2..+H/2` en Y.
3. **`/ iResolution.xx`** : on divise par la **largeur** (et **non** la hauteur). Pourquoi `.xx` plutôt que `.xy` ? Parce que `.xy` écraserait l'image en ellipse sur écran non-carré. En divisant les deux composantes par la même grandeur (la largeur), on préserve l'**aspect ratio** : un cercle reste un cercle.

Résultat : `uv.x ∈ [-0.5, +0.5]` (toujours), `uv.y ∈ [-h/2w, +h/2w]` (dépend du ratio).

```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Étape 1 : recentrer (origine au milieu de l'écran).
    // Étape 2 : normaliser par la largeur (préserve l'aspect ratio).
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    // Visualisation debug : R = uv.x, G = uv.y, B = 0.
    //   - centre de l'écran = noir (0, 0, 0)
    //   - droite = rouge (uv.x > 0)
    //   - haut   = vert  (uv.y > 0)
    //   - coin haut-droit = jaune (rouge + vert)
    vec3 col = vec3(uv, 0.);

    fragColor = vec4(col, 1.0);
}
```

> **À tester :** mets `vec3(uv * 2., 0.)` pour multiplier l'intensité, ou `vec3(length(uv))` pour voir un dégradé radial. Comprendre `uv` est la base de tout shader 2D.

---

## Étape 2 — Raymarching d'une sphère

**Notion :** le **sphere tracing** est une technique de rendu où, pour chaque pixel, on lance un rayon depuis la caméra dans la scène et on avance le long de ce rayon jusqu'à toucher une surface.

**Trois ingrédients clés :**

1. **SDF (Signed Distance Function)** : une fonction `map(p)` qui retourne la **distance signée** au point `p` jusqu'à la surface la plus proche. **Négative** à l'intérieur de l'objet, **positive** à l'extérieur, **zéro** sur la surface. Pour une sphère de centre `C` et rayon `R` : `SDF(p) = length(p - C) - R`.

2. **Le rayon** : défini par une **origine** `ro` (ray origin) et une **direction** `rd` (ray direction, unitaire). Pour chaque pixel, on construit `rd` à partir des `uv` ⟹ chaque pixel = un rayon différent.

3. **La boucle de marche** : on part de `ro`, on évalue `map(p)`, on **avance d'exactement la distance signée** ⟹ garantie qu'on ne traverse jamais la surface (puisque la distance signée = la plus petite distance possible). Quand `map(p) < ε`, on a touché.

**Pourquoi `rd = normalize(vec3(uv, 1.))` ?** On construit un rayon qui part de la caméra et passe par le pixel courant projeté sur un plan à `z = 1` devant elle. `normalize` rend le vecteur unitaire ⟹ chaque "pas" correspond bien à une unité de distance dans le monde.

```glsl
// SDF d'une sphère de rayon 0.5 placée 5 unités devant la caméra.
//   length(p - C) = distance euclidienne au centre.
//   - R          = on retire le rayon : la SDF vaut 0 sur la surface, négative à l'intérieur.
float map(vec3 p)
{
    return length(p - vec3(0., 0., 5.)) - 0.5;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    // === CONSTRUCTION DU RAYON ===
    vec3 ro = vec3(0., 0., 0.);          // caméra à l'origine du monde
    vec3 rd = normalize(vec3(uv, 1.));   // direction : (uv.x, uv.y, 1) normalisé.
                                         //   z=1 → on regarde vers les Z positifs.
                                         //   uv.x, uv.y dispersent le rayon par pixel.

    // === BOUCLE DE SPHERE TRACING ===
    vec3 p = ro;          // position courante du marcheur, on part de la caméra
    vec3 col = vec3(0.);  // noir par défaut (rien touché = ciel noir)

    for (float i = 0.; i < 128.; ++i)   // 128 itérations max : sécurité anti-boucle infinie
    {
        float d = map(p);          // distance signée au plus proche objet depuis p
        if (d < 0.01)              // ε : seuil de "touché". Trop grand = artefacts ; trop petit = lent.
        {
            col = vec3(1.);
            break;                 // on a touché, on sort
        }
        p += rd * d;               // BOND ADAPTATIF : on avance d'autant que la SDF nous le permet.
                                   //   Loin de la surface : grand pas (rapide).
                                   //   Près de la surface : petits pas (précis).
                                   //   ⟹ converge en O(log) pour des SDF simples.
    }

    fragColor = vec4(col, 1.0);
}
```

> **Fait étonnant :** sans `break`, si on n'a rien touché après 128 itérations, on est probablement très loin → on peut considérer "ciel". `i` peut servir d'AO grossier (plus on a itéré, plus on est dans un coin).

---

## Étape 3 — Composition de SDF : ajout d'un sol

**Notion :** la force des SDF, c'est qu'on peut les **composer** avec des opérations booléennes (CSG = Constructive Solid Geometry).

**SDF de plan horizontal :** un plan à `y = h` a pour SDF la fonction `p.y - h`. À `p.y = h` la SDF vaut 0 (on est sur le plan), au-dessus elle est positive, en-dessous négative. Ici `p.y + 1.` = `p.y - (-1.)` ⟹ plan à `y = -1`.

**Opérations CSG sur SDF (à connaître absolument) :**
- **Union (A ∪ B)** : `min(a, b)` — distance au plus proche des deux.
- **Intersection (A ∩ B)** : `max(a, b)` — on n'est dans la scène que si on est dans les deux.
- **Différence (A \ B)** : `max(a, -b)` — A privé de B (B "creuse" A).

Ici on veut une scène = sphère **OU** sol ⟹ `min`.

```glsl
float map(vec3 p)
{
    // SDF de la sphère (cf. étape 2).
    float sphere = length(p - vec3(0., 0., 5.)) - 0.5;

    // SDF d'un plan horizontal.
    //   Forme générale : p.y - h pour un plan à y = h.
    //   Ici p.y + 1. ⟹ plan à y = -1 (un peu sous la sphère).
    //   Note : la SDF d'un plan est strictement euclidienne (gradient unitaire),
    //   contrairement à des SDF déformées qu'on verra plus tard.
    float ground = p.y + 1.;

    // UNION CSG : on garde la distance au plus proche.
    //   min(a, b)            = union (A ∪ B)
    //   max(a, b)            = intersection (A ∩ B)
    //   max(a, -b)           = différence (A \ B)
    //   smin/smax            = versions "lisses" (blob, raccord arrondi)
    return min(sphere, ground);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., 0.);
    vec3 rd = normalize(vec3(uv, 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        float d = map(p);
        if (d < 0.01) { col = vec3(1.); break; }
        p += rd * d;
    }

    fragColor = vec4(col, 1.0);
}
```

> **Limite immédiate :** comme on retourne juste un float, on ne peut **pas savoir** quel objet a été touché → tout est uniformément blanc. C'est le problème que résout l'étape 4 (système de matériaux).

---

## Étape 4 — Système de matériaux (map retourne vec2)

**Notion :** problème de l'étape 3 : on touche **quelque chose** mais on ne sait pas **quoi**. Solution : on transporte un **identifiant de matériau** (matID) à côté de la distance.

**Pattern classique en raymarching :**
- `map(p)` retourne maintenant un `vec2`. `.x` = distance signée, `.y` = ID du matériau.
- Une fonction `_min` custom compare les distances **mais préserve l'ID** du plus proche (un `min(vec2, vec2)` standard ferait du min composante par composante, ce qu'on ne veut **pas**).
- Dans la boucle, après collision, on lit `res.y` et on attribue la couleur correspondante.

**Pattern de l'accumulateur :** on initialise `acc = vec2(GROS, 0.)` puis on fait `acc = _min(acc, vec2(d_objet, id_objet))` pour chaque objet. À la fin, `acc` contient la SDF de l'objet le plus proche **ET** son ID. Évolutif : ajouter un objet = ajouter une ligne.

```glsl
// _min : équivalent de min() pour vec2(distance, matID).
//   - Compare uniquement les distances (.x).
//   - Garde l'ID (.y) de l'objet le plus proche.
//   ATTENTION : un min() natif sur vec2 ferait min(a.x, b.x), min(a.y, b.y) → faux ici.
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    // Pattern accumulateur : on commence avec une distance énorme et un ID dummy.
    //   La première vraie SDF passera systématiquement par le _min ⟹ acc sera écrasé.
    vec2 acc = vec2(100000., 0.);

    // Chaque objet : sa SDF + son matID.
    acc = _min(acc, vec2(length(p - vec3(0., 0., 5.)) - 0.5, 0.));  // sphère, matID 0
    acc = _min(acc, vec2(p.y + 1., 1.));                            // sol,    matID 1

    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., 0.);
    vec3 rd = normalize(vec3(uv, 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);          // res.x = distance, res.y = matID

        if (res.x < 0.01)
        {
            // Branchement par ID. Pour des shaders complexes, on extrait souvent
            // ce switch dans une fonction getMat(p, n, res) → cf. tunnel1 étape 6.
            if (res.y == 0.) col = vec3(1., 0., 0.2);  // sphère rouge-rosé
            if (res.y == 1.) col = vec3(0.5);          // sol gris neutre
            break;
        }
        p += rd * res.x;            // on continue avec res.x (distance), on ignore l'ID pour la marche
    }

    fragColor = vec4(col, 1.0);
}
```

> **Pour aller plus loin :** on peut utiliser `.y` pour bien plus que des couleurs : refléchissement, rugosité, IOR, glow… À ce stade, on a la fondation pour différencier visuellement chaque objet.

---

## Étape 5 — Travelling avant (animation par déformation de l'espace)

**Notion :** principe fondamental du shader live : **bouger le monde plutôt que la caméra**.

**Équivalence physique :** déplacer la caméra de `+v*t` en Z et déplacer le monde de `-v*t` en Z donnent **exactement** la même image. Mais coder le second est plus simple : tout se passe dans `map()`, `ro` reste fixe, on n'a pas à recalculer `rd` ni à transformer la base.

**`p.z += iTime * 3.` dans `map()`** signifie : "depuis le point de vue du shader, la scène est plus loin de `iTime * 3` unités sur Z". Pour que la SDF d'un objet à `z=5` soit "touchée", il faut maintenant que le rayon arrive à `z = 5 - iTime * 3`. ⟹ visuellement la sphère se rapproche, donc semble venir vers nous à 3 unités/seconde.

**Convention de signe :** `+=` = la scène recule = la caméra avance. `-=` = la scène avance = la caméra recule.

**Important :** `iTime` est le temps écoulé en secondes depuis le démarrage du shader (uniform fourni par Shadertoy). Toute fonction qui en dépend devient animée.

```glsl
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    // === TRAVELLING PAR DÉFORMATION DE L'ESPACE ===
    // Pour le shader, le monde est translaté de +iTime*3 sur Z.
    // Visuellement : tout défile vers la caméra à 3 unités/seconde.
    //   p.z += k → on avance (objets viennent à nous)
    //   p.z -= k → on recule
    //   3. = vitesse en unités/seconde. Augmenter pour plus rapide.
    p.z += iTime * 3.;

    vec2 acc = vec2(100000., 0.);
    acc = _min(acc, vec2(length(p - vec3(0., 0., 5.)) - 0.5, 0.));
    acc = _min(acc, vec2(p.y + 1., 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 0., 0.);
    vec3 rd = normalize(vec3(uv, 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.) col = vec3(0.5);
            break;
        }
        p += rd * res.x;
    }

    fragColor = vec4(col, 1.0);
}
```

> **Note :** la sphère défile mais on la voit qu'une fois (puis elle disparaît derrière). À l'étape 8 on la **multipliera à l'infini** par domain repetition pour avoir un défilement continu d'objets.

---

## Étape 6 — Caméra surélevée et FOV élargi

**Notion :** on règle la **position** de la caméra et son **angle de vision** (FOV) pour passer d'une vue droite à une vue plongeante de type "couloir qui défile".

**Position `ro = (0, 2, -10)` :**
- `x = 0` : centré horizontalement.
- `y = 2` : 2 unités au-dessus du sol (qu'on a remonté à `y = 0`).
- `z = -10` : 10 unités **en arrière** de l'origine. Plus on recule, plus on voit loin avant que le travelling commence à amener du contenu.

**FOV via `vec3(uv * 2., 1.)` :**
- Rappel : `rd = normalize(vec3(uv, 1.))` projette les pixels sur un plan à `z=1` ⟹ FOV ≈ 53° (atan(0.5) × 2).
- En multipliant `uv` par 2, on **étire** le plan virtuel : un pixel "tout à droite" projette maintenant à `x = 1` au lieu de `x = 0.5` ⟹ FOV ≈ 90° (atan(1) × 2). Champ de vision élargi → on capte plus de scène.
- **Trade-off** : un FOV trop large ⟹ déformations en bord d'image (fish-eye). 90° = limite acceptable pour un shader artistique.

**Sphère relocalisée :** plus `vec3(0,0,5)` mais `vec3(0,0,0)`. Avec le travelling `p.z += iTime*3`, la sphère est testée à des positions `z` croissantes ⟹ elle "remonte" vers la caméra puis disparaît derrière (z négatif).

```glsl
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.z += iTime * 3.;

    vec2 acc = vec2(100000., 0.);

    // Sphère placée à l'origine du monde (au lieu de z=5).
    //   length(p) - 0.5 = SDF d'une sphère de rayon 0.5 centrée en (0,0,0).
    //   Avec le travelling, elle viendra à la caméra puis passera derrière.
    acc = _min(acc, vec2(length(p) - 0.5, 0.));

    // Sol à y=0 (au lieu de y=-1) : plus simple.
    //   La caméra est à y=2, donc 2 unités au-dessus.
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    // === POSITIONNEMENT DE LA CAMÉRA ===
    vec3 ro = vec3(0., 2., -10.);
    //          x=0  : centré
    //          y=2  : surélevé (vue plongeante)
    //          z=-10: reculé (du recul pour voir le défilement arriver)

    // === FOV via le plan de projection ===
    vec3 rd = normalize(vec3(uv * 2., 1.));
    //                       ^^^^^^^
    //   uv × 1 → FOV ~53°  (assez resserré, vue "téléobjectif")
    //   uv × 2 → FOV ~90°  (large, vue "grand angle") ← choix ici
    //   uv × 4 → FOV ~127° (fish-eye, déformations marquées)

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.) col = vec3(0.5);
            break;
        }
        p += rd * res.x;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 7 — Pas de raymarching réduit (anti-overshoot)

**Notion :** une étape "préventive" pour les déformations à venir (mod, sin, texture noise…). Comprendre **pourquoi** un facteur multiplicatif `< 1` est nécessaire.

**Le problème de la SDF non-euclidienne :**
- Une SDF "honnête" (sphère, plan, box) retourne la **vraie** distance euclidienne à la surface. Avancer de cette distance est sans danger : on ne peut pas dépasser la surface.
- Mais dès qu'on **déforme l'espace** dans `map()` (`mod`, `abs`, `sin`, échantillonnage de texture), la fonction retournée n'est plus une vraie SDF — elle peut **surestimer** la distance réelle.
- Conséquence : si on avance de cette distance "menteuse", on peut **traverser la surface** sans s'en rendre compte ⟹ artefacts visuels (trous, surfaces qui clignotent).

**La parade : multiplier par un facteur < 1.**
- `* 0.4` ⟹ on n'avance que de 40 % de la distance estimée. On reste prudent.
- Coût : il faut plus d'itérations pour atteindre une surface lointaine ⟹ plus lent.
- Choix typique : 0.5 à 0.7 pour des SDF modérément déformées, 0.3 à 0.4 pour très déformées.

**Constante de Lipschitz :** mathématiquement, le facteur idéal est `1 / max(||∇f||)`. Pour une SDF correcte, ce gradient vaut 1 partout. Pour des SDF déformées par un mapping de constante de Lipschitz `L > 1`, il faut multiplier la marche par `1/L`.

```glsl
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.z += iTime * 3.;

    vec2 acc = vec2(100000., 0.);
    acc = _min(acc, vec2(length(p) - 0.5, 0.));
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.) col = vec3(0.5);
            break;
        }

        // === PAS RÉDUIT (× 0.4) ===
        // Ne nécessaire ICI à l'œil nu (pas encore de déformation),
        // mais on l'introduit en prévision de :
        //   - mod() pour la répétition (étape 8) — sous-estime parfois
        //   - sin/cos sur p (étapes 10, 11) — distord la métrique
        //   - texture comme noise (étape 13) — distance invalide
        // Sans ce facteur, ces étapes produiraient des trous noirs et des artefacts.
        // 0.4 = compromis raisonnable. Plus petit (0.2) = plus sûr mais 2× plus lent.
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

> **À tester :** quand on aura les déformations, remettre `* 1.0` à la place de `* 0.4` et observer les artefacts apparaître. C'est le meilleur moyen de comprendre pourquoi cette ligne existe.

---

## Étape 8 — Domain repetition : multiplier la sphère à l'infini

**Notion :** la technique la plus emblématique du raymarching procédural. Avec quelques lignes, on transforme **un seul** objet en **une infinité de copies** régulièrement espacées, sans surcoût (la SDF n'est évaluée qu'**une fois** par appel de `map`).

**Principe :** au lieu d'évaluer `SDF(p)`, on évalue `SDF(repli(p))` où `repli` est une fonction qui replie l'espace en cellules. À l'intérieur d'une cellule, `repli(p)` retourne la position **locale** centrée — c'est comme si on était toujours dans la cellule (0, 0).

**Les deux opérations clés :**

1. **`floor((p + reps/2) / reps)`** : donne l'**ID entier** de la cellule courante. Vecteur `vec2` du genre `(3, -2)`. Le `+ reps/2` décale pour que la cellule (0,0) soit centrée sur l'origine du monde (pas sur son coin).

2. **`mod(p + reps/2, reps) - reps/2`** : ramène la coordonnée locale dans `[-reps/2, +reps/2]`. C'est le **recentrage** : peu importe la cellule où on est, la sphère est testée comme si elle était au centre.

**Important :** on garde une copie locale `ps = p` parce qu'on ne veut **PAS** que le sol soit aussi répété. Le sol utilise `p` original (continu), seules les sphères utilisent `ps` (replié).

**Limite :** la SDF d'une sphère unique dépasse rarement `reps/2`. Si une sphère "déborde" de sa cellule (rayon > reps/2), il faut tester aussi les cellules voisines (`mirror repetition`).

```glsl
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.z += iTime * 3.;

    vec2 acc = vec2(100000., 0.);

    // === DOMAIN REPETITION ===
    vec3 ps = p;             // copie : on ne veut PAS modifier p (le sol l'utilise non-replié)
    vec2 reps = vec2(3.);    // taille d'une cellule, en X et Z. Plus grand = sphères plus espacées.

    // ID de la cellule courante : (i, j) entier.
    //   Le "+ reps*0.5" décale pour centrer la cellule (0,0) sur l'origine
    //   plutôt que de l'aligner sur son coin bas-gauche.
    //   ⟹ chaque cellule a un ID stable et symétrique.
    vec2 id = floor((ps.xz + reps * 0.5) / reps);

    // Recentrage du point dans la cellule courante.
    //   mod(x + reps/2, reps) ∈ [0, reps]
    //   - reps/2          → ∈ [-reps/2, +reps/2]
    //   ⟹ peu importe où on est dans le monde, ps.xz "voit" toujours
    //     la sphère placée en (0, ?, 0) au centre de sa cellule.
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;

    // SDF de LA sphère, évaluée localement.
    //   Conséquence visuelle : une grille infinie de sphères, espacées de 3 unités.
    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    // Le sol utilise p (non replié) → reste continu, pas de répétition.
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.) col = vec3(0.5);
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

> **À tester :** modifier `reps = vec2(2.)` (sphères plus serrées), `vec2(5., 1.)` (rangées rapprochées en Z, espacées en X), ou ajouter `p.x` dans `reps` pour étirer dynamiquement.

---

## Étape 9 — Décalage pseudo-aléatoire par cellule (hash via `sin`)

**Notion :** une grille parfaitement régulière est l'œil identifie immédiatement → trop "synthétique". On veut **briser** cette régularité en décalant chaque sphère d'une valeur **différente** mais **stable dans le temps**.

**Le problème : générer un nombre "aléatoire" par cellule.**
- On dispose de l'ID entier de la cellule (étape 8) ⟹ identifiant unique.
- On veut une fonction `hash(id) → vec2` qui retourne un décalage déterministe.
- Vraie fonction de hash GLSL = coûteuse. **Astuce paresseuse :** utiliser `sin` qui est rapide et déjà oscillant.

**Le hash "pauvre" `sin(id + id.x + id.y)` :**
- `sin` retourne `[-1, +1]`, donc le décalage reste raisonnable.
- `id + id.x + id.y` mélange les composantes : deux cellules qui n'ont qu'une coordonnée commune (par ex. `(3, 0)` et `(3, 1)`) auront des `sin` différents grâce à la somme `id.x + id.y` qui change.
- **Limite** : ce n'est PAS un vrai hash uniforme — il y a des corrélations visibles. Pour des projets sérieux, utiliser `fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453)`.

**Pourquoi décaler `ps.xz` AVANT de calculer la SDF ?** Parce que la SDF mesure la distance à `(0, 0)` localement. Si on translate le point d'observation, la sphère semble bouger dans l'autre sens ⟹ effet de placement aléatoire dans la cellule.

```glsl
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.z += iTime * 3.;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;

    // === HASH PAUVRE PAR CELLULE ===
    // sin(id + id.x + id.y) ∈ [-1, 1]² → décalage stable par cellule, varié visuellement.
    //   - "id" est entier → sin l'évalue à des phases déterministes par cellule.
    //   - "+ id.x + id.y" évite que deux cellules en ligne aient le même décalage.
    //   - Pas un vrai hash uniforme, mais suffisant pour casser la régularité.
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.) col = vec3(0.5);
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 10 — Grille procédurale via variable globale `pmap`

**Notion :** on veut peindre une grille sur le sol qui **défile** avec le travelling. Deux problèmes à résoudre :

**1) Récupérer les coordonnées animées hors de `map()`.** Dans `map()` on travaille sur une copie locale de `p` qu'on a modifiée (`p.z += iTime * 3.`). Quand on sort de la boucle de raymarching dans `mainImage`, le `p` qu'on a là est dans le **monde fixe** : il ne contient pas le décalage `iTime`. Si on utilisait directement ce `p` pour dessiner la grille, les lignes resteraient **collées sous la caméra** sans jamais bouger.

→ Astuce : on déclare une variable **globale** `pmap` qu'on remplit dans `map()` après les déformations. À chaque appel de `map()`, `pmap` est écrasée. Au dernier appel (celui qui a confirmé la collision), `pmap` contient les coords **animées** du point d'impact. On la lit dans `mainImage` pour dessiner.

**2) Construire des lignes avec `sin`.** `sin(x)` oscille entre -1 et 1. En faisant `sin(x) + 0.99`, on obtient une fonction qui vaut **presque toujours positive** (entre -0.01 et 1.99) **sauf** dans une fenêtre étroite autour des minima de `sin` — exactement aux endroits où on veut tracer un trait. On a deux directions à canaliser : X et Z. Une grille = "ligne en X **OU** ligne en Z" → on prend `min(grid.x, grid.y)`. Le `min` est petit (proche de 0) si **l'une des deux** oscillations est dans son creux → on est sur une ligne ou un croisement.

**3) Inverser et durcir le contraste.** `g` est ≈ 0 sur les lignes, ≥ 0.99 ailleurs. `clamp(g * 5., 0., 1.)` étire l'intervalle utile : tout ce qui dépasse 0.2 devient 1 (noir après inversion). `1. - …` inverse pour que les **lignes ressortent en blanc** sur fond noir.

```glsl
vec3 pmap;  // globale : passerelle entre map() et mainImage()

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.z += iTime * 3.;
    pmap = p;  // on sauvegarde p APRÈS les déformations.
               // À la dernière itération du raymarching (= point d'impact),
               // mainImage pourra relire ces coords animées.

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                // Étape A : deux signaux sinusoïdaux indépendants en X et Z.
                //   - "* 10."     contrôle la densité (10 oscillations par unité de monde).
                //   - "+ 0.99"    décale la sinusoïde vers le positif :
                //                   sin ∈ [-1, 1]  →  grid ∈ [-0.01, 1.99].
                //                 Conséquence : grid n'est ≈ 0 (voire négatif) que sur
                //                 une bande très fine autour des minima → c'est ÇA, la ligne.
                vec2 grid = sin(pmap.xz * 10.) + 0.99;

                // Étape B : on combine les deux directions.
                //   min(a, b) = "le plus petit des deux".
                //   Si la ligne X EST traversée (grid.x ≈ 0) OU la ligne Z (grid.y ≈ 0),
                //   alors g ≈ 0. Ailleurs, g ≈ 1. → on obtient un quadrillage.
                float g = min(grid.x, grid.y);

                // Étape C : on transforme g en masque binaire "lisse".
                //   - "* 5."           amplifie : tout ce qui n'est pas une ligne
                //                      saute vite au-delà de 1 et sera clampé.
                //   - "clamp(.., 0,1)" force dans [0,1].
                //   - "1. - ..."       inverse : lignes = 1 (blanc), reste = 0 (noir).
                col = vec3(1.) * (1. - clamp(g * 5., 0., 1.));
            }
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

> **À tester :** mets `col = vec3(grid.x);` puis `col = vec3(g);` puis enlève le `1. -` — tu visualises chacune des trois étapes A/B/C séparément. Très utile pour comprendre les compositions de signaux en GLSL.

---

## Étape 11 — Déformation sinusoïdale du sol (vagues en Z)

**Notion :** **plier l'espace** avant d'évaluer une SDF est l'une des techniques les plus puissantes en raymarching procédural. Aucune nouvelle géométrie, aucun nouvel objet : on triche sur les coordonnées **avant** que la SDF du plan les voie.

**Le mécanisme :**
- La SDF du plan est `p.y` ⟹ "je suis à `p.y` unités du plan horizontal `y=0`".
- Si on remplace `p.y` par `p.y - f(p.z)` **avant** de retourner la SDF, alors la surface "plate" devient le lieu où `p.y = f(p.z)` ⟹ courbe.
- `f(p.z) = cos(p.z * 0.2) * 0.5` : le plan ondule en Z avec une amplitude de ±0.5.

**Décomposition de `p.y -= cos(p.z * 0.2) * 0.5` :**
- `cos(p.z * 0.2)` : le `* 0.2` est la fréquence. Période = 2π / 0.2 ≈ 31 unités de monde par cycle ⟹ vagues lentes, longues.
- `* 0.5` : l'amplitude. Le sol monte/descend de ±0.5 unité.
- `p.y -=` : on **soustrait** la hauteur de la vague à `p.y`. Si la vague est haute (cos = +1, hauteur 0.5), la SDF retourne 0 quand `p.y = 0.5` au lieu de `p.y = 0` ⟹ la surface s'élève.

**Coût :** zéro. C'est ce qui rend cette technique magique.

**Lisibilité :** sans la grille de l'étape 10, l'ondulation est invisible (sol monochrome = pas de repère). C'est un cas d'école de l'importance d'avoir des **textures de surface** pour percevoir la **forme**.

```glsl
vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.6) * 0.5;  // ondulation verticale du sol
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.) * (1. - clamp(g * 5., 0., 1.));
            }
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 12 — Vignettage radial sur la grille

**Notion :** on atténue la grille avec la distance horizontale au point d'impact `length(p.xz)`. Ça produit un dégradé doux qui sombre vers l'horizon → sensation de profondeur.

```glsl
#define sat(a) clamp(a, 0., 1.)

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));
    acc = _min(acc, vec2(p.y, 1.));
    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));  // vignettage
            }
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 13 — Texture de bruit pour relief du sol

**Notion :** sampler une texture de bruit comme **fonction continue 2D** plutôt que pour ses pixels. On retire la valeur du bruit à `p.y` → le sol prend du relief. Deux échelles superposées (`* 0.001` et `* 0.002`) pour avoir du low-freq + high-freq.

> Bind une texture de bruit (Noise Medium, RGBA Noise Medium…) sur **iChannel0**.

```glsl
#define sat(a) clamp(a, 0., 1.)

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;
    ground -= texture(iChannel0, p.xz * 0.001).x;       // bruit basse fréq
    ground -= texture(iChannel0, p.xz * 0.002).x * 2.;  // bruit haute fréq
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 14 — Chemin "way" : zone plate de largeur ondulante

**Notion :** on veut un **couloir plat** au centre où la sphère défile, et du relief uniquement sur les bords. L'idée : construire un masque scalaire `way` qui vaut 0 sur le couloir et 1 loin du couloir, puis **multiplier le bruit par ce masque**. Là où `way = 0`, le bruit est annulé → sol plat. Là où `way = 1`, le bruit s'applique pleinement → bumps.

⚠️ **Attention au mot « ondulation » :** ce n'est pas la même qu'à l'étape 11. Là, c'était la hauteur du sol qui ondulait (`p.y -= cos(p.z * 0.2) * 0.5`). Ici, c'est la **largeur du couloir plat** qui oscille en Z. Le couloir reste centré sur l'axe x=0, mais il s'élargit et se rétrécit alternativement quand on avance.

**Décomposition de la formule :**
```
way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2
```
- `abs(p.x) - 1.0` : la base. Négatif pour |x| < 1 (couloir de largeur 2), positif au-delà.
- `- sin(p.z)` : on **soustrait** une oscillation lente. Quand `sin(p.z) = +1`, on retire 1 → la zone négative s'agrandit, le couloir devient plus large (jusqu'à |x| < 2). Quand `sin(p.z) = -1`, on ajoute 1 → la zone négative se referme, le couloir disparaît presque.
- `- sin(p.z * 3.3) * 0.2` : oscillation plus rapide et plus faible → micro-variations sur la largeur. La fréquence non-entière (3.3) évite un cycle trop régulier.

**Étapes finales :**
- `sat(way * 0.5)` : on coupe les valeurs négatives à 0 (= couloir totalement plat) et on plafonne à 1 (= bumps à fond). Le `* 0.5` adoucit la transition entre les deux.
- `pow(.., 1.)` : ne fait rien ici (puissance 1 = identité). Sert à donner un point d'accroche pour ajuster la courbe de transition (mets `2.` ou `4.` pour durcir le bord du couloir).

> **Pour visualiser le masque seul, remplace dans `mainImage` le bloc `if (res.y == 1.)` par :
> `col = vec3(way_dbg);` après avoir stocké `way` dans une globale `float way_dbg;`. Tu verras alors directement les zones noires (couloir) et blanches (bords bumpés) qui pulsent en Z.**
>
> L'effet est aussi beaucoup plus lisible **après l'étape 15** : la caméra s'incline vers le sol et le couloir devient évident.

```glsl
#define sat(a) clamp(a, 0., 1.)

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;

    // Construction du masque "way" :
    //   abs(p.x) - 1.0     : couloir de base, largeur 2 centré sur x=0.
    //                        Négatif au centre (=plat), positif sur les bords (=bumps).
    //   - sin(p.z)         : la largeur du couloir PULSE en Z.
    //                        sin=+1 → +1 de marge → couloir élargi à |x|<2.
    //                        sin=-1 → -1 de marge → couloir resserré, presque fermé.
    //   - sin(p.z*3.3)*0.2 : micro-variations rapides en plus, fréquence non-entière
    //                        pour casser la régularité.
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;

    // sat() : on remappe en [0,1].
    //   way < 0 (centre du couloir)   → 0  → bruit annulé → sol plat.
    //   way > 2 (bien au-delà)        → 1  → bruit pleinement appliqué.
    //   * 0.5 : étire la transition pour qu'elle ne soit pas trop brutale.
    // pow(., 1.) = identité ; à modifier (2., 4.) si on veut un bord plus net.
    way = pow(sat(way * 0.5), 1.);

    // Multiplication du bruit par le masque : 0 sur le couloir, intact sur les bords.
    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 15 — Caméra animée (3 rotations)

**Notion :** on perturbe la **direction du rayon** `rd` plutôt que la position de la caméra → plus simple. Trois rotations 2D :
1. `rd.yz *= rot(0.1)` — inclinaison constante vers le sol
2. `rd.xy *= rot(sin(iTime * 0.5) * 0.2)` — roll oscillant (rotation autour de Z)
3. `rd.xz *= rot(sin(iTime * 0.35) * 0.2)` — yaw oscillant (rotation autour de Y)

Les fréquences différentes (0.5 vs 0.35) évitent un cycle trop régulier.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.);
    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    rd.yz *= rot(0.1);                          // inclinaison vers le sol
    rd.xy *= rot(sin(iTime * 0.5) * 0.2);       // oscillation autour Z
    rd.xz *= rot(sin(iTime * 0.35) * 0.2);      // oscillation autour Y

    vec3 p = ro;
    vec3 col = vec3(0.);
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        p += rd * res.x * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 16 — Bloom par accumulation pendant la marche

**Notion :** à chaque pas du raymarching, si la cellule courante est une sphère (matID == 0), on accumule un peu de couleur rouge dans `accCol`. Plus la trajectoire du rayon **frôle** des sphères, plus elle s'éclaire. Ajout final en post → faux glow gratuit, pas de seconde passe.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.);
    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));
    rd.yz *= rot(0.1);
    rd.xy *= rot(sin(iTime * 0.5) * 0.2);
    rd.xz *= rot(sin(iTime * 0.35) * 0.2);

    vec3 p = ro;
    vec3 col = vec3(0.);
    vec3 accCol = vec3(0.);   // accumulateur de bloom

    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        if (res.y == 0.) accCol += vec3(1., 0., 0.2) * 0.02;  // bloom

        p += rd * res.x * 0.4;
    }

    col += accCol;

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 17 — Ciel : gradient procédural

**Notion :** pour les rayons qui n'ont rien touché (et plus tard pour le brouillard), on a besoin d'une couleur de ciel. On la calcule à partir de `rd.y` (angle vertical). Mix entre vert (`cola`) en bas et bleu (`colb`) en haut. Quand le rayon manque la scène, on affiche directement le ciel.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.);
    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

vec3 gradient(vec3 rd)
{
    vec3 cola = vec3(0.102, 1.000, 0.655) * 1.5;  // vert (bas)
    vec3 colb = vec3(0.102, 0.776, 1.000);        // bleu (haut)
    return mix(cola, colb, sat(rd.y * 15.));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));
    rd.yz *= rot(0.1);
    rd.xy *= rot(sin(iTime * 0.5) * 0.2);
    rd.xz *= rot(sin(iTime * 0.35) * 0.2);

    vec3 p = ro;
    vec3 col = gradient(rd);   // par défaut on voit le ciel
    vec3 accCol = vec3(0.);
    bool hit = false;

    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            hit = true;
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        if (res.y == 0.) accCol += vec3(1., 0., 0.2) * 0.02;
        p += rd * res.x * 0.4;
    }

    col += accCol;

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 18 — Étoiles via texture + puissance

**Notion :** sample d'une texture de bruit dans `rd.xy`, puis `pow(..., 15)` pour ne garder **que les pics les plus brillants** → des étoiles. La courbe en puissance écrase les valeurs basses (noir) et préserve les hautes (étoiles). Mix avec le gradient pour faire apparaître les étoiles uniquement vers le haut du ciel.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.);
    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

vec3 gradient(vec3 rd)
{
    vec3 sky = vec3(0.);
    sky += pow(texture(iChannel0, rd.xy).x, 15.);  // étoiles = pics du bruit

    vec3 cola = vec3(0.102, 1.000, 0.655) * 1.5;
    vec3 colb = vec3(0.102, 0.776, 1.000);

    return mix(
        mix(cola, colb, sat(rd.y * 15.)),  // gradient vert→bleu
        sky,                                // ajout étoiles
        sat(rd.y * 5.)                      // poids étoiles selon hauteur
    );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));
    rd.yz *= rot(0.1);
    rd.xy *= rot(sin(iTime * 0.5) * 0.2);
    rd.xz *= rot(sin(iTime * 0.35) * 0.2);

    vec3 p = ro;
    vec3 col = gradient(rd);
    vec3 accCol = vec3(0.);

    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        if (res.y == 0.) accCol += vec3(1., 0., 0.2) * 0.02;
        p += rd * res.x * 0.4;
    }

    col += accCol;

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 19 — Brouillard atmosphérique exponentiel

**Notion :** plus un objet est loin, plus l'air entre lui et la caméra l'efface. Modèle classique : `mix(col, ciel, 1 - exp(-distance * k))`. La courbe exponentielle donne une atténuation plus naturelle qu'un mix linéaire. Ici le ciel sert de couleur de fond → la scène se fond dedans : géométrie lointaine + ciel = continuité visuelle.

```glsl
#define sat(a) clamp(a, 0., 1.)
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))

vec3 pmap;

vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x) return a;
    return b;
}

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;
    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.);
    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;
    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

vec3 gradient(vec3 rd)
{
    vec3 sky = vec3(0.);
    sky += pow(texture(iChannel0, rd.xy).x, 15.);

    vec3 cola = vec3(0.102, 1.000, 0.655) * 1.5;
    vec3 colb = vec3(0.102, 0.776, 1.000);

    return mix(
        mix(cola, colb, sat(rd.y * 15.)),
        sky,
        sat(rd.y * 5.)
    );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));
    rd.yz *= rot(0.1);
    rd.xy *= rot(sin(iTime * 0.5) * 0.2);
    rd.xz *= rot(sin(iTime * 0.35) * 0.2);

    vec3 p = ro;
    vec3 col = gradient(rd);
    vec3 accCol = vec3(0.);

    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);
            if (res.y == 1.)
            {
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }
            break;
        }
        if (res.y == 0.) accCol += vec3(1., 0., 0.2) * 0.02;
        p += rd * res.x * 0.4;
    }

    col += accCol;

    // brouillard : interpole entre la couleur de la scène et le ciel selon la distance
    col = mix(
        col,
        gradient(rd),
        sat(1. - exp(-distance(p, ro) * 0.08 + 1.5))
    );

    fragColor = vec4(col, 1.0);
}
```

---

## Étape 20 — FINAL : passage en multipass (Buffer A → Image)

**Notion :** Shadertoy permet de chaîner des passes via les **buffers**. On déplace tout le shader dans **Buffer A**, puis la passe **Image** se contente de lire `iChannel0` (= Buffer A) et d'afficher. Avantage : on peut ajouter du post-process (bloom, color grading, AA…) dans la passe Image **sans toucher** au raymarching.

> Configuration Shadertoy :
> - **Buffer A** : iChannel0 = ta texture de bruit
> - **Image** : iChannel0 = Buffer A

### Buffer A
```glsl
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x)
        return a;
    return b;
}

#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))
#define sat(a) clamp(a, 0., 1.)

vec3 pmap;

vec2 map(vec3 p)
{
    p.y -= cos(p.z * 0.2) * 0.5;
    p.z += iTime * 3.;
    pmap = p;

    vec2 acc = vec2(100000., 0.);

    vec3 ps = p;
    vec2 reps = vec2(3.);
    vec2 id = floor((ps.xz + reps * 0.5) / reps);
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5;

    ps.xz += sin(id + id.x + id.y);

    acc = _min(acc, vec2(length(ps) - 0.5, 0.));

    float ground = p.y;

    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.);

    ground -= texture(iChannel0, p.xz * 0.001).x * way;
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way;

    acc = _min(acc, vec2(ground, 1.));

    return acc;
}

vec3 gradient(vec3 rd)
{
    vec3 sky = vec3(0.);
    sky += pow(texture(iChannel0, rd.xy).x, 15.);

    vec3 cola = vec3(0.102, 1.000, 0.655) * 1.5;
    vec3 colb = vec3(0.102, 0.776, 1.000);

    return mix(
        mix(cola, colb, sat(rd.y * 15.)),
        sky,
        sat(rd.y * 5.)
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 col = vec3(0.);

    vec3 ro = vec3(0., 2., -10.);
    vec3 rd = normalize(vec3(uv * 2., 1.));

    rd.yz *= rot(0.1);
    rd.xy *= rot(sin(iTime * 0.5) * 0.2);
    rd.xz *= rot(sin(iTime * 0.35) * 0.2);

    vec3 p = ro;
    vec3 accCol = vec3(0.);

    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p);

        if (res.x < 0.01)
        {
            if (res.y == 0.) col = vec3(1., 0., 0.2);

            if (res.y == 1.)
            {
                col = vec3(0.5);
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y);
                col = vec3(1.)
                    * (1. - sat(g * 5.))
                    * (1. - sat(length(p.xz) * 0.01 + 0.3));
            }

            break;
        }

        if (res.y == 0.)
            accCol += vec3(1., 0., 0.2) * 0.02;

        p += rd * res.x * 0.4;
    }

    col += accCol;

    col = mix(
        col,
        gradient(rd),
        sat(1. - exp(-distance(p, ro) * 0.08 + 1.5))
    );

    fragColor = vec4(col, 1.0);
}
```

### Image
```glsl
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = texture(iChannel0, uv).xyz;
    fragColor = vec4(col, 1.0);
}
```

---

## Récap des concepts par étape

| # | Concept clé |
|---|---|
| 1 | UV normalisées centrées |
| 2 | Sphere tracing (SDF + boucle) |
| 3 | Composition de SDF (`min`) |
| 4 | Matériaux par ID (`vec2` + `_min`) |
| 5 | Animation par déformation de l'espace (`p.z += iTime`) |
| 6 | Caméra surélevée et FOV |
| 7 | Pas de raymarching réduit (anti-overshoot) |
| 8 | Domain repetition (`mod` + `floor`, ID de cellule) |
| 9 | Pseudo-random par cellule (hash via `sin(id…)`) |
| 10 | Globale `pmap` + grille procédurale en world-space |
| 11 | Déformation analytique du sol (`cos`), visible grâce à la grille |
| 12 | Vignettage radial |
| 13 | Texture de bruit comme fonction continue |
| 14 | Modulation latérale par SDF analytique (chemin "way") |
| 15 | Animation caméra par 3 rotations 2D sur `rd` |
| 16 | Bloom par accumulation pendant la marche |
| 17 | Skybox gradient procédural |
| 18 | Étoiles : `pow(noise, n)` |
| 19 | Brouillard atmosphérique exponentiel |
| 20 | Multipass Shadertoy (Buffer A → Image) |
