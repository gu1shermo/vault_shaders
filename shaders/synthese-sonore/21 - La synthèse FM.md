# 21 — La synthèse FM (modulation de fréquence)

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 21/30**
> **Tags :** #synthese-sonore #FM #modulation #ESGI

---

## Principe fondamental

> "La synthèse FM repose sur une onde porteuse dont la fréquence est modifiée par une onde modulante."

```
[Onde modulante (M)]
         ↓
    modifie la fréquence de
         ↓
[Onde porteuse (P)] → [Sortie audio]
```

- **Onde porteuse (Carrier / P)** : l'oscillateur dont on entend la sortie
- **Onde modulante (Modulator / M)** : l'oscillateur qui modifie la fréquence de la porteuse

### Différence avec la modulation d'amplitude (AM)

| Modulation | Paramètre affecté | Résultat |
|---|---|---|
| **AM** | Amplitude de la porteuse | Son qui varie en volume |
| **FM** | Fréquence de la porteuse | Génération d'harmoniques complexes |

---

## Découverte historique

**John Chowning** — Stanford University, années 1960

En expérimentant avec des effets de vibrato, Chowning a poussé les paramètres à l'extrême :
- Vibrato lent (< 20 Hz) → variation de hauteur perçue
- En augmentant la vitesse et la profondeur → le vibrato disparaît et un **spectre harmonique complexe** apparaît
- Découverte accidentelle que la FM génère de **nouvelles harmoniques**

**1966** : Chowning formule la théorie FM en synthèse audio  
**1974** : Yamaha achète le brevet à Stanford  
**1980** : Yamaha GS1 (premier synthétiseur FM commercial, très cher)  
**1983** : Yamaha **DX7** — révolution commerciale, 200 000 unités vendues

---

## Les opérateurs FM

Un **opérateur** en synthèse FM est un bloc composé de :
- Un **oscillateur sinusoïdal** (sinus uniquement en FM classique)
- Un **amplificateur** (VCA/DCA)
- Un **générateur d'enveloppe** (indépendant par opérateur)

### Comportement des opérateurs

| Rôle | Terme | Description |
|---|---|---|
| Opérateur **porteuse** | Carrier | Sa sortie est entendue |
| Opérateur **modulante** | Modulator | Modifie la fréquence de la porteuse |

Un même opérateur peut jouer les deux rôles selon la configuration.

### Auto-modulation (feedback)

Un opérateur peut se **moduler lui-même** (sa propre sortie est renvoyée en entrée) :
- Feedback faible → légère distorsion harmonique
- Feedback fort → formes d'ondes complexes, presque du bruit

---

## Algorithmes FM

L'**algorithme** = la configuration de routage entre les opérateurs.

```
Algorithme simple (2 opérateurs) :
[M] → [P] → Sortie

Algorithme parallèle :
[P1] → Sortie
[P2] → Sortie
(Synthèse additive de sinusoïdes)

Algorithme cascade :
[M3] → [M2] → [M1] → [P] → Sortie
(Modulation en chaîne)
```

Le **Yamaha DX7** a 32 algorithmes différents utilisant 6 opérateurs.

---

## Efficacité spectrale

> "Avec seulement 2 oscillateurs, on peut obtenir un signal **extrêmement riche en harmoniques**."

Comparaison :

| Méthode | Oscillateurs | Richesse harmonique |
|---|---|---|
| Additive | 1 par harmonique | Totalement contrôlée, 1 à 1 |
| **FM** | **2 opérateurs** | Spectre potentiellement infini |

La FM est **bien plus efficace** que la synthèse additive pour créer un spectre riche.

---

## FM vs. Radio FM

La seule différence entre la synthèse FM audio et la radio FM est la **gamme de fréquences** :
- Radio FM : 87,5–108 MHz
- Synthèse FM audio : dans la plage audible (20 Hz–20 kHz)

Le principe mathématique est **identique**.

---

## Instruments et logiciels FM

| Instrument | Opérateurs | Algorithmes |
|---|---|---|
| **Yamaha DX7** (1983) | 6 | 32 |
| Yamaha DX21/DX27/DX100 | 4 | 8 |
| Yamaha TX81Z | 4 | 8 |
| Yamaha FS1R | 8 + 8 (formant) | 88 |
| **FM8** (Native Instruments) | 6+1 | Multiples |
| **DEXED** (open source) | 6 | 32 (DX7 compatible) |
| Volca FM (Korg) | 6 | 32 (DX7 compatible) |
| DX7 V (Arturia) | 6 | 32 |

### Cartes son historiques

Les premiers synthétiseurs de jeux vidéo utilisaient la FM :
- **AdLib** (1987) : OPL2 (Yamaha YM3812) — 2 opérateurs
- **Sound Blaster** : OPL3 — évolution de l'AdLib
- Musiques de Doom, Wolfenstein 3D, etc.

---

**← Précédent :** [[20 - Les formes de synthèse granulaire]]  
**→ Suite :** [[22 - Le spectre dans la synthèse FM]]
