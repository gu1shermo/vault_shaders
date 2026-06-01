# 18 — Les tables d'ondes (Wavetable)

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 18/30**
> **Tags :** #synthese-sonore #wavetable #tables-d-ondes #ESGI

---

## Principe fondamental

> "La synthèse wavetable calcule les valeurs d'échantillons pour un seul cycle d'onde, les stocke, puis relit en boucle pour reconstituer le son."

### Observation clé

Une forme d'onde **périodique** est par nature **répétitive** : le cycle 1 est identique au cycle 2, 3, 4…  
→ **Inutile de recalculer ou stocker tous les cycles** — un seul suffit.

```
Son réel (1 seconde à 440 Hz) :
[cycle 1][cycle 2][cycle 3]...[cycle 440]
         = identiques
         
Wavetable (1 cycle stocké) :
[cycle 1] → relecture en boucle 440 fois/seconde
```

---

## Structure d'une table d'ondes

Une table d'ondes est un **tableau de valeurs** :
- Chaque **case** = un échantillon (valeur d'amplitude à un instant précis)
- La lecture **séquentielle** des cases reconstitue un cycle complet
- La relecture en boucle reconstitue le son continu

```
Table : [v1][v2][v3]...[v128]
         ↓   ↓   ↓      ↓
         Lecture cyclique → onde continue
```

---

## Contrôle de la hauteur

La hauteur (fréquence) est contrôlée par la **vitesse de lecture** :

| Vitesse de lecture | Effet sur la fréquence |
|---|---|
| Lecture rapide (moins de cases/seconde) | Fréquence plus haute → son plus aigu |
| Lecture lente (plus de cases/seconde) | Fréquence plus basse → son plus grave |

```
Table de 256 cases, lue à 44100 Hz standard :
- Pour La 440 Hz : lire 256 cases × 440 = 112 640 cases/seconde
  → lecture accélérée = hauteur plus haute
```

---

## Tables d'ondes multiples et morphing

Un synthétiseur wavetable peut contenir **plusieurs tables d'ondes différentes** :

```
Table 1 (dents de scie)
Table 2 (carrée)
Table 3 (forme complexe)
Table 4 (forme harmonique riche)
```

Un paramètre de **morphing** permet de **passer fluidement** d'une table à l'autre :
- Transition sonore intéressante, impossible avec une forme d'onde statique
- Permet de créer des sons **évolutifs** dans le temps
- Le timbre change progressivement → son "animé" sans LFO ni enveloppe de filtre

---

## Avantages vs. synthèse traditionnelle

| Aspect | Synthèse traditionnelle | Wavetable |
|---|---|---|
| Calcul en temps réel | Oui | Non (déjà calculé) |
| Efficacité CPU | Plus coûteuse | Très efficace |
| Formes d'ondes | Limitées (sinus, carrée...) | Infinies (formes complexes stockées) |
| Évolution du timbre | Via filtre/LFO | Via morphing de tables |

---

## Instruments et logiciels historiques

### PPG Wave 2 (Wolfgang Palm, 1980)

- **Pionnier** de la synthèse wavetable commerciale
- Utilise des "Wavecomputers" avec mémoire de tables d'ondes
- Son caractéristique : métallique et cristallin
- Utilisé par Peter Gabriel, Depeche Mode, Klaus Schulze

### Waldorf Microwave (1990) et Wave

- Suite logique du PPG, par les anciens ingénieurs
- Microwave (1990) : version rack, très populaire en studio
- Possibilités de morphing avancées

### Instruments modernes

| Instrument | Type |
|---|---|
| Serum (Xfer Records) | Logiciel — wavetable ultime, très populaire |
| Massive X (Native Instruments) | Logiciel — wavetable + modulation |
| Absynth (Native Instruments) | Logiciel — wavetable + granulaire |
| PPG Wave 3.V (Waldorf) | Plugin émulation du PPG Wave |

---

## Différence avec le sampler

| Wavetable | Sampler |
|---|---|
| Stocke **1 cycle** d'onde | Stocke un **son entier** (plusieurs secondes) |
| Mémoire minimale | Mémoire importante nécessaire |
| Son synthétisé, géométrique | Son réaliste (enregistrement d'instruments) |
| Hauteur par vitesse de lecture | Hauteur par transposition / vitesse |

---

**← Précédent :** [[17 - L'échantillonnage]]  
**→ Suite :** [[19 - Présentation de la synthèse granulaire]]
