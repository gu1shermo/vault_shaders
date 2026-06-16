# 12 — Les différents types de messages MIDI

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 12/30**
> **Tags :** #synthese-sonore #MIDI #messages #ESGI

---

## Structure d'un message MIDI

Chaque message MIDI comprend :
- Un **octet de statut** : type du message + numéro de canal
- Un ou deux **octets de données** : valeurs du paramètre (0–127)

---

## Messages principaux

### 1. Note On / Note Off

- **Note On** : déclenche une note
  - Numéro de note : 0–127 (Do 0 = 0, La 4 = 69, Do central = 60)
  - Velocity : 0–127
  - Note On avec velocity 0 = équivalent de Note Off
- **Note Off** : relâche la note
  - Déclenche la phase Release de l'enveloppe
  - "Panic / All Notes Off" : bouton qui force l'arrêt de toutes les notes bloquées

---

### 2. Velocity

> "Vitesse à laquelle une touche passe de la position de repos à la position pressée."

- Plage : 0–127
- Velocity modérée : 60–70
- Velocity maximale : 127 (jeu fort)
- Velocity minimale : 1 (jeu pianissimo — 0 = Note Off)
- Applications : volume de la note, timbre (sons d'instruments qui changent selon la force du jeu), déclenchement de samples différents

**Release Velocity** : certains appareils reconnaissent aussi la vitesse de **relâchement** de la touche pour affecter la fin du son.

---

### 3. Program Change (PC)

- Change le preset/timbre sur l'instrument récepteur
- Plage : 0–127 (128 presets par banque)
- Utilisé en live pour changer de son entre deux morceaux

---

### 4. Bank Select

- Accède aux banques de presets supplémentaires (quand > 128 sons disponibles)
- Envoyé avant le Program Change
- Implémenté via Control Change 0 (MSB) et Control Change 32 (LSB)

---

### 5. Aftertouch

Modulation déclenchée par la **pression maintenue** sur la touche après l'enfoncement initial.

| Type | Description |
|---|---|
| **Channel Aftertouch** | Une valeur unique pour toutes les touches du canal → simpler hardware |
| **Polyphonic Aftertouch** | Valeur indépendante par touche → hardware complexe, très expressif |

Utilisations : vibrato automatique, variation de volume, ouverture du filtre selon la pression.

---

### 6. Control Change (CC)

> "Données de contrôle continu pour potentiomètres, faders, molettes."

- Plage : CC 0–127 (128 contrôleurs numérotés)
- Chaque CC peut être assigné à n'importe quel paramètre du synthétiseur
- Peut consommer beaucoup de **bande passante MIDI** si envoyé en continu → peut bloquer les messages de notes

**CCs importants standardisés :**

| CC | Fonction |
|---|---|
| 0 | Bank Select MSB |
| 1 | Modulation Wheel |
| 7 | Volume |
| 10 | Pan (gauche/droite) |
| 11 | Expression |
| 32 | Bank Select LSB |
| 64 | Sustain Pedal (on/off) |
| 121 | Reset All Controllers |
| 123 | All Notes Off |

---

### 7. Pitch Bend

> "Modifie la hauteur d'une note, typiquement via une molette dédiée."

- **Encodé sur 14 bits** → **16 384 valeurs** (au lieu de 128 pour les CC standard)
- Centre = 8192 (pas de pitch bend)
- Plage configurable : par défaut ±2 demi-tons (sur la plupart des synthés)
- Résolution bien supérieure aux CC standard → glissements de hauteur très fins

---

### 8. System Exclusive (SysEx)

- Messages spécifiques au **fabricant**
- Permettent :
  - Transfert de presets complets
  - Paramétrage fin d'un appareil
  - Implémentation de micro-accordages (gammes non tempérées)
- Format libre : chaque fabricant définit son propre protocole

---

## Extensions avancées

### RPN — Registered Parameter Numbers

5 paramètres standardisés avec résolution **14 bits** (16 384 valeurs) :

| RPN | Paramètre |
|---|---|
| 0 | Sensibilité du Pitch Bend |
| 1 | Accordage grossier (demi-tons) |
| 2 | Accordage fin (cents) |
| 3 | Profondeur de modulation |
| 4 | Reset |

### NRPN — Non-Registered Parameter Numbers

- Paramètres librement assignables par le fabricant
- Non standardisés — varie selon les appareils
- Résolution **14 bits**

---

## Modes MIDI

| Mode | Émission | Réception |
|---|---|---|
| **Omni** | 1 canal | Tous les canaux |
| **Poly** | 1 canal | 1 canal, polyphonique |
| **Mono** | 1 canal | 1 canal, monophonique |
| **Multi** | Multiples canaux | Multiples canaux (multitimbral) |

---

## MIDI Clock et Transport (Sync)

- **MIDI Clock** : synchronise plusieurs appareils MIDI → 24 impulsions par noire
- **MMC** (MIDI Machine Control, 1992) : commandes Start, Stop, Continue, Locate pour contrôle de transport

---

**← Précédent :** [[11 - Présentation de la norme MIDI]]  
**→ Suite :** [[13 - Pitch bend, unisson, portamento et vibrato]]
