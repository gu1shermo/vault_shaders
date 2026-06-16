# 25 — Synthèse pulsar et distorsion de phase

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 25/30**
> **Tags :** #synthese-sonore #pulsar #distorsion-de-phase #Casio #ESGI

---

## 1. Synthèse Pulsar

> "Une forme particulière de synthèse granulaire, théorisée par Curtis Roads."

### Principe

La synthèse pulsar utilise des unités minimales appelées **pulsarettes** :

```
Pulsarette = [Forme d'onde] + [Durée de silence]
              (partie sonore)   (partie silencieuse)
```

La période totale reste constante, mais le rapport entre partie sonore et partie silencieuse peut varier.

### Mécanisme

En faisant varier la **durée de la forme d'onde** sans changer la **période totale** :
- On simule l'effet d'un **filtre résonant** (comme une synthèse par formants)
- On peut effectuer des **glissandos** en temps réel entre valeurs musicales traditionnelles

```
Période fixe T :

[onde courte] [──silence long──]  → son avec harmoniques aiguës
[──onde longue──] [silence court] → son avec harmoniques graves
```

### Contexte théorique

Curtis Roads a théorisé la synthèse pulsar dans son ouvrage "Microsound" (2001).  
Lien fort avec la bioacoustique (battements de cœur, signaux neuronaux) et l'astrophysique (pulsars).

**Implémentations** : essentiellement académiques — très peu de produits commerciaux.

---

## 2. Synthèse par Distorsion de Phase

> "Développée par Casio et implémentée dans les synthétiseurs de la série CZ."

### Principe

La distorsion de phase opère via une **"fonction de phase"** non-linéaire qui déforme la lecture d'une table d'ondes :

```
Lecture normale d'un cycle (linéaire) :
Position 0% → 100% à vitesse constante
→ Sinusoïde pure

Lecture avec fonction de phase (non-linéaire) :
Position 0% → 50% très rapidement, puis 50% → 100% lentement
→ Forme d'onde déformée = harmoniques générées
```

### Analogie avec la FM

La distorsion de phase est conceptuellement proche de la FM, avec une différence clé :
- En FM : le modulant est une **sinusoïde**
- En distorsion de phase : la fonction modulante peut être **n'importe quelle forme** — mais elle doit être à la même fréquence que la porteuse

### Avantages vs. FM

| Aspect | FM | Distorsion de phase |
|---|---|---|
| Rapport C/M | Variable | Toujours 1:1 (même fréquence) |
| Fonction modulante | Sinusoïde | Formes variées |
| Intuitivité | Complexe | Plus accessible |
| Résultat sonore | Très riche | Riche, différent |

### Instruments Casio CZ

La série **Casio CZ** (CZ-101, CZ-1000, CZ-3000, CZ-5000) — années 80 :
- Son caractéristique "plastique" mais expressif
- Bien moins cher que les DX7 de Yamaha → démocratisation
- 8 lignes par oscillateur (deux oscillateurs par voix)
- Enveloppes à 8 points

---

## Comparaison générale

| Technique | Principe | Spectre | Instruments |
|---|---|---|---|
| **Synthèse pulsar** | Grains avec ratio silence | Contrôlé par timing | Académique |
| **Distorsion de phase** | Lecture non-linéaire de wavetable | FM-like mais différent | Casio CZ |

---

**← Précédent :** [[24 - Applications de la synthèse par modèle physique]]  
**→ Suite :** [[26 - Synthèse formantique et arithmétique linéaire]]
