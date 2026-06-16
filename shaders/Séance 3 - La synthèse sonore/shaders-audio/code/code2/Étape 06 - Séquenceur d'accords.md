# Étape 06 — Séquenceur d'accords

> Décomposition [[shadertoy2 code]] — **étape 6 / 10**
> Concept : enchaîner **5 accords** sur 16 temps avec une cascade de tests `?:`, et fondre la fin de chaque accord.

---

## Objectif pédagogique

- Construire une **progression d'accords** sélectionnée par le temps.
- Comprendre le couple `mod` global / `mod` local : « quel accord » vs « depuis quand ».
- Appliquer un **fondu de sortie** (`smoothstep` décroissant) pour lier les accords sans claquement.

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
    t = mod(t, 16.0*beatdur);                 // boucle de 16 temps

    // Quel accord ? (demi-tons)
    vec4 chord =
        (t < 4.0*beatdur)  ? vec4(-3.0, -1.0, 0.0, 4.0) :
        (t < 8.0*beatdur)  ? vec4(-3.0,  0.0, 2.0, 5.0) :
        (t < 12.0*beatdur) ? vec4(-7.0, -3.0, 0.0, 7.0) :
        (t < 14.0*beatdur) ? vec4(-5.0,  0.0, 2.0, 4.0) :
                             vec4(-5.0, -1.0, 2.0, 4.0);

    float t_cur = mod(t, 4.0*beatdur);        // temps écoulé dans l'accord courant
    float env   = smoothstep(4.0*beatdur, 3.5*beatdur, t_cur);  // fondu de sortie
    return padChord(N(chord), t_cur) * env;
}

vec2 mainSound( int samp, float t )
{
    return padChordPattern(t);
}
```

---

## Théorie

### Deux horloges : « quel accord » et « depuis quand »

C'est le même raisonnement qu'à l'étape 01, mais pour des accords. On a besoin de deux mesures du temps :

```glsl
t = mod(t, 16.0*beatdur);          // (1) position dans la grille de 16 temps
...
float t_cur = mod(t, 4.0*beatdur); // (2) position dans l'accord courant
```

- **Horloge (1)** : `mod(t, 16*beatdur)` — où en est-on dans la boucle complète ? Sert à **sélectionner** l'accord via les tests `?:`.
- **Horloge (2)** : `mod(t, 4*beatdur)` — depuis combien de temps l'accord courant a-t-il commencé ? Sert à **alimenter** `padChord` (attaque `smoothstep`, etc.).

Sans la seconde, chaque accord recevrait un `t` toujours croissant et son attaque ne se rejouerait jamais. `padChord` doit toujours recevoir un temps qui **repart de 0** à chaque nouvel accord.

### La cascade `?:` — le séquenceur

```glsl
vec4 chord =
    (t < 4.0*beatdur)  ? vec4(...) :
    (t < 8.0*beatdur)  ? vec4(...) :
    (t < 12.0*beatdur) ? vec4(...) :
    (t < 14.0*beatdur) ? vec4(...) :
                         vec4(...);
```

Une chaîne d'opérateurs ternaires lue de haut en bas : le **premier** test vrai gagne. La grille n'est **pas régulière** :

| Temps | Durée | Accord (demi-tons) | Couleur |
|---|---|---|---|
| 0–4   | 4 temps | -3, -1, 0, 4   | La mineur |
| 4–8   | 4 temps | -3, 0, 2, 5    | Ré mineur 7 / Fa6 |
| 8–12  | 4 temps | -7, -3, 0, 7   | Fa add9 |
| 12–14 | **2 temps** | -5, 0, 2, 4 | Do add9 |
| 14–16 | **2 temps** | -5, -1, 2, 4 | Sol majeur |

Les deux derniers accords ne durent que 2 temps : la progression **accélère** en fin de boucle avant de retomber sur le premier accord. C'est un effet de **cadence** — la phrase « respire ».

> GLSL n'a pas de `switch` sur des plages de réels. La cascade `?:` est la forme idiomatique d'un séquenceur sur Shadertoy. Elle se déroule en quelques `mix`/`step` à la compilation : coût négligeable.

### `max(t, 0.0)` — la sécurité de départ

```glsl
t = max(t, 0.0);
```

On verra à l'étape 07 que `padChordPattern` sera appelée avec des temps **décalés vers le passé** (`t - beatdur`). Pour `t` proche de 0, l'argument peut devenir **négatif**. Un `t` négatif fausserait les `mod` et les `smoothstep`. `max(t, 0.0)` borne le problème dès l'entrée.

### Le fondu de sortie `smoothstep` décroissant

```glsl
float env = smoothstep(4.0*beatdur, 3.5*beatdur, t_cur);
```

Quand le **premier argument est plus grand que le second**, `smoothstep` est **décroissant** : il vaut 1 tant que `t_cur < 3.5*beatdur`, puis descend en douceur vers 0 entre `3.5` et `4.0*beatdur`.

Effet : chaque accord est **plein** pendant 3,5 temps puis **s'efface** sur le dernier demi-temps, juste avant que le suivant n'attaque. Sans ce fondu, le changement d'accord serait une discontinuité brutale → un « clic » audible. Le fondu de sortie + l'attaque `smoothstep` de `padSynth` forment ensemble un **crossfade** entre accords.

---

## Ce qu'on entend

Une progression de 5 accords planants qui s'enchaînent sans heurt, boucle toutes les 16 temps (≈ 9,6 s). Les deux accords courts en fin de cycle créent une petite accélération, puis tout retombe sur le La mineur du départ. C'est une vraie **trame harmonique**.

---

## Expérimentations suggérées

1. Réécrire la progression : remplacer les 5 `vec4` par vos propres accords.
2. Supprimer le fondu (`env = 1.0`) → écouter les **clics** aux changements d'accord. Restaurer ensuite.
3. Régulariser la grille : mettre les 5 tests à `4, 8, 12, 16, 20` et `mod(t, 20*beatdur)` → une boucle de 5 accords égaux.
4. Élargir le fondu : `smoothstep(4.0*beatdur, 2.0*beatdur, t_cur)` → les accords se chevauchent largement, effet très « nappe ».

---

## Limites de cette étape

La progression est nette mais **sèche** : pas de profondeur, pas de halo. Un pad d'ambiance vit dans une **réverbération**. On la fabrique à coût quasi nul à l'étape 07.

---

[[Étape 05 - Empiler un accord|← Étape 05]] · [[Étape 07 - Réverbération par échos|→ Étape 07 — Réverbération par échos]]

#shader #audio #shadertoy #td
