# 17 — L'échantillonnage

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 17/30**
> **Tags :** #synthese-sonore #echantillonnage #sampling #Nyquist #ESGI

---

## Définition

> "L'échantillonnage est le fait d'enregistrer de manière numérique un signal analogique, via un convertisseur analogique-numérique (CAN)."

### Analogique vs. Numérique

| Analogique | Numérique |
|---|---|
| Signal continu (infiniment divisible) | Signal discret (instants précis) |
| Enregistré comme variation continue | Prélève des mesures à intervalles réguliers |
| Exemple : sillon de disque vinyle | Exemple : fichier WAV, AIFF |

---

## Taux d'échantillonnage (Sample Rate)

Le **taux d'échantillonnage** = nombre de mesures (échantillons) prélevées par seconde.

| Taux | Usage |
|---|---|
| **44 100 Hz** (44,1 kHz) | Standard CD, production musicale |
| **48 000 Hz** (48 kHz) | Vidéo, broadcast (cinéma, TV) |
| **88 200 / 96 000 Hz** | Haute résolution, mastering |
| **192 000 Hz** | Ultra-haute résolution |

> Le CD utilise **44 100 Hz codé sur 16 bits** : 44 100 échantillons par seconde, chaque valeur sur 16 bits.

---

## Résolution en bits (Bit Depth)

Le **nombre de bits** détermine la **plage dynamique** (différence entre le son le plus faible et le plus fort) :

| Résolution | Plage dynamique | Usage |
|---|---|---|
| **8 bits** | ~48 dB | Téléphonie, anciens jeux vidéo |
| **16 bits** | ~96 dB | CD standard |
| **24 bits** | ~144 dB | Studio, production professionnelle |
| **32 bits float** | Illimité théoriquement | Traitement interne des DAWs |

---

## Le théorème de Nyquist-Shannon

> "Il faut au moins 2 échantillons par cycle d'une forme d'onde pour la reproduire correctement."

### Démonstration

Pour reproduire une fréquence F, il faut un taux d'échantillonnage d'**au moins 2×F** :

```
Fréquence à reproduire : 20 000 Hz (limite auditive)
Taux minimum requis   : 2 × 20 000 = 40 000 Hz
Taux CD               : 44 100 Hz → marge de sécurité
```

### Fréquence de Nyquist

La **fréquence de Nyquist** = moitié du taux d'échantillonnage.

```
Taux = 44 100 Hz → Fréquence de Nyquist = 22 050 Hz
```

→ Toute fréquence au-dessus de la Nyquist ne peut pas être correctement représentée.

---

## L'aliasing (Repli de fréquences)

Quand une fréquence **dépasse** la fréquence de Nyquist, elle se reproduit à une **fréquence parasite plus basse** dans le signal numérique.

### Exemple concret

```
Taux d'échantillonnage : 44 100 Hz
Fréquence de Nyquist  : 22 050 Hz

Fréquence d'un harmonique : 37 500 Hz
→ Repli : 44 100 - 37 500 = 6 600 Hz parasite
```

Ce 6 600 Hz est une fréquence **artefactuelle** qui pollue le signal — c'est l'**aliasing**.

### Solution : Filtre anti-repliement (anti-aliasing)

Un **filtre passe-bas** est appliqué lors de l'enregistrement pour couper toutes les fréquences **au-dessus de la Nyquist** avant la conversion :

```
Signal analogique → [Filtre anti-aliasing] → [CAN] → Signal numérique
```

Un **filtre de lissage** (reconstruction) est appliqué lors de la lecture pour reconstituer la courbe continue.

---

## Le processus complet d'enregistrement/lecture

```
ENREGISTREMENT :
Microphone → signal analogique
→ Filtre anti-aliasing (coupe > 22 kHz)
→ CAN (Convertisseur Analogique-Numérique)
→ Stockage en mémoire/disque (valeurs numériques)

LECTURE :
Stockage → CNA (Convertisseur Numérique-Analogique)
→ Filtre de reconstruction (lissage)
→ Signal analogique
→ Amplificateur → haut-parleurs
```

---

## Application en synthèse : le sampler

Le **sampler** est un instrument qui enregistre des sons réels (échantillons) et les relit musicalement :

- Chaque note du clavier **transpose** l'échantillon en changeant la vitesse de lecture
- Techniques : **looping** (mise en boucle de la partie stable du son pour le tenir indéfiniment)
- Les samplers historiques (Fairlight CMI, E-mu Emulator, Akai MPC) ont révolutionné la musique des années 80

---

**← Précédent :** [[16 - La synthèse additive]]  
**→ Suite :** [[18 - Les tables d'ondes (Wavetable)]]
