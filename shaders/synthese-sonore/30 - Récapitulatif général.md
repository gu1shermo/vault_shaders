# 30 — Récapitulatif général

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 30/30**
> **Tags :** #synthese-sonore #recap #ESGI

---

## Vue d'ensemble des types de synthèse

### Tableau comparatif complet

| Type | Principe | Matière première | Forces | Exemples d'instruments |
|---|---|---|---|---|
| **Soustractive** | Filtrer un signal riche | Dents de scie, carrée, bruit | Intuitive, chaleureuse | Minimoog, Korg MS-20 |
| **Additive** | Empiler des sinusoïdes | Sinusoïdes | Contrôle total du spectre | Hammond B3, Kawai K5 |
| **FM** | Moduler la fréquence d'une porteuse | Opérateurs (sinus) | Riche avec peu d'oscillateurs | Yamaha DX7, FM8 |
| **Wavetable** | Lire des cycles en boucle | Tableaux d'un cycle | Efficace, timbres variés | PPG Wave, Serum |
| **Granulaire** | Juxtaposer des micro-segments | Grains | Time-stretch, textures | Omnisphere, Absynth |
| **Modèle physique** | Simuler la physique | Équations mathématiques | Réalisme acoustique | Pianoteq, Yamaha VL-1 |
| **LA (Roland)** | Échantillons d'attaque + soustractive | PCM + oscillateurs | Attaques réalistes | Roland D-50 |
| **Distorsion de phase** | Lire une wavetable non-linéairement | Wavetable + fonction de phase | FM-like, accessible | Casio CZ |
| **Formantique** | Reproduire des formants | FOF | Synthèse vocale | IRCAM CHANT |
| **Stochastique** | Processus aléatoires contrôlés | Fonctions probabilistes | Textures organiques | GenDy (Xenakis) |

---

## Chronologie de l'évolution des types de synthèse

```
1919  Thérémine (premier instrument électronique sans contact)
1930  Trautonium
~1935 Ondes Martenot (ruban + oscillateurs)
1940s Hammond B3 (additive par roues phoniques)
1950s Enregistreurs magnétiques, premiers studios
1960s Synthèse FM théorisée par Chowning
1963  Films avec Trautonium (Les Oiseaux)
1970  Minimoog — synthèse soustractive analogique portable
1975  Polymoog — première polyphonie
1978  Korg MS-20 — semi-modulaire
1980  PPG Wave — wavetable
1983  Yamaha DX7 — FM digitale commerciale
1984  Roland D-50 — synthèse LA (hybride)
1987  Kawai K5 — additive numérique
1990s Modèle physique commercial (Yamaha VL-1)
2000s Synthèse logicielle (soft-synths)
2010s Explosion des plug-ins (Serum, Massive X...)
```

---

## Les blocs de base d'un synthétiseur

Quel que soit le type de synthèse, les blocs fondamentaux sont les mêmes :

```
┌─────────────────────────────────────────────────────────┐
│                    SYNTHÉTISEUR                         │
│                                                         │
│  [SOURCE] ──→ [TRAITEMENT] ──→ [AMPLIFICATION] ──→ OUT  │
│  Oscillateur    Filtre (VCF)     Ampli (VCA)            │
│  (VCO/DO)       + Résonance      + Enveloppe ADSR       │
│                 + Enveloppe                             │
│                                                         │
│  [LFO] ──→ Module n'importe quel paramètre              │
│  [MIDI] ──→ Contrôle depuis clavier / séquenceur        │
└─────────────────────────────────────────────────────────┘
```

---

## Récapitulatif des notions fondamentales

### Le son et les ondes

| Paramètre | Définition | Unité |
|---|---|---|
| Amplitude | Distance entre axe et extremum → volume | Pascal / dB |
| Fréquence | Cycles par seconde | Hz |
| Période | Durée d'un cycle | s / ms |
| Phase | Décalage entre deux ondes | degrés (°) |
| Harmonique | Multiple entier de la fondamentale | Hz |
| Spectre | Ensemble des composantes fréquentielles | — |

### Les formes d'ondes

| Forme | Harmoniques | Usage |
|---|---|---|
| Sinusoïde | Aucun | Son pur |
| Carrée | Impairs (1/f) | Sons creux |
| Dents de scie | Tous | Soustractive |
| Triangulaire | Impairs (1/f²) | Sons doux |

### Les filtres

| Type | Laisse passer | Atténue |
|---|---|---|
| Passe-bas | < coupure | > coupure |
| Passe-haut | > coupure | < coupure |
| Passe-bande | Zone centrale | Extrêmes |
| Coupe-bande | Extrêmes | Zone centrale |

### MIDI

| Résolution | Bits | Valeurs |
|---|---|---|
| Standard | 7 bits | 128 (0–127) |
| Pitch Bend / RPN | 14 bits | 16 384 |
| Canal | — | 16 par port |

---

## Glossaire des termes clés

| Terme | Définition |
|---|---|
| **Timbre** | Couleur sonore — différencie deux sons de même hauteur et volume |
| **Formant** | Pic de résonance définissant les voyelles |
| **Aliasing** | Artefact numérique par sous-échantillonnage |
| **Nyquist** | Fréquence maximale reproductible = taux_échantillonnage / 2 |
| **Pôle (filtre)** | Chaque pôle = 6 dB/oct de pente supplémentaire |
| **Opérateur (FM)** | Oscillateur + ampli + enveloppe dans la synthèse FM |
| **Algorithme (FM)** | Routage entre opérateurs |
| **Grain** | Micro-segment temporellement délimité |
| **VCO** | Voltage Controlled Oscillator — analogique |
| **VCF** | Voltage Controlled Filter — analogique |
| **VCA** | Voltage Controlled Amplifier — analogique |
| **LFO** | Low Frequency Oscillator < 20 Hz — modulateur |
| **CV/Gate** | Control Voltage / Gate — protocole pré-MIDI |
| **SysEx** | System Exclusive — messages MIDI spécifiques au fabricant |
| **Duty Cycle** | Rapport cyclique d'une onde rectangulaire |
| **Wavetable** | Table d'un cycle d'onde lu en boucle |
| **Time-stretch** | Modifier la durée sans modifier la hauteur |
| **Pitch-shift** | Modifier la hauteur sans modifier la durée |
| **Portamento** | Glissement progressif de fréquence entre deux notes |
| **Paraphonie** | Oscillateurs indépendants + chaîne de traitement partagée |
| **Multitimbralité** | Sons différents simultanément sur canaux MIDI distincts |

---

**← Précédent :** [[29 - Le Trautonium et le Thérémine]]  
**← Retour au début :** [[01 - Qu'est-ce que la synthèse sonore]]
