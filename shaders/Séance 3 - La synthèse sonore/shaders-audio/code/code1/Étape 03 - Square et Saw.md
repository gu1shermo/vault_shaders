# Étape 03 — Onde carrée et dent de scie

> Décomposition [[shadertoy1 code]] — **étape 3 / 8**
> Concept : enrichir le spectre avec des waveforms non-sinusoïdales, prendre conscience de l'**aliasing**.

---

## Objectif pédagogique

- Construire deux waveforms classiques **directement à partir de primitives GLSL** (sans LUT, sans intégration).
- Comparer leur timbre au sinus de l'étape précédente.
- Comprendre le **théorème de Nyquist-Shannon** et entendre où la production de ces ondes brutes pose problème.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

float sinPluck(float f, float t)
{
    return sin(TWOPI * f * t) * exp(-3.0 * t) * 0.1;
}

float squarePluck(float f, float t)
{
    return sign(sin(TWOPI * f * t)) * exp(-3.0 * t) * 0.1;
}

float sawPluck(float f, float t)
{
    return (mod(t * f, 1.0) * 2.0 - 1.0) * exp(-3.0 * t) * 0.1;
}

vec2 mainSound( int samp, float t )
{
    float sig = 0.0;
    float tn = mod(t, 2.0);            // une boucle de 2 s

    if (tn < 0.7)      sig = sinPluck   (440.0, tn);
    else if (tn < 1.4) sig = squarePluck(440.0, tn - 0.7);
    else               sig = sawPluck   (440.0, tn - 1.4);

    return vec2(sig);
}
```

> Trois plucks successifs sur la **même fréquence** : on entend uniquement la différence de **timbre**.

---

## Théorie

### Onde carrée — `sign(sin(...))`

```glsl
sign(sin(TWOPI * f * t))   // +1 ou -1, transition instantanée
```

Une décomposition de Fourier d'une onde carrée parfaite donne :

$$ \text{square}(t) = \frac{4}{\pi} \sum_{k=0}^{\infty} \frac{\sin\left((2k+1)\,2\pi f t\right)}{2k+1} $$

C'est-à-dire **toutes les harmoniques impaires** : `f, 3f, 5f, 7f…` avec une décroissance en `1/n`. Son timbre : **clarinette électronique**, **chiptune NES**.

### Onde dent de scie — `mod(t*f, 1.0) * 2.0 - 1.0`

```glsl
mod(t * f, 1.0)            // rampe [0, 1[ qui repart à 0 à chaque période 1/f
* 2.0 - 1.0                // remappée en [-1, +1[
```

Sa décomposition de Fourier contient **toutes les harmoniques** (paires et impaires) avec décroissance `1/n` :

$$ \text{saw}(t) = -\frac{2}{\pi} \sum_{k=1}^{\infty} \frac{\sin(2\pi k f t)}{k} \cdot (-1)^k $$

Timbre : **violon synthétique**, **basse analogique** type Moog. Très brillant, très riche.

### Le problème : l'**aliasing**

Les deux waveforms ci-dessus contiennent un **nombre infini d'harmoniques**. Or, le **théorème de Nyquist-Shannon** énonce :

> Un signal échantillonné à `Fs` ne peut représenter sans ambiguïté que des fréquences `< Fs / 2`.

Shadertoy échantillonne à **44 100 Hz**, donc la limite est **22 050 Hz** (Nyquist).

Toute harmonique au-dessus de Nyquist se **replie** (« *fold back* ») sous forme de fréquence parasite **non-harmonique** dans la bande audible.

#### Calcul rapide

À 440 Hz :

- 50e harmonique = 22 000 Hz → tout juste audible et déjà sous Nyquist.
- 51e = 22 440 Hz → **se replie** à `44100 - 22440 = 21 660` Hz.
- 100e = 44 000 Hz → se replie à 100 Hz : une **harmonique parasite** très basse !

C'est pourquoi une saw brute à 440 Hz **sonne sale**, surtout dans les aigus quand on monte la fréquence fondamentale.

> **Analogie visuelle** : le **wagon-wheel effect** — la roue de diligence qui semble tourner à l'envers dans les vieux westerns. Le film capture 24 images par seconde, donc une roue qui fait plus de 12 tours/seconde apparaît « repliée » dans une autre vitesse apparente.

### Pourquoi `sign(sin(x))` ne fait pas exception

Une transition `-1 → +1` parfaitement instantanée ⇒ pente infinie ⇒ spectre **infini**. Le compilateur ne « lisse » rien : ce que vous échantillonnez, c'est cette discontinuité brutale, et tout ce qui dépasse 22 kHz se replie.

> On verra en **cours 3** (saw bass) comment construire une saw **anti-aliasée manuellement** en lissant la discontinuité par une polynomial transition.

---

## Ce qu'on entend

Trois plucks à 440 Hz, séparés par 0.7 s :

1. **Sinus** — rond, pur, presque ennuyeux.
2. **Square** — nasillard, chiptune.
3. **Saw** — agressif, métallique, brillant.

Plus la fréquence augmente, plus la saw devient « sale » : c'est l'aliasing.

---

## Expérimentations suggérées

1. **Test aliasing** : remplacer `440.0` par `1760.0` (deux octaves plus haut) → la saw devient nettement plus désagréable.
2. **Test extrême** : `5000.0` → on entend des partiels « impossibles » plus bas que la fondamentale. C'est du repliement pur.
3. **Comparer mathématiquement** :
   - `sin(TWOPI*f*t) + sin(TWOPI*3.0*f*t)/3.0` → approximation d'une square avec **seulement 2 harmoniques**, sans aliasing.
   - Ajouter `+ sin(TWOPI*5.0*f*t)/5.0` etc. Observer comment ça converge vers la square — sans le sale.
4. **Pluck triangle** : implémenter `(2.0 * abs(2.0 * mod(t*f, 1.0) - 1.0) - 1.0)`. Spectre proche de la square mais en `1/n²` ⇒ moins brillant, moins aliasé.

---

## Limites de cette étape

L'aliasing condamne ces waveforms brutes dès qu'on monte en fréquence. La solution moderne et **adaptée au GPU** : la **synthèse FM**, qui produit des spectres riches mais **bornés** ⇒ étapes 04–05.

---

[[Étape 02 - Enveloppe et sinPluck|← Étape 02]] · [[Étape 04 - Modulation FM|→ Étape 04 — Modulation FM]]

#shader #audio #shadertoy #td
