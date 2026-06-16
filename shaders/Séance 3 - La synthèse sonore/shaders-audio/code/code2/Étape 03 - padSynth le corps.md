# Étape 03 — padSynth, le corps

> Décomposition [[shadertoy2 code]] — **étape 3 / 10**
> Concept : un instrument = **plusieurs couches FM superposées**. On pose ici les deux couches de « corps » du pad et son enveloppe d'attaque.

---

## Objectif pédagogique

- Comprendre la **stratification** : additionner plusieurs `FM(...)` faibles pour fabriquer un timbre.
- Écrire une fonction d'instrument `padSynth(f, t)` avec son **propre paramètre `t` local**.
- Utiliser une enveloppe d'**attaque** `smoothstep` — un pad n'a pas de percussion.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))

vec2 padSynth(float f, float t)
{
    vec2 sig = vec2(0.0);

    // CORPS : deux couches FM, désaccord stéréo via vec2
    sig += FM(f,       f + vec2(-1.0, 1.62), 1.0) * 0.03;
    sig += FM(f + 2.0, f + vec2(1.0, -1.62), 1.0) * 0.02;

    // Enveloppe d'attaque douce (pad = montée progressive, pas de claquement)
    float env = smoothstep(0.0, 0.3, t);
    return sig * env;
}

vec2 mainSound( int samp, float t )
{
    float tn = mod(t, 3.0);          // une note de pad qui se relance toutes les 3 s
    return padSynth(N(0.0), tn);     // Do4
}
```

---

## Théorie

### La stratification : un timbre = une somme de couches

Aucun instrument réel n'a un spectre « tout fait ». On le **construit** en superposant des sources élémentaires. Ici, deux couches FM :

```glsl
sig += FM(f,       f + vec2(-1.0, 1.62), 1.0) * 0.03;
sig += FM(f + 2.0, f + vec2(1.0, -1.62), 1.0) * 0.02;
```

- Les deux couches sont des FM à index modéré (`iom = 1.0`) → spectre harmonique doux.
- La seconde est portée à `f + 2.0` : un **léger désaccord de porteuse** entre les deux couches. Elles « battent » lentement l'une contre l'autre → le son **respire** au lieu d'être figé.
- Le désaccord stéréo `vec2(...)` est **inversé** entre les deux couches (`(-1, 1.62)` puis `(1, -1.62)`) → L et R sont encore plus décorrélés → image stéréo très large.
- Les gains `0.03` et `0.02` sont **faibles** : on prévoit d'empiler 4 voix d'accord (étape 05) puis un lead (étape 09). Chaque couche doit rester discrète pour que la **somme** ne sature pas `[-1, 1]`.

> Règle d'or du mixage additif sur Shadertoy : penser au **budget d'amplitude** dès la première couche. Il est bien plus simple de prévoir petit que de tout réatténuer après coup.

### La fonction `padSynth` et le `t` local

```glsl
vec2 padSynth(float f, float t) { ... }
```

`padSynth` reçoit **son propre `t`** en paramètre. À l'intérieur, ce paramètre **masque** (shadowing) tout `t` extérieur. La macro `FM`, qui capture « le `t` visible », utilise donc le `t` **local** de `padSynth`.

Conséquence pratique : l'appelant décide du temps qu'il injecte. En passant `mod(t, 3.0)`, `mainSound` fait redémarrer la note toutes les 3 secondes — `padSynth` ne sait même pas qu'elle est rejouée.

### L'enveloppe d'attaque `smoothstep`

```glsl
float env = smoothstep(0.0, 0.3, t);
```

`smoothstep(a, b, x)` monte **en douceur** de 0 à 1 quand `x` passe de `a` à `b` (courbe en S, dérivées nulles aux bords).

- Le code 1 utilisait `exp(-λt)` : une enveloppe qui **décroît** → instrument percussif (pluck).
- Ici `smoothstep(0, 0.3, t)` : une enveloppe qui **croît** sur 0,3 s puis reste à 1 → instrument **tenu** (pad). Aucun claquement à l'attaque, le son « se lève » doucement.

C'est la signature sonore d'un pad : on doit pouvoir poser un accord sans qu'aucune note ne pique.

---

## Ce qu'on entend

Une nappe (« pad ») chaude sur un Do4, qui **monte doucement** en 0,3 s puis se maintient, large dans l'espace, avec un très léger battement qui l'empêche d'être statique. Pas d'extinction : la note reste pleine jusqu'au relancement à 3 s.

---

## Expérimentations suggérées

1. Allonger l'attaque : `smoothstep(0.0, 1.5, t)` → le pad émerge très lentement, façon ambient.
2. Commenter la seconde couche `FM(f + 2.0, ...)` → le son devient plat et **figé** : c'est le désaccord de porteuse qui le fait respirer.
3. Mettre les deux désaccords stéréo identiques (`vec2(-1.0, 1.62)` partout) → l'image stéréo se rétrécit.
4. Monter l'index : `FM(f, ..., 4.0)` → un pad beaucoup plus brillant, presque cuivré.

---

## Limites de cette étape

Le corps seul est correct mais **anonyme** : il manque la « voix » du synthé, cette composante aiguë qui bouge et donne du caractère. C'est l'objet de l'étape 04.

---

[[Étape 02 - Macro FM stéréo|← Étape 02]] · [[Étape 04 - padSynth la personnalité|→ Étape 04 — padSynth, la personnalité]]

#shader #audio #shadertoy #td
