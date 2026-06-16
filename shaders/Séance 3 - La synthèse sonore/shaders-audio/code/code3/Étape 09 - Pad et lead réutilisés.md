# Étape 09 — Pad et lead réutilisés

> Décomposition [[shadertoy3 code]] — **étape 9 / 10**
> Concept : importer le pad et le lead du code 2, repérer ce qui a changé.

---

## Objectif pédagogique

- **Réutiliser** un instrument déjà conçu plutôt que le réécrire.
- Repérer les **modifications** apportées au pad du code 2.
- Comprendre l'intérêt du paramètre `tt` (LFO continu entre les notes).

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define FM(fc, fm, iom)  sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define FM2(pc, pm, iom) sin(mod(pc,TWOPI) + (iom)*sin(mod(pm,TWOPI)))
#define N(nn) 440.*exp2(((nn)-9.)/12.)

// ===== PAD (repris du code 2, avec un LFO piloté par tt) =====
vec2 padSynth(float f, float t, float tt)
{
    vec2 sig = vec2(0);
    sig += FM(f, f+vec2(-1.,1.62), 1.) * 0.03;
    sig += FM(f+2., f+vec2(1.,-1.62), 1.) * 0.02;
    float fc = f*round(2000./f);
    float iom = 1000./f;
    sig += FM(fc, f+vec2(0.7,-2.), iom*(1. - 0.5*sin(1.9*tt))) * 0.01;
    sig += FM(fc-2., f+vec2(-1.,1.6), iom*(1. + 0.5*sin(3.*tt))) * 0.007;
    float env = smoothstep(0., 0.3, t);
    return sig * env;
}

vec2 padChord(vec4 fs, float t, float tt)
{
    vec2 sig = vec2(0);
    sig += padSynth(fs.x, t, tt)    * vec2(0.8,0.3);
    sig += padSynth(fs.y, t, tt-1.) * vec2(1., 0.1);
    sig += padSynth(fs.z, t, tt+1.) * vec2(0.1, 1.);
    sig += padSynth(fs.w, t, tt-2.) * vec2(0.3, 0.8);
    return sig;
}

vec2 padChordPattern(float t)
{
    t = max(t, 0.);
    t = mod(t, 16.*beatdur);
    vec4 chord =
        (t <  4.*beatdur) ? vec4(-3., -1., 0., 4.) :
        (t <  8.*beatdur) ? vec4(-3.,  0., 2., 5.) :
        (t < 12.*beatdur) ? vec4(-7., -3., 0., 7.) :
        (t < 14.*beatdur) ? vec4(-5.,  2., 4., 7.) :
                            vec4(-5., -1., 2., 4.);
    float t_cur = mod(t, 4.*beatdur);
    float env = smoothstep(4.*beatdur, 3.99*beatdur, t_cur);
    return padChord(N(chord), t_cur, t) * env;
}

vec2 padChordPatternVerb(float t)
{
    return padChordPattern(t)
    + padChordPattern(t-0.75*beatdur) * 0.8
    + padChordPattern(t-1.5*beatdur)  * 0.5
    + padChordPattern(t-3.62*beatdur) * 0.5;
}

// ===== LEAD (identique au code 2) =====
float vibratoPhase(float f0, float semitones, float vibHz, float t)
{
    float df = 0.06*f0*semitones;
    return TWOPI*f0*t + df/vibHz*sin(TWOPI*vibHz*t);
}

vec2 leadSynth(float f, float t)
{
    vec2 sig = vec2(0);
    t = max(t, 0.);
    float vibEnv = smoothstep(0., 0.5, t);
    float phase = vibratoPhase(f, 0.2*vibEnv, 5., t);
    float tpt = TWOPI*t;
    sig += FM2(phase, phase, 1.) * 0.05;
    sig += FM2(phase+5.*tpt, phase+vec2(-1.,0.8)*tpt, 3.) * 0.02;
    float ratio = round(5000./f);
    float iom = 1500./f;
    sig += FM2(ratio*phase, phase, iom) * 0.01;
    sig += FM2(ratio*phase+5.*tpt, phase+vec2(3.,-3.)*tpt, iom) * 0.01;
    float fc = f*round(10000./f);
    iom = 10000./f;
    sig += FM(fc, f, iom) * 0.05 * exp(-30.*t);
    float env = 0.7*(1.+smoothstep(0.02,0.,t) + 0.3*smoothstep(0.,0.5,t));
    return sig * env;
}

