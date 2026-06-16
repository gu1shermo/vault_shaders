# Étape 07 — wahLead, balayage de filtre

> Décomposition [[shadertoy3 code]] — **étape 7 / 10**
> Concept : balayage rapide de `fc`, double enveloppe (filtre + amplitude).

---

## Objectif pédagogique

- Réemployer `filteredSaw` pour produire un effet **« wah »**.
- Comprendre l'enveloppe de filtre **en cloche** (montée puis descente).
- Distinguer enveloppe de **timbre** et enveloppe d'**amplitude**.

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
    // Un synthé bref qui fait "wah" (ou "waw" ?)
    float dur  = 0.1;
    float env  = smoothstep(0.0, dur/2.0, t) * smoothstep(dur,      dur/2.0, t);
    float env2 = smoothstep(0.0, dur/4.0, t) * smoothstep(2.0*dur,  dur,     t);
    float fc   = 400.0 + 10000.0*env;            // coupure balayée en cloche
    float sig  = filteredSaw(f, fc, t) * 0.1;
    return sig * env2;                            // enveloppe d'amplitude
}

vec2 mainSound( int samp, float t )
{
    float tt = mod(t, beatdur);
    return vec2(wahLead(N(4.0), tt));
}
```

---

## Théorie

### Le « wah », c'est un filtre qui bouge

Une pédale wah-wah de guitare déplace la **fréquence de coupure** d'un filtre d'avant en arrière. Le timbre s'ouvre puis se referme : l'oreille entend une voyelle qui passe de « ou » à « a » à « ou ».

Ici, pas de pédale : on fait **bouger `fc` tout seul**, automatiquement, à chaque note.

### L'enveloppe de filtre en cloche

```glsl
float env = smoothstep(0.0, dur/2.0, t) * smoothstep(dur, dur/2.0, t);
```

Produit de deux `smoothstep` :

- `smoothstep(0, dur/2, t)` : **monte** de 0 à 1 sur la première moitié,
- `smoothstep(dur, dur/2, t)` : **descend** de 1 à 0 sur la seconde (bornes inversées).

Le produit est une **cloche** : 0 → 1 → 0 sur la durée `dur` (0,1 s), pic au milieu.

```glsl
float fc = 400.0 + 10000.0*env;
```

`fc` balaie donc **400 Hz → 10 400 Hz → 400 Hz** : le filtre s'ouvre grand puis se referme. C'est le « wah ».

### Deux enveloppes, deux rôles

| Enveloppe | Fenêtre | Pilote | Effet |
|---|---|---|---|
| `env`  | `[0, dur]` = 0,1 s | la **coupure** `fc` | le balayage « wah » |
| `env2` | `[0, 2·dur]` = 0,2 s | l'**amplitude** | l'attaque et l'extinction |

`env2` est **plus longue** que `env` : le filtre a fini son aller-retour alors que le son n'est pas encore tout à fait éteint. C'est exactement le principe d'un synthé **soustractif** classique — un VCF (filtre) et un VCA (volume) avec deux enveloppes indépendantes — reproduit en formules pures.

> `filteredSaw` reçoit ici un `fc` **qui varie dans le temps** : la fonction de l'[[Étape 04 - Saw filtrée anti-aliasée|étape 04]] est sans état, on peut donc lui passer un cutoff différent à chaque échantillon sans aucun coût.

---

## Ce qu'on entend

Un son court et **expressif** qui fait « wah », répété chaque temps. Bref, vocal, parfait pour une ligne mélodique mordante.

---

## Expérimentations suggérées

1. Allonger `dur` à `0.3` → un wah lent et traînant.
2. Élargir le balayage : `fc = 200.0 + 18000.0*env` → effet plus spectaculaire.
3. Figer `fc = 3000.0` → plus de wah, juste une saw filtrée constante.
4. Échanger `env` et `env2` → l'amplitude devient une cloche, le filtre une longue rampe : timbre méconnaissable.

---

## Limites de cette étape

Un wah par temps, c'est monotone. L'étape suivante lui donne un **rythme tordu** avec des sauts d'octave, et l'enrobe d'un delay stéréo.

---

[[Étape 08 - Séquenceur wah et delay|→ Étape 08 — Séquenceur wah et delay]]

#shader #audio #shadertoy #td
