# Étape 08 — Vibrato correct

> Décomposition [[shadertoy2 code]] — **étape 8 / 10**
> Concept : moduler la hauteur d'une note **sans la faire dériver** — l'erreur classique du vibrato, et sa correction par intégration de phase.

---

## Objectif pédagogique

- Comprendre pourquoi `f += sin(t)` est un **vibrato faux** (dérive de hauteur).
- Comprendre la correction : moduler la **phase**, pas la fréquence.
- Découvrir la macro `FM2`, variante de `FM` qui prend des **phases déjà calculées**.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))

// FM2 : comme FM, mais reçoit des PHASES (radians) au lieu de fréquences.
#define FM2(pc, pm, iom) sin(mod(pc, TWOPI) + (iom)*sin(mod(pm, TWOPI)))

// Phase d'une note avec vibrato JUSTE
float vibratoPhase(float f0, float semitones, float vibHz, float t)
{
    float df = 0.06*f0*semitones;                       // amplitude du vibrato (en Hz)
    return TWOPI*f0*t + df/vibHz*sin(TWOPI*vibHz*t);    // phase intégrée
}

vec2 mainSound( int samp, float t )
{
    float tn = mod(t, 2.0);
    float f  = N(7.0);                       // Sol4

    float vibEnv = smoothstep(0.0, 0.5, tn); // le vibrato arrive progressivement
    float phase  = vibratoPhase(f, 0.2*vibEnv, 5.0, tn);

    vec2 sig = vec2(FM2(phase, phase, 1.0)) * 0.2;
    float env = exp(-1.5*tn);
    return sig * env;
}
```

---

## Théorie

### L'erreur naturelle : moduler la fréquence

Pour un vibrato, le réflexe est d'écrire :

```glsl
// FAUX
float f = f0 + df*sin(TWOPI*vibHz*t);
float sig = sin(TWOPI * f * t);
```

Ça **semble** correct : la fréquence oscille autour de `f0`. Mais le piège est dans le terme `f * t`. La phase devrait être l'**intégrale** de la fréquence. Or ici on écrit `f(t) * t`, et en dérivant :

$$ \frac{d}{dt}\big[f(t)\cdot t\big] = f(t) + f'(t)\cdot t $$

La fréquence réellement entendue est `f(t) + f'(t)·t`. Le terme parasite `f'(t)·t` **croît avec le temps** : plus la note dure, plus le vibrato déforme la hauteur moyenne. La note **dérive** — faux musicalement.

> C'est le commentaire `// WRONG` / `// RIGHT` du code source de [[shadertoy2 code]]. 

### La correction : intégrer la fréquence en phase

La phase doit être l'**intégrale** de `2π·f(t)`. Avec une fréquence sinusoïdale `f(t) = f0 + df·cos(2π·vibHz·t)` :

$$ \text{phase}(t) = 2\pi f_0 t + \frac{df}{vibHz}\sin(2\pi \cdot vibHz \cdot t) $$

C'est exactement `vibratoPhase` :

```glsl
return TWOPI*f0*t + df/vibHz*sin(TWOPI*vibHz*t);
```

- `TWOPI*f0*t` : la phase de la porteuse (hauteur stable).
- `df/vibHz*sin(...)` : l'ondulation du vibrato, **correctement intégrée** (le `1/vibHz` vient de l'intégration du `cos`).

Aucun terme parasite : la hauteur **moyenne** reste exactement `f0`, quelle que soit la durée. C'est en réalité de la **modulation de fréquence** — un vibrato n'est rien d'autre qu'une FM à fréquence très basse (5 Hz) et index faible.

Les paramètres :
- `df = 0.06*f0*semitones` : profondeur du vibrato. `semitones` dose l'écart de hauteur.
- `vibHz = 5.0` : 5 oscillations par seconde — le vibrato naturel d'un chanteur ou d'un violoniste.

### Le vibrato progressif

```glsl
float vibEnv = smoothstep(0.0, 0.5, tn);
phase = vibratoPhase(f, 0.2*vibEnv, 5.0, tn);
```

`vibEnv` monte de 0 à 1 sur la première demi-seconde. La profondeur passée à `vibratoPhase` est `0.2*vibEnv` : la note **démarre droite**, puis le vibrato **s'installe** progressivement. C'est exactement le geste d'un instrumentiste : on attaque la note nette, on l'orne ensuite.

### La macro `FM2`

```glsl
#define FM2(pc, pm, iom) sin(mod(pc, TWOPI) + (iom)*sin(mod(pm, TWOPI)))
```

`FM2` est la jumelle de `FM` (étape 02), avec une différence d'**interface** :

| Macro | Reçoit | Wrapping |
|---|---|---|
| `FM(fc, fm, iom)` | des **fréquences** | `TWOPI*fract(f*t)` |
| `FM2(pc, pm, iom)` | des **phases** (radians) | `mod(phase, TWOPI)` |

`FM` calcule la phase elle-même (`f*t`). `FM2` suppose qu'on lui donne la phase **déjà construite** — ici la sortie de `vibratoPhase`, qui contient le vibrato. Le `mod(·, TWOPI)` joue le même rôle de précision que le `fract` de `FM` : ramener la phase dans `[0, 2π)`.

C'est `FM2` qu'utilisera `leadSynth` (étape 09), car le lead a besoin d'injecter une phase **pré-modulée par le vibrato** dans toutes ses couches FM.

> `vec2(FM2(...))` : `FM2(phase, phase, 1.0)` avec des phases `float` renvoie un `float`. On le promeut explicitement en `vec2` pour la lisibilité — comme `vec2(sig)` au [[Étape 01 - Sinus pur|code 1]].

---

## Ce qu'on entend

Un Sol4 qui démarre droit puis prend un vibrato vivant à 5 Hz — chantant, naturel, **sans dérive de hauteur**. La note reste centrée sur le Sol du début à la fin.

---

## Expérimentations suggérées

1. Coder le vibrato **faux** et comparer :
   ```glsl
   float fWrong = f + 0.06*f*0.2*vibEnv * sin(TWOPI*5.0*tn);
   vec2 sig = vec2(sin(TWOPI*fWrong*tn)) * 0.2;
   ```
   Sur 2 s, on entend la note **glisser** au lieu d'osciller proprement.
2. Profondeur : `0.6*vibEnv` → vibrato large façon opéra ; `0.05*vibEnv` → vibrato subtil.
3. Vitesse : `vibHz = 3.0` (langoureux) vs `8.0` (nerveux, presque trémolo).
4. Supprimer `vibEnv` (profondeur constante) → la note attaque déjà vibrée : moins naturel.

---

## Limites de cette étape

Une porteuse + une modulante, c'est encore un timbre nu. Le vrai `leadSynth` empile **cinq couches** — corps, présence, attaque — autour de cette phase vibrée. C'est l'étape 09.

---

[[Étape 07 - Réverbération par échos|← Étape 07]] · [[Étape 09 - leadSynth|→ Étape 09 — leadSynth]]

#shader #audio #shadertoy #td
