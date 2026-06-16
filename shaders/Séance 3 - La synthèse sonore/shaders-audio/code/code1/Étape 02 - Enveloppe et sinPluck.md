# Étape 02 — Enveloppe exponentielle et `sinPluck`

> Décomposition [[shadertoy1 code]] — **étape 2 / 8**
> Concept : décroissance exponentielle, déclenchement périodique, factorisation en fonction réutilisable.

---

## Objectif pédagogique

- Façonner le **profil temporel** d'une note avec une enveloppe `exp(-λt)`.
- Faire **redéclencher** la note avec `mod`.
- Encapsuler le pattern « note pincée » dans une fonction réutilisable.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

float sinPluck(float f, float t)
{
    return sin(TWOPI * f * t) * exp(-3.0 * t) * 0.1;
}

vec2 mainSound( int samp, float t )
{
    float sig = 0.0;
    sig += sinPluck(440.0, mod(t, 1.0));   // La, redéclenché toutes les secondes
    return vec2(sig);
}
```

---

## Théorie

### L'enveloppe exponentielle

Une corde pincée, une lame de marimba frappée, une cloche : tous suivent la même équation différentielle d'oscillateur amorti :

$$ \ddot{x} + 2\lambda \dot{x} + \omega_0^2 x = 0 $$

dont la solution est une sinusoïde modulée par $e^{-\lambda t}$. C'est pour cela que la **décroissance exponentielle** est physiquement réaliste, pas un choix arbitraire.

Le coefficient `3.0` est notre `λ` :

- `λ` grand (8, 15…) → percussion **sèche** (claquement, pizzicato).
- `λ` petit (0.5, 1) → son **long** (cloche, drone court).

> **Outil** : [graphtoy.com](https://graphtoy.com) → tracer `exp(-3*x)` et `exp(-8*x)` pour visualiser.

### Le déclenchement par `mod`

Sans `mod`, `t` croît indéfiniment, donc `exp(-3*t)` tend vers 0 et le son disparaît au bout de ~2 s, pour ne **jamais revenir**.

```glsl
mod(t, 1.0)
```

remplace `t` par sa valeur **modulo 1 seconde** : un signal en dents de scie qui repart de 0 chaque seconde. La note se redéclenche périodiquement.

#### Piège GLSL classique

GLSL **n'autorise pas la conversion implicite** `int → float`. `mod(t, 1)` produit une erreur de compilation. Toujours écrire `1.0`.

### Factorisation en fonction

```glsl
float sinPluck(float f, float t) { ... }
```

Un seul endroit à modifier pour changer l'enveloppe ou la forme d'onde. Pattern récurrent dans tout le module : **chaque waveform devient une fonction `xxxPluck(f, t)`**.

---

## Ce qu'on entend

Un La pincé qui se répète **toutes les secondes**, comme un métronome harmonique. Chaque coup démarre fort puis s'éteint sur ~700 ms (durée caractéristique : `1/λ` ≈ 333 ms à `-1` neper, soit environ 1 seconde pour devenir inaudible).

---

## Expérimentations suggérées

1. **λ extrême** : remplacer `-3.0` par `-15.0` → claquement très sec. Puis `-0.5` → drone qui se chevauche d'une période à l'autre.
2. **Période** : `mod(t, 0.5)` → deux fois plus rapide. `mod(t, 2.0)` → deux fois plus lent.
3. **Décalage** : `mod(t + 0.5, 1.0)` → la note démarre 0.5 s plus tard dans la boucle. Utile pour **désynchroniser** deux voix.
4. **Empilement** : ajouter `sig += sinPluck(660.0, mod(t, 1.0));` → quinte (rapport 3/2). Réfléchir : pourquoi `660 / 440 = 1.5` sonne « consonant » ?

---

## Limites de cette étape

Le sinus est **trop pur** : aucune harmonique, donc aucun timbre. Aucun instrument acoustique ne ressemble à ça. Étape suivante : enrichir le spectre avec des ondes plus complexes.

---

[[Étape 01 - Sinus pur|← Étape 01]] · [[Étape 03 - Square et Saw|→ Étape 03 — Square et Saw]]

#shader #audio #shadertoy #td