vec2 leadSynthPattern(in float t)
{
    vec2 sig = vec2(0);
    t -= 1.75*beatdur;
    t = max(t, 0.);
    t = mod(t, 8.*beatdur);
    #define P(nn, b) sig += leadSynth(N(nn), t) * step(0., t) * smoothstep((b)*beatdur, (b)*beatdur-0.01, t); t -= (b)*beatdur;
    P(7., 0.25);  P(9., 0.5);  P(7., 1.);   P(9., 1.);
    P(9.+12., 0.5); P(16., 0.5); P(14., 1.); P(12., 0.5);
    P(9., 0.25);  P(7., 0.25); P(9., 1.5);
    #undef P
    return sig;
}

vec2 leadSynthPatternVerb(float t)
{
    return leadSynthPattern(t)
    + leadSynthPattern(t-0.005).yx     * vec2(0.3,0.7)
    + leadSynthPattern(t-0.75*beatdur) * 0.5 * vec2(-1,1)
    + leadSynthPattern(t-1.5*beatdur)  * 0.25 * vec2(-1,-1);
}

vec2 mainSound( int samp, float t )
{
    return padChordPatternVerb(t) + leadSynthPatternVerb(t);
}
```

---

## Théorie

### Réutiliser plutôt que réécrire

Le pad et le lead ont été **entièrement décortiqués** dans le code 2 ([[Étape 03 - padSynth le corps]] à [[Étape 10 - Séquenceur lead et mix final]]). Les recopier ici tels quels, c'est traiter un instrument comme une **brique réutilisable** — exactement ce qu'on attend d'une bibliothèque. On ne re-décompose pas : on **importe** et on note les différences.

### Ce qui a changé sur le pad

| Élément | Code 2 | Code 3 |
|---|---|---|
| Signature | `padSynth(f, t)` | `padSynth(f, t, tt)` |
| LFO de personnalité | `sin(1.9*t)`, `sin(3.*t)` | `sin(1.9*tt)`, `sin(3.*tt)` |
| Voix de `padChord` | même `t` partout | `tt`, `tt-1`, `tt+1`, `tt-2` |
| Reverb (`...Verb`) | échos + ping-pong `.yx` | 3 échos décalés (`0.75`, `1.5`, `3.62`) |

### Pourquoi le paramètre `tt` ?

Dans le code 2, le LFO de « personnalité » du pad oscillait sur `t`, le temps **local à la note** — il repartait donc de zéro à chaque accord.

Le code 3 sépare deux temps :

- `t` : le temps **local** à la note (pour l'enveloppe d'attaque `smoothstep(0., 0.3, t)`),
- `tt` : un temps **continu**, qui ne se réinitialise pas entre les accords.

Le LFO tourne désormais sur `tt` : il **balaie sans couture** d'un accord au suivant, au lieu de se relancer. Le pad respire de façon continue. Et `padChord` décale `tt` pour chaque voix (`tt-1`, `tt+1`, `tt-2`) → les quatre voix ne modulent pas en phase, l'accord est plus vivant.

> Leçon de conception : pour qu'une modulation soit **continue** malgré un séquenceur qui relance les notes, il faut lui passer un temps *qui*, lui, ne se relance pas. Un instrument bien fait sépare « temps de la note » et « temps du morceau ».

---

## Ce qu'on entend

La nappe (pad) et la mélodie (lead) du code 2, jouant ensemble — le **socle harmonique et mélodique** du morceau, sur lequel marimba, basse et wah vont venir se poser.

---

## Expérimentations suggérées

1. Jouer le pad seul (`return padChordPatternVerb(t);`) puis le lead seul → réviser le code 2.
2. Passer `t` au lieu de `tt` dans `padSynth` → réentendre le LFO « qui se relance » du code 2.
3. Donner le même `tt` aux 4 voix de `padChord` → l'accord se fige, moins de vie.
4. Retirer les échos de `padChordPatternVerb` → comparer avec/sans reverb.

---

## Limites de cette étape

Les cinq instruments existent. Les empiler bruts les fait **lutter dans le grave** : la basse et les attaques se masquent. L'étape finale règle ça avec une **compression sidechain** et assemble le mix.

---

[[Étape 10 - Sidechain et mix final|→ Étape 10 — Sidechain et mix final]]

#shader #audio #shadertoy #td
