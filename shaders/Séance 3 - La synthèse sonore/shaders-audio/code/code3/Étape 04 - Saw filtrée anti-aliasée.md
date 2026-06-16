# Étape 04 — Saw filtrée anti-aliasée

> Décomposition [[shadertoy3 code]] — **étape 4 / 10**
> Concept : `filteredSaw`, repli de phase par `round`, lissage de la discontinuité.

---

## Objectif pédagogique

- Comprendre le problème d'**aliasing** d'une dent de scie idéale.
- Lire et maîtriser `filteredSaw` — la fonction **centrale** du code 3.
- Saisir comment une **fréquence de coupure** se traduit en largeur de transition.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define N(nn) 440.*exp2(((nn)-9.)/12.)

float filteredSaw(float f, float fc, float t)
{
    // f  : fréquence de la note
    // fc : fréquence de coupure (cutoff)
    // t  : temps
    float x = f*t;                 // phase, en nombre de périodes
    float w = 0.5*f/fc;            // demi-largeur de la transition
    w = min(w, 0.5);               // jamais plus large qu'une demi-période
    x -= round(x);                 // repli : x dans [-0.5, +0.5]
    return mix(-2.0*x - 1.0,       // segment avant le saut
               -2.0*x + 1.0,       // segment après le saut
               smoothstep(-w, w, x));
}

vec2 mainSound( int samp, float t )
{
    float f  = N(-12.0);                       // note grave
    float fc = mix(300.0, 12000.0,             // coupure balayée lentement
                   0.5 + 0.5*sin(t));
    return vec2(filteredSaw(f, fc, t)) * 0.3;
}
```

---

## Théorie

### Le problème : la saw idéale alias

Une dent de scie idéale a un spectre **infini** (`f, 2f, 3f, …`). Échantillonnée à 44,1 kHz, tout partiel au-dessus de 22,05 kHz **se replie** dans l'audible : c'est l'aliasing, un fourmillement métallique parasite. Plus la note est aiguë, plus c'est audible.

**Solution** : limiter le spectre. Une saw n'a qu'une seule source de hautes fréquences — sa **discontinuité** (le saut brutal de `+1` à `-1`). Adoucir ce saut = filtrer passe-bas.

### `filteredSaw`, ligne par ligne

```glsl
float x = f*t;          // phase
x -= round(x);          // x ∈ [-0.5, +0.5], le saut est en x = 0
```

`round` arrondit à l'entier le plus proche : `x - round(x)` est la phase repliée **centrée**, le saut tombe pile en `x = 0`.

```glsl
return mix(-2.0*x - 1.0, -2.0*x + 1.0, smoothstep(-w, w, x));
```

- `-2x - 1` : la rampe **avant** le saut (vaut `-1` en `x → 0⁻`).
- `-2x + 1` : la rampe **après** le saut (vaut `+1` en `x → 0⁺`).
- Sans lissage, on passerait de l'une à l'autre instantanément → la discontinuité, donc l'aliasing.
- `smoothstep(-w, w, x)` **interpole** entre les deux segments sur la fenêtre `[-w, +w]` : le saut devient une **rampe douce**.

### La coupure pilote la largeur

```glsl
float w = 0.5*f/fc;
w = min(w, 0.5);
```

`w` est proportionnel à `f/fc` :

- `fc` **grand** (coupure haute) → `w` petit → saut quasi net → saw brillante, beaucoup d'harmoniques.
- `fc` **petit** (coupure basse) → `w` large → saut très adouci → son feutré, sourd.

Adoucir la discontinuité **est** un filtrage passe-bas : `fc` joue exactement le rôle de la fréquence de coupure d'un filtre. Le `min(w, 0.5)` empêche la transition de déborder de la période.

> C'est de l'anti-aliasing **analytique** : au lieu de générer puis filtrer, on dessine directement la forme d'onde déjà band-limitée. Pas de filtre récursif — impossible en shader sans état.

---

## Ce qu'on entend

Un bourdon de dent de scie dont le timbre **« s'ouvre et se ferme »** lentement (le `sin(t)` balaie `fc`). Coupure haute : c'est brillant, agressif. Coupure basse : ça devient un sinus feutré. Aucun fourmillement d'aliasing, même quand c'est brillant.

---

## Expérimentations suggérées

1. Figer `fc = 12000.0` puis `fc = 400.0` → comparer brillant *vs* sourd.
2. Forcer `w = 0.0` (saw idéale) avec `f = N(24.0)` (note aiguë) → écouter l'aliasing réapparaître.
3. Monter `f` à `N(36.0)` en gardant `fc` modéré → la saw reste propre : c'est l'anti-aliasing qui travaille.
4. Remplacer `round(x)` par `floor(x)` → le saut se décale, la forme reste correcte.

---

## Limites de cette étape

`filteredSaw` est une **brique nue**. Pour en faire une basse, il faut l'habiller : un sub, du détune, et surtout une **enveloppe de coupure** qui referme le filtre dans le temps. C'est l'étape suivante.

---

[[Étape 05 - bassSynth saw stab|→ Étape 05 — bassSynth « saw stab »]]

#shader #audio #shadertoy #td
