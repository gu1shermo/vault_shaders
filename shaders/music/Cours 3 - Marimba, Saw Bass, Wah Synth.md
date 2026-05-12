# Cours 3 — Marimba, Saw Bass anti-aliasée et Wah Synth

> Module **Shadertoy Audio** — 5e année ESGI
> Source : *Making Music in Shadertoy — Episode 3* (Alexis Thibault)
> Pré-requis : [[Cours 1 - Bases, waveforms et melodie]], [[Cours 2 - FM Synthesis, Pad, Lead Synth]]

---

## Vue d'ensemble

Trois instruments très différents, trois techniques très différentes :

| Instrument | Technique | Difficulté |
|---|---|---|
| **Marimba** | FM inharmonique, ratio non-entier | Facile |
| **Saw bass** | Synthèse de saw **anti-aliasée à la main** | Avancé (théorie) |
| **Wah synth** | Synthèse additive + enveloppe spectrale | Moyen |

L'objectif final est de **compléter une chanson** à 100 BPM avec : pad, marimba, saw bass, wah synth.

---

## 1. Marimba — FM inharmonique

### 1.1 Théorie : les modes propres d'une lame

Une lame de marimba (ou de xylophone) est une **poutre vibrante**. Sa physique est régie par l'équation d'Euler-Bernoulli, et ses modes propres sont :

$$ f_n \propto \beta_n^2 \quad \text{avec} \quad \beta_1 \approx 4.73,\ \beta_2 \approx 7.85 $$

Ce qui donne approximativement :

- mode 1 (fondamentale) : $f_1$
- mode 2 : $\approx 2.76\, f_1$
- mode 3 : $\approx 5.40\, f_1$

> **Ces ratios ne sont pas entiers** : la marimba est **inharmonique**. C'est le secret de son timbre xylophone-cloche-bois.

En FM, on simule cet effet avec un **ratio modulateur/porteur non-entier** :

```glsl
float marimba(float f, float t) {
    float iom = 1.5 * exp(-30.0 * t);   // IOM qui décroît très vite
    float carrier = sin( TAU * fract(f * t) + iom * sin( TAU * fract(7.0 * f * t) ) );
    return carrier * exp(-5.0 * t);
}
```

Décomposition :

- **`fc = f`** : la note jouée.
- **`fm = 7 * f`** : ratio entier ici, mais **les sidebands** créent du contenu à $f \pm n \cdot 7f$ = $\{-6f, +8f, -13f, +15f…\}$ — **les fréquences négatives se replient**, créant $+6f$, partiel inharmonique perçu.
- **IOM qui décroît vite** : seul l'attaque a le timbre métallique ; ensuite, on revient au sinus pur (la fondamentale).

> C'est exactement la **physique** d'une lame : les harmoniques aiguës s'amortissent plus vite que la fondamentale.

### 1.2 Le `fract` : éviter la perte de précision

```glsl
sin( TAU * fract(f * t) )
```

Pour `f = 440` et `t = 60` (1 minute), `f * t = 26400`. Le `sin` GLSL en `float32` commence à perdre en précision au-delà de quelques milliers de radians. Le `fract` ramène la phase dans `[0, 1[`, ce qui garde la précision constante.

### 1.3 Pattern de marimba (techno)

```glsl
vec2 marimbaPattern(float t) {
    t = mod(t, 16.0 * BD);            // 16 beats
    vec2 sig = vec2(0.0);

    // dotted 8th, classique techno
    float positions[6] = float[6](0.0, 0.75, 1.5, 2.25, 3.0, 3.5);
    float notes[6]     = float[6](4.0, 12.0, 4.0, 5.0,  9.0, 12.0);

    for (int i = 0; i < 6; i++) {
        float ti = mod(t - positions[i] * BD, 4.0 * BD);
        sig += marimba(N(notes[i]), ti) * pan(0.5 * sin(float(i)));
    }
    return sig;
}
```

> **Rythme « dotted eighth »** : durée 3/8 entre deux frappes. Pattern emblématique de la techno et de la trance — l'oreille perçoit une pulsation à contretemps qui « tire en avant ».

---

## 2. Saw bass — La synthèse anti-aliasée

### 2.1 Le problème, rappel du Cours 1

