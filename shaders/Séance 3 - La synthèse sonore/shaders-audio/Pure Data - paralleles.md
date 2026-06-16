# Pure Data — parallèles avec les cours shader audio

> **Note compagnon** des cours [[Cours 1 - Bases, waveforms et melodie|Cours 1]], [[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2]] et [[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3]].
> Source bibliographique principale : *bang | Pure Data* (F. Zimmer dir., Wolke Verlag, 2006) — voir `Zimmer - 2006 - bang Pure Data.pdf` (ignoré du repo).

L'objectif : pour chaque concept abordé en GLSL/Shadertoy, montrer **comment on l'écrirait en Pure Data** et **pourquoi le paradigme change tout**.

---

## 1. Pure Data en deux paragraphes

**Pure Data (Pd)** est un **langage de programmation visuel temps réel** pour la musique et le signal, écrit par **Miller Puckette** au début des années 90. Le code se manipule comme un graphe : des **boîtes** (`[osc~ 440]`, `[*~ 0.5]`, etc.) reliées par des **fils** qui transportent soit du **signal audio** (44.1 kHz, fils épais, suffixe `~`), soit des **messages** asynchrones (control rate, fils fins).

> *« Pd is a graphic computer music language for real-time applications and was written by Miller S. Puckette. Pd can also be read and understood as public domain. »* — W. Ritsch, **Does Pure Data Dream of Electric Violins?**, *bang* (2006), p. 11.

Cette dualité **signal / message** est le cœur du modèle : un patch Pd contient simultanément du DSP audio (synchrone, sample-accurate) et de la logique de contrôle (asynchrone, event-driven).

---

## 2. Trois différences fondamentales avec un shader audio

| Aspect | Shader audio (`mainSound`) | Pure Data |
|---|---|---|
| **Paradigme** | Fonctionnel pur, stateless | Dataflow stateful, graphe persistant |
| **État** | Aucun — tout est `f(t)` | Filtres récursifs, buffers, mémoire de phase |
| **Temps** | Échantillon `t` passé en argument | Horloge globale + scheduler-dispatcher |
| **Parallélisme** | Massif (GPU, 1 thread / sample) | Séquentiel par sample, multi-canal |
| **Interaction** | Pas d'entrée utilisateur (sauf `iMouse`) | MIDI, HID, OSC, capteurs, vidéo natifs |
| **Récursion** | Interdite | Naturelle (feedback loops `delwrite~/delread~`) |
| **Compilation** | GPU → SPIR-V | Patch interprété live |

> *« In Pd graphs, however, two independent levels of data flow are represented, one signal level (signal dataflow) and one event level (message system). »* — Ritsch, p. 13.

C'est exactement **ce qui manque** au shader pour faire des choses comme un filtre IIR ou un délai à feedback. Inversement, ce qui manque à Pd, c'est la **densité d'évaluation parallèle** d'un GPU — Pd calcule typiquement par **blocs de 64 samples**, pas en SIMD massif.

---

## 3. Parallèles concept par concept

### 3.1 Onde sinus de base (Cours 1, §2)

| Shader | Pure Data |
|---|---|
| `sin(TAU * 440.0 * time)` | `[osc~ 440]` → `[*~ 0.1]` → `[dac~]` |

`[osc~ f]` est l'**oscillateur sinusoïdal** de Pd. Il **maintient sa phase en interne** — pas besoin de passer `t`. C'est le premier indice du changement de paradigme : la fonction d'onde est encapsulée dans un objet qui possède un état.

```
[osc~ 440]
   |
[*~ 0.1]
   |
[dac~]
```

> **Anecdote pédagogique** : le tilde `~` qui suffixe les objets DSP est une convention de Pd/Max. Sans tilde = message, avec tilde = signal. Les étudiants confondent souvent les deux au début.

### 3.2 Enveloppe exponentielle (Cours 1, §3)

| Shader | Pure Data |
|---|---|
| `exp(-3.0 * t)` | `[line~ 1 0 333]` ou `[vline~]` |

Pure Data n'a pas d'`exp` natif côté audio aussi simple — on utilise typiquement un **générateur de rampe** `[line~]` (linéaire) ou `[vline~]` (variable). Pour une vraie exponentielle, on calcule via une table ou avec un filtre à un pôle :

```
[bang(
   |
[del 0(           ← envoie un "0"
   |
[line~ 1 0.001 0( ← rampe vers 0 en 0.001s, démarre à 1
   |
[*~ ...]          ← multiplie par le signal
```

Ou plus élégant, on échantillonne directement `exp` dans un buffer avec `[tabread4~]`.

