# Étape 06 — Séquenceur de basse

> Décomposition [[shadertoy3 code]] — **étape 6 / 10**
> Concept : croches régulières, progression de fondamentales, `mod` de relance.

---

## Objectif pédagogique

- Construire la ligne de basse sur 16 temps.
- Comprendre le pattern 80's : **« jouer toutes les croches »**.
- Caler la progression de basse sous les accords du pad.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define N(nn) 440.*exp2(((nn)-9.)/12.)

float filteredSaw(float f, float fc, float t)
{
    float x = f*t;
    float w = min(0.5*f/fc, 0.5);
    x -= round(x);
    return mix(-2.0*x - 1.0, -2.0*x + 1.0, smoothstep(-w, w, x));
}

vec2 bassSynth(float f, float t)
{
    vec2 sig = vec2(0);
    float fc  = 15000.0*exp(-80.0*t) + 100.0;
    float fc2 = 15000.0*exp(-40.0*t) + 100.0;
    sig += 0.10*filteredSaw(f/2.0, fc, t);
    sig += 0.05*sin(TWOPI*fract(f/2.0*t));
    sig += 0.10*filteredSaw(f+1.618, fc2, t+1.0)*vec2(1.0,0.2);
    sig += 0.10*filteredSaw(f-1.0,  fc2, t+1.7)*vec2(0.2,1.0);
    return sig;
}

vec2 bassSynthPattern(float t)
{
    // Pattern de basse 80's : on joue juste toutes les croches !
    t = max(t, 0.0);
    t = mod(t, 16.0*beatdur);
    float nn =
        (t <  4.0*beatdur) ? -3.0 :
        (t <  8.0*beatdur) ?  2.0 :
        (t < 12.0*beatdur) ?  5.0 :
        (t < 14.0*beatdur) ?  0.0 :
                             -5.0;
    float f = N(nn)/2.0;                  // une octave plus bas
    t = mod(t, 0.5*beatdur);              // relance à chaque croche
    return bassSynth(f, t);
}

vec2 mainSound( int samp, float t )
{
    return bassSynthPattern(t);
}
```

---

## Théorie

### « Jouer toutes les croches »

La ligne de basse la plus simple — et l'une des plus efficaces de la house / techno 80's :

```glsl
t = mod(t, 0.5*beatdur);   // 0,5 temps = une croche
return bassSynth(f, t);
```

Une seule ligne de séquençage : `bassSynth` est **relancé à chaque croche**, sans exception. Pas de rythme à programmer — la régularité *est* le groove. C'est le moteur des *driving basslines*.

### La progression de fondamentales

```glsl
float nn =
    (t <  4.0*beatdur) ? -3.0 :   // mesure 1
    (t <  8.0*beatdur) ?  2.0 :   // mesure 2
    (t < 12.0*beatdur) ?  5.0 :   // mesure 3
    (t < 14.0*beatdur) ?  0.0 :   // demi-mesure 4
                         -5.0;    // demi-mesure 4 (suite)
```

Une fondamentale par tranche de 4 temps (mesure), avec un changement à la demi-mesure pour la dernière. Les numéros `{-3, 2, 5, 0, -5}` sont les **toniques** des accords joués par le pad : la basse pose le **fondement harmonique** sous la progression.

> `f = N(nn)/2.0` : la basse joue déjà la fondamentale **une octave plus bas**, et `bassSynth` redescend encore d'une octave pour son sub (`f/2.`). La fondamentale réelle du sub tombe donc dans la zone **40–100 Hz** — la « bonne » plage d'une basse (cf. [[Cours 3 - Marimba, Saw Bass, Wah Synth]] §2.6).

### `max(t, 0.0)` : protéger l'enveloppe

`bassSynth` contient des `exp(-λt)`. Pour `t < 0` (avant le début du morceau), `exp(-λt)` **explose**. Le `t = max(t, 0.0)` en tête de fonction garde le temps positif — un réflexe systématique avec les enveloppes exponentielles.

---

## Ce qu'on entend

Une **ligne de basse pulsée** régulière, une note par croche, qui change de fondamentale toutes les 4 mesures. C'est carré, hypnotique, dansant.

---

## Expérimentations suggérées

1. Remplacer `mod(t, 0.5*beatdur)` par `mod(t, beatdur)` → une note par temps : moins de drive.
2. Modifier la progression `nn` → tester d'autres toniques.
3. Retirer le `max(t, 0.0)` et démarrer le shader → écouter/observer la saturation des premières millisecondes.
4. Mettre `f = N(nn)` (sans `/2.`) → la basse remonte d'une octave : trop haute, ce n'est plus une basse.

---

## Limites de cette étape

La basse tient le grave. Il manque un instrument **expressif** dans le médium-aigu. L'étape suivante réutilise `filteredSaw` autrement : pour un **wah**.

---

[[Étape 07 - wahLead balayage de filtre|→ Étape 07 — wahLead, balayage de filtre]]

#shader #audio #shadertoy #td
