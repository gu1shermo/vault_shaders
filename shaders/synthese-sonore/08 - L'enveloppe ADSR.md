# 08 — L'enveloppe ADSR

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 8/30**
> **Tags :** #synthese-sonore #ADSR #enveloppe #ESGI

---

## Qu'est-ce qu'une enveloppe ?

Une **enveloppe** définit l'**évolution d'un paramètre dans le temps**, typiquement l'amplitude du son (mais aussi la fréquence de coupure du filtre, la hauteur, etc.).

L'enveloppe la plus courante est l'**ADSR** : 4 paramètres qui décrivent la "forme" d'un son dans le temps.

---

## Les 4 étapes de l'ADSR

```
Amplitude
    ^
    |         SUSTAIN
    |    D   /‾‾‾‾‾‾‾‾‾\   R
    |   /‾\ /             \
    |  /   v               \
    | / A                   \
    |/                       \
    +------+--+-------+-------+----> Temps
           A  D       S       R
           |  |       |       |
           |  Decay   Sustain Release
           Attack
```

---

### A — Attack (Attaque)

> "Temps que le son met pour atteindre son niveau maximal depuis 0."

- Mesurée en **millisecondes (ms)** ou secondes
- **Attaque très courte** (< 10 ms) → son percussif, claquant, immédiat (piano, snare)
- **Attaque longue** (1–5 s) → son qui "gonfle" lentement, éthéré, pad (cordes, nappe)
- Influence fortement la perception du son : l'attaque est l'un des éléments clés par lesquels le cerveau identifie un instrument

### D — Decay (Déclin)

> "Temps pour descendre du niveau maximum après l'attaque vers le niveau de sustain."

- Mesurée en **millisecondes**
- Ajoute du **mouvement** et de la dynamique au son
- Decay long → le son "s'installe" progressivement après son pic
- Decay court → transition rapide vers le sustain

### S — Sustain

> "Niveau de volume auquel le son se maintient tant que la note est tenue."

- Exprimé en **niveau** (0–10 ou 0–100), **pas en temps**
- Le sustain dure tant que la touche reste enfoncée
- **Sustain = 0** → le son s'arrête au bout du decay (effet percussif même sur un son mélodique)
- **Sustain = max** → le son reste à pleine amplitude pendant toute la durée de la note

### R — Release (Relâchement)

> "Temps que le son met pour disparaître complètement après que la note est relâchée."

- Mesurée en **millisecondes** ou secondes
- Se déclenche **immédiatement** dès le relâché de la touche, même si A/D/S ne sont pas terminés
- **Release court** → son qui s'arrête brusquement (coupure nette)
- **Release long** → son qui "résonne" encore après le relâché (réverbération naturelle, cordes qui vibrent)

---

## Tableau récapitulatif

| Étape | Type de valeur | Court | Long |
|---|---|---|---|
| **Attack** | Temps (ms/s) | Son percussif | Son en fondu entrant |
| **Decay** | Temps (ms/s) | Transition rapide | Son qui "descend" lentement |
| **Sustain** | Niveau (0–100) | Effet percussif | Son tenu à pleine amplitude |
| **Release** | Temps (ms/s) | Coupure nette | Résonance après le relâché |

---

## Enveloppe sur l'amplificateur vs. sur le filtre

L'enveloppe peut contrôler différents paramètres :

### Enveloppe d'amplificateur (VCA)
- Contrôle le **volume** dans le temps
- Détermine si le son est percussif ou tenu

### Enveloppe de filtre (VCF)
- Contrôle la **fréquence de coupure** dans le temps
- Attaque brillante (filtre ouvert) puis son qui s'assombrit (filtre qui se ferme)
- Paramètre **"Filter Env Amount"** : intensité de l'effet de l'enveloppe sur le filtre

---

## Exemples sonores typiques

| Son | Attack | Decay | Sustain | Release |
|---|---|---|---|---|
| Piano | Court (10ms) | Moyen | 0 | Moyen |
| Violon legato | Long (300ms) | Court | 80% | Long |
| Snare | Très court | Court | 0 | Très court |
| Pad de cordes | Long (2s) | Moyen | 70% | Long (3s) |
| Basse synth | Court | Court | 100% | Court |

---

## Variantes avancées

| Variante | Description | Exemple d'instrument |
|---|---|---|
| **DAHDSR** | Ajoute un Delay (avant l'attaque) et un Hold (maintien post-attaque) | Moog Sub 37 |
| **Enveloppe 8 paramètres** | Multiple temps et niveaux | Yamaha DX7 |
| **Paramètre Hold** | La note peut être relâchée sans déclencher le Release | Instruments à vent synthétiques |
| **Enveloppe LFO** | L'enveloppe contrôle la profondeur d'un LFO | Nombreux synthès modernes |

---

**← Précédent :** [[07 - Les différents types de filtres]]  
**→ Suite :** [[09 - Polyphonie et monodie]]
