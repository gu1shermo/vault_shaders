# Étape 10 — Séquenceur lead et mix final

> Décomposition [[shadertoy2 code]] — **étape 10 / 10**
> Concept : dérouler une mélodie avec la macro `P`, l'enrober d'échos, et **mixer le lead avec le pad** — le morceau complet.

---

## Objectif pédagogique

- Comprendre la macro `P(nn, b)` : un séquenceur qui « consomme » le temps note après note.
- Réutiliser la réverbération par échos (étape 07) sur le lead.
- Assembler les **deux branches** — pad et lead — dans `mainSound`.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define bpm 100.0
#define beatdur (60.0/bpm)
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))
#define FM(fc, fm, iom)  sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define FM2(pc, pm, iom) sin(mod(pc, TWOPI) + (iom)*sin(mod(pm, TWOPI)))

// ---------- BRANCHE PAD (étapes 03 à 07) ----------
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
         + padChordPattern(t - 0.01).yx * 0.3 * vec2(-1.0, 1.0)
         + padChordPattern(t - beatdur) * 0.25;
}

// ---------- BRANCHE LEAD (étapes 08 à 09) ----------
float vibratoPhase(float f0, float semitones, float vibHz, float t)
{
    float df = 0.06*f0*semitones;
    return TWOPI*f0*t + df/vibHz*sin(TWOPI*vibHz*t);
}

vec2 leadSynth(float f, float t)
{
    vec2 sig = vec2(0.0);
    t = max(t, 0.0);
    float vibEnv = smoothstep(0.0, 0.5, t);
    float phase  = vibratoPhase(f, 0.2*vibEnv, 5.0, t);
    float tpt    = TWOPI*t;
    sig += FM2(phase,           phase,                      1.0) * 0.05;
    sig += FM2(phase + 5.0*tpt, phase + vec2(-1.0, 0.8)*tpt, 3.0) * 0.02;
    float ratio = round(5000.0/f);
    float iom   = 1500.0/f;
    sig += FM2(ratio*phase,           phase,                     iom) * 0.01;
    sig += FM2(ratio*phase + 5.0*tpt, phase + vec2(3.0,-3.0)*tpt, iom) * 0.01;
    float fc = f * round(10000.0/f);
    iom = 10000.0/f;
    sig += FM(fc, f, iom) * 0.05 * exp(-30.0*t);
    float env = 0.7*(1.0 + smoothstep(0.02, 0.0, t) + 0.3*smoothstep(0.0, 0.5, t));
    return sig * env;
}

vec2 leadSynthPattern(in float t)
{
    vec2 sig = vec2(0.0);
    t -= 1.75*beatdur;            // léger lever (la mélodie n'attaque pas sur le 1)
    t = max(t, 0.0);
    t = mod(t, 8.0*beatdur);      // boucle mélodique de 8 temps

    // P(nn, b) : joue la note nn pendant b temps, puis avance l'horloge.
    #define P(nn, b) sig += leadSynth(N(nn), t) * step(0.0, t) * smoothstep((b)*beatdur, (b)*beatdur-0.01, t); t -= (b)*beatdur;

    P(7.0,       0.25);
    P(9.0,       0.5);
    P(7.0,       1.0);
    P(9.0,       1.0);
    P(9.0+12.0,  0.5);
    P(16.0,      0.5);
    P(14.0,      1.0);
    P(12.0,      0.5);
    P(9.0,       0.25);
    P(7.0,       0.25);
    P(9.0,       1.5);

    #undef P
    return sig;
}

vec2 leadSynthPatternVerb(float t)
{
    return leadSynthPattern(t)
         + leadSynthPattern(t - 0.005).yx          * vec2(0.3, 0.7)
         + leadSynthPattern(t - 0.75*beatdur) * 0.5 * vec2(-1.0, 1.0)
         + leadSynthPattern(t - 1.5*beatdur)  * 0.25 * vec2(-1.0, -1.0);
}

// ---------- MIX FINAL ----------
vec2 mainSound( int samp, float t )
{
    vec2 sig = vec2(0.0);
    sig += padChordPatternVerb(t);
    sig += leadSynthPatternVerb(t);
    return sig;
}
```

---

## Théorie

### La macro `P` — un séquenceur qui consomme le temps

Le code 1 déroulait sa séquence avec un tableau `const float[]` et une boucle `for` ([[Étape 08 - Séquenceur jingle|étape 08 du code 1]]). Ici, autre stratégie : une **macro qui se substitue en cascade**.

```glsl
#define P(nn, b) sig += leadSynth(N(nn), t) * step(0.0, t) * smoothstep((b)*beatdur, (b)*beatdur-0.01, t); t -= (b)*beatdur;
```

Chaque `P(nn, b)` fait deux choses :

1. **Joue** la note `nn` pour une durée `b` temps, avec le `t` courant.
2. **Avance l'horloge** : `t -= (b)*beatdur` — la note suivante reçoit un `t` diminué de la durée déjà écoulée.

Les notes s'écrivent alors **les unes sous les autres**, comme une partition. La 1ʳᵉ voit `t`. La 2ᵉ voit `t - 0.25*beatdur`. La 3ᵉ voit `t - 0.75*beatdur`. Etc. La note dont le `t` décalé tombe dans `[0, b*beatdur)` est **celle qui sonne** ; les autres sont éteintes.

Les deux garde-fous dans la macro :

- `step(0.0, t)` : vaut 0 si `t < 0` → une note **pas encore commencée** est muette. (`leadSynth` fait déjà `max(t,0)` en interne — d'où ce `step` complémentaire qui coupe vraiment le son.)
- `smoothstep((b)*beatdur, (b)*beatdur-0.01, t)` : fondu décroissant de 10 ms en **fin** de note → coupe proprement avant la note suivante, pas de clic.

| `P(nn, b)` | Note | Durée |
|---|---|---|
| `P(7, 0.25)`  | Sol4 | croche |
| `P(9, 0.5)`   | La4  | — |
| `P(7, 1.0)`   | Sol4 | noire |
| `P(9, 1.0)`   | La4  | noire |
| `P(21, 0.5)`  | La5 (octave) | — |
| `P(16, 0.5)`  | Mi5  | — |
| `P(14, 1.0)`  | Ré5  | noire |
| `P(12, 0.5)`  | Do5  | — |
| `P(9, 0.25)`  | La4  | croche |
| `P(7, 0.25)`  | Sol4 | croche |
| `P(9, 1.5)`   | La4  | longue finale |

Total : 8 temps, exactement la période `mod(t, 8.0*beatdur)`.

> `#define` / `#undef` autour du bloc : la macro `P` n'existe **que** dans `leadSynthPattern`. Bonne hygiène — une macro qui modifie `sig` et `t` ne doit pas fuiter ailleurs.

