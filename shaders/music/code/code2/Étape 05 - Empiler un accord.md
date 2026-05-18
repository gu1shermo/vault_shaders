# Étape 05 — Empiler un accord

> Décomposition [[shadertoy2 code]] — **étape 5 / 10**
> Concept : jouer **4 notes simultanées** avec `padSynth`, chacune placée différemment dans l'espace stéréo.

---

## Objectif pédagogique

- Construire un accord en additionnant 4 appels à `padSynth`.
- Passer un accord comme un **`vec4` de demi-tons**, converti d'un coup en fréquences par la macro `N`.
- Comprendre la **pondération stéréo par voix** : `* vec2(gaucheR, droiteR)`.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))

vec2 padSynth(float f, float t)
{
    vec2 sig = vec2(0.0);
    sig += FM(f,       f + vec2(-1.0, 1.62), 1.0) * 0.03;
    sig += FM(f + 2.0, f + vec2(1.0, -1.62), 1.0) * 0.02;
    float fc  = f * round(2000.0/f);
    float iom = 1000.0/f;
    sig += FM(fc,       f + vec2(0.7, -2.0), iom * (1.0 - 0.5*sin(1.9*t))) * 0.010;
    sig += FM(fc - 2.0, f + vec2(-1.0, 1.6), iom * (1.0 + 0.5*sin(3.0*t))) * 0.007;
    float env = smoothstep(0.0, 0.3, t);
    return sig * env;
}

vec2 padChord(vec4 fs, float t)
{
    vec2 sig = vec2(0.0);
    sig += padSynth(fs.x, t) * vec2(0.8, 0.3);   // voix grave  → plutôt à gauche
    sig += padSynth(fs.y, t) * vec2(1.0, 0.1);   // voix 2      → franchement à gauche
    sig += padSynth(fs.z, t) * vec2(0.1, 1.0);   // voix 3      → franchement à droite
    sig += padSynth(fs.w, t) * vec2(0.3, 0.8);   // voix aiguë  → plutôt à droite
    return sig;
}

vec2 mainSound( int samp, float t )
{
    float tn = mod(t, 4.0);
    // Accord en demi-tons : La3, Do4, Ré4, Fa4
    vec4 chord = vec4(-3.0, 0.0, 2.0, 5.0);
    return padChord(N(chord), tn);
}
```

---

## Théorie

### Un accord = une somme de voix

```glsl
vec2 padChord(vec4 fs, float t)
{
    vec2 sig = vec2(0.0);
    sig += padSynth(fs.x, t) * ...;
    sig += padSynth(fs.y, t) * ...;
    ...
}
```

Même principe que la stratification de l'étape 03, à un étage au-dessus : là on empilait des **couches FM** pour fabriquer un timbre, ici on empile des **notes** pour fabriquer un accord. La FM additive est récursive par nature — tout est somme de sinus.

### `N` appliqué à un `vec4`

```glsl
vec4 chord = vec4(-3.0, 0.0, 2.0, 5.0);
return padChord(N(chord), tn);
```

La macro `N(nn)` = `440.0*exp2(((nn)-9.0)/12.0)`. Les fonctions GLSL `exp2`, `+`, `*`, `/` opèrent **composante par composante** sur les vecteurs. Donc `N(chord)` calcule **les 4 fréquences d'un coup** et renvoie un `vec4`.

| Composante | Demi-tons | Note | Fréquence |
|---|---|---|---|
| `.x` | -3 | La3 | 220,0 Hz |
| `.y` |  0 | Do4 | 261,6 Hz |
| `.z` | +2 | Ré4 | 293,7 Hz |
| `.w` | +5 | Fa4 | 349,2 Hz |

C'est un La mineur coloré (La, Do, Ré, Fa) — un empilement de tierces et quartes typique d'un pad d'ambiance, ni franchement majeur ni franchement mineur.

> Écrire l'accord en **demi-tons** plutôt qu'en Hz : on transpose tout l'accord en ajoutant une constante (`chord + 12.0` → une octave plus haut), et il reste lisible musicalement.

### La pondération stéréo par voix

```glsl
sig += padSynth(fs.x, t) * vec2(0.8, 0.3);
```

Chaque voix est multipliée par un `vec2(gainGauche, gainDroite)` **différent**. C'est un panoramique manuel, voix par voix :

- voix `.x` → `(0.8, 0.3)` : majoritairement à gauche.
- voix `.y` → `(1.0, 0.1)` : presque tout à gauche.
- voix `.z` → `(0.1, 1.0)` : presque tout à droite.
- voix `.w` → `(0.3, 0.8)` : majoritairement à droite.

Résultat : les 4 notes de l'accord sont **étalées** dans le champ stéréo au lieu d'être empilées au centre. L'accord devient un **mur sonore large** dont on distingue les voix séparément — chacune a sa place dans l'espace.

> Ce panning brut (gains arbitraires non normalisés) suffit ici. Le code 1 introduisait le panning à **puissance constante** (`normalize`, [[Étape 06 - Panning constant power|étape 06 du code 1]]) ; on aurait pu le réutiliser, mais sur un pad tenu, la différence est négligeable et la lisibilité prime.

---

## Ce qu'on entend

Un accord de 4 notes tenu, large, qui monte en 0,3 s et se relance toutes les 4 secondes. Au casque, on **promène l'oreille** d'une voix à l'autre : grave à gauche, aigu à droite. C'est riche, planant, statique.

---

## Expérimentations suggérées

1. Changer l'accord : `vec4(-3.0, 1.0, 4.0, 8.0)` → La **majeur**. Entendre la couleur basculer.
2. Mettre toutes les pondérations à `vec2(0.5)` → l'accord se **recentre** en un bloc mono compact.
3. Transposer : `padChord(N(chord + 5.0), tn)` → même accord, une quarte plus haut.
4. Ajouter une 5ᵉ voix une octave sous la basse : `sig += padSynth(N(-3.0-12.0), t) * vec2(0.5);`.

---

## Limites de cette étape

L'accord est unique et se répète à l'identique. Une vraie partie de pad **enchaîne plusieurs accords** — une progression. Il faut un séquenceur d'accords : étape 06.

---

[[Étape 04 - padSynth la personnalité|← Étape 04]] · [[Étape 06 - Séquenceur d'accords|→ Étape 06 — Séquenceur d'accords]]

#shader #audio #shadertoy #td
