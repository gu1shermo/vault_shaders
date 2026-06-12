# 27 — Synthèse stochastique et synthèse graphique

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 27/30**
> **Tags :** #synthese-sonore #stochastique #graphique #Xenakis #ESGI

---

## 1. Synthèse Stochastique

### Principe

La synthèse stochastique modélise des sons **sans structure périodique reconnaissable** — essentiellement des formes de bruit — en utilisant des **processus aléatoires contrôlés** (stochastiques).

### La limite de l'aléatoire en informatique

> "Il n'y a rien d'aléatoire dans l'informatique."

Les ordinateurs génèrent des séquences **pseudo-aléatoires** — des suites de nombres qui semblent aléatoires mais suivent en réalité un algorithme déterministe et se répètent éventuellement (période du générateur pseudo-aléatoire).

→ La synthèse stochastique utilise ces pseudo-aléas comme source de variation contrôlée.

---

### Iannis Xenakis et le système GenDy

**Iannis Xenakis** (1922–2001) — compositeur grec-français, un des pionniers de la musique algorithmique et stochastique.

**Système GenDy** (Dynamic Stochastic Synthesis) :
- Crée des formes d'ondes à partir de **points calculés par des distributions de probabilité**
- Ces points sont reliés par des segments → construction d'une forme d'onde
- À chaque nouveau cycle, les positions des points sont modifiées selon les probabilités définies → la forme d'onde évolue continuellement

```
Cycle 1 : /‾\_/‾‾‾\__
Cycle 2 : /‾‾\/\_/‾\
Cycle 3 : __/‾\__/‾‾
→ Évolution continue et imprévisible mais contrôlée
```

**Paramètres statistiques contrôlables :**
- Distribution de probabilité des variations de position
- Distribution de probabilité des variations d'amplitude
- Nombre de points de contrôle par cycle

---

### Applications de la synthèse stochastique

Utilisée principalement dans la musique **contemporaine académique** et **expérimentale** :
- Textures évolutives et imprévisibles
- Simulations de bruits naturels complexes
- Ambiances sonores organiques

---

## 2. Synthèse Graphique

### Principe

> "Convertit des données visuelles en audio via un traitement numérique."

L'utilisateur **dessine** directement des informations qui sont interprétées comme du son :
- Un dessin d'arc → une note ou une trajectoire fréquentielle
- Un tracé dans le temps → une ligne mélodique
- Une image bitmap → un spectre sonore

---

### Historique

**1925** : premières notations sonores photographiques → brevet déposé.  
Les inventeurs de l'époque expérimentaient avec la photo-électricité pour créer du son à partir de formes imprimées sur film.

**Années 50-60** : générateurs photo-électriques expérimentaux.

---

### Le système UPIC (Xenakis, 1977)

**UPIC** = Unité Polyagogique Informatique du CEMAMu (Centre d'Études de Mathématique et Automatique Musicales, Paris)

Fonctionnement :
1. L'utilisateur dessine des **arcs** sur une tablette graphique
2. L'axe **horizontal** = temps
3. L'axe **vertical** = fréquence
4. La **courbure** et **épaisseur** de l'arc = timbre et amplitude

→ La composition musicale devient un acte de **dessin**.

Utilisé par Xenakis lui-même dans ses œuvres, et par des compositeurs invités à l'IRCAM.

---

### Instruments modernes : Harmor (Image Line)

**Harmor** (Image Line, 2011) — synthétiseur plug-in :
- Synthèse additive + import d'images
- Importer une image = générer un spectre sonore basé sur les niveaux de gris
- Manipulation des partials visuellement
- Pont entre synthèse graphique et synthèse additive moderne

---

## Tableau comparatif

| Synthèse | Méthode | Personnage clé | Usage |
|---|---|---|---|
| **Stochastique** | Processus aléatoires contrôlés | Iannis Xenakis | Textures, musique contemporaine |
| **Graphique** | Conversion visuel → audio | Iannis Xenakis (UPIC) | Composition graphique |

---

**← Précédent :** [[26 - Synthèse formantique et arithmétique linéaire]]  
**→ Suite :** [[28 - Les Ondes Martenot et l'Ondioline]]
