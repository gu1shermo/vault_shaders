# Étape 05 — `fmPluck` : stratification et stéréo

> Décomposition [[shadertoy1 code]] — **étape 5 / 8**
> Concept : superposer **plusieurs FM** avec des paramètres différents pour obtenir un timbre **vivant et large**.

---

## Objectif pédagogique

- Stratifier (« layering ») plusieurs voix FM pour construire un timbre composite.
- Créer une **largeur stéréo** par **détune** entre canal gauche et droit.
- Séparer le **corps** du son (long, doux) et son **attaque** (courte, brillante) en deux couches.

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

    // Corps : deux porteuses légèrement désaccordées entre L et R
    sig.x += FM(f + 1.0, f + 1.0, 1.0, t) * env;
    sig.y += FM(f - 1.0, f - 1.0, 1.0, t) * env;

    // Attaque : index élevé + décroissance très rapide (mono, ajouté aux deux canaux)
    sig += FM(f, f, 15.0, t) * exp(-20.0*t) * 0.03;

    return sig;
}

vec2 mainSound( int samp, float t )
{
    return fmPluck(440.0, mod(t, 1.0));
}
```

---

## Théorie

### Layer 1 — Le corps (stéréo désaccordé)

```glsl
sig.x += FM(f + 1.0, f + 1.0, 1.0, t) * env;
sig.y += FM(f - 1.0, f - 1.0, 1.0, t) * env;
```

Deux voix FM **identiques sauf** que la fréquence est `f+1` à gauche et `f-1` à droite. Conséquences :

1. **Battement à 2 Hz** : la différence entre les deux donne une oscillation très lente du volume perçu si on additionne. Mais comme on les sépare en L et R, ça crée plutôt une **respiration spatiale**.
2. **Largeur stéréo** : l'oreille, en comparant L et R, perçoit le son comme **« étalé »** dans l'espace plutôt que ponctuel.
3. **Image plus « analogique »** : aucun synthé numérique n'est parfaitement stable ; ce micro-détune imite le comportement de deux oscillateurs analogiques.

> **Index = 1** : sidebands modérés, timbre doux type **harpe électrique**.

### Layer 2 — L'attaque (mono, brillante, courte)

```glsl
sig += FM(f, f, 15.0, t) * exp(-20.0*t) * 0.03;
```

- **`iom = 15`** : spectre **très riche**, métallique → simule le bruit transitoire d'un pluck (le « clic » de l'attaque d'une corde).
- **`exp(-20.0*t)`** : décroissance **6× plus rapide** que le corps → le transitoire dure ~50 ms et disparaît.
- **`* 0.03`** : volume très bas — c'est juste un « assaisonnement » qui rend l'attaque audible sans masquer le corps.
- **Mono** (`sig += …` sans `.x` ou `.y`) : la pointe de l'attaque est ponctuelle au centre, le corps est large autour → bonne profondeur d'image.

### Pourquoi cette architecture marche

C'est le **principe fondamental des synthétiseurs analogiques** des années 70 :

| Composant | Réalité physique | Notre code |
|---|---|---|
| Body | Corps de l'instrument, résonance lente | Layer 1 (FM doux, env lente) |
| Attack/click | Friction archet, pincement corde | Layer 2 (FM brillant, env rapide) |
| Detune | Imperfection des oscillateurs | `±1.0` Hz entre L et R |

L'oreille humaine reconstruit un « instrument » à partir de ces trois ingrédients alors qu'aucun corps physique n'est modélisé. C'est de la **synthèse de timbre par couches**, l'inverse de la modélisation physique.

### Pourquoi `+1.0` et pas `+2.0` ou plus

Le **seuil de fusion binaurale** : en dessous de ~10 Hz d'écart entre les deux oreilles, le cerveau **fusionne** les deux sources en une seule perception spatialement large. Au-dessus, ça commence à sonner comme **deux instruments distincts** désaccordés (effet « honky-tonk piano »).

`±1 Hz` à 440 Hz = ratio `1.0023` ≈ **4 cents** musicaux : largement sous le seuil de fusion ⇒ effet de chorus/largeur sans dédoublement audible.

---

## Ce qu'on entend

Comparé au `fmBeep` mono de l'étape 04 : un son qui semble **plus grand**, **plus présent**, avec un petit **clic d'attaque** au moment du déclenchement. Image stéréo nette : le son « respire » légèrement entre les deux oreilles.

> Casque obligatoire pour entendre la différence — sur des enceintes intégrées, la stéréo est écrasée.

---

## Expérimentations suggérées

1. **Désactiver l'attaque** : commenter la ligne `sig += FM(f, f, 15.0, …)`. Comparer : le son est-il moins « vivant » ?
2. **Élargir le détune** : remplacer `±1.0` par `±5.0`, puis `±20.0`. À quel moment la fusion binaurale lâche-t-elle ?
3. **Attaque variable** : remplacer le `15.0` de `iom` par `30.0 * exp(-50.0*t)` (l'index lui-même décroît) → effet de « wah » très bref, signature DX7.
4. **Mono check** : retourner `vec2((sig.x + sig.y) * 0.5)` à la place → écouter ce qu'on perd quand on collapse la stéréo.

---

## Limites de cette étape

Le panning est **fixé** (le corps est étalé symétriquement). Si on veut **placer** une voix précisément à gauche ou à droite (par exemple chaque note d'une mélodie à un endroit différent de la scène stéréo), il faut une fonction de panning paramétrable ⇒ étape 06.

---

[[Étape 04 - Modulation FM|← Étape 04]] · [[Étape 06 - Panning constant power|→ Étape 06 — Panning constant power]]

#shader #audio #shadertoy #td
