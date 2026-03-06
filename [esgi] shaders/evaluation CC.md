# RENDU le 30/03/26

## ATTENTION, vérifiez bien que vos shaders sont *public* ou *unlisted*


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

voir: https://www.shadertoy.com/view/scXGzn

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
- ombre (sharp, diffuse à zéro si on se trouve dans l'ombre d'un objet)
- caméra
- bonus+: effet de toon shading
- bonus+: soft shadows
- bonus+: répétition de l espace
- bonus+: déformer le sol avec une texture de noise
- bonus+:  ajouter du bloom sur un autre objet
- bonus+: ajouter blur horizontal/vertical
- bonus++: si le rayon ne touche rien, il tape dans un "ciel" => background
	- voir https://www.shadertoy.com/view/lXsXRj
- bonus++: reflect dans la scène qui va piocher dans les autres objets 
	- voir https://www.shadertoy.com/view/ctVyWK


---
- perturber la surface d'un des objets avec une texture 3D
- ajouter texture un autre objet
- 

### Shader 4 — Value Noise / Voronoi
voir: https://www.shadertoy.com/view/tXyBWd
voir: https://www.shadertoy.com/view/sff3D8
- au choix: value noise avec layers (fractal noise?) vu mercredi ou voronoi (vu vendredi)
- bonus+ : utiliser le noise dans une scène 2D 
- bonus++: le "mapper" à un objet 3D (sur la face d'un cube par exemple)

### Exercices post process
1. pixellisation
2. edge detection
3. toon




