	# Étape 08 — Séquenceur jingle (assemblage final)

> Décomposition [[shadertoy1 code]] — **étape 8 / 8**
> Concept : dérouler une séquence de notes via un **tableau constant** et une **boucle `for` bornée**.

---

## Objectif pédagogique

- Stocker une mélodie dans un **tableau GLSL `const`**.
- Utiliser une **boucle `for` à borne compile-time** pour dérouler le séquenceur sur GPU.
- Spatialiser chaque note **différemment** selon son index.
- Comprendre les **pièges** des notes négatives en `t` et de la précision flottante.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

float FM(float fc, float fm, float iom, float t)
{
    return sin(TWOPI*fc*t + iom*sin(TWOPI*fm*t));
}

vec2 fmPluck(float f, float t)
{
    float env = exp(-3.0*t) * 0.1;
    vec2 sig = vec2(0.0);
    sig.x += FM(f + 1.0, f + 1.0, 1.0, t) * env;
    sig.y += FM(f - 1.0, f - 1.0, 1.0, t) * env;
    sig += FM(f, f, 15.0, t) * exp(-20.0*t) * 0.03;
    return sig;
}

vec2 pan(float pos)
{
    return normalize(vec2(1.0 - pos, 1.0 + pos));
}

float interval(float semitones)
{
    return pow(2.0, semitones / 12.0);
}

const float notes[] = float[6](-12.0, -5.0, 2.0, -5.0, 3.0, 5.0);

vec2 jingle(float t)
{
    vec2 sig = vec2(0.0);
    for (int i = 0; i < 6; i++)
    {
        float nn  = notes[i];                       // demi-tons depuis La 440
        float fi  = 440.0 * interval(nn);           // fréquence de la note i
        float t0i = 0.25 * float(i);                // décalage temporel : 0.25 s par note
        float ti  = mod(t - t0i, 2.0);              // boucle de 2 s
        float pos = float((i + 1) % 3) - 1.0;       // -1 / 0 / +1 / -1 / 0 / +1

        sig += fmPluck(fi, ti) * pan(pos);
    }
    return sig;
}