### 3.3 Sommation, polyphonie (Cours 1, §4)

```
[osc~ 440]   [osc~ 660]
       \      /
       [+~ ]
         |
       [*~ 0.5]   ← attention au clipping !
         |
       [dac~]
```

Le `[+~]` est la version signal de l'addition. Comme en shader, on doit baisser l'amplitude pour éviter le clipping.

### 3.4 Panning stéréo (Cours 1, §6)

```
[osc~ 440]
    |
   [t a a]            ← duplique le signal
    |    |
[*~ 0.7] [*~ 0.3]     ← gain L différent de R
    |    |
  [dac~ 1 2]
```

Pour un **constant-power pan**, on utilise typiquement `[expr~ cos($v1 * 0.7854)]` et `[expr~ sin($v1 * 0.7854)]` (avec `$v1 ∈ [0,1]`).

### 3.5 Aliasing (Cours 1, §7)

Pd a des oscillateurs **bandlimited** natifs dans plusieurs externals (`[phasor~]` + filtrage manuel, ou la bibliothèque `[bsaylor]`). Le `[phasor~]` brut alias autant qu'une saw en shader. Mais à la différence du shader, **on peut faire suivre un filtre passe-bas** :

```
[phasor~ 440]   ← saw brute (aliase)
    |
[*~ 2] → [-~ 1] ← passe en [-1, +1]
    |
[lop~ 5000]     ← passe-bas simple à 5 kHz (impossible en shader !)
    |
[dac~]
```

> Le `[lop~]` est exactement le filtre IIR à un pôle qu'on n'a pas pu écrire en shader.

### 3.6 Modulation de fréquence (Cours 1, §8 et Cours 2 entier)

Le **patch FM canonique** en Pd :

```
[osc~ 440]                ← modulator (fm = 440)
    |
[*~ 200]                  ← amplitude de modulation (devient déviation Hz)
    |
[+~ 440]                  ← ajoute à la carrier (fc = 440)
    |
[osc~ ]                   ← carrier modulée
    |
[*~ 0.1]
    |
[dac~]
```

Trois différences importantes avec la version shader :

1. **Pas de phase explicite** : `[osc~]` lit sa fréquence en signal et gère sa propre phase. La modulation est *naturellement* correcte (pas de piège du vibrato comme en [[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2 §6]]).
2. **L'IOM n'existe pas en tant que paramètre** — on règle directement la déviation `Δf`. C'est plus intuitif physiquement, moins compact à raisonner.
3. **C'est vraiment** de la FM (pas de la phase modulation comme dans nos shaders).

> *« I'm the Operator with the Pocket Calculator »* — T. Musil & H. A. Wiltsche, *bang* (2006), p. 43. Le titre, clin d'œil à Kraftwerk, résume l'esthétique : Pd reproduit le sentiment de manipuler un patch modulaire analogique, oscillateurs et fils inclus.

### 3.7 Filtres (impossibles en shader, naturels en Pd)

C'est **la grande absence** du module shader. Pd les implémente trivialement :

| Filtre | Objet Pd |
|---|---|
| Passe-bas 1 pôle | `[lop~ fc]` |
| Passe-haut 1 pôle | `[hip~ fc]` |
| Passe-bande | `[bp~ fc Q]` |
| Biquad générique | `[biquad~ ...]` ou `[fexpr~ ...]` |
| Filtre VCF Moog | externals comme `[moog~]` |

Tous reposent sur des **équations récursives** $y[n] = \sum a_k x[n-k] - \sum b_k y[n-k]$ — impossibles en shader puisqu'on n'a pas accès à $y[n-1]$.

> **TP suggéré** : refaire la **saw anti-aliasée** du [[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3]] avec une saw brute `[phasor~]` suivie d'un `[lop~ 4000]`, et comparer à l'oreille avec la version shader « bandlimited à la main ».

### 3.8 Modélisation physique (Cours 3, §1 marimba)

Pure Data dispose d'**objets dédiés à la modélisation physique** via les bibliothèques `pmpd` et `msd` de Cyrille Henry :

> *« pmpd provides objects for the simulation of physical behaviors such as basic energetic and movement related objects. These are mass and link, allowing particle-based physical modeling. They simulate the behaviors of a single mass or link (a link is, for example, a spring between two masses) and react like ideal objects in a physical world. »* — C. Henry, **Basic Physical Modeling Concepts**, *bang* (2006), p. 52.

Concrètement on peut **construire un instrument à partir de masses et de liens visco-élastiques** :

