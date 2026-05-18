# Étape 01 — Temps musical et notes

> Décomposition [[shadertoy2 code]] — **étape 1 / 10**
> Concept : structurer le temps en **temps musicaux** (`bpm`, `beatdur`) et nommer les notes par **demi-tons** (macro `N`).

---

## Objectif pédagogique

- Passer du temps « physique » (secondes) au temps **musical** (temps / beats).
- Comprendre la macro `N(nn)` qui convertit un **numéro de demi-ton** en fréquence.
- Construire un mini-séquenceur de 4 notes pour entendre la grille rythmique.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853

#define bpm 100.0
#define beatdur (60.0/bpm)

// nn = demi-tons. N(9) = La 440. N(0) = Do4. exp2(x) = 2^x.
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))

vec2 mainSound( int samp, float t )
{
    // Position dans une mesure de 4 temps
    float beat = mod(t, 4.0*beatdur);
    float idx  = floor(beat / beatdur);   // 0, 1, 2, 3

    // Une note par temps : Do, Mi, Sol, Do aigu
    float nn = (idx < 1.0) ? 0.0  :
               (idx < 2.0) ? 4.0  :
               (idx < 3.0) ? 7.0  : 12.0;

    float f  = N(nn);
    float tn = mod(beat, beatdur);        // temps local dans le temps courant

    float env = exp(-5.0*tn);
    float sig = sin(TWOPI*f*tn) * env * 0.2;
    return vec2(sig);
}
```

---

## Théorie

### Du temps physique au temps musical

Shadertoy nous donne `t` en **secondes**. La musique, elle, se compte en **temps** (beats). Le pont est le tempo :

```glsl
#define bpm 100.0            // 100 battements par minute
#define beatdur (60.0/bpm)   // durée d'un temps = 0.6 s
```

À partir de là, tout se mesure en multiples de `beatdur` : une mesure 4/4 = `4.0*beatdur`, une croche = `0.5*beatdur`. C'est la **seule** unité de temps qu'on manipulera dans le reste de la décomposition.

> Mettre `bpm` en `#define` plutôt qu'en variable : on peut changer le tempo de **tout le morceau** d'un seul chiffre.

### La macro `N(nn)` — nommer les notes

```glsl
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))
```

C'est la formule du **tempérament égal**, déjà vue à l'[[Étape 07 - Intervalles et tempérament|étape 07 du code 1]], mais ici figée en macro :

- `nn` est un **numéro de demi-ton**. L'octave fait 12 demi-tons.
- `exp2(x)` calcule `2^x` — un demi-ton = `2^(1/12)`.
- L'offset `-9.0` cale le repère : `N(9)` donne exactement `440 Hz` (le La), et `N(0)` donne le **Do4** (≈ 261,6 Hz).

| `nn` | Note | Fréquence |
|---|---|---|
| 0  | Do4  | 261,6 Hz |
| 4  | Mi4  | 329,6 Hz |
| 7  | Sol4 | 392,0 Hz |
| 12 | Do5  | 523,3 Hz |

`N(nn+12)` monte d'une octave, `N(nn-12)` descend d'une octave. Toute la suite du morceau s'écrit en demi-tons, jamais en Hertz.

### Le mini-séquenceur

```glsl
float beat = mod(t, 4.0*beatdur);   // boucle de 4 temps
float idx  = floor(beat / beatdur); // dans quel temps suis-je ? 0..3
float tn   = mod(beat, beatdur);    // depuis combien de temps ?
```

`floor(beat/beatdur)` répond à **« quelle note »**, `mod(beat,beatdur)` répond à **« depuis quand »**. Ce couple `idx` / `tn` est le squelette de tous les séquenceurs des étapes suivantes.

---

## Ce qu'on entend

Quatre notes percussives — Do, Mi, Sol, Do — un arpège de Do majeur, qui boucle toutes les 2,4 secondes (4 × 0,6 s). Sec et carré : c'est volontaire, on entend la **grille**.

---

## Expérimentations suggérées

1. Changer `bpm` à `60.0` puis `160.0` → la grille s'étire / se resserre, **les notes ne changent pas**.
2. Changer la suite de demi-tons : `0, 3, 7, 10` → arpège de Do **mineur 7**.
3. Mettre `nn = floor(beat/beatdur)*2.0` → une gamme par tons qui monte.
4. Remplacer `exp(-5.0*tn)` par `exp(-1.0*tn)` → les notes se chevauchent (legato).

---

## Limites de cette étape

Le timbre est un sinus nu, identique sur les deux canaux : aucune couleur, aucune largeur stéréo. Pour enrichir le spectre **sans aliasing**, on reprend la modulation de fréquence — mais cette fois écrite en macro et **stéréo**. C'est l'étape 02.

---

[[Étape 02 - Macro FM stéréo|→ Étape 02 — Macro FM stéréo]]

#shader #audio #shadertoy #td