Une saw idéale a un spectre infini ($f, 2f, 3f, …$). Échantillonnée à 44.1 kHz, tout partiel au-dessus de 22.05 kHz **se replie** (aliasing). À une fondamentale de 80 Hz, c'est tolérable. À 880 Hz, c'est catastrophique.

### 2.2 Théorie : limiter le spectre = lisser les discontinuités

Une saw a une **discontinuité** à chaque période (saut de +1 à -1). Cette discontinuité contient l'énergie haute fréquence problématique.

**Idée** : remplacer la discontinuité par une **transition lisse** sur une petite fenêtre. C'est équivalent (en filtrage) à appliquer un filtre passe-bas.

### 2.3 Construction étape par étape

#### Étape 1 — la saw idéale

```
y(x) = 1 - 2*fract(x)
```

Sur $[0, 1[$ : descend linéairement de $+1$ à $-1$, puis discontinuité.

#### Étape 2 — paramétrer la position du saut

On choisit de placer le saut à $x = 0$. Alors :

- Pour $x \in [0.2, 1[$ : $y = 1 - 2x$ (linéaire descendant).
- Pour $x \in [0, 0.2]$ : on fait une **transition smooth** entre la fin du cycle précédent (qui valait $-1$) et le début du nouveau (qui vaut $+1$).

#### Étape 3 — formulation analytique

```glsl
float sawAA(float f, float t) {
    float x = fract(f * t);
    // segment linéaire
    float linear = 1.0 - 2.0 * x;
    // segment transition (entre cycles)
    float xx = x - 0.5;
    float transition = (xx > 0.0 ? -1.0 : 1.0) - 2.0 * xx;  // décalé
    // mélange via smoothstep dans la zone de transition
    float blend = smoothstep(0.0, 0.2, abs(xx) - 0.3);
    return mix(linear, transition, blend);
}
```

> **Attention** : cette formulation est pédagogique. L'auteur de la vidéo a en réalité tracé la fonction sur papier, dérivé une formule fermée, et l'a transposée. La version « propre » sera dans l'exercice 2.

### 2.4 Une version plus simple et plus fidèle au tuto

```glsl
float sawAA(float f, float t) {
    float x = fract(f * t) - 0.5;          // x ∈ [-0.5, +0.5]
    // deux pentes, smoothstep entre elles autour de x=0 (le saut)
    float a = -2.0 * x - 1.0;              // pente descendante avant saut
    float b = -2.0 * x + 1.0;              // pente descendante après saut
    float k = smoothstep(-0.2, 0.2, x);
    return mix(a, b, k);
}
```

### 2.5 Construction du bass synth

```glsl
vec2 saw80sBass(float f, float t) {
    // 1. note fondamentale
    vec2 sig = vec2(sawAA(f * 1.005, t + 1.0),
                    sawAA(f * 0.995, t + 1.0));  // detuning stéréo
    // 2. sub-bass (octave en dessous, sinus pur, mono)
    sig += vec2(sin(TAU * fract(f * 0.5 * t)) * 0.6);
    return sig;
}
```

#### 2.5.1 Pourquoi `t + 1.0` ?

À `t = 0`, la phase est exactement zéro. Sans décalage, les deux voix détunées commencent en phase → pas d'effet stéréo perceptible avant que le détuning ne les sépare. Un offset (`t + 1.0`) garantit que les phases soient déjà décorrélées dès le début.

#### 2.5.2 Le sub-bass

Une sinusoïde une octave en-dessous (`f * 0.5`) donne du « poids » sans encombrer le médium. On la garde **mono** (`vec2(x)` plutôt qu'un vrai stéréo) car les fréquences <100 Hz sont localisées par l'oreille avec peu de précision spatiale.

### 2.6 Choix de la fondamentale : où placer la basse ?

> Règle d'or : **fondamentale entre 40 et 100 Hz**. Au-dessous : pas assez d'enceintes peuvent la reproduire. Au-dessus : ce n'est plus une basse, c'est un médium.

```glsl
// Pattern de basse
float bassFreq =
    (bar == 0) ? N(-12.0) :    // A1
    (bar == 1) ? N(-19.0) :    // D1
    (bar == 2) ? N(-16.0) :    // F1
    (halfBar)  ? N(-9.0)  :    // C2
                 N(-14.0);     // G1

// Sub-bass joue à la moitié → tomber dans 40-100 Hz
```

---

## 3. Sidechain compression (la pompe)

### 3.1 Pourquoi

En techno/house, un **kick** vient régulièrement. Sans gestion, la basse et le kick se chevauchent en spectre → tout se brouille.

**Solution** : baisser le volume de la basse **pile au moment** où le kick frappe. C'est la **compression sidechain**.

### 3.2 Astuce : pas besoin de kick

Même si on n'a **pas encore** mis le kick, on peut **simuler son effet sur la basse**. Le pattern « pompé » donne déjà une sensation rythmique, et quand on ajoutera le kick plus tard, ça s'enclenchera naturellement.

### 3.3 Forme de l'enveloppe « bump »

```glsl
float bump(float t) {
    // t = position dans le beat, ∈ [0, BD]
    float p = mod(t, BD) / BD;       // [0, 1[
    float att = smoothstep(0.0, 0.2, p);   // monte de 0 à 1 sur les 20% du beat
    return mix(0.2, 1.0, att);             // entre 20% et 100%
}

sig *= bump(t);   // applique à la basse
```

> Forme : à `p = 0` (kick) → gain = 0.2 (-14 dB). Puis remontée smooth à 1.0 sur 20% du beat. Ça « respire ».

On applique le même bump (plus léger) au pad et à la marimba pour qu'ils suivent la pulsation.

---

## 4. Wah Synth — Synthèse additive + filtre spectral

### 4.1 Concept

Un son « wah » (comme la pédale wah-wah de guitare) est un son riche en harmoniques où **on balaie un filtre passe-bande** lentement. La pédale change la fréquence de coupure du filtre, donnant cet effet vocal caractéristique.

Sans filtre récursif (impossible en shader), on **synthétise directement chaque harmonique avec son amplitude**.

### 4.2 Implémentation

```glsl
float wahSynth(float f, float t, float dur) {
    // enveloppe 1 : filtre (balaie la fréquence de coupure)
    float filterEnv = (t < dur * 0.5)
        ? smoothstep(0.0, dur * 0.5, t)
        : smoothstep(dur, dur * 0.5, t);
    // enveloppe 2 : amplitude globale
    float ampEnv = (t < dur * 0.1)
        ? smoothstep(0.0, dur * 0.1, t)
        : smoothstep(dur, dur * 0.1, t);

    float fc = mix(400.0, 10000.0, filterEnv);   // balayage 400Hz → 10kHz

    float sig = 0.0;
    // somme additive d'harmoniques pondérées par le filtre
    for (int n = 1; n <= 20; n++) {
        float fn = float(n) * f;
        if (fn > fc) break;                       // coupure brutale
        float weight = smoothstep(fc, fc * 0.5, fn);  // taper near cutoff
        sig += weight * sin(TAU * fract(fn * t)) / float(n);
    }
    return sig * ampEnv;
}
```

### 4.3 Pourquoi `1/n` en pondération de base ?

Une **saw idéale** a précisément ce profil : $a_n = 1/n$. En tronquant la somme à `fc`, on obtient une saw **bandlimited** : c'est l'équivalent additif de l'anti-aliasing du §2.

### 4.4 La double enveloppe

| Enveloppe | Rôle |
|---|---|
| `filterEnv` (lent, half-up half-down) | Donne l'effet « wah » |
| `ampEnv` (rapide, attack court) | Donne le rythme |

C'est exactement le principe d'un **synthétiseur soustractif** classique (VCF + VCA), mais reproduit en formule pure.

---

## 5. Conduite d'un pattern « wah »

```glsl
vec2 wahPattern(float t) {
    t = mod(t, 16.0 * BD);
    vec2 sig = vec2(0.0);

    // notes choisies pour coller aux accords du pad
    float ns[4] = float[4]( 4.0, 5.0, 4.0, 2.0);

    for (int i = 0; i < 4; i++) {
        float ti = t - float(i) * 4.0 * BD;
        // ajouts rythmiques pour casser la monotonie
        if (mod(float(i), 2.0) < 0.5) ti = mod(ti, BD);
        sig += wahSynth(N(ns[i]), max(ti, 0.0), 2.0 * BD) * pan(sin(float(i)));
    }
    return sig;
}
```

> Le `mod(ti, BD)` interne fait **re-déclencher la note plusieurs fois par bar** sur certaines positions. C'est ce qui crée le côté « hoquet » caractéristique.

### Pattern « fake reverb »

```glsl
vec2 wahWithReverb(float t) {
    vec2 dry = wahPattern(t);
    vec2 wet = wahPattern(t - 0.5).yx * 0.4;   // L/R swap
    vec2 wet2 = wahPattern(t - 1.0).yx * 0.2;
    return dry + wet + wet2;
}
```

---

## 6. Assemblage final

```glsl
vec2 mainSound(int samp, float time) {
    vec2 sig = vec2(0.0);
    sig += padPatternReverb(time)     * 0.5;
    sig += marimbaPattern(time)       * 0.4;
    sig += saw80sBassPattern(time)    * 0.6;
    sig += wahWithReverb(time)        * 0.3;
    // sidechain global
    sig *= bump(time);
    return sig * 0.9;   // marge anti-clipping
}
```

### Conseils de mix

- **Vérifier le maximum** : ouvrir l'audio dans Audacity, regarder le pic. S'il dépasse `±0.95`, baisser le coefficient global.
- **Séparation spectrale** : chaque instrument doit dominer une bande différente (basse < 200 Hz, marimba 500–2000 Hz, wah 1–5 kHz, pad partout en fond).
- **Séparation spatiale** : alterner les pannings pour éviter l'empilement central.

---

## 7. Limites de Shadertoy revisitées

À ce stade vous avez touché :

- **Pas de récursion** → astuce des macros / déroulement manuel.
- **Pas d'état** → tout exprimer en fonction de `t`.
- **Délais limités** → le « reverb » est en réalité du recalcul complet de la pattern à `t - d`. Coût CPU multiplié.
- **`pow`, `log`, `sin` coûteux** → en pratique, à 44.1 kHz mono, on a ~22 µs par sample pour calculer le signal. Au-delà, Shadertoy ne joue pas en temps réel et il faut compiler le buffer entier d'avance.

---

## 8. Exercices

1. **Marimba** — Faire varier le ratio modulateur (`7 * f`) en `{2, 3, 5, 11}` et caractériser le timbre. Lequel sonne le plus « bois », lequel le plus « cloche » ?
2. **Saw AA** — Comparer à l'oreille et au spectrogramme :
    - une saw brute (`fract(f*t)*2-1`),
    - la version `sawAA` du §2.5,
    - une saw additive bandlimited (somme de N harmoniques).
   Tracer le bruit d'aliasing résiduel selon `f`.
3. **Sub-bass** — Quel décalage octave (`f*0.5`, `f*0.25`) donne le plus de poids sans devenir inaudible ? Tester sur des enceintes différentes.
4. **Wah** — Réécrire `wahSynth` en remplaçant le smoothstep par une **résonance** (peak du filtre à `fc` plutôt que coupure). Indice : pondérer chaque harmonique par $\frac{1}{1 + Q \cdot (f_n/f_c - 1)^2}$.
5. **Mix complet** — Composer une boucle de 16 mesures intégrant pad, marimba, bass, wah, avec un changement d'accord par mesure. Soumettre le `.glsl` + un export `.wav` 30 s.

---

## 9. Pour aller plus loin

- **Karplus-Strong** (cordes pincées) — algorithme original récursif, mais on peut écrire une version analytique tronquée pour Shadertoy.
- **Modèles physiques de poutre** (équation d'Euler-Bernoulli) — pour aller plus loin que la FM approximative en marimba.
- **PolyBLEP** et **MinBLEP** — les vraies techniques pro d'anti-aliasing pour saw / square.
- **Sidechain en vrai** : RMS detection + envelope follower (impossible en stateless, intéressant à étudier théoriquement).

---

## Liens

- Vidéo source : <https://www.youtube.com/watch?v=9XeE0v5JLiQ>
- Dexed (DX7 émulateur) : <https://asb2m10.github.io/dexed/>
- PolyBLEP, théorie : <https://www.kvraudio.com/forum/viewtopic.php?t=375517>
