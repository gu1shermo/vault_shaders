# Étape 01 — Sinus pur

> Décomposition [[shadertoy1 code]] — **étape 1 / 8**
> Concept : signature de `mainSound`, onde sinusoïdale, fréquence d'échantillonnage.

---

## Objectif pédagogique

- Comprendre la signature de `mainSound` et le rôle du paramètre `t`.
- Produire le **son le plus simple possible** : un sinus pur à 440 Hz.
- Saisir la contrainte de domaine `[-1, +1]` et la nécessité d'un facteur d'atténuation.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

vec2 mainSound( int samp, float t )
{
    float f = 440.0;
    float sig = sin(TWOPI * f * t) * 0.1;
    return vec2(sig);
}
```

---

## Théorie

### Le paradigme `mainSound`

Shadertoy appelle `mainSound(samp, t)` **44 100 fois par seconde**, en parallèle sur le GPU, exactement comme `mainImage` est appelée pour chaque pixel.

- `samp` : indice de l'échantillon (entier croissant).
- `t` : temps en secondes — c'est notre **seule variable d'entrée utile**.
- Retour : `vec2(L, R)` ∈ `[-1, +1]²`.

### Le sinus comme oscillation

L'expression mathématique d'une sinusoïde de fréquence `f` est :

$$ s(t) = \sin(2\pi f t) $$

- `2π * f * t` est la **phase instantanée** en radians.
- Une période complète vaut `2π`, soit un temps `T = 1/f`.
- À **440 Hz**, l'oscillation se répète toutes les `1/440 ≈ 2,27 ms`. C'est le **La 3**, référence universelle de l'accord d'orchestre.

### Pourquoi `* 0.1` ?

L'amplitude brute d'un `sin` est `±1`. Dès qu'on **somme plusieurs voix** (cours suivants), on dépasse vite `[-1, +1]` → **clipping**. On prend l'habitude dès maintenant d'atténuer chaque voix à 10 %.

### Note GLSL : `#define TWOPI`

GLSL ne fournit pas `M_PI`. On définit `TWOPI ≈ 6.2831` une fois pour toutes. Précision suffisante pour de l'audio (l'oreille ne perçoit pas le drift de phase < 1 ‰).

---

## Ce qu'on entend

Un bourdon continu à 440 Hz, **stable** dans le temps, **identique** sur les deux canaux. C'est sec, électronique, sans vie : aucune attaque, aucune extinction.

> Si on retourne un `float`, GLSL le promeut en `vec2(x, x)` : mono. Ici on explicite `vec2(sig)` pour la lisibilité.

---

## Expérimentations suggérées

1. Changer `f` à `220.0` puis `880.0` → écouter l'octave en bas / en haut.
2. Remplacer `* 0.1` par `* 1.0` → entendre la différence de niveau. **Ne pas dépasser**.
3. Remplacer `sin(TWOPI * f * t)` par `cos(TWOPI * f * t)` → indiscernable à l'oreille (le déphasage de π/2 est inaudible sur une note tenue).

---

## Limites de cette étape

Le son ne s'arrête jamais, ne se relance jamais, ne ressemble à **aucun instrument réel**. Tous les instruments percussifs présentent une décroissance d'énergie : c'est l'objet de l'étape suivante.

---

[[Étape 02 - Enveloppe et sinPluck|→ Étape 02 — Enveloppe et `sinPluck`]]

#shader #audio #shadertoy #td
