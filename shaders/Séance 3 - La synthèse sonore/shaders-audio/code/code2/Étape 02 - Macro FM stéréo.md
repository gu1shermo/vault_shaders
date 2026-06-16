# Étape 02 — Macro FM stéréo

> Décomposition [[shadertoy2 code]] — **étape 2 / 10**
> Concept : la FM écrite en **macro**, l'astuce `fract` de précision, et la **modulante `vec2`** qui crée la largeur stéréo.

---

## Objectif pédagogique

- Réécrire la modulation de fréquence en **macro** plutôt qu'en fonction, et comprendre pourquoi.
- Comprendre l'astuce `fract` qui protège la **précision flottante** sur de longues durées.
- Découvrir qu'en passant un `vec2` comme fréquence de modulation, on obtient **deux timbres légèrement différents** L/R — la base de toute la spatialisation du morceau.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853

// fc et fm peuvent être des float OU des vec2.
// La macro utilise implicitement la variable `t` du contexte appelant.
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))

vec2 mainSound( int samp, float t )
{
    float f = 220.0;

    // fm est un vec2 : modulante désaccordée différemment à gauche et à droite
    vec2 sig = FM(f, f + vec2(-1.0, 1.62), 1.0) * 0.2;

    float env = exp(-2.0*mod(t, 2.0));
    return sig * env;
}
```

---

## Théorie

### Rappel : la formule FM

```glsl
sin( TWOPI*fc*t  +  iom * sin(TWOPI*fm*t) )
```

`fc` = porteuse (hauteur perçue), `fm` = modulante (structure du spectre), `iom` = index (richesse). Détaillé à l'[[Étape 04 - Modulation FM|étape 04 du code 1]]. Ici, deux changements de forme importants.

### Pourquoi une macro et pas une fonction ?

```glsl
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
```

Une macro est une **substitution de texte** avant compilation. Conséquences :

- **Polymorphisme gratuit** : `FM(440., 440., 1.)` renvoie un `float`, `FM(440., vec2(...), 1.)` renvoie un `vec2`. Une fonction GLSL aurait imposé un type de retour fixe. La macro, elle, laisse le compilateur déduire le type des arguments réels.
- **Capture de `t`** : la macro n'a **pas** de paramètre `t`. Elle utilise la variable `t` qui existe là où on l'écrit. Pratique, mais piégeux : `FM(...)` ne compile que si une variable nommée `t` est visible.

> Les parenthèses autour de chaque argument — `(fc)`, `(fm)`, `(iom)` — sont **obligatoires**. Sans elles, `FM(a+b, ...)` se substituerait en `(a+b)*t` mal parenthésé. Réflexe de toute macro arithmétique en C/GLSL.

### L'astuce `fract` — précision flottante

Comparez avec le code 1 : ici la phase est `fract((fc)*t)` et non `(fc)*t`.

Le problème : à `fc = 440 Hz` et `t = 60 s`, l'argument `fc*t = 26400`. Un `float` 32 bits n'a que ~7 chiffres significatifs : autour de 26400, le **pas** entre deux flottants représentables dépasse 0,001. La phase devient « granuleuse » → le sinus crachote.

La solution exploite la **périodicité** : `sin` est `2π`-périodique, donc

```
sin(TWOPI * x) == sin(TWOPI * fract(x))
```

`fract(x)` jette la partie entière (les tours complets, inaudibles) et ne garde que `[0, 1)`. L'argument reste **petit et précis** quelle que soit la durée de lecture. Indispensable pour un morceau qui tourne en boucle plusieurs minutes.

### La modulante `vec2` — naissance de la stéréo

```glsl
FM(f, f + vec2(-1.0, 1.62), 1.0)
```

`fm` vaut `vec2(f-1.0, f+1.62)` : la modulante est **désaccordée de −1 Hz à gauche, +1,62 Hz à droite**. La macro propage le `vec2` : `sin(TWOPI*fract(vec2))` devient un `vec2`, et le résultat final est un `vec2` — deux signaux FM **proches mais pas identiques**.

L'oreille interprète deux timbres légèrement décorrélés comme un son **large**, qui « remplit » l'espace. C'est exactement l'effet d'un *chorus* analogique. Coût : zéro — un seul `vec2` au lieu d'un `float`.

> Les valeurs `-1.0` et `1.62` sont **asymétriques exprès**. Un désaccord symétrique (`±1.0`) garderait L et R en phase et l'effet serait plus faible. L'asymétrie casse la corrélation.

---

## Ce qu'on entend

Un son FM grave (220 Hz), chaud, qui se relance toutes les 2 secondes — mais surtout **large** : au casque, il ne sort pas d'un point, il occupe tout l'espace entre les deux oreilles.

---

## Expérimentations suggérées

1. Remplacer le `vec2` par un `float` : `FM(f, f + 1.0, 1.0)` → le son **se recentre**, devient mono et étroit. C'est tout l'enjeu.
2. Élargir le désaccord : `f + vec2(-6.0, 9.0)` → ça « bat » audiblement (battements), plus instable.
3. Supprimer `fract` dans la macro et laisser tourner 2 min → écouter le signal se dégrader (crachotements).
4. Faire varier `iom` : `1.0` → `4.0` → `0.1` → du clair au métallique au quasi-pur.

---

## Limites de cette étape

Une seule couche FM, c'est encore pauvre. Un vrai pad de synthé empile **plusieurs** couches FM aux rôles distincts (corps, brillance, mouvement). On commence cet empilement à l'étape 03.

---

[[Étape 01 - Temps musical et notes|← Étape 01]] · [[Étape 03 - padSynth le corps|→ Étape 03 — padSynth, le corps]]

#shader #audio #shadertoy #td
