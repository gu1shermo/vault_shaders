# Cours 1 — Bases, waveforms et mélodie


---

## 1. Pourquoi faire de la musique dans un shader ?

Un shader Shadertoy n'est pas seulement un programme qui calcule la couleur d'un pixel. L'onglet **Sound** permet d'écrire une fonction `mainSound` qui, exactement comme `mainImage` pour les pixels, est évaluée **en parallèle sur le GPU**, mais cette fois pour chaque **échantillon audio**.

| `mainImage` | `mainSound` |
|---|---|
| `out vec4 fragColor` | `vec2` retour |
| `in vec2 fragCoord` | `in float time` |
| 1 invocation = 1 pixel | 1 invocation = 1 sample |
| Sortie : couleur RGBA | Sortie : amplitude stéréo (L, R) |

La fréquence d'échantillonnage de Shadertoy est **44 100 Hz**, donc la fonction est appelée 44 100 fois par seconde.

### Signature

```glsl
vec2 mainSound( in int samp, float time )
{
    // time = position temporelle de l'échantillon (en secondes)
    // retour.x = canal gauche, retour.y = canal droit
    return vec2( /* amplitude L */, /* amplitude R */ );
}
```

> Si on retourne un `float`, GLSL le promeut en `vec2(x, x)` → signal **mono**.

### Contrainte fondamentale : domaine de sortie

L'amplitude doit rester dans `[-1, +1]`. Au-delà, le signal **clippe** (écrêtage) : c'est l'équivalent audio d'une couleur qui sature. C'est :

- audible (distorsion désagréable),
- destructif lorsqu'on **somme plusieurs voix** (rapidement on sort de l'intervalle),
- la principale raison pour laquelle on multiplie systématiquement les signaux par une **amplitude < 1**.

---

## 2. Première onde : sinus pur

```glsl
#define TAU 6.2831853

float a = 440.0; // La 3 (440 Hz, le "La" de référence)
float sig = sin( TAU * a * time );
```

### Théorie

Une onde sinusoïdale de fréquence `f` a pour expression : $s(t) = \sin(2\pi f t)$.

- Le terme `TAU * f * t` est la **phase**, en radians.
- Une période complète vaut $2\pi$, ce qui correspond à un temps $T = 1/f$.

Plus `f` est élevée, plus la note est **aiguë**. L'oreille humaine perçoit grosso modo de **20 Hz à 20 kHz**, et la perception de la hauteur est **logarithmique** : doubler la fréquence = monter d'une octave.

---

## 3. Enveloppe : façonner le son dans le temps

Une onde brute joue à amplitude constante : aucun instrument réel ne fait ça. Tous les sons percussifs présentent une **décroissance exponentielle** de leur énergie.

```glsl
float env = exp( -3.0 * t );
float sig = 0.1 * sin( TAU * 440.0 * t ) * env;
```

### Pourquoi exponentielle ?

Dans la nature, l'amortissement d'un oscillateur (corde, membrane, lame de marimba…) est régi par une équation différentielle linéaire : la solution décroît en $e^{-\lambda t}$. Le coefficient $\lambda$ contrôle la **vitesse de décroissance** :

- $\lambda$ grand → percussion sèche (claquement),
- $\lambda$ petit → son long (cloche, cymbale).

