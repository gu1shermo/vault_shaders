# 23 — La synthèse par modèle physique

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 23/30**
> **Tags :** #synthese-sonore #modele-physique #ESGI

---

## Principe fondamental

> "Simulation mathématique du comportement acoustique d'un instrument réel."

La synthèse par modèle physique ne "joue" pas un enregistrement ni ne filtre des formes d'ondes — elle **calcule** en temps réel le comportement physique des vibrations comme si l'instrument existait réellement.

---

## La relation excitateur-résonateur

Tout instrument acoustique repose sur cette dualité :

| Composant | Rôle | Exemples |
|---|---|---|
| **Excitateur** | Source d'énergie mécanique | Pincé (guitare), souffle (flûte), archet (violon), frappe (piano) |
| **Résonateur** | Corps vibrant qui amplifie et colore le son | Corde, tuyau d'air, membrane, caisse de résonance |

L'interaction entre excitateur et résonateur détermine le son produit.

---

## Étapes de modélisation

### 1. Définition des paramètres physiques

- **Dimensions** : longueur, diamètre, épaisseur de l'instrument
- **Masse** : poids des composantes vibrantes
- **Élasticité** : rigidité, tension des cordes, etc.

### 2. État initial et conditions aux limites

- **Position de départ** : état vibratoire initial (ex. : corde à sa position de repos)
- **Conditions aux limites** : contraintes physiques (ex. : extrémités fixes d'une corde)
- Ces conditions peuvent être **non réalistes** → création d'instruments "chimériques" impossibles physiquement

### 3. Relation excitateur-résonateur

- Modélisation de l'interaction entre la source d'énergie et le corps vibrant
- **Impédance** : résistance naturelle des matériaux à la propagation des vibrations
- **Diffusion sonore** : comment l'énergie rayonne dans l'espace

---

## Les trois méthodes principales

### 1. Masses et Ressorts (Hiller & Ruiz, fin années 60)

> "Des masses reliées par des ressorts simulent les vibrations d'une corde."

**Principe** :
- La corde est modélisée comme une série de masses reliées par des ressorts
- Une énergie extérieure est appliquée sur une masse (pincement)
- L'énergie se propage de masse en masse par compression/extension des ressorts
- La vibration globale est calculée en résolvant les équations différentielles de chaque masse

```
o-~-o-~-o-~-o-~-o-~-o    (o = masse, ~ = ressort)
         ↑
    pincement ici → énergie se propage dans les deux sens
```

**Limite** : calcul très lourd pour un grand nombre de masses (résolution vs. temps de calcul)

---

### 2. Synthèse Modale (années 90)

> "Divise l'instrument en sous-structures avec leurs propres caractéristiques."

**Principe** :
- L'instrument est divisé en **sous-structures** (cordes, chevalet, table d'harmonie, membrane)
- Chaque sous-structure est modélisée par ses **modes de résonance** (fréquences naturelles de vibration)
- Les modes interagissent selon les couplages physiques entre structures

**Exemple** : le logiciel **Modalys** développé à l'IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris).

**Avantage** : plus efficace que les masses-ressorts car travaille avec les modes (résumé spectral) plutôt que les détails locaux.

---

### 3. Synthèse MSW (McIntyre, Schumacher, Woodhouse)

> "Modélise des instruments entiers basée sur le comportement temporel du signal."

**Principe** :
- Travaille directement avec le signal temporel à la jonction excitateur/résonateur
- Particulièrement efficace pour les instruments à **anches** (clarinette, saxophone) et à **cordes frottées** (violon, violoncelle)
- Modélise le couplage non-linéaire entre l'archet et la corde (stick-slip phénomène)

---

## Guide d'onde (Waveguide)

> "Un montage mathématique qui modélise le milieu dans lequel les ondes vont évoluer (corde ou tube)."

### Principe du guide d'onde

Basé sur l'observation qu'une onde se propage dans une corde de la même façon qu'un signal dans une **ligne à retard** :

```
Pincement → onde se propage →→→ jusqu'à l'extrémité
                            ←←← réflexion à l'extrémité
                            Interférences → son final
```

La **ligne à retard** simule le temps de propagation de l'onde le long de la corde.

### Exemple : la corde de piano

```
Impact du marteau en milieu de corde :
→ Deux ondes naissent et se propagent en sens opposés
→ Rencontrent les chevalets aux extrémités
→ Rebond et retour
→ Création d'interférences → son du piano
```

### Algorithme Karplus-Strong (1983)

Algorithme fondateur de la synthèse par guide d'onde :
1. Remplir une mémoire tampon (buffer) avec du **bruit blanc**
2. Appliquer un **filtre passe-bas** à la sortie de cette mémoire
3. La sortie filtrée est **réinjectée** dans la mémoire (boucle de feedback)
4. Le signal résultant simule une **corde vibrante** avec amortissement naturel

→ Résultat très réaliste pour les sons de corde (guitare, koto, harpe)

---

**← Précédent :** [[22 - Le spectre dans la synthèse FM]]  
**→ Suite :** [[24 - Applications de la synthèse par modèle physique]]
