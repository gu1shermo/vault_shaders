# Étape 08 — Séquenceur wah et delay

> Décomposition [[shadertoy3 code]] — **étape 8 / 10**
> Concept : rythme par cascade de `mod`, saut d'octave conditionnel, delay stéréo.

---

## Objectif pédagogique

- Construire un rythme **irrégulier** à partir de replis de `mod`.
- Insérer un comportement conditionnel : le **saut d'octave**.
- Ajouter un **delay / reverb** par sommes décalées.

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

float wahLead(float f, float t)
{
    float dur  = 0.1;
    float env  = smoothstep(0.0, dur/2.0, t) * smoothstep(dur,     dur/2.0, t);
    float env2 = smoothstep(0.0, dur/4.0, t) * smoothstep(2.0*dur, dur,     t);
    float fc   = 400.0 + 10000.0*env;
    return filteredSaw(f, fc, t) * 0.1 * env2;
}

float wahLeadPattern(float t)
{
    // Un rythme bizarre avec le synthé "wah"
    t = max(0.0, t);
    t = mod(t, 16.0*beatdur);
    // Notes prises dans les accords
    float nn =
        (t <  4.0*beatdur) ? 4.0 :
        (t <  8.0*beatdur) ? 5.0 :
        (t < 12.0*beatdur) ? 5.0 :
        (t < 14.0*beatdur) ? 4.0 :
                             2.0;
    t = mod(t, 8.0*beatdur);
    float t1 = mod(t, 4.0*beatdur);
    t1 = mod(t1, 1.75*beatdur);
    t1 = mod(t1, 1.5*beatdur);
    if (2.25*beatdur <= t && t < 4.0*beatdur)
    {
        nn += 12.0;            // saute une octave de temps en temps
        t  -= 2.25*beatdur;
    }
    else
    {
        t = t1;
    }
    return wahLead(N(nn), t);
}

vec2 wahLeadPatternVerb(float t)
{
    // Delay/reverb "trippy"
    vec2 sig = vec2(0);
    sig.x += wahLeadPattern(t);
    sig.y += wahLeadPattern(t - 0.52*beatdur);
    sig   += wahLeadPattern(t - 1.54*beatdur) * vec2(-0.5, 0.1);
    sig   += wahLeadPattern(t - 1.78*beatdur) * vec2( 0.1,-0.5);
    return sig;
}

vec2 mainSound( int samp, float t )
{
    return wahLeadPatternVerb(t);
}
```

---

## Théorie

### Un rythme par replis successifs

```glsl
t = mod(t, 8.0*beatdur);
float t1 = mod(t, 4.0*beatdur);
t1 = mod(t1, 1.75*beatdur);
t1 = mod(t1, 1.5*beatdur);
```

Replier `t` par `1.75` puis par `1.5` (en temps) ne donne **pas** un rythme régulier : les restes successifs créent un motif **boiteux**, asymétrique. C'est voulu — le « rythme bizarre » du commentaire. Empiler des `mod` de périodes non multiples est une recette pour fabriquer du **groove syncopé** sans tableau de positions.

### Le saut d'octave conditionnel

```glsl
if (2.25*beatdur <= t && t < 4.0*beatdur)
{
    nn += 12.0;            // +12 demi-tons = une octave
    t  -= 2.25*beatdur;
}
else
{
    t = t1;
}
```

Sur une fenêtre précise de la boucle (entre 2,25 et 4 temps), le motif **monte d'une octave** (`nn += 12`) et utilise un autre découpage temporel. Ailleurs, il prend le rythme boiteux `t1`. Ce `if` introduit une **variation** : sans lui, les 8 temps seraient identiques. C'est la touche d'imprévu qui rend la ligne vivante.

### Le delay stéréo

```glsl
vec2 wahLeadPatternVerb(float t)
{
    vec2 sig = vec2(0);
    sig.x += wahLeadPattern(t);                              // direct, à gauche
    sig.y += wahLeadPattern(t - 0.52*beatdur);               // direct décalé, à droite
    sig   += wahLeadPattern(t - 1.54*beatdur) * vec2(-0.5, 0.1);  // écho 1
    sig   += wahLeadPattern(t - 1.78*beatdur) * vec2( 0.1,-0.5);  // écho 2
    return sig;
}
```

Faute de mémoire tampon en shader, on **rappelle la fonction de motif à des temps passés** : `wahLeadPattern(t - d)` *est* le signal d'il y a `d` secondes. En sommer plusieurs copies, décalées et atténuées, simule un **delay / reverb** (cf. [[Étape 07 - Réverbération par échos]] du code 2).

Ici les retards sont **différents entre L et R** (`t` vs `t - 0.52*beatdur`) et les gains pannés en miroir : les échos rebondissent d'un côté à l'autre — l'effet « trippy » ping-pong.

> Coût : chaque écho **recalcule entièrement** le motif. Quatre appels = quatre fois le calcul. À surveiller quand on empile les instruments.

---

## Ce qu'on entend

Une ligne de wah **syncopée**, qui grimpe parfois d'une octave, noyée dans un delay stéréo qui rebondit gauche/droite. Hypnotique et « planant ».

---

## Expérimentations suggérées

1. Commenter les deux lignes d'écho → comparer le wah sec *vs* avec delay.
2. Désactiver le saut d'octave (`if (false)`) → le motif perd sa variation.
3. Changer les retards `1.54` / `1.78` → autres rythmes d'écho.
4. Remplacer `mod(t1, 1.5*beatdur)` par `mod(t1, 1.0*beatdur)` → rythme moins boiteux.

---

## Limites de cette étape

Marimba, basse, wah : trois instruments prêts. Manquent le **pad** et le **lead** — repris du code 2. C'est l'objet de l'étape suivante.

---

[[Étape 09 - Pad et lead réutilisés|→ Étape 09 — Pad et lead réutilisés]]

#shader #audio #shadertoy #td
