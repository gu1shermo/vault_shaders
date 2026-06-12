# 19 — Présentation de la synthèse granulaire

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 19/30**
> **Tags :** #synthese-sonore #granulaire #grains #ESGI

---

## Concept de base

La synthèse granulaire utilise le **grain** comme unité sonore fondamentale.

Un **grain** est un micro-segment sonore :
- Délimité dans le temps (début et fin définis)
- Contient une forme d'onde + une enveloppe modulante
- Durée typique : entre **1 ms et 100 ms**

---

## Pourquoi les grains ? La limite de Fourier

La **théorie de Fourier** (fondement de la synthèse additive) a une limitation majeure :

> "Fourier ne peut pas déterminer la **localisation temporelle** des composantes harmoniques d'un signal."

**Exemple concret :**
- Accord de Do-Mi-Sol joué simultanément
- Arpège Do-Mi-Sol joué consécutivement
→ Fourier analyse les **mêmes fréquences** dans les deux cas — il ne peut pas les distinguer car ses sinusoïdes sont de **durée infinie**.

### Solution apportée par les grains

Les grains ont une **durée finie** → ils permettent de localiser précisément les événements sonores dans le temps ET en fréquence.

```
Fourier : fréquence ✓ | position dans le temps ✗
Grain   : fréquence ✓ | position dans le temps ✓
```

---

## Historique

| Date | Événement |
|---|---|
| **1925** | Norbert Wiener propose théoriquement d'appliquer les "grains d'énergie" de la physique quantique au son |
| **1947** | Dennis Gabor théorise le concept : "quantum acoustique" |
| **1978** | Curtis Roads implémente les premiers éléments logiciels |
| **1980** | Martin Bastiaans valide complètement la théorie |

**Ambassadeurs artistiques principaux :** Iannis Xenakis, Barry Truax, Curtis Roads

---

## Caractéristiques d'un grain

### Paramètres fondamentaux

| Paramètre | Description |
|---|---|
| **Point de départ** | Position temporelle précise dans le signal source |
| **Durée** | Longueur du grain (1–100 ms) |
| **Enveloppe** | Forme de l'amplitude du grain (gaussienne, trapèze, etc.) |
| **Fréquence/Hauteur** | Contenu fréquentiel propre au grain |
| **Phase** | Position initiale de la forme d'onde dans le grain |
| **Panoramique** | Localisation spatiale gauche/droite |

### La durée du grain et la perception

```
Grain très court (< 10 ms) :
→ L'oreille ne perçoit pas de hauteur définie
→ Seulement un "clic" ou une texture

Grain court (10–50 ms) :
→ Début de perception de la hauteur

Grain long (50–100 ms) :
→ Hauteur clairement perçue
→ Meilleur contenu harmonique
```

> **Règle pratique :** au-dessous de ~100 ms, l'oreille a du mal à évaluer précisément la hauteur d'un grain.

---

## Espacement des grains et perception

L'espacement entre les grains détermine une caractéristique perceptuelle :

| Espacement | Effet perçu |
|---|---|
| Grains très proches (haute densité) | Son continu, tenu → **hauteur perçue** |
| Grains espacés (basse densité) | Effets rythmiques, discontinus |

### La hauteur globale dépend de deux facteurs :
1. La **longueur** des grains (contenu fréquentiel interne)
2. La **densité** de déclenchement (fréquence à laquelle les grains s'enchaînent)

---

## Sources de grains

Un grain peut contenir n'importe quelle forme d'onde :
- Sinusoïde simple
- Forme synthétique (carré, dents de scie)
- Résultat de synthèse FM
- **Échantillon audio** (extrait d'un son enregistré)

→ La synthèse granulaire appliquée à des sons réels permet de les **décomposer et reconstruire** de manière créative.

---

## Types d'enveloppes de grain

L'enveloppe module l'amplitude du grain pour éviter les "clics" aux transitions :

```
Gaussienne :          Trapèze :          Triangle :
    /\                 ____                /\
   /  \               /    \              /  \
  /    \             /      \            /    \
 /      \           /        \          /      \
```

L'enveloppe **gaussienne** est la plus utilisée car elle produit le moins d'artefacts spectraux.

---

**← Précédent :** [[18 - Les tables d'ondes (Wavetable)]]  
**→ Suite :** [[20 - Les formes de synthèse granulaire]]
