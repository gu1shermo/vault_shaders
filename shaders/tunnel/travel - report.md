
# Rapport — bug étape 16 (bloom)

## Symptôme

À l'étape 16 (`Bloom par accumulation pendant la marche`), la version naïve produit un **pilier rouge vertical** au centre de l'image, qui monte du sol jusqu'au sommet du framebuffer. L'effet est censé n'éclairer que les rayons qui **frôlent** une sphère ; il éclaire en réalité aussi les rayons qui partent vers le ciel.

![[Pasted image 20260501143205.png]]

## Code en cause

```glsl
for (float i = 0.; i < 128.; ++i)
{
    vec2 res = map(p);
    if (res.x < 0.01) { /* hit */ break; }

    if (res.y == 0.) accCol += vec3(1., 0., 0.2) * 0.02;  // ← bug
    p += rd * res.x * 0.4;
}
```

L'accumulation se déclenche dès que `res.y == 0.` (i.e. la sphère est plus proche que le sol), **sans tenir compte de `res.x`** (la distance réelle à la sphère).

## Pourquoi `res.y == 0.` reste vrai très loin des sphères

Dans `map()` :

```glsl
acc = _min(acc, vec2(length(ps) - 0.5, 0.)); // sphère, ID 0
acc = _min(acc, vec2(ground,           1.)); // sol,    ID 1
```

avec `ground = p.y - bruit(...)`. Pour un rayon dirigé vers le haut, `p.y` augmente linéairement. La SDF du sol vaut alors approximativement `p.y` (grand positif). La SDF de la sphère vaut `length(ps) - 0.5` ; comme `ps.y = p.y` et que `length` est dominée par sa plus grande composante, on a `length(ps) ≈ p.y` également — mais **toujours légèrement plus petit** que `p.y` quand `ps.xz` est petit, et de toute façon comparable.

Conclusion : à grande altitude, `length(ps) - 0.5 < p.y`, donc `_min` retient la sphère, donc `res.y == 0.`. À chaque pas, on accumule `0.02` de rouge "gratuit". Sur ~128 itérations on atteint `2.56` saturé → pilier rouge plein écran.

## Fix : pondérer l'accumulation par la proximité

```glsl
if (res.y == 0.) accCol += vec3(1., 0., 0.2) * (1. - sat(res.x / 0.5)) * 0.05;
```

Le facteur `(1. - sat(res.x / 0.5))` :
- vaut **1** quand `res.x → 0` (le rayon est juste à côté d'une sphère) ;
- vaut **0** dès que `res.x ≥ 0.5` (la sphère est trop loin pour glow) ;
- correspond exactement à la sémantique annoncée : "plus le rayon **frôle** la sphère, plus elle s'éclaire".

Le coefficient passe de `0.02` à `0.05` pour compenser le fait que le poids vaut maintenant en moyenne moins de 1.

## Vérification

Pour un rayon qui part vers le ciel, `res.x ≈ length(ps) - 0.5` reste dans l'ordre de plusieurs unités → `sat(res.x / 0.5)` saturé à 1 → poids = 0 → **plus aucune contribution**. Le pilier rouge disparaît.

Pour un rayon qui passe au ras d'une sphère, `res.x` descend vers `0.01` (seuil d'arrêt) → poids ≈ 1 → bloom maximum sur les pas proches. L'effet halo autour des sphères au sol est préservé.

## Pattern de référence

C'est exactement la forme utilisée à l'étape 9 de `tunnel1` :

```glsl
accCol += getMat(p, vec3(0.), d) * (1. - sat(d.x / .5)) * .05;
```

Le bug venait d'une simplification trop agressive (suppression du `(1. - sat(...))`) en oubliant que sans pondération, n'importe quelle classification par ID continue de "tirer" le bloom au-delà de la zone visuellement pertinente.

## Propagation

Le même fix est appliqué dans `travel - étapes.md` aux étapes **16, 17, 18, 19, 20** et dans `travel.md` (Buffer A final) — toutes ces étapes copiaient la même boucle.
