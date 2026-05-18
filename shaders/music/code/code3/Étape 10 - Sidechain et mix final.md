# Étape 10 — Sidechain et mix final

> Décomposition [[shadertoy3 code]] — **étape 10 / 10**
> Concept : compression sidechain simulée (*pumping*), dosage du mix. **Code final.**

---

## Objectif pédagogique

- Comprendre la **compression sidechain** et pourquoi elle est indispensable en musique électronique.
- Lire l'astuce `mix(pumping, 1., k)` : doser le *pumping* instrument par instrument.
- Assembler les **cinq instruments** en un mix équilibré.

---

## Code complet (onglet *Sound*) — identique à [[shadertoy3 code]]

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define FM(fc, fm, iom)  sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define FM2(pc, pm, iom) sin(mod(pc,TWOPI) + (iom)*sin(mod(pm,TWOPI)))
#define N(nn) 440.*exp2(((nn)-9.)/12.)

// ===== PAD =====
vec2 padSynth(float f, float t, float tt)
{
    vec2 sig = vec2(0);
    sig += FM(f, f+vec2(-1.,1.62), 1.) * 0.03;
    sig += FM(f+2., f+vec2(1.,-1.62), 1.) * 0.02;
    float fc = f*round(2000./f);
    float iom = 1000./f;
    sig += FM(fc, f+vec2(0.7,-2.), iom*(1. - 0.5*sin(1.9*tt))) * 0.01;
    sig += FM(fc-2., f+vec2(-1.,1.6), iom*(1. + 0.5*sin(3.*tt))) * 0.007;
    return sig * smoothstep(0., 0.3, t);
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
    t = max(t, 0.); t = mod(t, 16.*beatdur);
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

// ===== LEAD =====
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
    return sig * 0.7*(1.+smoothstep(0.02,0.,t) + 0.3*smoothstep(0.,0.5,t));
}
vec2 leadSynthPattern(in float t)
{
    vec2 sig = vec2(0);
    t -= 1.75*beatdur; t = max(t, 0.); t = mod(t, 8.*beatdur);
    #define P(nn, b) sig += leadSynth(N(nn), t) * step(0., t) * smoothstep((b)*beatdur, (b)*beatdur-0.01, t); t -= (b)*beatdur;
    P(7., 0.25); P(9., 0.5); P(7., 1.); P(9., 1.);
    P(9.+12., 0.5); P(16., 0.5); P(14., 1.); P(12., 0.5);
    P(9., 0.25); P(7., 0.25); P(9., 1.5);
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

// ===== BASS =====
float filteredSaw(float f, float fc, float t)
{
    float x = f*t;
    float w = min(0.5*f/fc, 0.5);
    x -= round(x);
    return mix(-2.*x-1., -2.*x+1., smoothstep(-w, w, x));
}
vec2 bassSynth(float f, float t)
{
    vec2 sig = vec2(0);
    float fc  = 15000.*exp(-80.*t) + 100.;
    float fc2 = 15000.*exp(-40.*t) + 100.;
    sig += 0.1*filteredSaw(f/2., fc, t);
    sig += 0.05*sin(TWOPI*fract(f/2.*t));
    sig += 0.1*filteredSaw(f+1.618, fc2, t+1.) * vec2(1.,0.2);
    sig += 0.1*filteredSaw(f-1.,   fc2, t+1.7) * vec2(0.2,1.);
    return sig;
}
vec2 bassSynthPattern(float t)
{
    t = max(t, 0.); t = mod(t, 16.*beatdur);
    float nn =
        (t <  4.*beatdur) ?-3. :
        (t <  8.*beatdur) ? 2. :
        (t < 12.*beatdur) ? 5. :
        (t < 14.*beatdur) ? 0. :
                           -5.;
    float f = N(nn)/2.;
    t = mod(t, 0.5*beatdur);
    return bassSynth(f, t);
}

// ===== WAH LEAD =====
float wahLead(float f, float t)
{
    float dur = 0.1;
    float env  = smoothstep(0.,dur/2., t) * smoothstep(dur,    dur/2., t);
    float env2 = smoothstep(0.,dur/4., t) * smoothstep(2.*dur, dur,    t);
    float fc = 400.+10000.*env;
    return filteredSaw(f, fc, t) * 0.1 * env2;
}
float wahLeadPattern(float t)
{
    t = max(0.,t); t = mod(t, 16.*beatdur);
    float nn =
        (t <  4.*beatdur) ? 4. :
        (t <  8.*beatdur) ? 5. :
        (t < 12.*beatdur) ? 5. :
        (t < 14.*beatdur) ? 4. :
                            2.;
    t = mod(t, 8.*beatdur);
    float t1 = mod(t, 4.*beatdur);
    t1 = mod(t1, 1.75*beatdur);
    t1 = mod(t1, 1.5*beatdur);
    if(2.25*beatdur <= t && t < 4.*beatdur) { nn += 12.; t -= 2.25*beatdur; }
    else { t = t1; }
    return wahLead(N(nn), t);
}
vec2 wahLeadPatternVerb(float t)
{
    vec2 sig = vec2(0);
    sig.x += wahLeadPattern(t);
    sig.y += wahLeadPattern(t - 0.52*beatdur);
    sig   += wahLeadPattern(t - 1.54*beatdur) * vec2(-0.5,0.1);
    sig   += wahLeadPattern(t - 1.78*beatdur) * vec2(0.1,-0.5);
    return sig;
}

// ===== MARIMBA =====
float marimba(float f, float t)
{
    return FM(f, 7.*f, 1.5*exp(-80.*t)) * exp(-5.*t) * 0.1;
}
vec2 marimbaPattern(float t)
{
    t = mod(t, 16.*beatdur);
    vec2 nn =
        (t <  4.5*beatdur) ? vec2(4.,12.) :
        (t <  8.*beatdur)  ? vec2(5.,9.)  :
        (t < 12.5*beatdur) ? vec2(9.,12.) :
        (t < 14.*beatdur)  ? vec2(7.,12.) :
                             vec2(7.,11.);
    t = mod(t, 8.*beatdur);
    t = mod(t, 6.*beatdur);
    t = mod(t, 0.75*beatdur);
    vec2 sig = vec2(0);
    sig += marimba(N(nn.x), t) * vec2(0.7,0.2);
    sig += marimba(N(nn.y), t) * vec2(0.1,0.5);
    return sig;
}

// ===== MAIN SOUND =====
vec2 mainSound( int samp, float t )
{
    vec2 sig = vec2(0);

    // Compression sidechain simulée :
    // on baisse le signal au début de chaque temps.
    float pumping = smoothstep(0., 0.2, mod(t,beatdur))
                  * smoothstep(beatdur, beatdur-0.01, mod(t,beatdur));

    sig += padChordPatternVerb(t)  * mix(pumping, 1., 0.5) * 0.7;
    sig += leadSynthPatternVerb(t) * mix(pumping, 1., 0.7) * 0.8;
    sig += wahLeadPatternVerb(t)   * mix(pumping, 1., 0.5) * 0.7;
    sig += bassSynthPattern(t)     * mix(pumping, 1., 0.2);
    sig += marimbaPattern(t)       * mix(pumping, 1., 0.7);

    return sig;
}
```

---

## Théorie

### Le problème : l'embouteillage du grave

Cinq instruments sommés, ça sature. Surtout, la **basse** et les **attaques** des autres instruments occupent la même zone d'énergie au **même instant** — le début du temps. Résultat : tout se masque, le mix devient boueux et le signal *clippe*.

### La compression sidechain

En techno / house, un **kick** frappe sur chaque temps. La parade de mixage consiste à **baisser le volume des autres instruments pile quand le kick frappe**, puis à les laisser remonter. C'est la **compression sidechain** — le fameux effet de « pompe » qui fait *respirer* le morceau.

Ici il n'y a même pas de kick : on **simule directement son effet**. Une enveloppe suffit.

```glsl
float pumping = smoothstep(0., 0.2, mod(t,beatdur))
              * smoothstep(beatdur, beatdur-0.01, mod(t,beatdur));
```

`mod(t, beatdur)` est la position dans le temps courant. `pumping` vaut :

- **0** au tout début du temps (le « kick » virtuel),
- remonte à **1** en 0,2 s (`smoothstep(0., 0.2, …)`),
- reste à **1**, puis retombe juste avant le temps suivant.

Chaque temps, le mix est donc **brièvement creusé** : il pompe.

### `mix(pumping, 1., k)` : doser instrument par instrument

```glsl
sig += bassSynthPattern(t) * mix(pumping, 1., 0.2);   // k = 0.2
sig += marimbaPattern(t)   * mix(pumping, 1., 0.7);   // k = 0.7
```

`mix(pumping, 1., k)` interpole entre `pumping` (sidechain à fond) et `1.` (aucun sidechain). `k` est le **taux d'épargne** :

| `k` | Effet | Instruments |
|---|---|---|
| `0.2` | fortement pompé | basse |
| `0.5` | moyennement pompé | pad, wah |
| `0.7` | à peine pompé | lead, marimba |

La **basse pompe fort** (`k=0.2`) : c'est elle qui doit céder la place au kick. Le **lead pompe peu** (`k=0.7`) : il porte la mélodie, on ne veut pas qu'il disparaisse. Doser `k` par instrument, c'est faire du mix.

### Le dosage final

Chaque ligne porte aussi un gain global (`0.7`, `0.8`, `1.0` implicite pour basse et marimba). C'est l'**équilibre des niveaux** : on règle qui domine. Réflexe de fin de morceau — exporter le `.wav`, vérifier dans Audacity que le pic ne dépasse pas `±0,95`, sinon baisser les coefficients.

---

## Ce qu'on entend

Le **morceau complet** : nappe, mélodie, basse pulsée, wah planant, marimba à contretemps — le tout qui **respire** à 100 BPM grâce au sidechain. C'est le code 3 dans son état final.

---

## Expérimentations suggérées

1. Forcer `pumping = 1.` (commenter le calcul) → le morceau ne respire plus : comparer.
2. Mettre tous les `k` à `0.2` → tout pompe fort : effet « pompe » exagéré.
3. Couper des instruments un par un (commenter une ligne `sig += …`) → isoler chaque rôle dans le mix.
4. Exporter 30 s en `.wav`, ouvrir dans Audacity, vérifier le pic et le spectre.

---

## Bilan de la décomposition

En 10 étapes, le morceau à cinq instruments du code 3 a été reconstruit :

- **Marimba** : FM inharmonique, ratio 7:1, index décroissant.
- **`filteredSaw`** : anti-aliasing analytique — le pivot, partagé par basse et wah.
- **Basse** : enveloppe de coupure (« stab »), sub mono, détune stéréo.
- **Wah** : balayage de filtre en cloche, double enveloppe.
- **Pad + lead** : importés du code 2, avec un LFO continu (`tt`).
- **Mix** : compression sidechain dosée par instrument.

> Le fil rouge des trois codes : tout exprimer en **fonction du temps `t`**, sans état, sans récursion — et compenser ces contraintes par des **astuces** (`fract`, `mod`, sommes décalées, anti-aliasing analytique).

---

## Pour aller plus loin

- Ajouter un vrai **kick** synchronisé sur `pumping` (cf. [[Cours 3 - Marimba, Saw Bass, Wah Synth]] §3).
- Remplacer `filteredSaw` par une saw **additive band-limitée** (somme d'harmoniques) et comparer.
- Brancher l'onglet **Image** (le visualiseur de croches) sur ce son.
- Composer une variation : nouvelle progression d'accords, nouveaux motifs.

---

[[Étape 09 - Pad et lead réutilisés|← Étape 09]] · [[_Index - Décomposition shadertoy3|Retour à l'index]]

#shader #audio #shadertoy #td
