# 26 — Synthèse formantique et arithmétique linéaire (LA)

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 26/30**
> **Tags :** #synthese-sonore #formantique #LA #Roland-D50 #ESGI

---

## 1. Synthèse Formantique

### Qu'est-ce qu'un formant ?

> "Un formant est un pic d'amplitude de certaines fréquences au sein d'un signal sonore, caractéristique de la vocalisation humaine ou des instruments à vent."

```
Spectre d'un "A" chanté :
    
Amplitude
    |    █          █           █
    |   ███        ███         ███
    |  █████      █████       █████
    +--|-----|-----|-----|-----|-----> Fréquence
        F1        F2          F3
      (750Hz)   (1100Hz)    (2500Hz)
      ← Formant 1→ ← Formant 2 → ← F3 →
```

**Les formants définissent les voyelles** :
- Voyelle "A" → F1 élevé, F2 bas
- Voyelle "I" → F1 bas, F2 très élevé
- Voyelle "O" → F1 moyen, F2 bas

Les formants **varient avec la tessiture** :
- Soprano : formants à des fréquences différentes qu'un baryton pour la même voyelle
- Cette variation est naturelle car la géométrie du conduit vocal change

### Principe de la synthèse formantique

Reproduire les formants d'un instrument ou d'une voix en combinant :
- Des concepts de **modèle physique** (excitation + résonance)
- Des concepts de **synthèse granulaire** (éléments sonores unitaires)

### Fonctions d'ondes formantiques (FOF)

Technique développée à l'**IRCAM** par Xavier Rodet, Yves Potard et Jean-Baptiste Barrière.

**Logiciel CHANT** (début années 80, IRCAM) :
- Premier système de synthèse vocale par FOF
- Objectif : modéliser la voix humaine pour généraliser aux autres instruments
- Référence dans le domaine de la synthèse musicale par ordinateur

### Situation actuelle

La synthèse formantique **pure** est peu utilisée aujourd'hui :
- Les applications de synthèse vocale modernes préfèrent la **concaténation de phonèmes** préenregistrés (plus réaliste)
- Exemple : voix GPS, synthèse vocale TTS (Text-To-Speech)
- La synthèse formantique reste utilisée en recherche et dans certains effets créatifs (vocoders avancés)

---

## 2. Synthèse Arithmétique Linéaire (LA)

### Contexte historique

En 1987, Roland fait face à la domination du **Yamaha DX7** (synthèse FM) sur le marché.  
Roland cherche une alternative qui offre :
1. Des sons aussi réalistes que le DX7
2. Une approche plus intuitive (la FM était réputée difficile à programmer)
3. Des sons avec des **attaques réalistes** (le talon d'Achille de la synthèse pure)

### Principe de la synthèse LA

> "Combine la synthèse soustractive pour le corps du son avec de **courts échantillons** pour l'attaque."

```
Attaque d'une note pianistique :
[Échantillon court] + [Son synthétisé continu]
(quelques millisecondes    (dents de scie + filtre
 d'un vrai piano)           pour le sustain)
```

**Observation clé** : l'oreille humaine identifie les instruments principalement à leur **attaque** (les premières millisecondes du son). En utilisant une courte attaque échantillonnée, on trompe l'oreille sur la nature du son.

### Architecture du Roland D-50

```
Structure d'une voix D-50 :
Partiel 1 : [PCM Tonewheel] + [Synthèse soustractive]
Partiel 2 : [PCM Attack]    + [Synthèse soustractive]
         ↓
      [Mixage]
         ↓
    [Chorus/Reverb intégrés]
         ↓
         Sortie
```

- **PCM Tonewheel** : échantillons d'attaques réalistes stockés en ROM
- **Synthèse soustractive** : filtres, oscillateurs numériques pour le sustain
- **Effets intégrés** : première fois qu'un synthé inclut du chorus + reverb onboard

### Impact commercial

- Roland **D-50** (1987) : succès commercial massif, rival direct du DX7
- Son "DX7 killer" — sons de clavecin, de piano, de sons spatiaux caractéristiques
- Utilisé par des milliers de productions pop des années 80-90
- Émulation moderne : **D-50 V** (Arturia), **D-50** (Roland Cloud)

---

## Tableau comparatif : types de synthèse hybride

| Synthèse | Composants | Exemple |
|---|---|---|
| **LA (Roland)** | Échantillons courts + soustractive | Roland D-50 |
| **S+S** (Korg) | Sample + Synthesis | Korg M1, T-Series |
| **AWM2** (Yamaha) | Samples multi-niveaux | Yamaha SY77, Motif |

---

**← Précédent :** [[25 - Synthèse pulsar et distorsion de phase]]  
**→ Suite :** [[27 - Synthèse stochastique et graphique]]
