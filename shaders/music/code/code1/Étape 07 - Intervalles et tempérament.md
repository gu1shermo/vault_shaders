# Étape 07 — Intervalles et tempérament égal

> Décomposition [[shadertoy1 code]] — **étape 7 / 8**
> Concept : générer des **fréquences musicales** par demi-tons, pour passer du « bip » à la **mélodie**.

---

## Objectif pédagogique

- Comprendre la perception **logarithmique** de la hauteur et le **tempérament égal**.
- Implémenter `interval(semitones)` pour multiplier une fréquence de référence.
- Jouer plusieurs notes simultanément (accord) en empilant des `fmPluck`.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

float FM(float fc, float fm, float iom, float t)
{
    return sin(TWOPI*fc*t + iom*sin(TWOPI*fm*t));
}

vec2 fmPluck(float f, float t)
{
    float env = exp(-3.0*t) * 0.1;
    vec2 sig = vec2(0.0);
    sig.x += FM(f + 1.0, f + 1.0, 1.0, t) * env;
    sig.y += FM(f - 1.0, f - 1.0, 1.0, t) * env;
    sig += FM(f, f, 15.0, t) * exp(-20.0*t) * 0.03;
    return sig;
}

vec2 pan(float pos)
{
    return normalize(vec2(1.0 - pos, 1.0 + pos));
}

float interval(float semitones)
{
    return pow(2.0, semitones / 12.0);
}

vec2 mainSound( int samp, float t )
{
    float ref = 440.0;                           // La 3
    float tn  = mod(t, 2.0);

    vec2 sig = vec2(0.0);
    sig += fmPluck(ref * interval( 0.0), tn) * pan(-0.5);  // La
    sig += fmPluck(ref * interval( 4.0), tn) * pan( 0.0);  // Do# (tierce majeure)
    sig += fmPluck(ref * interval( 7.0), tn) * pan(+0.5);  // Mi  (quinte juste)
    return sig;
}
```

> Trois plucks **simultanés** formant un accord parfait de La majeur, étalés stéréo.

---

## Théorie

### La perception logarithmique de la hauteur

L'oreille humaine perçoit la hauteur d'un son de façon **logarithmique** en fréquence :

- Doubler la fréquence (440 → 880 Hz) ⇒ on entend monter d'**une octave**.
- Doubler à nouveau (880 → 1760 Hz) ⇒ une **deuxième octave**, perçue comme le **même écart** que la première.

C'est pour cela qu'un instrument couvre 8 octaves entre 27 Hz (La 0 d'un piano) et 4186 Hz (Do 8) avec **88 touches espacées régulièrement** : visuellement linéaire, perceptuellement logarithmique.

### Le tempérament égal à 12 demi-tons

L'**octave est divisée en 12 intervalles égaux** appelés demi-tons. Pour qu'ils soient « perçus comme égaux », ils doivent former une **suite géométrique** :

$$ r^{12} = 2 \quad \Rightarrow \quad r = 2^{1/12} \approx 1.05946 $$

`r` est le **ratio d'un demi-ton**. La fréquence d'une note distante de `n` demi-tons d'une référence vaut :

$$ f_n = f_{\text{ref}} \times 2^{n/12} $$

### En GLSL

```glsl
float interval(float semitones)
{
    return pow(2.0, semitones / 12.0);
}
```

> **Optimisation** : `exp2(x)` est généralement plus rapide et précis que `pow(2.0, x)` sur GPU. Notre code suit la convention de la vidéo source, mais en production on préférerait `exp2(semitones / 12.0)`.

### Table des intervalles principaux

| Demi-tons | Ratio `2^(n/12)` | Nom | Sensation |
|---|---|---|---|
| 0 | 1.000 | Unisson | Identique |
| 2 | 1.122 | Seconde maj. | Tendu |
| 3 | 1.189 | Tierce min. | Triste |
| 4 | 1.260 | Tierce maj. | Joyeux |
| 5 | 1.335 | Quarte juste | Stable |
| 7 | 1.498 | Quinte juste | Très stable |
| 8 | 1.587 | Sixte min. | Mélancolique |
| 9 | 1.682 | Sixte maj. | Doux |
| 12 | 2.000 | Octave | « Même note » plus haut |

### Pourquoi le tempérament égal est un compromis

Avec un tempérament **juste** (ratios entiers : 3/2 pour la quinte, 5/4 pour la tierce majeure), les accords sont **plus consonants** mais on ne peut moduler entre tonalités sans réaccorder l'instrument. Le tempérament égal **désaccorde légèrement** chaque intervalle pour permettre de **moduler partout** :

- Quinte juste théorique : `1.5000`
- Quinte tempérament égal : `1.4983` (`2^(7/12)`)
- Erreur : `-2 cents`, **inaudible** pour la plupart des auditeurs.

- Tierce majeure juste : `1.2500`
- Tierce majeure tempérée : `1.2599` (`2^(4/12)`)
- Erreur : `+14 cents`, **légèrement audible**, c'est la « tension » caractéristique des claviers modernes.

Bach a écrit son *Clavier bien tempéré* (1722) précisément pour démontrer qu'on pouvait jouer dans les **24 tonalités** sur un seul instrument grâce au tempérament.

---

## Ce qu'on entend

Un **accord de La majeur** (La – Do# – Mi) qui se réinitialise toutes les 2 s. Les trois notes sont étalées stéréo : La à gauche, Do# au centre, Mi à droite. Sensation d'un instrument **harmonique** large.

---

## Expérimentations suggérées

1. **Accord mineur** : remplacer la tierce majeure `interval(4.0)` par `interval(3.0)` (tierce mineure). Comparer émotionnellement.

2. **Power chord** : ne garder que la fondamentale et la quinte (`0.0` et `7.0`), retirer la tierce. C'est l'accord du **rock** et du **metal** — pas de connotation majeure/mineure.

3. **Cluster dissonant** : `interval(0.0)`, `interval(1.0)`, `interval(2.0)` — trois notes adjacentes. Tension maximale.

4. **Arpège** : déclencher les trois notes à des instants différents :
   ```glsl
   sig += fmPluck(ref * interval(0.0), mod(t,       2.0)) * pan(-0.5);
   sig += fmPluck(ref * interval(4.0), mod(t - 0.2, 2.0)) * pan( 0.0);
   sig += fmPluck(ref * interval(7.0), mod(t - 0.4, 2.0)) * pan(+0.5);
   ```
   C'est l'**arpège ascendant** classique.

5. **Tempérament pythagoricien** : implémenter une variante :
   ```glsl
   float intervalPyth(float semitones)
   {
       // Empilement de quintes pures (3/2) ramenées dans une octave.
       // Approximation simplifiée — à compléter en TP.
       return pow(1.5, semitones / 7.0);
   }
   ```
   Comparer un accord majeur dans les deux tempéraments.

---

## Limites de cette étape

On joue un seul **accord plaqué**, pas une **mélodie**. Pour faire défiler une suite de notes dans le temps, il faut un **séquenceur** : tableau de notes + boucle `for` ⇒ étape 08, la dernière.

---

[[Étape 06 - Panning constant power|← Étape 06]] · [[Étape 08 - Séquenceur jingle|→ Étape 08 — Séquenceur jingle]]

#shader #audio #shadertoy #td