> **Outil indispensable** : [graphtoy.com](https://graphtoy.com) — visualise vos enveloppes avant de les entendre. C'est le même auteur (Iñigo Quílez) que Shadertoy.

---

## 4. Factoriser : `sinpluck`

On encapsule l'idée « note plucked » (pincée) dans une fonction réutilisable :

```glsl
float sinpluck(float f, float t) {
    return 0.1 * sin(TAU * f * t) * exp(-3.0 * t);
}

vec2 mainSound(int samp, float time) {
    float sig = 0.0;
    sig += sinpluck(440.0, time);   // La
    sig += sinpluck(660.0, time);   // Mi (quinte)
    return vec2(sig);
}
```

Sommer deux sinus produit un **intervalle harmonique** (ici une quinte). Mais les deux notes commencent en même temps et ne se répètent jamais.

---

## 5. Répétition temporelle : `mod`

Pour qu'une note se redéclenche périodiquement, on remplace `t` par un temps **modulo une période** :

```glsl
float tNote = mod(time, 1.0);   // se réinitialise toutes les secondes
sig += sinpluck(440.0, tNote);
```

### Détail subtil : `1.0` vs `1`

GLSL **n'autorise pas la conversion implicite** entre `int` et `float`. `mod(time, 1)` ne compilera pas. Toujours écrire `1.0`.

### Décaler une note dans le temps

```glsl
sig += sinpluck(660.0, mod(time + 0.5, 1.0));
```

`+ 0.5` retarde le redéclenchement d'une demi-seconde. C'est la base d'un séquenceur rudimentaire.

---

## 6. Panning stéréo

`mainSound` retourne un `vec2`. On peut différencier le canal gauche (`.x`) et droit (`.y`) :

```glsl
vec2 sig = vec2(0.0);
sig += sinpluck(440.0, t) * vec2(1.0, 0.0);  // 100% gauche
sig += sinpluck(660.0, t) * vec2(0.0, 1.0);  // 100% droit
```

### Fonction de panning généralisée

On veut un paramètre `p ∈ [-1, +1]` (gauche → droite) qui ne change pas le volume perçu.

```glsl
vec2 pan(float p) {
    return normalize( vec2(1.0 - p, 1.0 + p) );
}
```

- `p = -1` → `(2, 0)` → après normalisation : tout à gauche.
- `p =  0` → `(1, 1)` → centre.
- `p = +1` → `(0, 2)` → tout à droite.

> **Pourquoi normaliser ?** Sans la normalisation, l'énergie totale du signal dépend de la position : un son centré (`vec2(1,1)`) serait plus fort qu'un son latéralisé (`vec2(2,0)`). La normalisation maintient $\sqrt{L^2 + R^2} = 1$, une **loi de panning constant power**.

---

## 7. Catalogue de waveforms

### 7.1 Square (carrée)

```glsl
float sq = sign( sin(TAU * f * t) );
```

`sign()` renvoie `+1` pour `sin > 0`, `-1` sinon. Très riche en harmoniques **impaires** : $f, 3f, 5f, 7f…$

### 7.2 Saw (dents de scie)

```glsl
float saw = mod(t * f, 1.0) * 2.0 - 1.0;   // [-1, +1] avec discontinuité
```

Toutes les harmoniques : $f, 2f, 3f, 4f…$. Timbre brillant, agressif.

### 7.3 ⚠️ Le problème : l'**aliasing**

Les ondes carrées et saw contiennent **un nombre infini d'harmoniques**. Or, le théorème de **Nyquist-Shannon** dit qu'on ne peut représenter sans ambiguïté qu'à des fréquences inférieures à la moitié du taux d'échantillonnage (22 050 Hz dans Shadertoy).

Les harmoniques **au-dessus** de Nyquist se replient (« *fold back* ») dans le spectre audible sous forme de **fréquences erronées** non harmoniques.

> **Analogie visuelle** : c'est exactement le **wagon-wheel effect** — la roue de la diligence dans les vieux westerns qui semble tourner à l'envers parce que la fréquence de capture est trop basse.

Conséquence : sur Shadertoy, une saw brute à 440 Hz **sonne sale** dans les aigus. On y reviendra en cours 3 (anti-aliasing manuel).

---

## 8. Modulation de fréquence (FM) — l'arme de prédilection

C'est **la** technique recommandée pour Shadertoy : aucune intégration coûteuse, très peu d'aliasing, énormément de timbres possibles.

### 8.1 Formulation

```glsl
float fmpluck(float fc, float fm, float iom, float t) {
    return sin( TAU * fc * t + iom * sin(TAU * fm * t) )
         * exp(-3.0 * t);
}
```

Trois paramètres :

- **`fc`** — *carrier frequency* : la fréquence porteuse, perçue comme la hauteur.
- **`fm`** — *modulator frequency* : la fréquence modulante, contrôle la **structure harmonique**.
- **`iom`** — *index of modulation* : profondeur de modulation, contrôle la **richesse spectrale**.

> **Précision technique** : strictement parlant, ceci est de la **phase modulation**. La vraie FM dérive le terme. En pratique audio, les deux donnent le même résultat tant que `fm` est fixe — c'est l'usage standard.

### 8.2 Effet des paramètres

| Paramètre | Quand on l'augmente | Métaphore |
|---|---|---|
| `iom` | Plus de partiels, son plus riche, plus métallique | « dureté » |
| `fm/fc` entier | Spectre harmonique propre | son tonal |
| `fm/fc` non-entier | Spectre inharmonique | cloches, métal frappé |

### 8.3 Exemple : un pluck stéréo riche

```glsl
vec2 sig = vec2(0.0);
sig.x = fmpluck(f,  f, 1.0, t);
sig.y = fmpluck(f, -f, 1.0, t);   // déphasage stéréo

// attaque agressive
sig += fmpluck(f, f, 15.0, t) * exp(-10.0 * t) * 0.3;
```

L'astuce : superposer deux FM, l'une avec un `iom` faible et une enveloppe lente (le « corps » du son), l'autre avec un `iom` élevé et une enveloppe **rapide** (l'« attaque »).

