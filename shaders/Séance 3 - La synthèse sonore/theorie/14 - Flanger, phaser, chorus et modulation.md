# 14 — Flanger, phaser, chorus et modulation

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 14/30**
> **Tags :** #synthese-sonore #effets #flanger #chorus #modulation #ESGI

---

## Introduction

Ce chapitre couvre les effets de **modulation temporelle** : ils créent des variations sonores en jouant sur les déphasages, les délais, et les modifications cycliques de paramètres.

---

## 1. Flanger

### Principe

Un signal est **dupliqué** et le doublon est mixé avec l'original avec un **léger décalage temporel** (quelques millisecondes).

Ce mélange de deux versions légèrement décalées crée un **filtrage en peigne** :
- Certaines fréquences s'additionnent → amplitude doublée
- D'autres fréquences s'annulent → silence (interférence destructive)

Les positions des pics et creux dans le spectre se déplacent avec le temps → son "wobbly" caractéristique.

### Caractéristique distinctive

> "Le flanger produit des pics et des creux fréquentiels de **dimensions et à intervalles réguliers**."

Les creux/pics sont **uniformément espacés** dans le spectre de fréquences.

### Paramètres

| Paramètre | Rôle |
|---|---|
| Rate | Vitesse de l'oscillation du délai |
| Depth | Amplitude de la variation du délai |
| Feedback | Ré-injection du signal → effet plus métallique |
| Mix | Proportion signal traité / original |

---

## 2. Phaser

### Principe

Similaire au flanger, mais utilise des **filtres à décalage de phase** (all-pass filters) au lieu d'un vrai délai.

### Différence avec le flanger

> "Avec un phaser, l'**espacement, la profondeur et la largeur** des creux et pics peuvent être modifiés."

- Les pics/creux ne sont **pas uniformément espacés** dans le spectre
- Possibilité de moduler la fréquence centrale des déphasages
- Son plus "rotatif", moins métallique que le flanger

### Analogie

Le flanger = spectacle de magie avec un miroir parfait  
Le phaser = le même miroir mais déformé et reconfigurable

---

## 3. Chorus

### Principe

Le chorus multiplie le signal en créant des **copies légèrement différenciées** par des variations de :
- Délai (légère différence temporelle entre copies)
- Fréquence (légère variation de hauteur)
- Vibrato désynchronisé (chaque copie oscille à sa propre phase)

### Effet résultant

Un son plus **large**, **riche** et **plein**, simulant plusieurs instruments jouant la même note avec de légères variations naturelles.

→ Simule un **ensemble** (chœur de violons, ensemble vocal) à partir d'un seul instrument

### Paramètres

| Paramètre | Rôle |
|---|---|
| Rate | Vitesse du LFO de modulation |
| Depth | Amplitude des variations |
| Voices | Nombre de copies générées |
| Mix | Proportion original/traité |

---

## 4. Ring Modulation

### Principe

L'amplitude d'une **onde porteuse (P)** est modulée par une **onde modulante (M)**.

Résultat : les fréquences originales disparaissent et sont remplacées par deux nouvelles fréquences :

```
Fréquences résultantes = P + M  et  P - M
```

**Exemple** : P = 440 Hz, M = 100 Hz → résultat : 540 Hz et 340 Hz

### Comportement selon la fréquence du modulant

| Fréquence du modulant | Effet |
|---|---|
| < 20 Hz | Trémolo (modulation d'amplitude perçue) |
| > 20 Hz | Ring modulation → nouvelles fréquences (inharmoniques) |

### Caractère sonore

- Son souvent **dur, métallique, dissonant**
- Les nouvelles fréquences ne sont généralement pas en relation harmonique avec l'original
- Très utilisé pour les **effets spéciaux**, sons de robots, effets "Dalek" (Doctor Who)

---

## 5. PWM — Pulse Width Modulation

> "Variation du rapport cyclique d'une onde rectangulaire pour modifier le contenu harmonique sans changer la fréquence fondamentale."

### Principe

- On fait varier le **duty cycle** (rapport cyclique) d'une onde rectangulaire
- Cette variation modifie la richesse harmonique du son
- La fréquence fondamentale et l'amplitude **restent stables**

### Modulation par LFO

En pilotant le duty cycle avec un **LFO** :
- Variation cyclique du timbre → son animé, "animé" de l'intérieur
- Crée un effet de **chorus organique** sans vrai délai

```
Duty cycle 50% (carré)  → son creux standard
Duty cycle 25%          → son plus aigu, plus fin
Duty cycle 10%          → son très étroit, cliquetant
Variation par LFO       → animation continue du timbre
```

---

## Tableau récapitulatif

| Effet | Mécanisme | Caractère sonore |
|---|---|---|
| **Flanger** | Délai variable + mixage → peigne régulier | Métallique, "swooshing" |
| **Phaser** | Déphasage par filtres all-pass | Rotatif, ondulant |
| **Chorus** | Copies avec délai/pitch légèrement différents | Large, ensemble |
| **Ring Modulation** | Multiplication de fréquences | Métallique, dissonant |
| **PWM** | Variation du duty cycle par LFO | Timbre animé, organique |

---

**← Précédent :** [[13 - Pitch bend, unisson, portamento et vibrato]]  
**→ Suite :** [[15 - La synthèse soustractive]]
