# 05 — Les différents types de bruits

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 5/30**
> **Tags :** #synthese-sonore #bruit #ESGI

---

## Qu'est-ce qu'un bruit en synthèse ?

En synthèse sonore, le **bruit** désigne un signal **apériodique** : sans fréquence fondamentale définie, sans structure répétitive.

Contrairement aux formes d'ondes périodiques (sinus, dents de scie…), le bruit contient des composantes fréquentielles **aléatoires** ou **pseudo-aléatoires**.

> Les bruits sont classés par "couleurs" selon leur densité spectrale de puissance.

---

## 1. Le Bruit Blanc

> "La somme de toutes les fréquences sonores à puissance égale."

- Contient **toutes les fréquences** de la plage audible (20 Hz – 20 kHz) à **puissance identique**
- Équivalent acoustique d'une lumière blanche (toutes les longueurs d'onde lumineuses)
- Son : signal dense, sifflant, comme un téléviseur sans signal ou le souffle du vent fort
- **Usage en synthèse** : vent, vagues, percussions (hi-hat, snare), textures sonores

```
Puissance
   |████████████████████████████
   |████████████████████████████
   +-----------------------------> Fréquence
   20Hz                    20kHz
```

---

## 2. Le Bruit Rose

> "Bruit blanc dont la puissance sonore s'abaisse de 3 dB à chaque octave."

- La puissance diminue de **3 dB par octave** en montant vers les aigus
- Cela crée une répartition d'énergie **homogène par octave** (chaque octave reçoit la même énergie totale)
- Son : plus chaud que le bruit blanc, moins sifflant
- **Usage** : principalement pour **calibrer et tester** des systèmes de diffusion audio — rarement utilisé en synthèse musicale créative

```
Puissance
   |███
   |   ████
   |       █████
   |            ██████
   +-----------------------------> Fréquence
   20Hz                    20kHz
```

---

## 3. Le Bruit Brun / Rouge (Brownien)

> "Inspiré du mouvement brownien découvert par Robert Brown en 1827."

**Origine du nom** : Le botaniste Robert Brown observa en 1827 que des particules de pollen en suspension dans l'eau étaient soumises à une **agitation continuelle** et aléatoire due aux chocs des molécules d'eau — c'est le **mouvement brownien**.

- La puissance diminue de **6 dB par octave** (deux fois plus rapide que le rose)
- Fortement chargé en **basses fréquences**
- Son : sourd, grave, comme un grondement lointain ou un vent puissant en basse
- **Usage** : sons graves amorphes, textures profondes

```
Puissance
   |████████
   |        ████
   |            ████
   |                ████
   +-----------------------------> Fréquence
   20Hz                    20kHz
```

---

## Tableau comparatif

| Couleur | Décroissance | Caracteristique | Usage |
|---|---|---|---|
| **Blanc** | Aucune (plat) | Toutes fréquences à égale puissance | Percussions, vent, synthèse |
| **Rose** | −3 dB/octave | Énergie égale par octave | Calibration audio |
| **Brun / Rouge** | −6 dB/octave | Dominance grave | Textures profondes |

---

## Autres couleurs

D'autres bruits existent théoriquement :
- **Bruit bleu** : +3 dB/octave (plus de hautes fréquences)
- **Bruit violet** : +6 dB/octave
- **Bruit gris** : spectre adapté à la courbe de Fletcher-Munson (audition humaine)

> Ces couleurs sont "quasiment jamais" rencontrées en synthèse sonore pratique.

---

## Générateurs de bruit dans les synthétiseurs

La plupart des synthétiseurs analogiques incluent un **générateur de bruit blanc** dans leur architecture.  
Ce bruit peut ensuite être :
- Filtré (→ bruit coloré)
- Enveloppé (→ sons percussifs)
- Modulé (→ textures animées)

**Exemple d'usage** : sur un Minimoog, le générateur de bruit est mixé avec les oscillateurs pour ajouter du "grain" au son.

---

**← Précédent :** [[04 - Les différentes formes d'ondes]]  
**→ Suite :** [[06 - Les différents types d'oscillateurs]]