### Le lever : `t -= 1.75*beatdur`

```glsl
t -= 1.75*beatdur;
t = max(t, 0.0);
```

La mélodie ne démarre pas sur le premier temps : elle est **décalée** de 1,75 temps. Musicalement, c'est un **lever** (anacrouse) — la phrase « prend son élan » avant le temps fort. Le `max(t, 0.0)` empêche les `t` négatifs au tout début de lecture.

### Les échos du lead

```glsl
vec2 leadSynthPatternVerb(float t)
{
    return leadSynthPattern(t)
         + leadSynthPattern(t - 0.005).yx          * vec2(0.3, 0.7)
         + leadSynthPattern(t - 0.75*beatdur) * 0.5 * vec2(-1.0, 1.0)
         + leadSynthPattern(t - 1.5*beatdur)  * 0.25 * vec2(-1.0, -1.0);
}
```

Même principe qu'à l'[[Étape 07 - Réverbération par échos|étape 07]], mais **quatre** termes et calibré pour une mélodie :

- `t - 0.005` + `.yx` : reflet précoce de 5 ms, canaux croisés → largeur.
- `t - 0.75*beatdur` : écho à la croche pointée, polarité gauche inversée → écho rythmique **syncopé**.
- `t - 1.5*beatdur` : écho lointain, les deux canaux inversés → queue de réverbération diffuse.

Les décalages `0.75` et `1.5` temps sont **musicaux** : les échos retombent dans la grille rythmique, ils dialoguent avec la mélodie au lieu de la brouiller.

### Le mix final

```glsl
vec2 mainSound( int samp, float t )
{
    vec2 sig = vec2(0.0);
    sig += padChordPatternVerb(t);    // trame harmonique (16 temps)
    sig += leadSynthPatternVerb(t);   // mélodie (8 temps)
    return sig;
}
```

Deux séquences de **périodes différentes** — le pad boucle sur 16 temps, le lead sur 8 — superposées par simple addition. La mélodie se rejoue donc **deux fois** par cycle d'accords, et tombe sur des harmonies différentes à chaque passage : c'est ce déphasage des périodes qui empêche le morceau de sonner répétitif.

Le **budget d'amplitude** anticipé depuis l'étape 03 (gains de couches faibles : `0.03`, `0.02`, `0.01`…) paie ici : la somme pad + lead + tous les échos reste dans `[-1, 1]` sans atténuation finale.

---

## Ce qu'on entend

Le morceau complet de [[shadertoy2 code]] : une trame d'accords planante et réverbérée, surmontée d'une mélodie de synthé chantante, vibrée, avec des échos qui rebondissent en rythme. Pad et lead bouclent à des vitesses différentes — le morceau évolue sans jamais se répéter exactement. **Vous venez de le reconstruire en 10 étapes.**

---

## Récapitulatif du parcours

| #  | Concept | Code clé |
|----|---|---|
| 01 | Temps musical, notes | `beatdur`, `N(nn)` = `exp2` |
| 02 | FM en macro, stéréo | `fract` de précision, modulante `vec2` |
| 03 | Stratification timbrale | somme de couches `FM`, attaque `smoothstep` |
| 04 | Personnalité du timbre | `round(2000/f)`, index modulé |
| 05 | Accord | `padChord`, `N(vec4)`, pan par voix |
| 06 | Séquenceur d'accords | cascade `?:`, fondu de sortie |
| 07 | Réverbération | sommes décalées, `.yx` ping-pong |
| 08 | Vibrato juste | intégration de phase, `FM2` |
| 09 | Lead 5 couches | corps / présence / attaque, fausse compression |
| 10 | Séquenceur + mix | macro `P`, périodes 8 vs 16, addition finale |

---

## Limites du code final

- La mélodie est **figée dans le binaire** (macro `P` déroulée). Pour une partition longue, il faudrait un *texture lookup* — cf. la remarque de l'[[Étape 08 - Séquenceur jingle|étape 08 du code 1]].
- Pas de **batterie**, pas de **basse** : c'est un duo pad + lead. L'épisode 3 ([[Cours 3 - Marimba, Saw Bass, Wah Synth]]) ajoute marimba et basse saw.
- La « réverbération » par 3-4 échos reste rudimentaire — une vraie réverb a une densité d'échos bien plus grande.
- Aucun couplage avec l'image : `mainImage` et `mainSound` ne partagent que `iTime`.

Ces pistes sont les prolongements naturels du module.

---

[[Étape 09 - leadSynth|← Étape 09]] · [[_Index - Décomposition shadertoy2|↑ Index]]

#shader #audio #shadertoy #td