```
[masse~ 1.0 0 0]        ← une masse de poids 1, position et vitesse initiale 0
[link~ 100 0.5]         ← un lien : rigidité 100, amortissement 0.5
[metro 1]               ← horloge à 1 ms pour faire avancer la simulation
```

L'équation utilisée est la même que celle qu'on a effleurée pour la marimba :

$$ F = m \ddot{x} \quad ; \quad F_{\text{lien}} = K \cdot \Delta L + D \cdot \Delta \dot{L} $$

On peut alors construire une **lame de marimba physique** comme une chaîne de masses-ressorts, plutôt que comme un signal FM approximant son spectre. C'est plus coûteux mais plus expressif (résonance, sympathies, etc.).

### 3.9 Reverb (Cours 2 §5, Cours 3 §5)

Le « fake reverb » des shaders (mélange de versions retardées) devient en Pd une **vraie reverb** :

```
[delwrite~ buffer 5000]   ← buffer circulaire de 5 s
[delread~ buffer 230]     ← tap à 230 ms
[delread~ buffer 470]
[delread~ buffer 730]
[+~] [+~] [+~]
     |
[*~ 0.6]                  ← feedback dans delwrite~ pour réverb infinie
```

Pour une **convolution reverb** (la « vraie » de pro), Pd a `[partconv~]` qui convolue un signal entrant avec une impulsion enregistrée.

### 3.10 Séquenceur / pattern (Cours 2 §10, Cours 3)

En shader, on **déroule la séquence à la compilation**. En Pd, on a un vrai **scheduler** :

```
[metro 500]      ← un "bang" toutes les 500 ms
   |
[counter 0 7]    ← compte 0..7 puis boucle
   |
[tabread notes]  ← lit la note correspondante dans un tableau
   |
[mtof]           ← convertit MIDI → Hz
   |
[osc~ ]
```

Plus expressif : on peut **changer la mélodie en live** sans recompiler.

> *« Through the possibility of creating live music with the computer, the paradigm of computer music software changes from "composing" to "making music". »* — Ritsch, p. 12.
> C'est ici que Pd devient **livecoding** et qu'on s'éloigne franchement du shader.

---

## 4. Objets Pd à connaître absolument

| Catégorie | Objets clés |
|---|---|
| Oscillateurs | `[osc~]` `[phasor~]` `[noise~]` |
| Enveloppes | `[line~]` `[vline~]` `[env~]` |
| Filtres | `[lop~]` `[hip~]` `[bp~]` `[biquad~]` |
| Math signal | `[+~]` `[-~]` `[*~]` `[/~]` `[expr~]` `[fexpr~]` |
| Délais | `[delwrite~]` `[delread~]` `[vd~]` |
| Tables | `[tabread~]` `[tabread4~]` `[tabwrite~]` |
| Sampling | `[soundfiler]` `[readsf~]` `[writesf~]` |
| Conversion | `[mtof]` (MIDI→Hz) `[ftom]` `[dbtorms]` |
| Contrôle | `[metro]` `[bang]` `[trigger]` `[select]` `[route]` |
| I/O | `[notein]` `[ctlin]` `[netreceive]` `[hid]` |
| Sortie | `[dac~]` `[adc~]` |
| Patches | `[pd subpatch]` `[abstraction]` `[inlet~/outlet~]` |

---

## 5. Le modèle d'instrument selon Steiner

Pour les étudiants qui voudront construire **un instrument complet** plutôt qu'une boucle, voici le découpage canonique :

> *« When approaching instrument design, the overall problem can be broken down into input, output, mapping, and feedback. The idea of input is straightforward: the data used to control the instrument. Output is also a simple concept: the desired result of playing the instrument. Mapping is a more complex idea: the processing and connecting of input data to parameters which control output. And last but not least, feedback is communication generated from the input, output, and/or mapping data. »* — H.-C. Steiner, **Building Your Own Instrument with Pd**, *bang* (2006), p. 75.

```
   gestes ──► [INPUT] ═════ MAPPING ═════► [OUTPUT] ──► audio/vidéo
                  ▲                            │
                  └────────── FEEDBACK ◄───────┘
```

Le **mapping** est la partie créative : un slider MIDI peut piloter directement la fréquence (mapping trivial) ou indirectement la rigidité d'une masse-ressort qui pilote elle-même un oscillateur (mapping riche). Cette idée n'a **aucun équivalent** dans le shader audio puisqu'il n'y a pas d'entrée utilisateur expressive.

> Ce schéma vaut un cours à lui tout seul — c'est le pont entre **synthèse** et **lutherie numérique**.