vec2 mainSound( int samp, float t )
{
    return jingle(t);
}
```

---

## Théorie

### Le tableau `const float[]`

```glsl
const float notes[] = float[6](-12.0, -5.0, 2.0, -5.0, 3.0, 5.0);
```

- `float[6](...)` est le **constructeur d'array** GLSL 4.0+. La taille **doit être connue à la compilation**.
- Le qualifier `const` permet au compilateur de placer les valeurs dans une **mémoire constante** (`uniform buffer` ou similaire) et de dérouler les accès indexés.
- L'écriture `float notes[]` (sans `6` après) est une **forme inférée** valide quand la taille est claire d'après le constructeur.

#### Décodage musical de la séquence

| `i` | Demi-tons | Fréquence | Note | Pan |
|---|---|---|---|---|
| 0 | -12 | 220 Hz | La 2 (octave basse) | 0 |
| 1 | -5 | 329.6 Hz | Mi 3 | +1 |
| 2 | +2 | 493.9 Hz | Si 3 | -1 |
| 3 | -5 | 329.6 Hz | Mi 3 | 0 |
| 4 | +3 | 523.3 Hz | Do 4 | +1 |
| 5 | +5 | 587.3 Hz | Ré 4 | -1 |

La sélection des notes (-12, -5, +2, -5, +3, +5) trace une mini-mélodie ascendante avec un rebond, typique d'un **jingle d'appel**.

### La boucle `for` déroulée

```glsl
for (int i = 0; i < 6; i++) { ... }
```

GLSL **ne supporte pas la récursion** et a un support très limité des boucles dynamiques. Mais :

- Les bornes sont des **littéraux entiers** (`0`, `6`) connus à la compilation.
- Les accès `notes[i]` se font dans un tableau de taille fixe.

⇒ le compilateur **déroule** complètement la boucle en 6 copies du corps. C'est l'équivalent shader d'un **séquenceur déroulé**, où le « temps » de la séquence n'existe pas dynamiquement : la **partition est inscrite dans le binaire**.

> Pour 100 notes, on déroule 100 fois. Pour 10 000 notes, on dépasse la taille des shaders et il faut **un autre paradigme** (par exemple un texture lookup avec les notes encodées en pixels).

### Le décalage temporel `t0i`

```glsl
float t0i = 0.25 * float(i);
float ti  = mod(t - t0i, 2.0);
```

- À `t = 0`, la note 0 démarre (`ti = 0`).
- À `t = 0.25`, la note 1 démarre.
- À `t = 1.25`, la note 5 (dernière) démarre.
- À `t = 2.0`, retour à la note 0.

**Piège critique** : sans `mod`, pour `i = 5` et `t < 1.25`, on aurait `ti = t - 1.25 < 0`. Or :

```glsl
exp(-3.0 * (-0.5)) = exp(1.5) ≈ 4.48
```

⇒ l'enveloppe **explose** au lieu de décroître, et la voix dépasse `[-1, +1]` en clipping violent.

Le `mod` évite ça en projetant `t - t0i` dans `[0, 2.0)`. Effet de bord : la note 5 commence à `t = 1.25` **et** se redéclenche à `t = 1.25 + 2 = 3.25` au lieu de continuer linéairement — c'est exactement ce qu'on veut pour une boucle.

> **Alternative** : `ti = max(t - t0i, 0.0)` ne redéclenche pas mais évite l'explosion. À utiliser pour des séquences **one-shot**.

### Le panning indexé

```glsl
float pos = float((i + 1) % 3) - 1.0;
```

Pour `i = 0, 1, 2, 3, 4, 5` : `(i+1) % 3` donne `1, 2, 0, 1, 2, 0` → `pos` donne `0, +1, -1, 0, +1, -1`.

C'est une **distribution cyclique** sur 3 positions stéréo. Coût zéro à l'exécution. Effet : la mélodie **rebondit** dans l'espace.

---

## Ce qu'on entend

Une mélodie courte de 6 notes, étalée stéréo, qui **boucle** toutes les 2 secondes. Le timbre est riche (corps + attaque FM), l'espace est vivant (chaque note rebondit dans une position différente), et l'enchaînement temporel est musical (0.25 s par note ≈ 240 BPM en doubles-croches).

C'est le **jingle complet** de [[shadertoy1 code]] — vous venez de le reconstruire en 8 étapes.

---

## Expérimentations suggérées

1. **Changer la mélodie** : remplacer le tableau par votre propre suite de demi-tons.
   ```glsl
   const float notes[] = float[8](0.0, 2.0, 4.0, 5.0, 7.0, 9.0, 11.0, 12.0); // gamme de Do majeur
   ```
   Ajuster `i < 8` dans la boucle.

2. **Tempo variable** : remplacer `0.25 * float(i)` par `0.125 * float(i)` (deux fois plus rapide) ou `0.5 * float(i)` (deux fois plus lent).

3. **Polyphonie verticale** : pour chaque note, jouer **deux notes simultanément** distantes d'une quinte :
   ```glsl
   sig += fmPluck(fi,                ti) * pan(pos);
   sig += fmPluck(fi * interval(7.0), ti) * pan(-pos) * 0.7;
   ```

4. **Auto-modulation du tempo** : moduler la vitesse par un sinus très lent → l'effet « horloge ralentie » des films oniriques.
   ```glsl
   float speed = 1.0 + 0.3 * sin(TWOPI * 0.1 * t);
   float t0i = 0.25 * float(i) / speed;
   ```

5. **Visualisation associée** : dans `mainImage`, lire le même tableau `notes` et afficher une **partition visuelle** avec l'indicateur de la note en cours. Le code audio et visuel partagent leur état uniquement via `iTime`.

---

## Récapitulatif du parcours

| # | Concept | Code clé |
|---|---|---|
| 01 | Onde pure | `sin(TWOPI*f*t) * 0.1` |
| 02 | Enveloppe + retrigger | `exp(-3*t)`, `mod(t, 1.0)` |
| 03 | Variantes timbrales + aliasing | `sign(sin)`, `mod(t*f, 1)*2-1` |
| 04 | Phase modulation | `sin(TWOPI*fc*t + iom*sin(TWOPI*fm*t))` |
| 05 | Stratification stéréo | détune ±1, double layer |
| 06 | Spatialisation propre | `normalize(vec2(1-p, 1+p))` |
| 07 | Hauteurs musicales | `pow(2, semitones/12)` |
| 08 | Séquenceur déroulé | `const float[]`, `for i<N`, `mod` |

---

## Limites du code final

- Toutes les notes ont la **même durée d'enveloppe** (`λ = 3`). Un vrai instrument adapte la durée à la note (basses longues, aigus courts).
- Pas de **dynamique** : toutes les notes ont la même intensité.
- Pas de **micro-désynchronisation** humaine : c'est métronomiquement parfait, donc un peu mécanique.
- Pas de **réverbération**, pas de couleur d'espace.

Ces points sont précisément les axes développés dans les [[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2]] et [[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3]].

---

[[Étape 07 - Intervalles et tempérament|← Étape 07]] · [[_Index - Décomposition shadertoy1|↑ Index]]

#shader #audio #shadertoy #td
