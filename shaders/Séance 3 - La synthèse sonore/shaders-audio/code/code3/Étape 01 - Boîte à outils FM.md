# Étape 01 — Boîte à outils FM

> Décomposition [[shadertoy3 code]] — **étape 1 / 10**
> Concept : rappel des macros `FM`, `FM2`, `N`, du tempo `bpm` / `beatdur`.

---

## Objectif pédagogique

- Réinstaller la **boîte à outils** héritée du code 2.
- Vérifier qu'on entend une note FM avant d'attaquer les instruments du code 3.
- Comprendre l'astuce `fract` de la macro `FM`.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)

#define bpm 100.
#define beatdur (60./bpm)

#define FM(fc, fm, iom)  sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define FM2(pc, pm, iom) sin(mod(pc,TWOPI) + (iom)*sin(mod(pm,TWOPI)))

#define N(nn) 440.*exp2(((nn)-9.)/12.)

vec2 mainSound( int samp, float t )
{
    // Une note FM rejouée à chaque temps.
    float tt = mod(t, beatdur);
    float f  = N(0.);                        // do médian (note 0 du système)
    vec2 sig = vec2(FM(f, f, 2.0));           // porteuse = modulante, index 2
    return sig * exp(-4.0*tt) * 0.3;          // enveloppe percussive
}
```

---

## Théorie

### Le morceau démarre où le code 2 s'arrête

Le code 3 ne réintroduit aucune base : il **réutilise** les macros du code 2 (cf. [[Étape 02 - Macro FM stéréo]]). On les remet en place ici pour que les étapes suivantes compilent seules.

### Les quatre macros

| Macro              | Rôle                                                                                   |
| ------------------ | -------------------------------------------------------------------------------------- |
| `bpm` / `beatdur`  | tempo : `beatdur` = durée d'un temps en secondes (ici `0,6 s`)                         |
| `FM(fc, fm, iom)`  | un oscillateur **modulé en fréquence** : porteuse `fc`, modulante `fm`, index `iom`    |
| `FM2(pc, pm, iom)` | la même chose, mais on passe directement des **phases** au lieu de fréquences          |
| `N(nn)`            | convertit un **numéro de demi-ton** en fréquence (`N(0)` = do médian, `N(9)` = 440 Hz) |

### L'astuce `fract` de la macro `FM`

```glsl
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
```

`fract((fc)*t)` ramène la phase dans `[0, 1[` **avant** de la multiplier par `2π`. Pour `f = 440` et `t = 60 s`, `f*t = 26400` : un `sin` en `float32` perdrait toute précision. Le `fract` garde la phase petite → précision constante, même après plusieurs minutes.

> Attention : `FM` est une **macro**, pas une fonction. Elle utilise la variable `t` du contexte d'appel. Toute fonction qui emploie `FM` doit donc avoir une variable locale nommée `t`.

### `mainSound` : le moteur

`mainSound(samp, t)` est appelée **44 100 fois par seconde**. `t` est le temps en secondes ; la sortie est un `vec2(L, R)` ∈ `[-1, 1]²`. Ici `mod(t, beatdur)` relance une enveloppe `exp` à chaque temps.

---

## Ce qu'on entend

Une note électronique sèche, **répétée à 100 BPM** (soit toutes les 0,6 s). Le timbre est légèrement métallique : c'est l'index de modulation `2.0` qui ajoute des harmoniques au sinus pur.

---

## Expérimentations suggérées

1. Changer l'index `2.0` → `0.0` (sinus pur) puis `8.0` (timbre criard, riche).
2. Remplacer `N(0.)` par `N(12.)` → une octave au-dessus.
3. Modifier `bpm` à `140.` → le morceau accélère.
4. Mettre la modulante à `2.*f` : `FM(f, 2.0*f, 2.0)` → timbre plus « cuivré ».

---

## Limites de cette étape

Une note FM générique, ce n'est aucun instrument précis. L'étape suivante en fait un **vrai timbre** : la marimba, par un simple choix de ratio.

---

[[Étape 02 - Marimba FM inharmonique|→ Étape 02 — Marimba FM inharmonique]]

#shader #audio #shadertoy #td
