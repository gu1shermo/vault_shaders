# Étape 07 — Réverbération par échos

> Décomposition [[shadertoy2 code]] — **étape 7 / 10**
> Concept : créer de la profondeur en **sommant des copies décalées dans le temps** du signal, avec inversion de canaux.

---

## Objectif pédagogique

- Comprendre qu'un effet temporel sur Shadertoy = **appeler la même fonction avec un `t` décalé**.
- Fabriquer une fausse réverbération / un écho sans aucun buffer mémoire.
- Comprendre le **ping-pong stéréo** : `.yx` qui échange gauche et droite.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define bpm 100.0
#define beatdur (60.0/bpm)
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
    sig += padSynth(fs.x, t) * vec2(0.8, 0.3);
    sig += padSynth(fs.y, t) * vec2(1.0, 0.1);
    sig += padSynth(fs.z, t) * vec2(0.1, 1.0);
    sig += padSynth(fs.w, t) * vec2(0.3, 0.8);
    return sig;
}

vec2 padChordPattern(float t)
{
    t = max(t, 0.0);
    t = mod(t, 16.0*beatdur);
    vec4 chord =
        (t < 4.0*beatdur)  ? vec4(-3.0, -1.0, 0.0, 4.0) :
        (t < 8.0*beatdur)  ? vec4(-3.0,  0.0, 2.0, 5.0) :
        (t < 12.0*beatdur) ? vec4(-7.0, -3.0, 0.0, 7.0) :
        (t < 14.0*beatdur) ? vec4(-5.0,  0.0, 2.0, 4.0) :
                             vec4(-5.0, -1.0, 2.0, 4.0);
    float t_cur = mod(t, 4.0*beatdur);
    float env   = smoothstep(4.0*beatdur, 3.5*beatdur, t_cur);
    return padChord(N(chord), t_cur) * env;
}

vec2 padChordPatternVerb(float t)
{
    return padChordPattern(t)
         + padChordPattern(t - 0.01).yx     * 0.3 * vec2(-1.0, 1.0)
         + padChordPattern(t - beatdur)     * 0.25;
}

vec2 mainSound( int samp, float t )
{
    return padChordPatternVerb(t);
}
```

---

## Théorie

### Un effet temporel = un appel décalé

Pas de buffer, pas de ligne à retard, pas de mémoire : sur Shadertoy, `mainSound` est **sans état**. Mais on dispose d'une chose puissante — une fonction `padChordPattern(t)` **pure** : on peut l'évaluer pour **n'importe quel `t`**, passé comme futur.

Donc « le son qu'il y avait il y a 10 ms » s'obtient simplement par `padChordPattern(t - 0.01)`. Un écho devient une **somme** :

```glsl
vec2 padChordPatternVerb(float t)
{
    return padChordPattern(t)                              // son direct
         + padChordPattern(t - 0.01).yx * 0.3 * vec2(-1,1) // reflet précoce
         + padChordPattern(t - beatdur) * 0.25;            // écho rythmique
}
```

Coût : on évalue `padChordPattern` **trois fois** au lieu d'une. C'est tout — le GPU encaisse sans broncher.

### Les trois termes

| Terme | Décalage | Gain | Rôle |
|---|---|---|---|
| `padChordPattern(t)` | 0 | 1 | le **son direct** |
| `padChordPattern(t-0.01).yx` | 10 ms | 0,3 | **réflexion précoce** : crée la sensation de « pièce » |
| `padChordPattern(t-beatdur)` | 1 temps (0,6 s) | 0,25 | **écho rythmique** : se cale sur le tempo |

- Le décalage de **10 ms** est sous le seuil d'écho distinct (~30 ms) : l'oreille ne l'entend pas comme une répétition mais comme une **coloration spatiale** — c'est ce qui simule une petite réverbération.
- Le décalage d'**un temps** (`beatdur`) est, lui, parfaitement audible : c'est un véritable **écho musical**, qui retombe en rythme.

### Le ping-pong stéréo : `.yx`

```glsl
padChordPattern(t - 0.01).yx
```

Le swizzle `.yx` **échange** les composantes d'un `vec2` : `(L, R)` devient `(R, L)`. La réflexion précoce a donc ses canaux **inversés** par rapport au son direct.

Effet psychoacoustique : le son direct vient (disons) plutôt de gauche, son reflet revient de droite. L'oreille en déduit un **volume d'espace** — les murs renvoient le son du côté opposé. C'est le principe du *ping-pong delay*.

Le `* vec2(-1.0, 1.0)` ajoute une **inversion de polarité** sur le canal gauche : encore plus de décorrélation L/R, donc une image encore plus large et diffuse. Sur un signal réverbérant, l'inversion de phase est inaudible en soi mais élargit la stéréo.

> Question piège pour les étudiants : « pourquoi pas de récursion, un écho qui se ré-échote lui-même ? » Parce que `padChordPatternVerb` n'appelle que `padChordPattern`, **jamais elle-même**. Une vraie réverb récursive ferait exploser le nombre d'appels (2ⁿ). Ici la profondeur est **finie et fixe** : 3 termes, point.

---

## Ce qu'on entend

La même progression d'accords qu'à l'étape 06, mais désormais **dans une pièce** : il y a de l'air, de la profondeur, un halo autour de chaque accord, et un écho discret qui retombe en rythme un temps plus tard. Le pad respire enfin dans un espace.

---

## Expérimentations suggérées

1. Commenter les deux termes d'écho → retour au son sec de l'étape 06. A/B saisissant.
2. Allonger l'écho rythmique : `padChordPattern(t - 2.0*beatdur)` → écho à la blanche, plus aéré.
3. Monter le gain de l'écho à `0.5` → il devient envahissant, le morceau se brouille. Garder les échos **discrets**.
4. Ajouter un **3ᵉ écho** plus lointain : `+ padChordPattern(t - 2.0*beatdur).yx * 0.12`.
5. Enlever le `.yx` du reflet précoce → la stéréo se rétrécit : c'est l'inversion de canaux qui crée l'espace.

---

## Limites de cette étape

La **branche pad est terminée** — corps, personnalité, accords, progression, espace. Mais un morceau a besoin d'une **mélodie** par-dessus la trame harmonique. On démarre la branche *lead* à l'étape 08, en commençant par un détail qui change tout : le vibrato.

---

[[Étape 06 - Séquenceur d'accords|← Étape 06]] · [[Étape 08 - Vibrato correct|→ Étape 08 — Vibrato correct]]

#shader #audio #shadertoy #td