---

## 9. Construire une mélodie

### 9.1 Tempérament égal

En musique occidentale moderne, l'**octave est divisée en 12 demi-tons égaux**. La fréquence d'une note distante de `n` demi-tons d'une référence vaut :

$$ f_n = f_{\text{ref}} \times 2^{n/12} $$

En GLSL :

```glsl
#define A4 440.0
float noteFreq(float semitones) {
    return A4 * exp2(semitones / 12.0);
}
```

> `exp2(x)` = $2^x$. C'est moins cher et plus précis que `pow(2.0, x)`.

### 9.2 Séquence de notes

```glsl
const float notes[6] = float[6]( 0.0, 7.0, 14.0, 7.0, 3.0, 5.0 );

vec2 jingle(float time) {
    vec2 sig = vec2(0.0);
    for (int i = 0; i < 6; i++) {
        float fi  = noteFreq(notes[i]);
        float t0i = 0.25 * float(i);                       // démarre tous les 0.25 s
        float ti  = mod(time - t0i, 2.0);                  // boucle 2 s
        sig += fmpluck(fi, fi, 1.0, ti) * pan( mod(float(i), 3.0) - 1.0 );
    }
    return sig;
}
```

### Points pédagogiques importants

1. **Les notes négatives** : avant `t0i`, `ti` est négatif → `exp(-3 * ti)` **explose** ! Il faut soit `mod` (comme ici), soit `max(t, 0.0)`.
2. **La boucle `for`** est dépliée par le compilateur — GLSL n'aime pas les boucles dynamiques, mais une taille fixe + tableau constant marche partout.
3. **Le panning indexé** spatialise la mélodie sans coût supplémentaire.

---

## 10. Récapitulatif du shader complet

```glsl
#define TAU 6.2831853
#define A4  440.0

float noteFreq(float n) { return A4 * exp2(n / 12.0); }

vec2 pan(float p) { return normalize(vec2(1.0 - p, 1.0 + p)); }

float fmpluck(float fc, float fm, float iom, float t) {
    if (t < 0.0) return 0.0;
    return sin(TAU * fc * t + iom * sin(TAU * fm * t)) * exp(-3.0 * t);
}

const float notes[6] = float[6](0.0, 7.0, 14.0, 7.0, 3.0, 5.0);

vec2 mainSound(int samp, float time) {
    vec2 sig = vec2(0.0);
    for (int i = 0; i < 6; i++) {
        float ti = mod(time - 0.25 * float(i), 2.0);
        sig += 0.15 * fmpluck(noteFreq(notes[i]), noteFreq(notes[i]), 1.0, ti)
                    * pan(mod(float(i), 3.0) - 1.0);
    }
    return sig;
}
```

---

## 11. Exercices

1. **Onde et enveloppe** — Reproduire un pluck à 220 Hz avec une décroissance lente (`λ = 1.0`) et un autre à 880 Hz avec une décroissance rapide (`λ = 8.0`). Comparer à l'oreille et sur un analyseur de spectre.
2. **Stéréo créatif** — Écrire une fonction qui spatialise une note selon une **trajectoire sinusoïdale** dans le temps : `p(t) = sin(2π * 0.5 * t)`.
3. **Tempérament** — Implémenter `noteFreq` pour un tempérament **pythagoricien** (quintes pures, octaves de ratio 3/2) au lieu d'égal. Comparer les deux sur un accord majeur.
4. **Aliasing** — Faire glisser la fréquence d'une saw brute de 50 Hz à 5 kHz et **écouter** où l'aliasing devient évident. Repérer le seuil.
5. **FM exploration** — Fixer `fc = 440`, faire varier `fm ∈ {220, 440, 660, 880, 1100}` et `iom ∈ {0.5, 2, 5, 15}`. Caractériser chaque timbre verbalement (« cloche », « cuivre », « voix »…).

---

## 12. Pour aller plus loin

- **Théorème de Nyquist-Shannon** : tout ingénieur audio doit le maîtriser.
- **Loi de panning constant power** : pourquoi les pros préfèrent une loi en $\cos/\sin$ plutôt qu'en racine.
- [[Cours 2 - FM Synthesis, Pad, Lead Synth]] — la suite : théorie de la FM et premiers vrais instruments.

---

## Liens

- Vidéo source : <https://www.youtube.com/watch?v=3mteFftC7fE>
- Graphtoy : <https://graphtoy.com>
- Shadertoy : <https://www.shadertoy.com>