---

## 6. Quand préférer Pd au shader (et inversement)

| Vous voulez… | Outil | Raison |
|---|---|---|
| Un son **stateless** courant dans une démo 4kb | Shader | Compilation GPU, pas d'environnement |
| Un **vrai filtre** résonant ou un VCF | Pd | Récursivité native |
| Une **convolution reverb** | Pd | Buffers et FFT natifs |
| Une **génération massive de voix** (1000 oscillateurs) | Shader | Parallélisme GPU |
| Un **instrument live** piloté par MIDI/capteurs | Pd | I/O temps réel intégré |
| Un **audio-visuel** où son et image partagent une formule | Shader | Une seule passe GPU |
| Un **patch modifiable en performance** | Pd | Hot-reload natif, scheduler dynamique |
| Une **modélisation physique masses-ressorts** | Pd + pmpd | Mémoire d'état |

---

## 7. Pistes de TP en Pure Data

### TP A — Mêmes instruments, autre paradigme (2h)
Reproduire en Pd les trois instruments du module :
- **pad** ([[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2 §4]]) : FM stéréo + couche presence + reverb `[delwrite~]/[delread~]`.
- **marimba** ([[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3 §1]]) : FM avec ratio inharmonique, comparer à une version pmpd masses-ressorts.
- **saw bass** ([[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3 §2]]) : `[phasor~]` + `[lop~]` au lieu du bandlimiting manuel.

Livrable : 3 patches `.pd` + un fichier d'écoute comparative avec la version shader.

### TP B — L'instrument live (3h)
À partir du modèle de Steiner :
- INPUT : un clavier MIDI ou la souris.
- MAPPING : créatif (un slider pilote la fréquence ET le filtre ET l'IOM FM).
- OUTPUT : un synthé construit lors du TP A.
- FEEDBACK : visuel via Gem (l'extension OpenGL de Pd) ou OSC vers Hydra.

Livrable : un patch jouable en live + une captation vidéo de 1 min.

### TP C — Physical modeling (3h)
Construire une **corde** en chaîne de masses-ressorts (`pmpd`), la pincer, écouter. Comparer la simulation à Karplus-Strong (filtre passe-bas dans un délai).

---

## 8. Installer Pure Data

- **Pd vanilla** (Miller Puckette) : <http://msp.ucsd.edu/software.html>
- **Pd-extended** (legacy, plus d'externals) : abandonné mais encore distribué.
- **Purr Data** (fork moderne) : <https://agraef.github.io/purr-data/>

Pour les TP : installer **Pd vanilla** + le package **pmpd** via `Help > Find externals`.

---

## 9. Bibliographie

### Le livre source (CC BY-NC-ND 2.5)

**Zimmer, F. (dir.).** *bang | Pure Data*. Wolke Verlag, Hofheim, 2006. ISBN 978-3-936000-37-5.
PDF dans ce dossier : `Zimmer - 2006 - bang Pure Data.pdf` (ignoré du repo).

Chapitres particulièrement utiles :

- **W. Ritsch** — *Does Pure Data Dream of Electric Violins?* (p. 11) — paradigme dataflow, théorie graphe, histoire.
- **C. Henry** — *Basic Physical Modeling Concepts* (p. 49) — pmpd, masses-ressorts, lutherie virtuelle.
- **H.-C. Steiner** — *Building Your Own Instrument with Pd* (p. 73) — modèle Input/Mapping/Output/Feedback.
- **B. Jurish** — *Music as a Formal Language* (p. 81) — musique comme langage formel.
- **M. Puckette** — *A Divide Between 'Compositional' and 'Performative' Aspects of Pd* (p. 143) — l'auteur de Pd sur les tensions de son outil.

### Compléments

- **M. Puckette** — *The Theory and Technique of Electronic Music*. World Scientific, 2007. Le manuel canonique. PDF gratuit : <http://msp.ucsd.edu/techniques.htm>
- **J. Kreidler** — *Loadbang: Programming Electronic Music in Pd*. Wolke Verlag, 2009. Approche pédagogique progressive.
- Documentation officielle : <https://puredata.info/docs>

---

## Liens internes

- [[_Index - Shaders Audio]] — sommaire du module
- [[Themes audio - panorama]] — vue d'ensemble des thèmes audio (Pd y figure en §2.1)
- [[Cours 1 - Bases, waveforms et melodie]]
- [[Cours 2 - FM Synthesis, Pad, Lead Synth]]
- [[Cours 3 - Marimba, Saw Bass, Wah Synth]]

#audio #puredata #cours #esgi #parallele
