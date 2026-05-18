# Étape 05 — bassSynth « saw stab »

> Décomposition [[shadertoy3 code]] — **étape 5 / 10**
> Concept : enveloppe de coupure, sub-oscillateur, détune stéréo.

---

## Objectif pédagogique

- Transformer `filteredSaw` en une **vraie basse** 80's.
- Comprendre l'**enveloppe de fréquence de coupure** (le « stab »).
- Voir comment empiler sub + composantes détunées pour le poids et la largeur.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define N(nn) 440.*exp2(((nn)-9.)/12.)

float filteredSaw(float f, float fc, float t)
{
    float x = f*t;
    float w = min(0.5*f/fc, 0.5);
    x -= round(x);
    return mix(-2.0*x - 1.0, -2.0*x + 1.0, smoothstep(-w, w, x));
}

vec2 bassSynth(float f, float t)
{
    // Basse "saw stab" classique des années 80
    vec2 sig = vec2(0);
    float fc  = 15000.0*exp(-80.0*t) + 100.0;  // enveloppe de coupure du sub
    float fc2 = 15000.0*exp(-40.0*t) + 100.0;  // enveloppe des composantes hautes
    sig += 0.10*filteredSaw(f/2.0, fc, t);                  // sub-oscillateur filtré
    sig += 0.05*sin(TWOPI*fract(f/2.0*t));                  // un peu plus de sub
    sig += 0.10*filteredSaw(f+1.618, fc2, t+1.0)*vec2(1.0,0.2); // composantes hautes
    sig += 0.10*filteredSaw(f-1.0,  fc2, t+1.7)*vec2(0.2,1.0);  // + stéréo & détune
    return sig;
}

vec2 mainSound( int samp, float t )
{
    float tt = mod(t, 0.5*beatdur);            // une croche relancée
    return bassSynth(N(-3.0)/2.0, tt);
}
```

---

## Théorie

### L'enveloppe de coupure : le « stab »

```glsl
float fc = 15000.0*exp(-80.0*t) + 100.0;
```

À l'attaque (`t = 0`), `fc ≈ 15100 Hz` : le filtre est grand ouvert, la saw est **brillante et mordante**. En quelques millisecondes, `exp(-80t)` s'effondre et `fc → 100 Hz` : le filtre se **referme**, il ne reste qu'un grave sourd.

Cette ouverture-puis-fermeture rapide du timbre, c'est le **« stab »** : le claquement caractéristique des basses synthé 80's / acid. C'est l'équivalent, sur le timbre, de ce que l'enveloppe d'amplitude fait au volume.

Deux enveloppes distinctes :

| Variable | Décroissance              | Cible                               |
| -------- | ------------------------- | ----------------------------------- |
| `fc`     | `exp(-80t)` — très rapide | le **sub-oscillateur**              |
| `fc2`    | `exp(-40t)` — plus lente  | les **composantes hautes** détunées |

Les aigus restent ouverts un peu plus longtemps que le sub → la basse garde de la « présence » après l'attaque.

### Le sub-oscillateur

```glsl
sig += 0.10*filteredSaw(f/2.0, fc, t);     // saw une octave plus bas
sig += 0.05*sin(TWOPI*fract(f/2.0*t));     // sinus pur, même octave
```

`f/2.0` joue **une octave en dessous** de la note demandée — d'où le `N(nn)/2.` côté appel. Une saw grave filtrée *plus* un sinus pur à la même fréquence : le sinus apporte le **poids** propre, sans encombrer le médium. On garde tout ça **mono** : sous 100 Hz, l'oreille localise mal — un sub stéréo ne servirait à rien.

### Détune stéréo des composantes hautes

```glsl
sig += 0.10*filteredSaw(f+1.618, fc2, t+1.0)*vec2(1.0,0.2);
sig += 0.10*filteredSaw(f-1.0,  fc2, t+1.7)*vec2(0.2,1.0);
```

Deux saw légèrement **désaccordées** (`f+1.618` et `f-1.0`, en Hz) : le petit écart de fréquence crée un **battement** lent qui épaissit le son. Pannées en miroir (`vec2(1,0.2)` à gauche, `vec2(0.2,1)` à droite), elles **élargissent** la stéréo.

> Les décalages temporels `t+1.0` et `t+1.7` désynchronisent les phases dès l'attaque : sans eux, les voix démarreraient en phase et l'effet de détune mettrait du temps à apparaître.

---

## Ce qu'on entend

Une basse synthé **grasse et claquante**, rejouée à la croche : une attaque brillante qui « stabbe », un corps grave épais, une légère largeur stéréo dans les aigus.

---

## Expérimentations suggérées

1. Ralentir l'enveloppe de coupure : `exp(-20.*t)` → le stab devient un long balayage « acid ».
2. Figer `fc = 5000.` (constant) → plus de stab : timbre statique.
3. Retirer le sinus de sub → la basse perd son poids dans le grave.
4. Augmenter le détune (`f+5.` / `f-5.`) → battement rapide, son « désaccordé ».

---

## Limites de cette étape

Une basse qui se répète mécaniquement à la croche n'est pas une ligne de basse. L'étape suivante en fait un **séquenceur** avec une progression harmonique.

---

[[Étape 06 - Séquenceur de basse|→ Étape 06 — Séquenceur de basse]]

#shader #audio #shadertoy #td
