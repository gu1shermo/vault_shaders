# 04 — Les différentes formes d'ondes

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 4/30**
> **Tags :** #synthese-sonore #formes-d-ondes #oscillateurs #ESGI

---

## Pourquoi les formes d'ondes ?

Les formes d'ondes sont les **matières premières** de la synthèse sonore. Chaque forme produit un contenu harmonique différent, ce qui détermine le timbre de départ avant tout traitement.

---

## 1. La Sinusoïde (Sinus)

```
    /\      /\
   /  \    /  \
--/    \--/    \-->
         \/    \/
```

- **Contenu harmonique** : fondamentale **uniquement**, zéro harmonique
- **Timbre** : son le plus pur, le plus "pauvre" harmoniquement
- **Usage** : base mathématique de toutes les autres ondes (Fourier), sons de flûte, test acoustique
- Toutes les autres formes d'ondes peuvent être **construites** à partir de sinusoïdes additionnées (synthèse additive)

---

## 2. L'Onde Carrée (Square Wave)

```
    ___     ___
   |   |   |   |
---|   |---|   |-->
           |   |
           |___|
```

- **Contenu harmonique** : fondamentale + **harmoniques impairs** (3e, 5e, 7e, 9e…)
- **Décroissance** : puissance ∝ **1/f** (le 3e harmonique a 1/3 de la puissance, le 5e a 1/5…)
- **Symétrie** : passe **50% du temps** au-dessus et 50% en dessous du point d'équilibre
- **Timbre** : son creux, nasal, caractéristique des synthétiseurs vintage
- **Variante asymétrique** : appelée **onde rectangulaire**

---

## 3. L'Onde d'Impulsion / Rectangulaire (Pulse Wave)

```
    _         _
   | |       | |
---| |-------| |-->
    |_______| |___
```

- **Contenu harmonique** : harmoniques impairs (comme la carrée, mais asymétrique)
- **Paramètre clé : Rapport cyclique (Duty Cycle)**
  - = fraction de temps que l'onde passe à l'état **haut** sur un cycle complet
  - 50% → onde carrée
  - 25% → onde plus étroite, son plus aigu et claquant
  - 75% → son différent des 25% malgré une forme miroir (phase inversée)
- **MLI / PWM (Pulse Width Modulation)** : variation du rapport cyclique pour modifier le contenu harmonique sans changer la fréquence → effets sonores très expressifs
- En modulant le duty cycle avec un LFO → son "animé", effet de chorus organique

---

## 4. L'Onde Triangulaire (Triangle)

```
    /\      /\
   /  \    /  \
--/    \--/    \-->
        \/      \/
```

- **Contenu harmonique** : fondamentale + **harmoniques impairs**
- **Décroissance** : puissance ∝ **1/f²** (plus rapide que la carrée)
  - Le 3e harmonique a 1/9 de la puissance (au lieu de 1/3 pour la carrée)
- **Timbre** : plus douce que la carrée, proche du son de flûte douce ou de clarinette
- Peut être **symétrique** ou **asymétrique** (en modifiant les pentes montante et descendante)

---

## 5. L'Onde en Dents de Scie (Sawtooth)

```
    /|    /|
   / |   / |
--/  |--/  |-->
     |      |
```

- **Contenu harmonique** : **TOUS les harmoniques** (pairs et impairs)
- C'est la forme d'onde **la plus riche harmoniquement**
- **Variantes** :
  - Rampe montante progressive + chute abrupte (sawtooth "classique")
  - Montée instantanée + descente progressive (dents de scie inversée)
- **Timbre** : brillant, agressif, riche — idéal pour la synthèse soustractive car il offre le maximum de matière à sculpter
- Sonne comme les cordes de synthétiseurs, les cuivres de synthèse

> "La plus riche en harmoniques et la plus intéressante pour la synthèse soustractive."

---

## 6. Le Grain (numérique uniquement)

- Source sonore **exclusivement numérique** (impossible en analogique)
- Composants : forme d'onde + point de départ + durée + enveloppe
- Contient des informations fréquentielles (période + spectre)
- Peut utiliser des formes d'ondes synthétiques **ou** des échantillons
- Stockées en **tables d'ondes** (tableaux 2D avec coordonnées X/Y)
- Base de la **synthèse granulaire** (chapitres 19-20)

---

## Tableau comparatif

| Forme d'onde | Harmoniques | Décroissance | Richesse | Usage principal |
|---|---|---|---|---|
| **Sinusoïde** | Aucun | — | Minimale | Sons purs, test |
| **Carrée** | Impairs | 1/f | Moyenne | Sons creux, vintage |
| **Rectangulaire** | Impairs (asym.) | 1/f variable | Variable | PWM, textures |
| **Triangulaire** | Impairs | 1/f² | Faible-moyenne | Sons doux |
| **Dents de scie** | Tous | Linéaire | Maximale | Soustractive, cordes |

---

## Application en synthèse soustractive

La **dents de scie** est la forme d'onde de référence en synthèse soustractive car :
1. Elle contient tous les harmoniques → le filtre a le maximum de matière à sculpter
2. Sa richesse harmonique permet de reproduire cordes, cuivres, voix
3. La **carrée** est utilisée pour les sons creux et nasaux (clarinette, bois)

---

**← Précédent :** [[03 - Les fréquences dans les ondes sonores]]  
**→ Suite :** [[05 - Les différents types de bruits]]
