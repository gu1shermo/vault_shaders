# Cours 2 — FM Synthesis, Pad et Lead Synth

> Module **Shadertoy Audio** — 5e année ESGI
> Source : *Making Music in Shadertoy — Episode 2* (Alexis Thibault)
> Pré-requis : [[Cours 1 - Bases, waveforms et melodie]]

---

## 1. Pourquoi la FM est l'outil idéal pour Shadertoy

Dans Shadertoy, on n'a pas accès aux outils habituels du DSP audio :

- pas de **filtres récursifs** (impossible : chaque sample est calculé indépendamment),
- pas d'**état persistant** (pas de mémoire entre échantillons),
- pas de **délais** efficaces (sauf à payer le prix d'un recalcul complet).

Mais on a une chose : on peut évaluer **n'importe quelle formule analytique** en `t`. La **modulation de fréquence** rentre parfaitement dans ce cadre : elle ne nécessite **aucun état**, juste un appel à `sin()` imbriqué.

---

## 2. Théorie : qu'est-ce vraiment que la FM ?

### 2.1 Fréquence instantanée et phase

Une onde générale s'écrit $s(t) = \sin(\varphi(t))$, où $\varphi$ est la **phase**.

La **fréquence instantanée** est par définition :

$$ f(t) = \frac{1}{2\pi} \frac{d\varphi}{dt} $$

Réciproquement, pour produire un signal de fréquence instantanée $f(t)$, il faut intégrer :

$$ \varphi(t) = 2\pi \int_0^t f(\tau)\,d\tau + \varphi_0 $$

> **Point capital** : on ne peut **pas** simplement écrire `sin(2π · f(t) · t)` quand `f` varie. C'est l'erreur la plus classique en synthèse sonore. On reviendra dessus au §6 (vibrato).

### 2.2 Modulation sinusoïdale → FM analytique

On choisit une fréquence instantanée modulée :

$$ f(t) = f_c + \Delta f \cdot \cos(2\pi f_m t) $$

- $f_c$ : **fréquence porteuse** (carrier),
- $f_m$ : **fréquence modulante**,
- $\Delta f$ : **déviation de fréquence** (en Hz).

En intégrant :

$$ \varphi(t) = 2\pi f_c t + \frac{\Delta f}{f_m} \sin(2\pi f_m t) $$

D'où le **signal FM** :

$$ s(t) = \sin\!\Big( 2\pi f_c t + \beta \sin(2\pi f_m t) \Big),\quad \beta = \frac{\Delta f}{f_m} $$

$\beta$ s'appelle l'**index of modulation** (IOM). C'est le paramètre qui contrôle la richesse spectrale.

### 2.3 En GLSL

```glsl
#define TAU 6.2831853

#define fm(fc, fm, iom) \
    sin(TAU * (fc) * t + (iom) * sin(TAU * (fm) * t))
```

On utilise une macro plutôt qu'une fonction parce qu'on a souvent besoin que `t` soit captée du contexte (vibrato, enveloppes…).

---

## 3. Structure spectrale de la FM

C'est **la** raison pour laquelle la FM est puissante : on contrôle précisément quels partiels apparaissent.

### 3.1 Règle des sidebands

Le signal FM décompose en série de **Bessel** :

$$ \sin(2\pi f_c t + \beta \sin(2\pi f_m t)) = \sum_{n=-\infty}^{+\infty} J_n(\beta) \sin\!\big(2\pi (f_c + n f_m) t\big) $$

En pratique, ce qu'il faut retenir :

> Le spectre contient des raies à $f_c \pm n \cdot f_m$, pour $n = 0, 1, 2, …$
> Le nombre de raies **audibles** est de l'ordre de $\beta$.

### 3.2 Démonstration empirique

Avec `fc = 1000 Hz`, `fm = 100 Hz` :

- `iom = 0` → un seul pic à 1000 Hz (sinus pur).
- `iom = 2` → pics à 800, 900, 1000, 1100, 1200 Hz.
- `iom = 10` → pics jusqu'à 0 Hz et 2000 Hz.
- `iom = 30` → spectre quasi-continu.

### 3.3 Le pliage des fréquences négatives

Que se passe-t-il si $f_c + n f_m < 0$ ? Exemple : $f_c = 500$, $f_m = 300$, $\beta = 2$.

- $500 - 300 = 200$ Hz ✓
- $500 - 600 = -100$ Hz → ?

Réponse : $\sin(-2\pi f t) = -\sin(2\pi f t)$. La fréquence négative apparaît dans le spectre comme une fréquence **positive de même valeur absolue**, avec une phase inversée.

Conséquence pratique : pour les sons graves avec gros IOM, on récupère du contenu replié dans le bas du spectre. Utile pour des basses, mais à manier avec précaution.

### 3.4 Ratio harmonique vs inharmonique

| Ratio $f_m / f_c$ | Résultat |
|---|---|
| Entier (1, 2, 3…) | Spectre **harmonique** → son tonal (corde, cuivre) |
| Rationnel simple (1/2, 2/3) | Sous-harmoniques → son riche mais musical |
| Irrationnel (1.414, 2.7) | Spectre **inharmonique** → cloches, percussions métalliques |

---

## 4. Construction d'un pad

Un **pad** est un son **lent**, **épais**, **stéréo**, qui sert de fond harmonique. On va le bâtir par **stratification** (« layering »).

### 4.1 Macro de note relative au Do médian

```glsl
#define N(n) (90.0 * exp2(((n) - 9.0) / 12.0))
```

- `N(0)` = Do central (≈ 60 Hz × 2^(...) selon la convention).
- Toute note s'exprime en **semitones depuis le Do central**.

> Choix : utiliser `90 Hz` comme ancre (un Do grave) plutôt que `440 Hz`. C'est juste un choix d'ergonomie : on a la mélodie en valeurs proches de 0.

### 4.2 Couche 1 : le corps

```glsl
float sig = 0.0;
sig += fm(f, f * 1.001, 1.0, t);   // léger detuning pour vivacité stéréo
```

Le **détuning** (frequencyfm légèrement différente du multiple entier) crée un mouvement subtil dans le timbre, parce que les harmoniques battent entre elles.

### 4.3 Enveloppe d'attaque lente

```glsl
float env = smoothstep(0.0, 0.5, t);  // monte de 0 à 1 en 0.5 s
sig *= env;
```

Une **attaque lente** (≥ 100 ms) est ce qui distingue un pad d'un pluck. Le `smoothstep` est cubique (`3x² - 2x³`), plus naturel qu'une rampe linéaire.

### 4.4 Couche 2 : la « personnalité »

Problème : un son confiné à 300–1000 Hz **se perd dans un mix**. On doit donner du **contenu haut-médium** pour que l'oreille puisse l'isoler.

```glsl
float fc2 = f * round(2000.0 / f);   // ≈ 2 kHz, mais multiple entier de f
float iom = 1000.0 / f;              // déviation ≈ 1 kHz
sig += 0.3 * fm(fc2, f, iom + sin(t), t);
```

- On **arrondit `fc2`** au multiple entier de `f` le plus proche → garantit un ratio harmonique → son musical.
- L'IOM est calculé pour que la **déviation de fréquence** soit constante (1 kHz) indépendamment de la note.
- L'IOM est lui-même **modulé lentement** par `sin(t)` → mouvement vivant.

### 4.5 Construction d'un accord

```glsl
vec2 padChord(vec4 fs, float t) {
    vec2 sig = vec2(0.0);
    sig += padSynth(fs.x, t) * pan(-0.3);
    sig += padSynth(fs.y, t) * pan(-0.8);
    sig += padSynth(fs.z, t) * pan(+0.8);
    sig += padSynth(fs.w, t) * pan(+0.3);
    return sig;
}
```

> **Astuce de mixage** : la **basse et la note la plus haute proches du centre**, les notes intermédiaires **larges**. C'est l'opposé de l'intuition, mais c'est ce qui sonne le plus naturel.

---

## 5. « Reverb » de pauvre

Shadertoy ne permet pas une vraie réverbération (qui demande un état persistant). On peut faire mieux : **mélanger une version retardée du signal**.

```glsl
vec2 padChordReverb(float t) {
    vec2 dry = padChordPattern(t);
    vec2 wet = padChordPattern(t - 0.5).yx * 0.2;  // swap L/R + 20%
    vec2 early = padChordPattern(t - 0.005) * 0.1; // early reflections
    return dry + wet + early;
}
```

Trois astuces :

1. **Délai principal** (~0.5 s) → impression d'espace.
2. **Swap canaux** (`.yx`) → renforce l'effet stéréo (effet « ping-pong »).
3. **Délais courts** (~5 ms) → simulent les réflexions précoces (early reflections) qui donnent l'impression d'une pièce.

---

## 6. Construction d'un lead synth — et le vrai sens du vibrato

### 6.1 La fausse bonne idée

Premier réflexe pour un vibrato :

```glsl
// ❌ WRONG
float f = f0 + 0.06 * f0 * 0.2 * cos(TAU * 5.0 * t);
sig = fm(f, f, 1.0, t);
```

Résultat : un wobble qui **s'amplifie avec le temps**. Inutilisable.

### 6.2 Pourquoi c'est faux

En écrivant `sin(TAU * f(t) * t)`, la phase utilisée est $\varphi(t) = 2\pi f(t) \cdot t$.

Or la fréquence instantanée vaut $\frac{1}{2\pi}\frac{d\varphi}{dt}$. Par la **règle du produit** :

$$ \frac{d\varphi}{dt} = 2\pi \big( f(t) + f'(t) \cdot t \big) $$

Le terme parasite $f'(t) \cdot t$ croît linéairement avec $t$ → c'est lui qui produit le wobble explosif.

### 6.3 La bonne formule

Reprendre la théorie du §2 : pour une fréquence instantanée $f(t) = f_0 + \Delta f \cos(2\pi f_m t)$, la phase **intégrée** est :

$$ \varphi(t) = 2\pi f_0 t + \frac{\Delta f}{f_m} \sin(2\pi f_m t) $$

```glsl
float vibratoPhase(float f0, float depthSemitones, float vibratoHz, float t) {
    float df = 0.06 * f0 * depthSemitones;   // déviation en Hz
    return TAU * f0 * t + (df / vibratoHz) * sin(TAU * vibratoHz * t);
}
```

> **Pourquoi 0.06 ?** Un demi-ton vaut $2^{1/12} - 1 \approx 0.0595$. On le note 0.06 par convention pour les petits intervalles de vibrato.

### 6.4 Macro FM en phase

Comme on travaille maintenant avec des **phases** plutôt que des fréquences, on définit une seconde macro :

```glsl
#define fm2(pc, pm, iom) \
    sin( mod(pc, TAU) + (iom) * sin( mod(pm, TAU) ) )
```

Le `mod(., TAU)` évite les pertes de précision sur des grands `t` (au-delà de quelques dizaines de secondes, `sin()` devient bruité par les flottants 32 bits).

### 6.5 Vibrato avec enveloppe

Un vrai vibrato ne démarre pas instantanément — un chanteur attend ~0.5 s avant de l'introduire :

```glsl
float vibAmt = smoothstep(0.0, 0.5, t);
float phase  = vibratoPhase(f, 0.2 * vibAmt, 5.0, t);
```

---

## 7. Le « presence boost » (à 5 kHz)

L'oreille humaine est **maximalement sensible autour de 3–5 kHz** (courbes de Fletcher-Munson). C'est pourquoi les amplis guitare ont un bouton « Presence » qui boost cette zone.

```glsl
float ratio = round(5000.0 / f);             // multiple entier de f le plus proche de 5kHz
float pcHi  = ratio * phase;                 // phase porteuse aiguë
float iomHi = (2000.0 / f) * 0.01;
sig += fm2(pcHi, phase, iomHi);
```

L'opération `round(5000/f)` est l'astuce-clé : elle garantit que **le partiel généré soit harmonique** avec la fondamentale. Sans cela, on aurait un partiel inharmonique sonnant faux.

---

## 8. Attaque percussive

Pour donner de la **présence transitoire** (attaque), on superpose un blast FM à très haut IOM et décroissance ultra-rapide :

```glsl
sig += 0.3 * fm(f, f, 10000.0 / f, t) * exp(-20.0 * t);
```

- IOM énorme → spectre extrêmement large.
- `exp(-20 t)` → dure ~50 ms.
- On ne se soucie pas de la « justesse » harmonique : ça passe trop vite pour qu'on l'entende.

---

## 9. Compresseur de fortune (sidechain)

Un **compresseur** baisse le volume des sons forts avec un léger délai. On peut le simuler avec une enveloppe scriptée :

```glsl
float compEnv = 1.0 - 0.6 * exp(-8.0 * t);  // -6dB juste après l'attaque
sig *= compEnv;
```

C'est la base du fameux **pumping** qu'on entend dans la musique électro moderne : le pad « respire » au rythme du kick.

---

## 10. Pattern d'accords

```glsl
#define BPM 100.0
#define BD  (60.0 / BPM)   // beat duration

vec4 chord =
    (t < 4.0 * BD)  ? vec4( 0.0,  4.0,  7.0, 12.0) :  // Am add9? Cmaj
    (t < 8.0 * BD)  ? vec4(-7.0, -3.0,  0.0,  5.0) :  // Dm7
    (t < 12.0 * BD) ? vec4(-7.0, -2.0,  2.0,  5.0) :  // F + G
    (t < 14.0 * BD) ? vec4(-5.0,  0.0,  2.0,  4.0) :  // C add9
                      vec4(-5.0, -1.0,  2.0,  4.0);   // G6
```

### 10.1 Re-déclenchement propre

Quand l'accord change, il faut que les notes **redémarrent** sinon on entend des clics :

```glsl
float tCurrent = mod(t, 4.0 * BD);
float env = smoothstep(4.0 * BD, 3.5 * BD, tCurrent); // décroissance avant changement
```

Le `smoothstep` est **inversé** (paramètres swap) → il passe de 1 à 0 sur la fin du bar.

### 10.2 Garde contre les temps négatifs

```glsl
t = max(t, 0.0);
```

Sans cette ligne, la « reverb » lit du signal antérieur à `t=0` → tail de réverb fantôme avant le début.

---

## 11. Mélodie du lead (séquenceur)

Pour le lead, on n'a pas 4 notes simultanées mais une **séquence**. On utilise une macro pour ajouter une note à la position courante :

```glsl
#define ADD_NOTE(n, beats) \
    if (t >= 0.0 && t < (beats) * BD) \
        sig += leadSynth(N(n), t) * smoothstep((beats)*BD, (beats)*BD - 0.01, t); \
    t -= (beats) * BD;
```

Utilisation :

```glsl
ADD_NOTE( 0.0,  0.5)
ADD_NOTE( 4.0,  0.5)
ADD_NOTE( 7.0,  1.0)
ADD_NOTE(12.0,  0.5)
// ...
```

Élégant : chaque appel **avance le « curseur temporel »** `t`. C'est essentiellement un **séquenceur déroulé à la compilation**.

---

## 12. Limites à connaître

- **Pas de récursion** : `sig = pattern(t) + pattern(t-d)` est OK ; mais `pattern` ne peut pas s'appeler elle-même. Shadertoy refuse net (erreur `Recursive function call`).
- **Boucles** : OK si la borne est connue à la compilation. Sinon, le compilateur peut refuser de dérouler.
- **Précision float** : `sin(TAU * f * t)` avec `f * t` > ~10⁶ donne des résultats incorrects. Toujours `mod(phase, TAU)` au préalable.

---

## 13. Exercices

1. **Vérifier la formule de phase** — Implémenter la version « fausse » et la version « correcte » du vibrato dans deux shaders parallèles. Mesurer la différence à `t = 5 s` et `t = 30 s`.
2. **Spectre FM** — Avec `fc = 800`, `fm = 200`, faire varier `iom` de 0 à 20. Compter visuellement (analyseur de spectre) le nombre de partiels audibles. Vérifier la règle empirique : « ~$\beta$ partiels ».
3. **Sidebands négatifs** — Choisir `fc = 400`, `fm = 350`, `iom = 3`. Prédire le spectre avant d'écouter. Vérifier le repliement.
4. **Pad personnel** — Construire un pad complet avec : corps détuné, couche presence, vibrato lent (~0.3 Hz), reverb fake. Tester sur un accord majeur 7.
5. **Compresseur** — Coder une version paramétrable de `compEnv(t, attack, release, depth)` et l'appliquer au pad selon la position dans le beat.

---

## 14. Pour aller plus loin

- **DX7 émulateur** : [Dexed VST](https://asb2m10.github.io/dexed/) — le synthétiseur FM mythique de Yamaha. Indispensable pour explorer la FM en interactif.
- **Fonctions de Bessel** et leur rôle dans la décomposition spectrale FM.
- **Loi de Fletcher-Munson** : pourquoi un mix doit être équilibré différemment selon le volume d'écoute.
- [[Cours 3 - Marimba, Saw Bass, Wah Synth]] — instruments inharmoniques et anti-aliasing.

---

## Liens

- Vidéo source : <https://www.youtube.com/watch?v=CqDrw0l0tas>
- Analyseur de spectre web : <https://www.szynalski.com/tone-generator/> ou Audacity → Analyse > Spectre.
