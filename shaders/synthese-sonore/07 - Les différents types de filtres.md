# 07 — Les différents types de filtres

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 7/30**
> **Tags :** #synthese-sonore #filtres #VCF #ESGI

---

## Rôle du filtre en synthèse

Le filtre est le **sculpteur de timbre** dans la chaîne de synthèse. Il atténue sélectivement certaines fréquences pour façonner le spectre harmonique d'un son.

En synthèse soustractive, le filtre est l'**élément central** de la chaîne de traitement.

---

## Paramètres communs à tous les filtres

### 1. Fréquence de coupure (Cutoff)

Point à partir duquel les fréquences commencent à être atténuées.  
Contrôlée par un potentiomètre → change en temps réel ou via enveloppe.

### 2. Pente (Slope)

Vitesse d'atténuation exprimée en **dB/octave**.

> "Un filtre à 12 dB/octave appliquera une atténuation deux fois supérieure à un filtre à 6 dB/octave."

La pente est définie par le nombre de **pôles** :

| Pôles | Pente | Caractère |
|---|---|---|
| 1 pôle | 6 dB/oct | Doux |
| 2 pôles | 12 dB/oct | Moyen |
| 3 pôles | 18 dB/oct | Intermédiaire |
| **4 pôles** | **24 dB/oct** | Puissant — standard Moog |

> Le filtre **Moog 4 pôles** (24 dB/octave) est considéré comme la **référence industrielle**.

### 3. Résonance (Q / Resonance)

Accentue les fréquences proches de la fréquence de coupure.

- Résonance faible → filtrage doux
- Résonance forte → pic prononcé à la coupure, son sifflant caractéristique
- Résonance maximale → le filtre entre en **auto-oscillation** et génère une sinusoïde pure (la coupure devient une fréquence musicale)

---

## Les 4 types de filtres

### 1. Filtre Passe-Bas (Low-Pass Filter — LPF)

> "Destiné à ne laisser intactes que les fréquences situées en dessous de sa fréquence de coupure."

```
Amplitude
    |████████████\
    |            \\
    |              \
    +-----|----------\-----> Fréquence
         fc (coupure)
```

- **Laisse passer** : fréquences < coupure
- **Atténue** : fréquences > coupure
- Appelé aussi **coupe-haut** ou high-cut
- **Le plus utilisé en synthèse sonore** — crée des sons sombres, chauds, sourds
- Usages : bass lines, pads sombres, simulation de la distance (les aigus disparaissent)

### 2. Filtre Passe-Haut (High-Pass Filter — HPF)

> "Laisse intactes les fréquences au-dessus de sa fréquence de coupure."

```
Amplitude
    |            /████████
    |           /
    |          /
    +----------/-----------> Fréquence
              fc
```

- **Laisse passer** : fréquences > coupure
- **Atténue** : fréquences < coupure
- Appelé aussi **coupe-bas** ou low-cut
- Usages : éliminer les bourdonnements graves, créer des sons aériens et fins, effet de radio

### 3. Filtre Passe-Bande (Band-Pass Filter — BPF)

> "Combine un passe-haut et un passe-bas pour isoler une plage de fréquences entre deux limites."

```
Amplitude
    |        /\
    |       /  \
    |      /    \
    +-----/------\---------> Fréquence
         fc1    fc2
```

- **2 fréquences de coupure** : une basse et une haute
- **Laisse passer** : la plage entre fc1 et fc2
- **Atténue** : tout le reste
- Usages : effet téléphone, effet radio, isoler une fréquence médiane

### 4. Filtre Coupe-Bande / Notch Filter

> "Atténue une plage de fréquences entre deux limites tout en conservant le reste."

```
Amplitude
    |████████\    /████████
    |         \  /
    |          \/
    +----------\/----------> Fréquence
               fc
```

- Inverse du passe-bande
- **Laisse passer** : tout sauf une plage
- **Atténue** : la plage définie
- Usages : supprimer un larsen, éliminer un bourdonnement électrique, créer des creux tonaux

---

## Filtres contrôlés par tension : le VCF

Dans les synthétiseurs analogiques, le filtre est souvent un **VCF** (Voltage Controlled Filter) :
- Sa fréquence de coupure est contrôlée par une **tension électrique**
- Peut être piloté par l'enveloppe ADSR → la brillance évolue dans le temps
- Peut être piloté par un LFO → filtre animé en rythme
- Peut être piloté par le **keyboard tracking** (voir chapitre 13) → la coupure suit la note jouée

---

## Application : le filtre dans la synthèse soustractive

La chaîne standard :
```
[Oscillateur riche] → [VCF] → [VCA]
                         ↑
                    [Enveloppe de filtre]
```

1. L'oscillateur génère une dents de scie (riche en harmoniques)
2. Le filtre passe-bas coupe les aigus → son plus chaud et sombre
3. L'enveloppe de filtre fait varier la coupure → le timbre "évolue" (attaque brillante, corps sombre)

---

**← Précédent :** [[06 - Les différents types d'oscillateurs]]  
**→ Suite :** [[08 - L'enveloppe ADSR]]
