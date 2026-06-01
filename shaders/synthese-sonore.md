# Synthèse Sonore — Cours ESGI 5e année

> Source : dossier "Au cœur du son" — Audiofanzine (30 chapitres)

---

## Sommaire

1. [Le Son et les Ondes](#1-le-son-et-les-ondes)
2. [Caractéristiques d'une Onde](#2-caractéristiques-dune-onde)
3. [Fréquences et Spectre](#3-fréquences-et-spectre)
4. [Formes d'Ondes](#4-formes-dondes)
5. [Types de Bruits](#5-types-de-bruits)
6. [Oscillateurs](#6-oscillateurs)
7. [Filtres](#7-filtres)
8. [Enveloppe ADSR](#8-enveloppe-adsr)
9. [Polyphonie, Paraphonie, Multitimbralité](#9-polyphonie-paraphonie-multitimbralité)
10. [MIDI](#10-midi)
11. [Effets de Modulation](#11-effets-de-modulation)
12. [Effets Temporels](#12-effets-temporels)
13. [Synthèse Soustractive](#13-synthèse-soustractive)
14. [Synthèse Additive](#14-synthèse-additive)
15. [Échantillonnage et Wavetable](#15-échantillonnage-et-wavetable)
16. [Synthèse Granulaire](#16-synthèse-granulaire)
17. [Synthèse FM](#17-synthèse-fm)
18. [Synthèse par Modèle Physique](#18-synthèse-par-modèle-physique)
19. [Autres Types de Synthèse](#19-autres-types-de-synthèse)

---

## 1. Le Son et les Ondes

**Le son** = création et propagation d'une vibration dans un milieu élastique (air, eau, bois…).  
Il ne peut pas se propager dans le vide.

**Une onde** = manifestation physique de la propagation de la vibration.  
Les molécules transmettent la vibration à leurs voisines **sans se déplacer elles-mêmes** (mouvement vertical, pas horizontal).

**Représentation d'une onde :**
- Axe horizontal = temps
- Axe vertical = amplitude

**Onde simple** = sinusoïde seule.  
**Onde complexe** = combinaison de plusieurs sinusoïdes non identiques.

> **Théorème de Fourier** : toute onde complexe peut être décomposée en un ensemble d'ondes sinusoïdales simples (sauf les transitoires).

---

## 2. Caractéristiques d'une Onde

| Paramètre | Définition | Unité |
|---|---|---|
| **Amplitude** | Différence entre le point d'équilibre et le niveau maximal de pression. Correspond au volume. | Pascal / dB |
| **Période** | Temps pour effectuer un cycle complet. | secondes (ms) |
| **Longueur d'onde** | Distance entre deux cycles successifs. | mètres |
| **Phase** | Décalage temporel entre deux ondes, mesuré en degrés. | degrés (°) |

### Phase et interférences

| Situation | Résultat |
|---|---|
| En phase (0°) | Les amplitudes s'additionnent → volume doublé |
| Opposition de phase (180°) | Annulation totale → silence |
| Entre les deux | Effets partiels (phaser, flanger) |

---

## 3. Fréquences et Spectre

**Fréquence** = nombre de cycles par seconde → mesurée en **Hertz (Hz)**.  
Plage d'audition humaine : **20 Hz – 20 000 Hz**.

| Terme | Définition |
|---|---|
| **Fréquence fondamentale** | Détermine la hauteur perçue (ex. La 440 Hz) |
| **Harmoniques** | Multiples entiers de la fondamentale — définissent le timbre |
| **Partiels** | Composantes qui ne s'alignent pas sur la série harmonique → **inharmoniques** |
| **Spectre sonore** | Ensemble des composantes d'un son (fondamentale + harmoniques + partiels) |

> Les sons musicaux reposent sur des formes d'ondes **périodiques**.  
> Le bruit est **apériodique** (pas de hauteur définie).

---

## 4. Formes d'Ondes

| Forme d'onde | Contenu harmonique | Remarques |
|---|---|---|
| **Sinusoïde** | Fondamentale seule, zéro harmonique | Son le plus pauvre, le plus pur |
| **Carrée** | Harmoniques impairs, décroissance en 1/f | Symétrique (50% haut / 50% bas) |
| **Rectangulaire (Pulse)** | Harmoniques impairs | Asymétrique — rapport cyclique variable (PWM) |
| **Triangulaire** | Harmoniques impairs, décroissance en 1/f² | Plus douce que la carrée |
| **Dents de scie (Sawtooth)** | Tous les harmoniques | La plus riche — idéale pour la synthèse soustractive |

**Rapport cyclique (duty cycle)** : fraction de temps où l'onde est à l'état haut.  
La **MLI / PWM** (Pulse Width Modulation) fait varier ce rapport pour modifier le contenu harmonique sans changer la fréquence.

---

## 5. Types de Bruits

| Couleur | Caractéristique | Usage |
|---|---|---|
| **Blanc** | Toutes les fréquences à puissance égale | Synthèse (vent, percussions) |
| **Rose** | Puissance −3 dB/octave | Calibration de systèmes de diffusion |
| **Brun / Rouge** | Puissance −6 dB/octave | Plus grave, grave chargé |

> Les autres couleurs (bleu, violet, gris) sont quasi-absentes en synthèse sonore pratique.

---

## 6. Oscillateurs

| Type | Description |
|---|---|
| **VCO** (Voltage Controlled Oscillator) | Contrôlé par tension électrique. Caractère harmonique chaud, léger instabilité — analogique. |
| **DCO** (Digitally Controlled Oscillator) | Contrôle numérique, mais production de signal analogique. Plus stable que le VCO. |
| **DO** (Digital Oscillator) | Entièrement numérique. Stabilité maximale, peut émuler l'analogique. Base de la synthèse wavetable. |
| **LFO** (Low Frequency Oscillator) | Produit des fréquences < 20 Hz (inaudibles). **Ne génère pas de son**, mais **module** d'autres signaux (vibrato, tremolo, PWM…). |

---

## 7. Filtres

Tous les filtres partagent deux paramètres fondamentaux :
- **Fréquence de coupure** : point à partir duquel l'atténuation commence.
- **Pente** : vitesse d'atténuation, exprimée en **dB/octave**. Un filtre 4 pôles = 24 dB/octave (standard Moog).

| Type de filtre | Laisse passer | Atténue |
|---|---|---|
| **Passe-bas (Low-Pass)** | Fréquences < coupure | Fréquences > coupure |
| **Passe-haut (High-Pass)** | Fréquences > coupure | Fréquences < coupure |
| **Passe-bande (Band-Pass)** | Plage entre deux coupures | Reste du spectre |
| **Coupe-bande (Notch)** | Tout sauf une plage | Plage entre deux coupures |

> Le filtre **passe-bas** est le plus utilisé en synthèse sonore.

---

## 8. Enveloppe ADSR

L'enveloppe contrôle l'**évolution de l'amplitude dans le temps**.

```
Amplitude
    ^
    |    /\
    |   /  \____
    |  /        \
    | /          \
    |/            \________
    +--A--D--S---R--------> Temps
```

| Étape | Nom | Définition |
|---|---|---|
| **A** | Attack (Attaque) | Temps pour atteindre l'amplitude maximale depuis 0 |
| **D** | Decay (Déclin) | Temps pour descendre du pic vers le niveau de sustain |
| **S** | Sustain | Niveau d'amplitude maintenu tant que la note est tenue |
| **R** | Release (Relâchement) | Temps pour que le son disparaisse après relâche de la note |

- A, D, R → mesurés en **millisecondes**
- S → valeur de **niveau** (0–100)
- Attaque courte → son percussif / Attaque longue → son éthéré
- Sustain très bas → effet de percussion même sur un son mélodique

> Variation : certains synthés (ex. Yamaha DX7) ont 8 étapes d'enveloppe + paramètre "Hold".

---

## 9. Polyphonie, Paraphonie, Multitimbralité

| Terme | Définition |
|---|---|
| **Monodie** | Un seul son/note à la fois. Chaque voix = oscillateurs + filtre + ampli + enveloppes. |
| **Polyphonie** | Plusieurs voix indépendantes, chacune avec sa propre chaîne de traitement. |
| **Paraphonie** | Plusieurs oscillateurs déclenchables indépendamment, mais **partageant une seule chaîne** (filtre, ampli). |
| **Multitimbralité** | Capacité à produire simultanément des sons de **natures différentes** avec des enveloppes distinctes. |

**Systèmes de priorité (mode mono) :**
- Note la plus basse (synths américains années 70)
- Note la plus haute (fabricants japonais)
- Dernière note pressée
- Première note pressée

---

## 10. MIDI

**MIDI** = Musical Instruments Digital Interface.  
Protocole de communication entre instruments électroniques, effets et ordinateurs.  
**Ne transporte pas d'audio**, seulement des données de contrôle.

### Architecture

- **16 canaux** par port (pour adresser différentes machines ou timbres)
- Connecteurs DIN (IN / OUT / THRU) + USB (moderne)
- Résolution standard : **128 valeurs (7 bits)**

### Messages MIDI principaux

| Message | Description |
|---|---|
| **Note On / Off** | Déclenche / relâche une note |
| **Velocity** | Vitesse d'enfoncement de la touche → 0–127 |
| **Program Change** | Change de preset sur l'instrument récepteur |
| **Bank Select** | Accède à des banques de presets supplémentaires |
| **Aftertouch** | Pression maintenue sur une touche → modulation |
| **Control Change (CC)** | Données continues (potentiomètres, faders, molettes) |
| **Pitch Bend** | Codé sur **14 bits** → 16 384 niveaux de résolution |
| **SysEx** | Données spécifiques au fabricant (transfert de presets, paramètres) |
| **RPN / NRPN** | Paramètres étendus hors standard MIDI |

---

## 11. Effets de Modulation

| Effet | Principe |
|---|---|
| **Pitch Bend** | Modification en temps réel de la hauteur via molette (continu). |
| **Vibrato** | Variation très rapide de la fréquence (souvent piloté par LFO). |
| **Unisson** | Plusieurs oscillateurs légèrement désaccordés jouent la même note → son plus épais. |
| **Portamento / Glide** | Glissement de fréquence entre deux notes. Mode **Mono** : permanent. Mode **Legato** : seulement si les notes se chevauchent. |
| **Keyboard Tracking** | La fréquence de coupure du filtre suit la hauteur de la note jouée. |

---

## 12. Effets Temporels

### Flanger et Phaser

Signal dupliqué et mixé avec un léger décalage temporel → **filtrage en peigne** (certaines fréquences s'amplifient, d'autres s'annulent).

| Effet | Caractéristique |
|---|---|
| **Flanger** | Pics et creux à intervalles **réguliers** dans le spectre. |
| **Phaser** | Espacement, profondeur et largeur des pics/creux **variables**. |
| **Chorus** | Copies du signal avec légères variations de délai, fréquence et vibrato → son plus riche et large. |

### Ring Modulation

Amplitude d'une onde porteuse modulée par une onde modulante.  
Au-dessus de 20 Hz : les fréquences originales disparaissent → remplacées par les **sommes et différences** des fréquences.  
→ Résultat : son métallique, inharmonique.

### PWM (Pulse Width Modulation)

Variation du rapport cyclique d'une onde rectangulaire → modifie le contenu harmonique **sans changer la fréquence fondamentale**. Contrôlable par LFO.

---

## 13. Synthèse Soustractive

**Principe** : partir d'une source **riche en harmoniques** et retirer des fréquences via des filtres.

**Chaîne du signal :**

```
[Oscillateur(s)] → [Filtre(s)] → [Amplificateur]
                        ↑               ↑
                   [Enveloppe]    [Enveloppe ADSR]
```

- Les oscillateurs fournissent la matière sonore brute (dents de scie, carrée, triangle)
- Le filtre sculpte le timbre
- L'enveloppe du filtre fait évoluer la brillance dans le temps
- L'enveloppe de l'amplificateur contrôle le volume dans le temps

> La sinusoïde seule est **inutilisable** en synthèse soustractive (aucun harmonique à retirer).

**Instruments historiques clés :**
- Novachord (Hammond, années 30)
- Minimoog (1970) — 3 oscillateurs, filtre 4 pôles, popularisé par Keith Emerson
- Korg MS-20 (1978) — semi-modulaire, 2 filtres

---

## 14. Synthèse Additive

**Principe** : empiler des sinusoïdes simples pour reconstruire un son complexe.  
Inverse du théorème de Fourier : on **ajoute** des composantes au lieu de les décomposer.

> Limitation : aucune analyse n'offre une résolution parfaite → reproduction identique d'un son naturel impossible.

**Instruments historiques :**
- Orgue d'église (premier synthé additif, jeux de tuyaux)
- Telharmonium (1896) — roues phoniques
- Hammond B3 (années 30) — roues phoniques électriques
- Kawai K5 (1987) — 126 harmoniques sélectionnables avec enveloppes indépendantes

---

## 15. Échantillonnage et Wavetable

### Échantillonnage (Sampling)

Enregistrement numérique d'un signal analogique via un **convertisseur analogique-numérique** (CAN) à intervalles réguliers.

| Paramètre | Valeur standard CD |
|---|---|
| Taux d'échantillonnage | **44 100 Hz** (44,1 kHz) |
| Résolution | **16 bits** |
| Échantillons/seconde | 44 100 |

**Théorème de Nyquist-Shannon** :  
Il faut **au minimum 2 échantillons par cycle** pour reproduire correctement une fréquence.  
→ Pour reproduire 20 kHz, il faut un taux ≥ 40 kHz (d'où le 44,1 kHz du CD).

**Fréquence de Nyquist** = moitié du taux d'échantillonnage.  
Les fréquences au-dessus provoquent un **repli de fréquences** (aliasing) → filtre anti-repliement obligatoire.

### Synthèse Wavetable

Stocke un **seul cycle** d'une forme d'onde dans une table mémoire.  
La lecture en boucle reconstitue le son continu.

- Modifier la **vitesse de lecture** = modifier la hauteur
- Plusieurs tables peuvent être enchaînées → **transitions dynamiques** entre timbres

---

## 16. Synthèse Granulaire

**Principe** : le son est décomposé en **grains** — micro-segments sonores délimités dans le temps.

### Caractéristiques d'un grain

| Paramètre | Description |
|---|---|
| Point de départ | Défini précisément |
| Durée | Minimum ~100 ms pour percevoir une hauteur |
| Enveloppe | Module l'amplitude du grain |
| Fréquence / Phase | Informations propres à chaque grain |
| Pan | Localisation spatiale |

**Hauteur perçue** = dépend de la durée des grains ET de leur densité (fréquence de déclenchement).

> Différence avec Fourier : la théorie de Fourier ne localise pas les composantes dans le **temps**. Elle ne distingue pas un accord simultané d'un arpège.

### Formes de synthèse granulaire

| Variante | Description |
|---|---|
| **Grilles de Fourier / Ondelettes** | Permet le **time-stretch** et le **pitch-shift** indépendants |
| **Synchrone aux hauteurs** | Synthétise des formants (ex. voix humaine) |
| **Asynchrone** | Pulvérise les grains aléatoirement → "nuages" sonores à paramétrage statistique |

**Applications** : manipulation temporelle/tonale dans les DAWs, instruments comme Absynth, Omnisphere, Malström.

---

## 17. Synthèse FM

**Principe** : une **onde porteuse** voit sa fréquence modulée par une **onde modulante**.

```
[Modulante] → modifie la fréquence de → [Porteuse] → [Sortie]
```

Contrairement à la modulation d'amplitude (AM) qui affecte le volume, la FM affecte la **fréquence** → génère des harmoniques complexes.

### Opérateurs

Un **opérateur FM** = sinusoïde + VCA/DCA + générateur d'enveloppe.  
Les opérateurs peuvent :
- Se moduler mutuellement
- Être additionnés
- Se **auto-moduler**

La combinaison d'opérateurs suit des **algorithmes** prédéfinis.

### Spectre FM

Le spectre dépend du **rapport P/M** (fréquence porteuse / fréquence modulante) :

| Rapport P/M | Résultat |
|---|---|
| Entier | Harmoniques des deux fréquences → son harmonique |
| Non-entier | Composantes inharmoniques → son métallique |

**Indice de modulation** : `I = D / M`  
(D = profondeur de déviation, M = fréquence modulante)

- I faible → son pur proche d'une sinusoïde
- I élevé → spectre très riche, fréquence porteuse peut disparaître

Les amplitudes des bandes latérales sont calculées par les **fonctions de Bessel**.  
La puissance totale du signal reste constante quel que soit I.

### Historique FM

- Découverte : **John Chowning** (Stanford, années 60) — vibrato extrême → timbre
- Commercialisation : **Yamaha DX7** (1983) — instrument révolutionnaire
- Cartes son : Adlib, Sound Blaster (jeux vidéo)
- Logiciels : FM8 (Native Instruments), DEXED (open source)

---

## 18. Synthèse par Modèle Physique

**Principe** : simulation mathématique du comportement acoustique d'un instrument réel.

**Relation fondamentale :**
```
[Excitateur] → [Résonateur]
(pincé, souffle, archet)   (corde, tuyau, membrane)
```

### Étapes de modélisation

1. **Définition des paramètres** : dimensions, masse, élasticité
2. **État initial et conditions limites** : position de départ, contraintes physiques
3. **Relation excitateur-résonateur** : impédance des matériaux, diffusion sonore

### Méthodes principales

| Méthode | Description |
|---|---|
| **Masses et Ressorts** (Hiller & Ruiz, ~1968) | Masses reliées par des ressorts simulent les vibrations — énergie propagée par compression/extension |
| **Synthèse Modale** (années 90) | Divise l'instrument en sous-structures (corde, chevalet, membrane) avec caractéristiques propres. Ex : logiciel **Modalys** (IRCAM) |
| **Synthèse MSW** (McIntyre, Schumacher, Woodhouse) | Modélise le comportement temporel du signal — efficace pour attaques d'anches et cordes frottées |

---

## 19. Autres Types de Synthèse

| Type | Principe |
|---|---|
| **Synthèse par distorsion de phase** | Déforme la lecture d'un cycle de sinusoïde pour créer des harmoniques. Base du Casio CZ. |
| **Synthèse pulsar** | Génère des impulsions (pulsars) à fréquence variable, inspirée de signaux biologiques et cosmiques. |
| **Synthèse formantique** | Modélise les formants (résonances) de la voix et des instruments acoustiques. |
| **Arithmétique Linéaire (LA)** | Combine des formes d'ondes numériques avec de courts échantillons pour créer l'attaque. Base du Roland D-50. |
| **Stochastique** | Génère des sons à partir de processus aléatoires contrôlés (distributions probabilistes). Xenakis. |
| **Graphique** | L'utilisateur dessine directement la forme d'onde ou le spectre. |

---

## Tableau récapitulatif — Types de synthèse

| Type | Source | Transformation | Forces |
|---|---|---|---|
| **Soustractive** | Riche harmoniquement | Filtres | Intuitive, chaleureuse, vintage |
| **Additive** | Sinusoïdes | Empilement | Contrôle total du spectre |
| **FM** | Opérateurs (sinus) | Modulation de fréquence | Spectre complexe avec peu d'oscillateurs |
| **Wavetable** | Table d'un cycle | Lecture en boucle | Efficace, transitions dynamiques |
| **Granulaire** | Grains sonores | Juxtaposition temporelle | Time-stretch, textures, nuages |
| **Modèle physique** | Équations physiques | Simulation | Réalisme acoustique |
| **LA** | Échantillons courts + ondes | Hybridation | Attaques réalistes + corps synthétique |

---

## Glossaire rapide

| Terme | Définition |
|---|---|
| **Timbre** | Couleur sonore — ce qui différencie deux notes de même hauteur et volume |
| **Formant** | Résonance du conduit vocal ou d'un corps résonant — définit les voyelles |
| **Harmonique** | Multiple entier de la fondamentale |
| **Partiel inharmonique** | Composante ne s'alignant pas sur la série harmonique |
| **Aliasing / Repli** | Artefact numérique par sous-échantillonnage |
| **Pôle (filtre)** | Chaque pôle ajoute 6 dB/octave de pente — un filtre 4 pôles = 24 dB/oct |
| **Opérateur (FM)** | Oscillateur + ampli + enveloppe dans un synthé FM |
| **Algorithme (FM)** | Configuration de routage entre opérateurs |
| **Grain** | Micro-segment sonore de base de la synthèse granulaire |
| **VCA** | Voltage Controlled Amplifier — amplifie selon une tension |
| **LFO** | Low Frequency Oscillator — module d'autres paramètres (< 20 Hz) |
| **CV/Gate** | Control Voltage / Gate — protocole de contrôle analogique pré-MIDI |
