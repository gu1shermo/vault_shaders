# 11 — Présentation de la norme MIDI

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 11/30**
> **Tags :** #synthese-sonore #MIDI #ESGI

---

## Définition

**MIDI** = Musical Instruments Digital Interface

> "Protocole de communication entre instruments électroniques, effets et ordinateurs."

Le MIDI **ne transporte pas de signal audio**. Il transporte des **données de contrôle** : quelle touche est pressée, à quelle vitesse, sur quel canal, etc.

---

## Historique

- **1983** : norme MIDI créée sous l'impulsion d'Oberheim, Sequential Circuits et Roland
- Objectif : permettre à des instruments de marques différentes de communiquer entre eux
- Citation de William Buxton (1986) : "MIDI est un moyen de transmettre des informations sur les pressions de touches, les rotations de molettes et les manipulations de jeu."

---

## Ce que MIDI contrôle

| Ce que MIDI fait | Ce que MIDI ne fait PAS |
|---|---|
| Quelle touche est pressée | Transporter de l'audio |
| Vitesse d'enfoncement (velocity) | Définir le son lui-même |
| Pression après enfoncement (aftertouch) | Contrôler des paramètres non-MIDI |
| Valeurs de potentiomètres (CC) | Gérer la latence audio |
| Changements de preset | — |

---

## Architecture physique

### Connecteurs DIN

Le MIDI traditionnel utilise des connecteurs **DIN 5 broches** (Deutsche Industrie Norm).

Visuellement similaires aux anciens connecteurs audio, mais **incompatibles** avec eux.  
Transmission optique (opto-coupleur) pour isoler électriquement les appareils.

Trois types de prises :
| Prise | Rôle |
|---|---|
| **MIDI IN** | Reçoit les données MIDI entrantes |
| **MIDI OUT** | Envoie les données MIDI sortantes |
| **MIDI THRU** | Retransmet les données reçues sur IN (chaîne de devices) |

### MIDI via USB

La connexion USB remplace de plus en plus les connecteurs DIN traditionnels :
- Plus pratique (un seul câble pour données + alimentation)
- Permet l'identification automatique du périphérique
- Permet la transmission audio en parallèle
- **Inconvénient** : au-delà de 4–5 connexions USB simultanées, des instabilités peuvent apparaître — la fiabilité des DIN est supérieure

---

## Architecture des canaux MIDI

Le MIDI utilise **16 canaux par port** pour adresser différents instruments ou timbres.

```
Port A : canaux 1 à 16
Port B : canaux 1 à 16
Port C : canaux 1 à 16
...
```

Chaque canal peut contrôler un instrument ou un timbre indépendant.  
→ Base de la **multitimbralité** (voir chapitre 10).

### Convention MIDI standard

Le **canal 10** est traditionnellement réservé aux percussions (General MIDI).

---

## Résolution MIDI

La résolution standard MIDI = **7 bits** = 128 valeurs (0–127).

Utilisée pour : notes, velocity, control change, etc.

> **Limitation** : 128 degrés est insuffisant pour une reproduction précise de potentiomètres (un potentiomètre physique peut avoir des milliers de positions).

**Exceptions haute résolution** :
- **Pitch bend** : 14 bits → 16 384 valeurs
- **RPN/NRPN** : 14 bits → 16 384 valeurs

---

## Logiciels MIDI

| Type | Exemples |
|---|---|
| **Séquenceurs / DAWs** | Cubase, Logic Pro, Ableton Live, Pro Tools, Reaper |
| **Instruments virtuels** | Répondent aux commandes MIDI |
| **Panneaux de contrôle logiciels** | Gèrent les paramètres des appareils MIDI hardware |

---

## General MIDI (GM)

Apparu dans les années 90 avec les cartes son d'ordinateurs :
- Standardise l'**ordre des presets** pour compatibilité cross-appareils
- 128 sons standardisés dans un ordre défini (piano = 1, basse = 33, etc.)
- Largement utilisé pour les musiques de jeux vidéo des années 90

---

**← Précédent :** [[10 - Polyphonie, paraphonie et multitimbralité]]  
**→ Suite :** [[12 - Les différents types de messages MIDI]]
