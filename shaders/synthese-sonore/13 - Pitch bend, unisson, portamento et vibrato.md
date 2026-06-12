# 13 — Pitch bend, unisson, portamento et vibrato

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 13/30**
> **Tags :** #synthese-sonore #pitch-bend #vibrato #portamento #ESGI

---

## Introduction

Ce chapitre couvre les effets de **modulation de hauteur** et d'**expression** disponibles sur les synthétiseurs.

---

## 1. Pitch Bend

> "La molette de pitch bend permet la modification en temps réel de la hauteur de la note jouée."

### Mécanisme

- Contrôlée par une **molette** (ou bandeau/pavé tactile) sur le synthétiseur
- Effet **continu** : chaque position de la molette correspond à une hauteur précise
- Encodé en **MIDI sur 14 bits** → 16 384 niveaux de résolution
- Plage configurable (typiquement ±2 demi-tons, parfois ±12 ou ±24)

### Types de contrôleurs

| Contrôleur | Comportement |
|---|---|
| Molette (spring-loaded) | Revient au centre quand relâchée |
| Bandeau tactile | Accès direct à n'importe quelle valeur selon position |
| Pavé tactile (X/Y) | Pitch bend sur axe X, autre effet sur axe Y |

---

## 2. Vibrato

> "Effet obtenu par la variation très rapide de la hauteur d'une forme d'onde, donc de sa fréquence de base."

### Mécanisme

- Modulation de la **fréquence** de l'oscillateur par un **LFO**
- Le LFO fait varier la hauteur rapidement (5–8 Hz typiquement)

### Paramètres

| Paramètre | Effet |
|---|---|
| **Fréquence du LFO** | Vitesse du vibrato (Hz) |
| **Amplitude du LFO** | Profondeur du vibrato (étendue de la variation en cents) |
| **Retard (delay)** | Entrée progressive du vibrato après le début de la note |

### Expression musicale

Les instrumentistes à cordes appliquent le vibrato naturellement.  
Sur synthétiseur, il est souvent piloté par la **molette de modulation** (CC 1).

---

## 3. Unisson

> "Utilise plusieurs oscillateurs simultanément pour créer un son plus volumineux et épais."

### Mécanisme

- Plusieurs oscillateurs jouent la **même note** simultanément
- Chaque oscillateur est **légèrement désaccordé** (detune) par rapport aux autres
- Les oscillateurs peuvent être répartis dans l'espace **stéréo**

### Effet sonore

- Son beaucoup plus **large** et **épais**
- Les légères différences de fréquence créent des **battements** naturels → effet de chorus
- L'épaisseur augmente avec le nombre d'oscillateurs

### SuperSaw

Certains synthétiseurs virtuels proposent une forme d'onde **SuperSaw** :
- Simule automatiquement plusieurs dents de scie désaccordées
- Crée l'effet unisson sans mobiliser plusieurs oscillateurs séparés
- Popularisé par le Roland JP-8000 (1996) — base des sons de "trance" et "EDM"

---

## 4. Portamento / Glide

> "Le portamento reproduit toutes les fréquences situées entre deux notes."

### Mécanisme

Le portamento crée un **glissement continu de fréquence** entre une note et la suivante, passant par toutes les hauteurs intermédiaires.

### Deux modes

| Mode | Comportement |
|---|---|
| **Mono** | Portamento permanent — entre toutes les notes successives, qu'elles se chevauchent ou non |
| **Legato** | Portamento uniquement si les notes **se chevauchent** (touche 2 pressée avant relâché touche 1) |

### Paramètre Rate/Time

- Contrôle la **vitesse** du glissement
- Lent → glissement lent entre les notes (effet de saxophone, de theremine)
- Rapide → transition très brève, presque imperceptible

---

## 5. Keyboard Tracking

> "Définit la fréquence de coupure du filtre en fonction de la note jouée."

### Problème sans keyboard tracking

Un filtre avec une fréquence de coupure **fixe** : pour les notes aiguës, la fondamentale peut être filtrée car elle dépasse la coupure → son incohérent.

### Solution

Le keyboard tracking fait **monter la fréquence de coupure** en même temps que la note jouée :
- Note grave → coupure basse → son sombre
- Note aiguë → coupure plus haute → son plus brillant, proportionnel

### Paramètre

- Souvent réglable de 0% (aucun tracking) à 100% (la coupure suit exactement la fréquence de la note)
- À 100% : le filtre préserve le même rapport harmonique quel que soit la hauteur de note

---

**← Précédent :** [[12 - Les différents types de messages MIDI]]  
**→ Suite :** [[14 - Flanger, phaser, chorus et modulation]]
