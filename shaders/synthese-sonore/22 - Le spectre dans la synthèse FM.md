# 22 — Le spectre dans la synthèse FM

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 22/30**
> **Tags :** #synthese-sonore #FM #spectre #Bessel #ESGI

---

## Le rapport C/M et le type de spectre

La nature du spectre FM dépend du **rapport entre les fréquences** de la porteuse (C) et du modulant (M) :

```
Rapport C/M = Fréquence Porteuse / Fréquence Modulante
```

| Rapport C/M | Type de spectre | Son |
|---|---|---|
| **Entier** (1:1, 1:2, 2:1…) | **Harmonique** → fréquences alignées sur la fondamentale | Musical, tonal |
| **Non-entier** (1:1.5, 2:3.1…) | **Inharmonique** → fréquences non alignées | Métallique, cloche, dissonant |

### Classification de Barry Truax

Le compositeur Barry Truax a classifié les rapports C/M en **familles sonores** pour faciliter la conception FM :
- Familles proches des entiers → sons musicaux
- Ratios éloignés des entiers → sons de percussion, de métal, de bois

---

## L'indice de modulation (I)

> "L'indice de modulation traduit le degré de modulation subie par la porteuse."

### Formule

```
I = D / M

où :
D = déviation de fréquence (profondeur maximale de la modulation)
M = fréquence du modulant
```

### Effet de I sur le spectre

| Valeur de I | Résultat sonore |
|---|---|
| **I ≈ 0** | Son proche d'une sinusoïde pure (la porteuse) |
| **I = 1** | Quelques harmoniques présentes |
| **I = 5** | Spectre très riche, nombreuses harmoniques |
| **I = 10+** | Spectre extrêmement dense, proche du bruit |

Plus I augmente → plus le spectre s'enrichit → la porteuse peut **disparaître complètement** au profit des harmoniques.

---

## Les bandes latérales (Sidebands)

La FM génère des **bandes latérales** de part et d'autre de la fréquence porteuse :

```
Porteuse seule : ─────────│─────────
                          C

Avec modulation :  │  │  │││  │  │
                 C-3M C-2M C-M C C+M C+2M C+3M
```

Chaque bande latérale = **C ± n×M** (n = entier)

Théoriquement, la FM génère un nombre **infini** de bandes latérales.  
En pratique, les bandes au-delà d'un certain rang ont une amplitude négligeable.

---

## Les fonctions de Bessel

> "L'amplitude de chaque fréquence au sein du signal FM est déterminée par des fonctions mathématiques dites de Bessel."

Les **fonctions de Bessel** (Jn(I)) sont des fonctions mathématiques spéciales qui déterminent l'amplitude de chaque bande latérale :

| n (rang) | Amplitude de la bande C ± n×M |
|---|---|
| 0 | J₀(I) = amplitude de la porteuse |
| 1 | J₁(I) = amplitude de C±M |
| 2 | J₂(I) = amplitude de C±2M |
| 3 | J₃(I) = amplitude de C±3M |

### Propriété importante : conservation de l'énergie

> "La puissance totale du signal FM reste constante quel que soit l'indice de modulation."

Quand I augmente :
1. L'amplitude de la porteuse **diminue**
2. L'énergie est redistribuée dans les **bandes latérales**
3. La somme des puissances reste constante

→ La FM ne crée pas d'énergie — elle la **redistribue** dans le spectre.

---

## La largeur de bande (Bandwidth)

> "La largeur de bande représente l'ensemble des fréquences que le signal comporte."

**Règle de Carson** (approximation) :

```
Bandwidth ≈ 2 × (D + M) = 2 × M × (I + 1)
```

Plus l'indice de modulation est élevé → plus la largeur de bande augmente → plus le son est riche.

---

## Récapitulatif des paramètres FM

| Paramètre | Effet |
|---|---|
| **Rapport C/M entier** | Spectre harmonique (tonal) |
| **Rapport C/M non-entier** | Spectre inharmonique (métallique) |
| **I faible** | Son pur, peu d'harmoniques |
| **I élevé** | Son riche, beaucoup d'harmoniques |
| **I très élevé** | Son bruité |
| **Feedback** | Distorsion de la porteuse sur elle-même |

---

## Exemples de sons FM célèbres

| Son | Paramètres approximatifs |
|---|---|
| Cloche électrique | C/M non-entier (1:1.4), enveloppe décroissante |
| Basse électrique | C/M = 1:1, I modéré, enveloppe percussive |
| Piano DX7 | C/M = 1:1, I décroissant (attaque brillante) |
| Marimba | C/M non-entier, enveloppe rapide |
| Trompette | C/M = 1:1 + harmoniques, I variable |

---

**← Précédent :** [[21 - La synthèse FM]]  
**→ Suite :** [[23 - La synthèse par modèle physique]]
