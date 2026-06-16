# 02 — Anatomie des ondes sonores

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 2/30**
> **Tags :** #synthese-sonore #ondes #ESGI

---

## Ondes simples et ondes complexes

- **Onde simple** = une seule sinusoïde (son pur, sans harmoniques)
- **Onde complexe** = combinaison d'au moins deux ondes non identiques

Dès qu'on additionne une onde non identique à une sinusoïde, on obtient une onde complexe.

> **Théorème de Fourier :** "Toute onde complexe peut être décomposée en un certain nombre d'ondes sinusoïdales simples, à l'exception des transitoires."

---

## Les 4 caractéristiques d'une onde sonore

### 1. Amplitude

> "Différence entre son point d'équilibre et le niveau maximal de pression ou de dépression exercé sur le milieu ambiant."

- Mesurée en **Pascal** (pression physique)
- Perçue en **décibels (dB)** par l'oreille
- Plus l'onde s'éloigne de l'axe central, plus le son est **fort**
- Directement liée au **volume** du son

```
Amplitude
    ^
    |   /\
    |  /  \      ← amplitude = distance entre axe et sommet
    | /    \
----+--------\---> Temps
    |        \/
    |         ← même amplitude en dépression
```

### 2. Période

La **période** = temps nécessaire pour accomplir un cycle complet de la forme d'onde.

- Mesurée en **secondes** (ou millisecondes)
- Une onde périodique se répète indéfiniment avec la même durée de cycle

### 3. Longueur d'onde

La **longueur d'onde** = distance physique entre deux cycles successifs dans le milieu de propagation.

- Mesurée en **mètres**
- Liée à la fréquence et à la vitesse de propagation du son

### 4. Phase

La **phase** = décalage temporel entre deux ondes, mesuré en **degrés (°)**.

- Deux ondes identiques démarrées avec 90° d'écart sont **déphasées de 90°**
- La phase est toujours définie **par rapport à une autre onde**

---

## Les interférences de phase

La phase est un paramètre fondamental car deux ondes qui se croisent **interfèrent** :

| Situation | Résultat sonore |
|---|---|
| **En phase (0°)** | Les amplitudes s'additionnent → **volume doublé** |
| **Opposition de phase (180°)** | Les parties positives d'une onde annulent les parties négatives de l'autre → **silence total** |
| **45°, 90°, 135°…** | Résultats intermédiaires entre amplification et annulation |

### Schéma : ondes en phase vs. opposition

```
En phase :
  Onde A : /\/\/\
  Onde B : /\/\/\
  Résultat: taille doublée

En opposition :
  Onde A :  /\/\/\
  Onde B :  \/\/\/
  Résultat: silence
```

### Applications pratiques

Ces phénomènes d'interférence sont exploités dans des effets comme :
- **Phaser** : crée des déphasages variables sur certaines fréquences
- **Flanger** : interférences à intervalles réguliers
- **Annulation de bruit** (casques ANC)
- **Mixage audio** : problèmes de phase entre microphones

---

## Le théorème de Fourier (détail)

Joseph Fourier (mathématicien, 1768-1830) a démontré que :

1. **Toute forme d'onde complexe** peut être décomposée en une somme de sinusoïdes simples
2. Ces sinusoïdes ont des **fréquences et amplitudes différentes**
3. **Exception** : les **transitoires** (attaques brusques, impulsions) ne peuvent pas être parfaitement décomposés

→ C'est le fondement théorique de la **synthèse additive** (chapitre 16) et de l'**analyse spectrale**.

---

## Résumé

| Paramètre | Définition | Unité |
|---|---|---|
| Amplitude | Distance entre axe et extremum | Pascal / dB |
| Période | Durée d'un cycle complet | secondes / ms |
| Longueur d'onde | Distance physique entre deux cycles | mètres |
| Phase | Décalage temporel entre deux ondes | degrés (°) |

---

**← Précédent :** [[01 - Qu'est-ce que la synthèse sonore]]  
**→ Suite :** [[03 - Les fréquences dans les ondes sonores]]
