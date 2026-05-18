# Étape 09 — leadSynth

> Décomposition [[shadertoy2 code]] — **étape 9 / 10**
> Concept : un synthé solo en **5 couches** — corps, présence, attaque — avec une **fausse compression** pour le rendre puissant.

---

## Objectif pédagogique

- Stratifier un instrument lead à partir de la phase vibrée de l'étape 08.
- Comprendre les **trois familles de couches** : corps (grave), présence (médium-aigu), attaque (transitoire).
- Découvrir la **fausse compression** : une enveloppe qui accentue l'attaque et le corps.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831853
#define N(nn) (440.0*exp2(((nn)-9.0)/12.0))
#define FM(fc, fm, iom)  sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define FM2(pc, pm, iom) sin(mod(pc, TWOPI) + (iom)*sin(mod(pm, TWOPI)))

float vibratoPhase(float f0, float semitones, float vibHz, float t)
{
    float df = 0.06*f0*semitones;
    return TWOPI*f0*t + df/vibHz*sin(TWOPI*vibHz*t);
}

vec2 leadSynth(float f, float t)
{
    vec2 sig = vec2(0.0);
    t = max(t, 0.0);                          // protège l'enveloppe exponentielle

    float vibEnv = smoothstep(0.0, 0.5, t);
    float phase  = vibratoPhase(f, 0.2*vibEnv, 5.0, t);
    float tpt    = TWOPI*t;

    // CORPS — la fondamentale, chaude et large
    sig += FM2(phase,           phase,                      1.0) * 0.05;
    sig += FM2(phase + 5.0*tpt, phase + vec2(-1.0, 0.8)*tpt, 3.0) * 0.02;

    // PRÉSENCE — couche aiguë harmonique qui fait « percer » le lead
    float ratio = round(5000.0/f);
    float iom   = 1500.0/f;
    sig += FM2(ratio*phase,           phase,                     iom) * 0.01;
    sig += FM2(ratio*phase + 5.0*tpt, phase + vec2(3.0,-3.0)*tpt, iom) * 0.01;

    // ATTAQUE — transitoire brillant, éteint en ~30 ms
    float fc = f * round(10000.0/f);
    iom = 10000.0/f;
    sig += FM(fc, f, iom) * 0.05 * exp(-30.0*t);

    // FAUSSE COMPRESSION
    float env = 0.7*(1.0 + smoothstep(0.02, 0.0, t) + 0.3*smoothstep(0.0, 0.5, t));
    return sig * env;
}

