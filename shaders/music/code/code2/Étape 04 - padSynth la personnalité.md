# Étape 04 — padSynth, la personnalité

> Décomposition [[shadertoy2 code]] — **étape 4 / 10**
> Concept : ajouter au corps deux couches FM aiguës dont la **porteuse suit la note** (`round`) et dont l'**index est modulé** lentement.

---

## Objectif pédagogique

- Comprendre l'astuce `f * round(2000.0/f)` : choisir une porteuse aiguë **harmonique** de la note.
- Comprendre pourquoi l'index `1000.0/f` est plus grand pour les graves.
- Faire **bouger** le timbre en animant l'index avec un `sin` lent.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))

vec2 padSynth(float f, float t)
{
    vec2 sig = vec2(0.0);

    // CORPS (étape 03)
    sig += FM(f,       f + vec2(-1.0, 1.62), 1.0) * 0.03;
    sig += FM(f + 2.0, f + vec2(1.0, -1.62), 1.0) * 0.02;

    // PERSONNALITÉ : porteuse aiguë harmonique + index modulé
    float fc  = f * round(2000.0/f);   // multiple de f le plus proche de 2000 Hz
    float iom = 1000.0/f;              // index : grand pour les graves, petit pour les aigus
    sig += FM(fc,       f + vec2(0.7, -2.0), iom * (1.0 - 0.5*sin(1.9*t))) * 0.010;
    sig += FM(fc - 2.0, f + vec2(-1.0, 1.6), iom * (1.0 + 0.5*sin(3.0*t))) * 0.007;

    float env = smoothstep(0.0, 0.3, t);
    return sig * env;
}

vec2 mainSound( int samp, float t )
{
    float tn = mod(t, 4.0);
    return padSynth(N(0.0), tn);     // Do4
}
```

---

## Théorie

### La porteuse harmonique : `f * round(2000.0/f)`

On veut une couche **aiguë** (vers 2000 Hz, là où l'oreille est la plus sensible) mais qui ne sonne pas « fausse ». La contrainte : sa fréquence doit être un **multiple entier** de la note `f` pour rester dans le spectre harmonique.

```glsl
float fc = f * round(2000.0/f);
```

- `2000.0/f` = combien de fois `f` tient dans 2000 Hz (un réel).
- `round(...)` = l'entier le plus proche → un **rang harmonique** valide.
- `f * ce rang` = la fréquence de cet harmonique, garantie multiple de `f`.

Exemple pour `f = 261.6 Hz` (Do4) : `2000/261.6 ≈ 7.65` → `round = 8` → `fc = 8 × 261.6 ≈ 2093 Hz`, soit le **8ᵉ harmonique**. Pour une note grave, le rang choisi est plus grand ; pour une note aiguë, plus petit. **La couche aiguë suit toujours la note** sans jamais désaccorder le pad.

> `round` arrondit au plus proche (≠ `floor`). Indispensable ici : on veut l'harmonique *le plus proche* de la cible 2000 Hz, qu'il soit juste au-dessus ou juste en dessous.

### L'index inversement proportionnel : `1000.0/f`

```glsl
float iom = 1000.0/f;
```

Plus la note est **grave**, plus `iom` est **grand** → plus la couche aiguë est riche en sidebands. Pourquoi ce choix ?

- Une note grave a des harmoniques très serrés : il faut beaucoup de sidebands pour qu'elle « brille ».
- Une note aiguë a déjà ses harmoniques étalés haut dans le spectre : un index élevé déborderait au-delà de 20 kHz et **alierait**.

`1000.0/f` équilibre automatiquement les deux : richesse constante à l'oreille, aliasing maîtrisé sur toute la tessiture. C'est une **normalisation perceptive**.

### L'index modulé : faire vivre le timbre

```glsl
iom * (1.0 - 0.5*sin(1.9*t))   // varie entre 0.5·iom et 1.5·iom
iom * (1.0 + 0.5*sin(3.0*t))   // idem, mais à une autre vitesse
```

L'index n'est plus constant : il **oscille** lentement (1,9 Hz et 3 Hz, sous le seuil de hauteur). Comme l'index pilote la richesse spectrale, le **timbre se déforme en continu** — le pad scintille, « ondule ».

Les deux couches utilisent des **vitesses différentes** (1,9 et 3,0) et des **signes opposés** (`-` et `+`) : leurs ondulations ne se synchronisent jamais, ce qui rend le mouvement organique plutôt que mécanique.

> Note : la modulation se fait sur `sin(1.9*t)` — un `t` **non wrappé**, donc lent et continu. Rien à voir avec le `fract` interne de la macro `FM`, qui ne concerne que la phase audio.

---

## Ce qu'on entend

Le même pad qu'à l'étape 03, mais désormais **doté d'une voix** : une composante aiguë cristalline qui scintille et ondule par-dessus le corps. Le son n'est plus une nappe neutre, il a un caractère reconnaissable.

---

## Expérimentations suggérées

1. Commenter les deux couches « personnalité » → on retombe sur le pad anonyme de l'étape 03. A/B révélateur.
2. Figer l'index : remplacer `iom * (1.0 - 0.5*sin(1.9*t))` par `iom` seul → le scintillement disparaît, le pad redevient statique.
3. Accélérer la modulation : `sin(15.0*t)` → on entre dans le domaine du trémolo audible, presque un effet.
4. Changer la cible harmonique : `round(4000.0/f)` → couche encore plus aiguë et fine ; `round(800.0/f)` → plus médium et présente.
5. Jouer une note grave `N(-12.0)` puis aiguë `N(12.0)` → vérifier que `fc` et `iom` s'adaptent et que le timbre reste cohérent.

---

## Limites de cette étape

`padSynth` joue une **seule note**. Un pad existe pour poser des **accords** — plusieurs notes tenues simultanément. On empile 4 voix à l'étape 05.

---

[[Étape 03 - padSynth le corps|← Étape 03]] · [[Étape 05 - Empiler un accord|→ Étape 05 — Empiler un accord]]

#shader #audio #shadertoy #td
