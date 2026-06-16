# 06 — Les différents types d'oscillateurs

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 6/30**
> **Tags :** #synthese-sonore #oscillateurs #VCO #LFO #ESGI

---

## Rôle de l'oscillateur

Un **oscillateur** est le **générateur de source sonore** dans un synthétiseur. C'est lui qui produit les formes d'ondes (sinus, dents de scie, carrée…) à la fréquence souhaitée.

Il y a 4 types principaux d'oscillateurs selon la technologie employée.

---

## 1. VCO — Voltage Controlled Oscillator

> "Oscillateur contrôlé par une tension électrique pour les valeurs de forme d'onde, d'amplitude et de fréquence."

### Fonctionnement

- Tous les paramètres (forme d'onde, amplitude, fréquence) sont contrôlés par des **tensions électriques analogiques**
- La hauteur de note est typiquement envoyée depuis le clavier sous forme de **tension CV** (Control Voltage)
- Inclut généralement des potentiomètres de **pitch** et de **détune** pour l'accordage et la sélection d'octave

### Caractéristiques sonores

- **Instabilité naturelle** : les VCOs peuvent légèrement dériver en fréquence avec la température et nécessitent parfois un temps de chauffe
- Cette instabilité crée un **grain et une chaleur** très appréciés en production musicale
- Comportement "vivant" et imprédictible qui contribue au son "analogique" caractéristique

### Défauts

- Dérivent avec la température (problème d'accordage)
- Demandent parfois plusieurs minutes de chauffe avant stabilisation
- Plus coûteux à produire

---

## 2. DCO — Digitally Controlled Oscillator

- Le contrôle des paramètres est **numérique** (valeurs binaires), mais la **production du son reste analogique**
- Plus stable que les VCOs (le contrôle numérique élimine la dérive de fréquence)
- Conserve un caractère sonore très proche des VCOs car la forme d'onde est toujours générée en **analogique**
- Exemples d'instruments : Juno-106 de Roland, OB-8 de Oberheim

> Le DCO est un compromis : stabilité numérique + chaleur analogique.

---

## 3. DO — Digital Oscillator (Oscillateur Numérique)

- Entièrement **numérique** — utilisé dans les synthétiseurs non-analogiques et les logiciels
- **Avantages :**
  - Stabilité maximale (aucune dérive)
  - Les "défauts" deviennent programmables et contrôlables
  - Peut dépasser les formes d'ondes traditionnelles
  - **Indispensable pour la synthèse wavetable** (lecture de samples stockés)
- **Inconvénients :**
  - Son plus "froid", moins organique
  - Manque le grain analogique naturel

---

## 4. LFO — Low Frequency Oscillator

> "Oscillateur à basse fréquence : produit des fréquences inférieures à 20 Hz, donc inaudibles."

### Rôle fondamental

Le LFO **ne génère pas de son directement**. Il génère des signaux à très basse fréquence qui servent à **moduler** d'autres paramètres du synthétiseur.

L'oreille ne perçoit pas le LFO lui-même, mais perçoit **les effets** de sa modulation sur les paramètres audibles.

### Applications typiques du LFO

| Paramètre modulé | Effet résultant |
|---|---|
| Fréquence de l'oscillateur principal | **Vibrato** (variation de hauteur) |
| Amplitude (via VCA) | **Trémolo** (variation de volume) |
| Fréquence de coupure du filtre | **Wah** / filtre animé |
| Rapport cyclique (PWM) | Animation du timbre |
| Pan stéréo | Autopan |

### Paramètres d'un LFO

- **Fréquence** : de très lente (1 cycle toutes les 10 secondes) à rapide (~20 Hz)
- **Forme d'onde** : sinus (variation douce), carrée (variation brusque), dents de scie, aléatoire
- **Profondeur (depth)** : amplitude de la modulation
- **Sync** : synchronisation au tempo du morceau

---

## Tableau comparatif

| Type | Technologie | Stabilité | Caractère | Usage principal |
|---|---|---|---|---|
| **VCO** | Analogique | Faible | Chaleureux, vivant | Synthèse analogique classique |
| **DCO** | Contrôle num. + son analog. | Bonne | Proche VCO | Polysynths des années 80 |
| **DO** | Numérique pur | Excellente | Précis, froid | Wavetable, virtuel |
| **LFO** | Analogique ou num. | — | < 20 Hz | Modulation (vibrato, tremolo…) |

---

## Plusieurs oscillateurs dans un synthétiseur

La plupart des synthétiseurs comportent **2 à 3 oscillateurs** par voix, ce qui permet :
- Un son plus **épais** par mixage des formes d'ondes
- Des effets de **désaccordage** (detune) pour un son plus large
- Des **battements** entre deux oscillateurs légèrement désaccordés (chorus naturel)

> Exemple : le Minimoog a 3 VCOs — ils peuvent jouer des formes d'ondes différentes et être désaccordés indépendamment.

---

**← Précédent :** [[05 - Les différents types de bruits]]  
**→ Suite :** [[07 - Les différents types de filtres]]