vec2 mainSound( int samp, float t )
{
    return leadSynth(N(7.0), mod(t, 2.0));   // Sol4 répété
}
```

---

## Théorie

### Trois familles de couches

Un instrument lead crédible se découpe en trois registres, chacun fabriqué par des couches FM distinctes.

**Corps** — `* 0.05` et `* 0.02`, index 1 à 3 :
```glsl
sig += FM2(phase,           phase,                      1.0) * 0.05;
sig += FM2(phase + 5.0*tpt, phase + vec2(-1.0, 0.8)*tpt, 3.0) * 0.02;
```
La fondamentale et son entourage proche. La 2ᵉ couche ajoute `5.0*tpt` à la phase : c'est un **décalage de fréquence fixe** de 5 Hz (`tpt = 2π·t`), un détune qui épaissit. Sa modulante est un `vec2` → largeur stéréo (étape 02).

**Présence** — `* 0.01`, porteuse `ratio*phase` :
```glsl
float ratio = round(5000.0/f);   // harmonique le plus proche de 5000 Hz
float iom   = 1500.0/f;
sig += FM2(ratio*phase,           phase,                     iom) * 0.01;
sig += FM2(ratio*phase + 5.0*tpt, phase + vec2(3.0,-3.0)*tpt, iom) * 0.01;
```
Même astuce qu'au pad (étape 04) : `round(5000.0/f)` choisit un **harmonique** aigu, multiple entier de la note, qui « suit » la mélodie. C'est cette couche qui fait que le lead **perce** par-dessus le pad au lieu de se noyer dedans. Multiplier `phase` par `ratio` (entier) garde le vibrato cohérent : il se transpose proprement sur l'harmonique.

**Attaque** — `* exp(-30.0*t)`, index énorme :
```glsl
float fc = f * round(10000.0/f);
iom = 10000.0/f;
sig += FM(fc, f, iom) * 0.05 * exp(-30.0*t);
```
Un éclat très aigu et très riche (index `10000/f`), éteint en ~30 ms par `exp(-30·t)`. C'est le **transitoire d'attaque** : le « clic » initial qui donne du mordant. Noter qu'on utilise `FM` (et non `FM2`) — l'attaque n'a pas besoin du vibrato, juste d'un coup de brillance bref. Elle disparaît avant que le vibrato ne s'installe.

### `t = max(t, 0.0)` — protéger l'exponentielle

```glsl
t = max(t, 0.0);
```

`exp(-30.0*t)` avec un `t` négatif donnerait `exp(+grand)` → **explosion** du signal et clipping violent. C'est exactement le piège vu à l'[[Étape 08 - Séquenceur jingle|étape 08 du code 1]]. Le séquenceur de l'étape 10 enverra des `t` légèrement négatifs (notes pas encore commencées) : `max(t, 0.0)` est la ceinture de sécurité.

### La fausse compression

```glsl
float env = 0.7*(1.0 + smoothstep(0.02, 0.0, t) + 0.3*smoothstep(0.0, 0.5, t));
```

Un vrai compresseur réduit la dynamique en temps réel. On l'**imite** ici par une simple enveloppe de gain, somme de trois termes :

- `1.0` : le gain de base.
- `smoothstep(0.02, 0.0, t)` : **décroissant** (1er arg > 2e), vaut 1 sur les 20 premières ms puis tombe à 0 → un **coup de gain à l'attaque**. Le lead « claque » au démarrage.
- `0.3*smoothstep(0.0, 0.5, t)` : **croissant**, monte de 0 à 0,3 sur la première demi-seconde → le corps de la note **gonfle** légèrement après l'attaque, comme un son « tenu » qui s'épanouit.

Le tout × `0.7` pour rester dans le budget d'amplitude. Résultat perçu : un lead **dense, présent, qui pousse** — la signature d'un son « produit », mixé.

> C'est de la psychoacoustique de studio condensée en une ligne : pas de vrai traitement de dynamique, juste une courbe de gain bien choisie. Suffisant parce que l'oreille juge surtout l'**enveloppe** d'un son.

---

## Ce qu'on entend

Un synthé solo riche et puissant sur un Sol4 répété toutes les 2 s : une attaque qui claque, un corps chaud et large, une brillance aiguë qui perce, le tout animé d'un vibrato. C'est un vrai son de *lead*, prêt à porter une mélodie.

---

## Expérimentations suggérées

1. Désactiver les couches une par une (commenter) → isoler ce qu'apporte le corps, la présence, l'attaque.
2. Couper l'attaque (`exp(-30.0*t)` → `* 0.0`) → le lead devient mou, sans mordant.
3. Figer la compression (`env = 0.7`) → le son perd son claquement et son « gonflement ». A/B parlant.
4. Ralentir l'extinction de l'attaque : `exp(-8.0*t)` → l'éclat traîne, le son devient agressif.
5. Jouer grave `N(-5.0)` puis aigu `N(16.0)` → vérifier que `ratio` et `iom` adaptent le timbre.

---

## Limites de cette étape

`leadSynth` joue une note unique répétée. Il reste à le piloter avec une **mélodie**, à le placer dans l'espace par échos, et à le **mixer avec le pad**. C'est l'assemblage final : étape 10.

---

[[Étape 08 - Vibrato correct|← Étape 08]] · [[Étape 10 - Séquenceur lead et mix final|→ Étape 10 — Séquenceur lead et mix final]]

#shader #audio #shadertoy #td
