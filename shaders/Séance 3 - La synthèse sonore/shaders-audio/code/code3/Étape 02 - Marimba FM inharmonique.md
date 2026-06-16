# Étape 02 — Marimba FM inharmonique

> Décomposition [[shadertoy3 code]] — **étape 2 / 10**
> Concept : patch FM « marimba », ratio modulateur `7×`, index décroissant.

---

## Objectif pédagogique

- Construire un **timbre de marimba** en une seule ligne de FM.
- Comprendre pourquoi un **index de modulation décroissant** imite une lame qui vibre.
- Saisir le rôle de la double enveloppe (index + amplitude).

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define N(nn) 440.*exp2(((nn)-9.)/12.)

float marimba(float f, float t)
{
    // Patch FM "marimba" classique — simple et redoutablement efficace.
    return FM(f, 7.0*f, 1.5*exp(-80.0*t)) * exp(-5.0*t) * 0.1;
}

vec2 mainSound( int samp, float t )
{
    float tt = mod(t, beatdur);              // relance chaque temps
    return vec2(marimba(N(4.0), tt));        // une note tenue, en boucle
}
```

---

## Théorie

### Anatomie de `marimba`

Une seule expression FM, mais chaque terme compte :

```glsl
FM(f, 7.0*f, 1.5*exp(-80.0*t)) * exp(-5.0*t) * 0.1
```

| Élément                 | Rôle                                           |
| ----------------------- | ---------------------------------------------- |
| porteuse `f`            | la hauteur jouée                               |
| modulante `7.0*f`       | ratio **7:1** — c'est lui qui crée le timbre   |
| index `1.5*exp(-80.*t)` | richesse harmonique qui **s'éteint très vite** |
| `exp(-5.*t)`            | enveloppe d'amplitude (la note décroît)        |
| `0.1`                   | atténuation pour rester dans `[-1, 1]`         |

### Pourquoi un ratio 7:1 ?

En FM, une porteuse `fc` modulée à `fm` génère des **bandes latérales** aux fréquences `fc ± n·fm`. Avec `fm = 7f` :

$$ f,\ f \pm 7f,\ f \pm 14f,\ \dots\ =\ f,\ -6f,\ 8f,\ -13f,\ 15f,\ \dots $$

Les fréquences **négatives se replient** (un `sin` de fréquence négative = un `sin` de fréquence positive déphasé) : `-6f` revient à `6f`, `-13f` à `13f`. On obtient un spectre `{f, 6f, 8f, 13f, 15f…}` — **non harmonique**. C'est exactement la signature des modes propres d'une lame de bois : la marimba est un instrument **inharmonique**.

> Théorie physique détaillée (équation d'Euler-Bernoulli, modes en `β²`) dans [[Cours 3 - Marimba, Saw Bass, Wah Synth]] §1.

### Les deux exponentielles

- `exp(-80.*t)` sur l'**index** : ultra-rapide. Seule l'attaque (≈ 12 ms) a le timbre métallique riche ; ensuite, l'index tombe à zéro et il ne reste qu'un **sinus pur** (la fondamentale).
- `exp(-5.*t)` sur l'**amplitude** : plus lente. La note s'éteint en ≈ 0,2 s.

C'est la physique d'une lame frappée : **les harmoniques aiguës s'amortissent plus vite que la fondamentale**. Le maillet claque, puis le bois « chante ».

---

## Ce qu'on entend

Un son de **xylophone / marimba** : une attaque boisée et claire, suivie d'une extinction rapide et chaude. Rejoué tous les temps.

---

## Expérimentations suggérées

1. Remplacer `7.0*f` par `2.0*f`, `3.0*f`, `11.0*f` → caractériser : lequel sonne « bois », lequel « cloche » ?
2. Ralentir l'index : `exp(-20.*t)` → l'attaque métallique traîne, ça devient une cloche.
3. Ralentir l'amplitude : `exp(-1.*t)` → notes longues, irréalistes pour une marimba.
4. Mettre l'index constant `1.5` (sans `exp`) → timbre figé, sans vie : on entend le rôle de l'enveloppe.

---

## Limites de cette étape

Une seule note en boucle, ce n'est pas un motif. L'étape suivante construit le **séquenceur de marimba** : un rythme pointé sur deux voix.

---

[[Étape 03 - Séquenceur de marimba|→ Étape 03 — Séquenceur de marimba]]

#shader #audio #shadertoy #td
