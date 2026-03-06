
### Modalités d’évaluation

Les travaux réalisés pendant les cours et ateliers seront évalués dans le cadre du **contrôle continu**. L’objectif n’est pas uniquement d’obtenir un résultat final précis, mais surtout de montrer votre **compréhension des concepts vus en cours** et votre **capacité à les explorer**.

L’évaluation repose principalement sur plusieurs critères :

- **La maîtrise technique** : bonne utilisation des concepts étudiés (SDF, opérations booléennes, raymarching, éclairage, etc.).
    
- **L’exploration et l’expérimentation** : capacité à tester différentes idées, modifier les paramètres, combiner plusieurs techniques et aller au-delà du minimum demandé.
    
- **L’originalité** : propositions personnelles, composition de scène, variations intéressantes à partir des outils vus en cours.
    
- **La qualité visuelle** : l’aspect artistique peut être un plus, mais il reste secondaire par rapport à la compréhension technique.
    

Il n’est donc pas attendu que tous les travaux produisent exactement le même résultat. Au contraire, les exercices sont pensés comme des **espaces d’expérimentation** où chacun peut développer sa propre approche à partir des notions étudiées.

### Shader 1 — Composition 2D avec SDF

Réaliser une **composition de scène 2D** en utilisant les **Signed Distance Fields** vus en cours.

La scène doit au minimum inclure :

- plusieurs **formes primitives**
    
- des **opérations booléennes** (union, intersection, soustraction)
    
- au moins un exemple de **répétition de l’espace**
    

L’objectif est de montrer que vous comprenez comment **composer des formes à partir de fonctions de distance**.

---

### Shader 2 — Pavage de Truchet

Réaliser un **pavage de Truchet procédural**.

La scène doit inclure :

- une **grille répétée**
    
- une **variation aléatoire** des tuiles
    
- une composition visuelle cohérente
    

L’objectif est de travailler la **répétition de l’espace**, la **variation procédurale** et l’utilisation de **fonctions pseudo-aléatoires**.

---

### Shader 3 — Raymarching 3D

Réaliser une **scène 3D simple en raymarching**.

La scène doit inclure :

- une **composition d’objets SDF**
- le calcul de la **normale**
- un modèle d’éclairage simple comprenant :
    - **ambiant**
    - **diffuse**
    - **spéculaire**
- plusieurs objets et pouvoir les discriminer
- un sol
- ombre
- caméra
- bonus: effet de toon shading
- répétition de l espace
- perturber la surface d'un des objets avec une texture 3D
- ajouter du bloom sur un autre objet
- ajouter texture un autre objet
- 



### Shader 5 — Smooth minimum et fusion organique

Réaliser une **scène 3D en raymarching** dans laquelle plusieurs objets sont **fusionnés de manière lisse** à l’aide d’un _smooth minimum_.

La scène doit inclure :

- au moins **deux primitives SDF** (par exemple des sphères)
    
- l’utilisation de la fonction **smooth minimum (`smin`)** pour fusionner les formes
    
- un **éclairage diffuse simple**
    
- une **animation d’un des objets ou de la lumière**
    
- l’utilisation d’une **texture comme bruit volumétrique** pour perturber la surface
    




### Shader 6 — Structure filaire et accumulation de lumière

Réaliser une **scène 3D en raymarching** composée d’une **structure filaire animée**, avec une **accumulation de couleur produisant un effet lumineux**.

La scène doit inclure :

- une **forme principale construite à partir d’un cube modifié** (`_cucube`)
    
- un **cube interne** ou une autre primitive SDF
    
- une **rotation de la scène dans les trois axes**
    
- le calcul de la **normale**
    
- l’utilisation d’une **texture appliquée dans l’espace objet**
    
- une **accumulation de couleur (`+=`) produisant un effet lumineux**


### Shader — Répétition de l’espace et accumulation volumétrique

Réaliser une **scène 3D en raymarching** dans laquelle des formes sont **répétées dans l’espace** et produisent un **effet lumineux par accumulation de couleur le long du rayon**.

La scène doit inclure :

- une **répétition de l’espace 3D** avec `mod`
    
- une **primitive SDF simple** (sphère ou autre forme)
    
- une **caméra mobile**
    
- une **accumulation de couleur dans la boucle de raymarching**
    
- une **variation de couleur dépendant de la position dans l’espace**
    

Dans le code fourni, la répétition spatiale est réalisée par :

```cpp
p = mod(p + rep*0.5, rep) - rep*0.5;

```


### Shader — Diagramme de Voronoï animé et métriques de distance

Réaliser un **shader 2D procédural** générant un **diagramme de Voronoï animé**.  
L’objectif est de comprendre comment construire un Voronoï à partir d’une **grille spatiale**, de **points aléatoires par cellule**, et de différentes **métriques de distance**.

La scène doit inclure :

- une **division de l’espace en cellules régulières**
    
- un **point aléatoire par cellule**
    
- une **animation des points**
    
- la recherche du **point le plus proche**
    
- une visualisation basée sur la **distance minimale**


### Shader — Ville procédurale avec terrain fractal et répétition spatiale

Réaliser une **scène 3D en raymarching** représentant un **terrain procédural sur lequel sont placés des bâtiments générés automatiquement**.

L’objectif de cet exercice est de comprendre :

- la **construction d’une scène complexe avec des SDF**
    
- l’utilisation d’un **terrain procédural basé sur du bruit**
    
- la **répétition de l’espace pour générer une ville**
    
- l’utilisation d’un **identifiant de cellule pour varier les bâtiments**
    
- l’application d’un **éclairage diffuse simple**

