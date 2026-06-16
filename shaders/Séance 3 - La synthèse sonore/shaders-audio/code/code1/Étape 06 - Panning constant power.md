# Étape 06 — Panning constant power

> Décomposition [[shadertoy1 code]] — **étape 6 / 8**
> Concept : placer une voix mono à un endroit précis de la scène stéréo, **sans changement de volume perçu**.

---

## Objectif pédagogique

- Construire une fonction `pan(pos)` qui spatialise une voix selon un paramètre `pos ∈ [-1, +1]`.
- Comprendre pourquoi un panning naïf change le volume perçu et comment `normalize` le corrige.
- Saisir la **loi de puissance constante** (constant power panning) — utilisée par tous les DAW pros.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

float FM(float fc, float fm, float iom, float t)
{
    return sin(TWOPI*fc*t + iom*sin(TWOPI*fm*t));
}

vec2 fmPluck(float f, float t)
{
    float env = exp(-3.0*t) * 0.1;
    vec2 sig = vec2(0.0);
    sig.x += FM(f + 1.0, f + 1.0, 1.0, t) * env;
    sig.y += FM(f - 1.0, f - 1.0, 1.0, t) * env;
    sig += FM(f, f, 15.0, t) * exp(-20.0*t) * 0.03;
    return sig;
}

vec2 pan(float pos)
{
    vec2 e = vec2(1.0 - pos, 1.0 + pos);
    return normalize(e);
}

vec2 mainSound( int samp, float t )
{
    // Trois plucks à la même fréquence, placés à -1 (G), 0 (centre), +1 (D),
    // déclenchés successivement toutes les 0.5 s.
    vec2 sig = vec2(0.0);
    sig += fmPluck(440.0, mod(t,        1.5)) * pan(-1.0);
    sig += fmPluck(440.0, mod(t - 0.5,  1.5)) * pan( 0.0);
    sig += fmPluck(440.0, mod(t - 1.0,  1.5)) * pan(+1.0);
    return sig;
}
```

---

## Théorie

### Le problème du panning naïf

Approche **fausse** mais intuitive : interpoler linéairement entre les deux canaux.

```glsl
// Panning linéaire — NE PAS UTILISER
vec2 sig = mono * vec2(1.0 - p, p);   // p ∈ [0,1]
```

Au centre (`p = 0.5`), `vec2(0.5, 0.5)`. Le signal est divisé par 2 sur chaque canal.

#### La puissance acoustique perçue

L'oreille perçoit l'**énergie** d'un signal, qui se cumule en **somme des carrés** entre les deux canaux :

$$ P = L^2 + R^2 $$

- Centré linéaire : $P = 0.5^2 + 0.5^2 = 0.5$.
- Tout à gauche : $P = 1^2 + 0^2 = 1$.

**Le centre est perçu 2× moins fort** que les extrêmes ⇒ effet « creux au milieu » désagréable.

### La solution : la **loi de puissance constante**

On veut maintenir $L^2 + R^2 = \text{cst}$ pour toutes les positions de panning.

Géométriquement : si on pose `(L, R)` comme un point sur le **cercle unité**, alors `L² + R² = 1` par définition. Il suffit de choisir un point sur le cercle.

```glsl
vec2 pan(float pos)
{
    vec2 e = vec2(1.0 - pos, 1.0 + pos);   // direction non normalisée
    return normalize(e);                    // projection sur le cercle unité
}
```

- `pos = -1` : `e = (2, 0)` → `normalize` → `(1, 0)` → tout à gauche, énergie unitaire.
- `pos =  0` : `e = (1, 1)` → `(1/√2, 1/√2)` ≈ `(0.707, 0.707)` → centre.
- `pos = +1` : `e = (0, 2)` → `(0, 1)` → tout à droite, énergie unitaire.

Vérification : à toute position, $L^2 + R^2 = 1$. ✓

### La formule classique (équivalente)

Dans les DAW, on écrit souvent :

$$ L = \cos\left(\frac{\pi}{4}(1 + p)\right), \quad R = \sin\left(\frac{\pi}{4}(1 + p)\right) $$

avec `p ∈ [-1, +1]`. C'est exactement la **paramétrisation angulaire** du quart de cercle dans `[0°, 90°]`. La version `normalize(vec2(1-p, 1+p))` qu'on utilise est une **approximation** : elle suit le même cercle unité mais avec une vitesse angulaire **non uniforme** en `p`. Sur de petits déplacements de panning c'est imperceptible.

### Pourquoi le `vec2(1-pos, 1+pos)` et pas autre chose ?

C'est une **interpolation linéaire** des canaux **avant** projection sur le cercle :

| `pos` | `1 - pos` | `1 + pos` | Après normalize |
|---|---|---|---|
| -1 | 2 | 0 | (1, 0) |
| -0.5 | 1.5 | 0.5 | (0.949, 0.316) |
| 0 | 1 | 1 | (0.707, 0.707) |
| +0.5 | 0.5 | 1.5 | (0.316, 0.949) |
| +1 | 0 | 2 | (0, 1) |

C'est simple, élégant, sans branchement conditionnel ⇒ idéal pour GPU.

---

## Ce qu'on entend

Trois plucks identiques qui « se promènent » dans l'espace stéréo : **gauche → centre → droite**, séparés de 0.5 s. Volume perçu **stable** dans les trois positions.

> Test décisif : déplacer le casque alternativement sur l'oreille gauche puis droite — chaque oreille entend successivement les trois plucks avec la **même intensité**, mais à des moments différents.

---

## Expérimentations suggérées

1. **Comparer avec un panning linéaire fautif**.
   Remplacer `pan(pos)` par :
   ```glsl
   vec2 panNaif(float pos) { return vec2(1.0 - pos*0.5, 1.0 + pos*0.5) * 0.5; }
   ```
   Écouter : le pluck du centre semble notablement **plus faible** que ceux des bords.

2. **Trajectoire stéréo continue**. Spatialiser une seule note qui « tourne » lentement :
   ```glsl
   float p = sin(TWOPI * 0.5 * t);   // oscille entre -1 et +1, 1 cycle / 2 s
   vec2 sig = fmPluck(440.0, mod(t, 0.5)) * pan(p);
   ```

3. **Pan extrême** : `pan(-3.0)` → `vec2(4, -2)` normalisé. Que se passe-t-il ? L'algorithme accepte des valeurs hors `[-1, +1]` mais le signe négatif sur un canal inverse la phase ⇒ effet de **« décalage spatial fantôme »** qui sonne étrange en mono mais bizarre en stéréo. Utilisable créativement.

---

## Limites de cette étape

On répète toujours la même note à 440 Hz. Pour composer une mélodie, il faut générer des **fréquences musicales** à partir de demi-tons ⇒ étape 07.

---

[[Étape 05 - fmPluck stéréo|← Étape 05]] · [[Étape 07 - Intervalles et tempérament|→ Étape 07 — Intervalles et tempérament]]

#shader #audio #shadertoy #td
