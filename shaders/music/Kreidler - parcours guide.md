# Kreidler — parcours de lecture guidé

> Programme d'**auto-formation Pure Data** basé sur le tutoriel libre :
> **Johannes Kreidler, *Programming Electronic Music in Pd*, 2009.**
> Source en ligne : <http://www.pd-tutorial.com/english/index.html>
> Sommaire local : `shaders/music/index.html`

Compagnon des cours [[Cours 1 - Bases, waveforms et melodie|Cours 1]], [[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2]], [[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3]] et de la note [[Pure Data - paralleles]].

---

## 1. Pourquoi ce livre

Kreidler est un **compositeur** allemand. Son tutoriel a été écrit pour des compositeurs voulant apprendre Pd **par l'écoute** plutôt que par les formules. Cela en fait paradoxalement un **excellent complément** à un cours d'ingénierie shader, parce qu'il prend le contre-pied :

- Le shader part de la formule (`sin(TAU * f * t)`) ; Kreidler part du **son entendu**.
- Le shader est stateless ; Kreidler explore des structures **statefulles** (sampling, séquenceur, capteurs).
- Le shader est solitaire (le GPU calcule) ; Kreidler est **interactif** (la souris, le MIDI, le réseau).

Chaque section du livre suit la même trame : **Theory → Applications → Appendix → For those especially interested**. Cette structure se prête bien à un **parcours d'auto-formation hebdomadaire**.

---

## 2. Vue d'ensemble du parcours

8 semaines, ~3-4 h hebdomadaires (lecture + manipulation Pd + exercice).

| Semaine | Sujet Kreidler | Lien avec le module shader |
|---|---|---|
| 1 | Préface + Ch. 1-2 (Pd, control level) | Paradigme dataflow, à comparer au stateless GLSL |
| 2 | §3.1 Basics (pitch, volume) + §3.2 Additive | Cours 1 §2-§4 |
| 3 | §3.3 Subtractive | (Filtres : grande absence du shader) |
| 4 | §3.6 Modulation synthesis | **Cours 2 entier** |
| 5 | §3.5 Wave shaping + §3.4 Sampling | Cours 3 §2 (saw) + ouverture sampling |
| 6 | §3.7 Granular + §3.8 Fourier | Panorama §1.5 + ouverture analyse |
| 7 | §4 Controlling sound (algorithmes, séquenceur, HID, OSC) | Cours 2/3 §10 (patterns) + lutherie |
| 8 | §5.2 Visuals (GEM) + §3.9 Amplitude | Pont audio-visuel + mix |

---

## 3. Semaine par semaine

### Semaine 1 — Découvrir le paradigme

**Lectures** :
- [Preface](http://www.pd-tutorial.com/english/pr01.html) + [Methodology](http://www.pd-tutorial.com/english/pr02.html)
- [Chapter 1 — Introduction to Pd](http://www.pd-tutorial.com/english/ch01.html)
- [§1.2 — Installing and setting up Pd](http://www.pd-tutorial.com/english/ch01s02.html)
- [Chapter 2 — Programming with Pd for the first time](http://www.pd-tutorial.com/english/ch02.html)
- [§2.2 — The control level](http://www.pd-tutorial.com/english/ch02s02.html)

**Objectifs** :
- Installer Pd vanilla, comprendre la fenêtre principale.
- Distinguer boîtes-objet, boîtes-message, atomes, commentaires.
- Comprendre la **différence message / signal** (le tilde `~`).
- Faire les premiers patches en control rate (math, time, types).

**Lien shader** : la section §2.2.3 sur les **time operations** (`[delay]`, `[metro]`, `[pipe]`, `[timer]`) montre **tout ce que le shader n'a pas** — un scheduler explicite. C'est le bon moment pour expliciter en cours pourquoi le shader évite ces questions.

**Milestone** : un patch « bonjour Pd » qui compte les secondes et imprime dans la console.

**Patch type — compter les secondes** :

```
   [bang(           ← démarrage manuel
     |
   [metro 1000]     ← un "bang" toutes les 1000 ms
     |
   [+ 1]            ← incrémente
     |
   [f ]             ← stocke le résultat dans une float
     |   \____ retour vers [+ 1] pour boucler
   [print compteur]
```

> **Équivalent shader** : `int sec = int(time);`
> Le shader n'a pas besoin de scheduler — le temps lui est donné. Pd doit **construire activement** son passage du temps.

---

### Semaine 2 — Synthèse additive et bases acoustiques

**Lectures** :
- [§3.1 — Basics: pitch and volume](http://www.pd-tutorial.com/english/ch03.html#chapt3.1)
- [§3.2 — Additive synthesis](http://www.pd-tutorial.com/english/ch03s02.html) (Theory → Applications → For those especially interested)

**Concepts** :
- Conversion **MIDI ↔ Hz** via `[mtof]` / `[ftom]` — équivalent du `noteFreq()` du [[Cours 1 - Bases, waveforms et melodie|Cours 1 §9.1]].
- Échelle **logarithmique** du volume (dB), équivalent `[dbtorms]`.
- Somme de plusieurs `[osc~]` pondérés → tons complexes.

**Liens avec le module shader** :
- Le Cours 1 §2 (sin pur) = §3.1 de Kreidler.
- Le Cours 1 §4 (sommer plusieurs notes) = §3.2.
- Le « wah synth » du [[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3 §4]] est exactement de la synthèse additive bandlimitée → §3.2.4 « For those especially interested ».

**Exercice** : reproduire l'accord A-C#-E des cours en `[osc~]` empilés. Comparer le timbre à la version pluck FM.

**Patch type — accord majeur additif** :

```
[69(   [73(   [76(             ← messages : MIDI A4, C#5, E5
  |      |      |
[mtof] [mtof] [mtof]            ← conversion MIDI → Hz
  |      |      |
[osc~] [osc~] [osc~]            ← trois sinus
  |      |      |
[*~ .3][*~ .3][*~ .3]           ← réduire l'amplitude (3 voix → /3)
  \      |      /
   \_____|_____/
         |
       [+~ ]                    ← somme stéréo
         |
       [dac~]
```

> **Équivalent shader** :
> ```glsl
> float a = sin(TAU * 440.0 * t);
> float b = sin(TAU * 554.4 * t);
> float c = sin(TAU * 659.3 * t);
> return vec2(0.3 * (a + b + c));
> ```
> En Pd, on compose le graphe une fois pour toutes ; en shader, on évalue tout à chaque sample.

---

### Semaine 3 — Synthèse soustractive (la grande absence du shader)

**Lectures** :
- [§3.3 — Subtractive synthesis](http://www.pd-tutorial.com/english/ch03s03.html) en entier.

**Concepts** :
- Sources : `[noise~]`, `[phasor~]`, oscillateurs riches.
- Filtres : `[lop~]`, `[hip~]`, `[bp~]`, `[vcf~]`.
- Notion de **fréquence de coupure** et **résonance Q**.
- Application : synthèse soustractive d'un son d'orgue, d'un kick.

**Lien shader** : c'est **précisément ce qu'on ne peut pas faire en shader stateless**. Bonne occasion pour expliciter en cours pourquoi le shader doit recourir à la **synthèse additive bandlimitée** (Cours 3 §4) ou au **smoothing de discontinuité** (Cours 3 §2) plutôt qu'à un vrai filtre.

**Exercice comparatif** : refaire la saw bass du Cours 3 en `[phasor~]` + `[lop~ 4000]`. Comparer à l'oreille et au spectrogramme avec la version shader « bandlimited à la main ».

**Patch type — synthé soustractif (saw + filtre + résonance)** :

```
   [phasor~ 110]              ← saw brute à 110 Hz (A2)
        |
   [*~ 2] → [-~ 1]            ← remappe [0,1] → [-1,+1]
        |
   ┌────┴────┐
   |         |
[vcf~]   [<-- 2000(           ← fréquence de coupure pilotée
   |         | 
   |    [<-- 4(               ← résonance Q
   |
[*~ 0.3]
   |
[dac~]
```

> Le `[vcf~]` filtre passe-bande résonant. Ses **inlets de droite** reçoivent la coupure et le Q en messages.
> Côté shader, ce filtre récursif (`y[n] = a·x[n] + b·y[n-1] - c·y[n-2]`) est strictement **impossible** : pas d'accès à `y[n-1]`.

**Variante "wobble bass"** : un `[osc~ 0.5]` (LFO 0.5 Hz) → `[*~ 800]` → `[+~ 1200]` pilote l'inlet de coupure. La fréquence de coupure oscille → effet dubstep classique.

---

### Semaine 4 — Modulation synthesis (le cœur du Cours 2)

**Lectures** :
- [§3.6 — Modulation synthesis](http://www.pd-tutorial.com/english/ch03s06.html) en entier.

**Concepts couverts par Kreidler ET le Cours 2** :
- **Amplitude modulation** (AM) : produit de deux signaux → sidebands `f1±f2`.
- **Ring modulation** : variante de l'AM, multiplication signée.
- **Frequency modulation** : porteuse modulée par un autre oscillateur.
- **Phase modulation** : ce que font réellement nos shaders.

**Concepts nouveaux pour les étudiants** :
- L'AM et la ring mod, qu'on a juste effleurées dans [[Themes audio - panorama|Themes audio §1.4]].
- En Pd, on n'a **pas** le piège du vibrato « f(t) × t » du [[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2 §6]] parce que `[osc~]` gère sa phase en interne.

**Lien shader** : ce chapitre est **la** synthèse parfaite avec le Cours 2. Faire lire les deux en parallèle.

**Exercice projet** : reproduire le **lead synth** du Cours 2 (FM + vibrato + presence + attaque) en Pd. Comparer la difficulté d'écriture, les paramètres exposés.

**Patch type — synthé FM avec IOM contrôlé** :

```
   [440(              [1(           ← fc = 440 Hz, IOM = 1.0
     |                  |
     | ┌────────────────┘
     | |
     | └──► [*~ ]                    ← IOM scale la modulation
     |       ▲
     |    [osc~ ]                    ← oscillateur modulateur
     |       ▲
     |       └──── (relié à fc, donc fm = fc)
     |               
     └──► [+~ ]                      ← fc + (iom × mod)
            |
         [osc~ ]                     ← carrier modulée par le résultat
            |
         [*~ 0.3]
            |
         [dac~]
```

**Version explicite** avec déviation `Δf` plutôt qu'IOM :

```
[440(──┐
       └──► [osc~ ]    ← modulator à 440 Hz
              |
           [*~ 200]    ← déviation Δf = 200 Hz
              |
           [+~ 440]    ← fc + Δf·sin(...)
              |
           [osc~ ]     ← carrier
              |
           [*~ 0.3]
              |
           [dac~]
```

> **Avantage Pd** : la phase est gérée par `[osc~]` → **pas de piège du vibrato `f(t)·t`** du [[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2 §6]]. On modifie `f` à la volée, l'oscillateur intègre correctement.
> **Avantage shader** : on écrit la formule directe, c'est plus dense.

---

### Semaine 5 — Wave shaping et sampling

**Lectures** :
- [§3.5 — Wave shaping](http://www.pd-tutorial.com/english/ch03s05.html)
- [§3.4 — Sampling](http://www.pd-tutorial.com/english/ch03s04.html)

**Concepts** :
- **Wave shaping** : appliquer une fonction non-linéaire à un signal pour générer des harmoniques (distorsion, saturation, lookup table).
- **Sampling** : lire/écrire des tableaux audio (`[tabread~]`, `[tabwrite~]`, `[tabread4~]` pour interpolation cubique).

**Lien shader** :
- Le wave shaping est **trivial en shader** (`tanh`, `sign`, polynômes) — bonne occasion d'introduire des waveforms exotiques (`tanh(k * sin(...))`).
- Le sampling, en revanche, est **lourd en shader** (besoin d'une texture `iChannel`) — montre la force de Pd pour la manipulation de buffers.

**Exercice** : implémenter un **distortion FX** en wave shaping (shader ET Pd).

**Patch type — wave shaping (distortion `tanh`)** :

```
   [osc~ 220]            ← source sinusoïdale
        |
   [*~ ]                 ← gain pre-shaping (drive)
   ▲
[<-- 5(                  ← drive = 5 → saturation forte
        |
   [tabread4~ tanh-tbl]  ← lookup dans une table tanh précalculée
        |
   [*~ 0.5]              ← gain de sortie
        |
   [dac~]
```

> La table `tanh-tbl` est pré-remplie avec `tanh(x)` pour `x ∈ [-π, π]`. Le drive amplifie l'entrée → l'index pousse vers les bords saturés → harmoniques impaires.
> **Équivalent shader** : `return 0.5 * tanh(5.0 * sin(TAU * 220.0 * t));` — beaucoup plus court, parce que `tanh` est primitif en GLSL.

**Patch type — sampling avec lecture variable** :

```
   [bang(                    [open son.wav, 1(
     |                              |
   [soundfiler]            ← charge dans la table "buffer"
              \              /
               \            /
   [phasor~ 0.5]            ← rampe 0..1 sur 2 s (vitesse)
        |
   [*~ 44100]               ← convertit en index échantillon (1 s de son)
        |
   [tabread4~ buffer]       ← lecture interpolée
        |
   [dac~]
```

> En shader, lire un sample d'audio uploadé en texture est techniquement faisable mais lourd. En Pd, c'est natif.

---

### Semaine 6 — Granular et Fourier

**Lectures** :
- [§3.7 — Granular synthesis](http://www.pd-tutorial.com/english/ch03s07.html)
- [§3.8 — Fourier analysis](http://www.pd-tutorial.com/english/ch03s08.html)

**Concepts** :
- **Synthèse granulaire** : reproduire un son par micro-fragments. Histoire Xenakis-Roads (voir [[Themes audio - panorama|panorama §1.5]]).
- **FFT** dans Pd : `[fft~]`, `[ifft~]`, `[rfft~]`, transformations spectrales.

**Lien shader** : ces deux thèmes sont **inaccessibles au shader audio classique** mais essentiels à connaître pour un ingénieur audio. C'est aussi l'occasion d'introduire le **phase vocoder** et le **time-stretch sans changement de pitch**.

**Exercice** : un patch granulaire qui éclate un fichier `.wav` chargé en buffer ; jouer avec densité, durée des grains, position aléatoire.

**Patch type — grain unique (à dupliquer pour granular)** :

```
   [bang(                              ← déclenche un grain
     |
   [random 44100]                      ← position aléatoire (samples)
     |  
   [t f f]                             ← duplique
     |  \
[+ ...]  \
            \
             [vline~]                  ← rampe rapide pour position de lecture
                  |
            [tabread4~ source]          ← lecture du buffer
                  |
            [*~ ]                       ← multiplie par enveloppe Hann
                  |
            (← [tabread4~ hann] piloté par phase du grain)
                  |
               [dac~]
```

> Un seul grain : ~30 ms, enveloppe en cloche, position aléatoire dans un sample source.
> Pour faire de la granular : on duplique ce patch (ou on l'enferme dans `[poly]`) avec un `[metro 10]` qui balance des `[bang(` à 100 grains/seconde.

**Patch type — FFT analyse + resynthèse simple** :

```
   [adc~]                       ← micro
     |
   [rfft~]                      ← FFT bloc 64 samples (par défaut)
     | \
     |  └─► [outlet~ partie réelle]
     |
   [outlet~ partie imaginaire]

   ... traitement spectral ...

   [rifft~]                     ← inverse FFT
     |
   [dac~]
```

> Permet le **phase vocoder**, le **time stretching** sans changement de pitch, des effets spectraux exotiques. Tout ce qu'on ne peut **pas** faire en shader (besoin d'historique).

---

### Semaine 7 — Contrôler le son (interactivité)

**Lectures** :
- [Chapter 4 — Controlling sound](http://www.pd-tutorial.com/english/ch04.html)
- [§4.1 — Algorithms](http://www.pd-tutorial.com/english/ch04.html)
- [§4.2 — Sequencer](http://www.pd-tutorial.com/english/ch04s02.html)
- [§4.3 — HIDs (Human Interface Devices)](http://www.pd-tutorial.com/english/ch04s03.html)
- [§4.4 — Network (OSC, Netsend/Netreceive)](http://www.pd-tutorial.com/english/ch04s04.html)

**Concepts** :
- **Algorithmes génératifs** : random, Markov, Brownian motion appliqués à la musique.
- **Séquenceur** : `[metro]` + `[counter]` + tableau de notes (cf. [[Pure Data - paralleles|Pure Data - paralleles §3.10]]).
- **HID** : souris, joystick, capteurs — la dimension **performance live**.
- **OSC** : protocole standard de communication audio. Pont vers TouchDesigner, Max/MSP, Hydra, etc.

**Lien shader** : **ce que le shader audio ne permet PAS** — interaction utilisateur expressive. C'est ici qu'on rejoint le modèle Input/Mapping/Output/Feedback de **Steiner** (cité dans [[Pure Data - paralleles|Pure Data - paralleles §5]]).

**Projet** : un instrument jouable au clavier MIDI ou à la souris, paramètres mappés sur un synthé construit en semaine 4.

**Patch type — séquenceur 8 pas** :

```
   [bang(
     |
   [metro 125]              ← 125 ms par pas = 120 BPM en double-croches
     |
   [counter 0 7]            ← 0..7 puis boucle
     |
   [tabread melodie]        ← tableau de 8 notes MIDI : [60 62 64 65 67 64 62 60]
     |
   [mtof]                   ← MIDI → Hz
     |
   [osc~ ]                  ← oscillateur piloté par la mélodie
     |
   [*~ 0.3]
     |
   [dac~]
```

> Le tableau `melodie` est dessiné graphiquement dans Pd (`[array melodie]`) — on peut **modifier la mélodie en cliquant dessus en live**.
> Équivalent shader : un `const float[8]` figé à la compilation ([[Cours 1 - Bases, waveforms et melodie|Cours 1 §9.2]]).

**Patch type — contrôle MIDI** :

```
   [notein]                          ← reçoit MIDI in
     | \  \
   pitch vel canal
     |   |
   [mtof] |
     |   |
   [osc~] |
     |   [/ 127]  → [*~ ]            ← vélocité → gain
     └────────►   |
                [dac~]
```

> Reçoit notes MIDI d'un clavier physique ou virtuel.
> En shader : impossible sans MCP custom ou WebAudio externe.

---

### Semaine 8 — Visuels Pd + finitions

**Lectures** :
- [§3.9 — Amplitude corrections](http://www.pd-tutorial.com/english/ch03s09.html) (compression, limiting, normalisation)
- [§5.1 — Streamlining](http://www.pd-tutorial.com/english/ch05.html) (optimisation, abstractions, sous-patchs)
- [§5.2 — Visuals (GEM)](http://www.pd-tutorial.com/english/ch05s02.html)

**Concepts** :
- **Compression / limiting** : ce qu'on a simulé en shader avec le « compresseur de fortune » ([[Cours 2 - FM Synthesis, Pad, Lead Synth|Cours 2 §9]]).
- **Abstractions et sous-patchs** : organisation pro d'un projet Pd.
- **GEM** : OpenGL dans Pd → **le pont direct avec ton cours fragment shader**.

**Lien direct avec ton cours principal** : Kreidler §5.2.4 « For those especially interested » mentionne le passage de Pd à des shaders GLSL via GEM. C'est **le pont à exploiter** pour des projets pluri-disciplinaires.

**Projet final** : une performance audiovisuelle de 2 min en Pd+GEM, audio piloté par un capteur (souris, MIDI ou OSC), visuel piloté par l'audio (FFT → couleurs/formes).

**Patch type — compresseur simple (sidechain manuel)** :

```
   [osc~ 110]               [phasor~ 2]            ← source + kick virtuel à 2 Hz
        |                        |
        |                   [< 0.1]                ← détecte le début du cycle
        |                        |
        |                   [vline~ ...]           ← enveloppe "kick"
        |                        |
        |                   [-~ 1] → [*~ -1]       ← inverse (1→0 sur kick)
        |                        |
   [*~ ────────────────────────►]                   ← duck la source quand kick
        |
   [dac~]
```

> Reproduit la « pompe » du [[Cours 3 - Marimba, Saw Bass, Wah Synth|Cours 3 §3]] mais en utilisant un vrai détecteur de transient possible grâce à l'état.

**Patch type — pont audio → visuel avec GEM** :

```
[adc~]
   |
[env~ 256]              ← détecte l'enveloppe d'amplitude (RMS toutes les 256 samples)
   |
[/ 100]                 ← échelle pour pilotage
   |
[s amplitude]           ← envoie au sous-patch GEM

────── dans le sous-patch GEM ──────

[gemhead]
   |
[r amplitude]
   |
[translateXYZ 0 0 ▲]    ← Z piloté par le son
   |
[color $1 ▲ 1]          ← couleur pulse au rythme
   |
[cube 1]
```

> Au-delà du module audio : la **vraie convergence** avec ton cours fragment shader, puisque GEM est l'extension OpenGL de Pd et peut **charger des shaders GLSL** via `[glsl_program]` et `[glsl_vertex]` / `[glsl_fragment]`.

---

## 4. Tableau de correspondance rapide

| Concept shader (mes cours) | Chapitre Kreidler | URL directe |
|---|---|---|
| `mainSound` signature, `time` | §2.2.3 Time operations | [ch02s02](http://www.pd-tutorial.com/english/ch02s02.html) |
| `sin(TAU * f * t)` | §3.1 Basics + §3.2 Additive | [ch03](http://www.pd-tutorial.com/english/ch03.html) / [ch03s02](http://www.pd-tutorial.com/english/ch03s02.html) |
| Enveloppe `exp(-λt)` | §3.9 Amplitude corrections | [ch03s09](http://www.pd-tutorial.com/english/ch03s09.html) |
| Saw + aliasing | §3.3 Subtractive + §3.5 Wave shaping | [ch03s03](http://www.pd-tutorial.com/english/ch03s03.html) / [ch03s05](http://www.pd-tutorial.com/english/ch03s05.html) |
| FM / phase modulation | **§3.6 Modulation synthesis** | [ch03s06](http://www.pd-tutorial.com/english/ch03s06.html) |
| Filtres (filtre VCF) | §3.3 Subtractive | [ch03s03](http://www.pd-tutorial.com/english/ch03s03.html) |
| Tempérament, mélodie | §3.1.1 Pitch | [ch03](http://www.pd-tutorial.com/english/ch03.html) |
| Pattern d'accords | §4.2 Sequencer | [ch04s02](http://www.pd-tutorial.com/english/ch04s02.html) |
| Fake reverb (délais) | §3.4 Sampling + §3.7 Granular | [ch03s04](http://www.pd-tutorial.com/english/ch03s04.html) / [ch03s07](http://www.pd-tutorial.com/english/ch03s07.html) |
| Compresseur, sidechain | §3.9 Amplitude corrections | [ch03s09](http://www.pd-tutorial.com/english/ch03s09.html) |
| Audio-visuel intégré | §5.2 Visuals (GEM) | [ch05s02](http://www.pd-tutorial.com/english/ch05s02.html) |

---

## 5. Mode d'emploi pour tes étudiants

**Suggestion d'introduction du parcours** (à donner aux étudiants) :

> Ce parcours de 8 semaines accompagne le module *Faire de la musique dans un shader*. L'objectif n'est pas de devenir expert Pd, mais de **comprendre par contraste** ce qu'apporte le paradigme stateless du shader audio.
>
> Chaque semaine :
> 1. Lire le chapitre Kreidler indiqué (sections Theory + Applications obligatoires, Appendix + For especially interested optionnelles).
> 2. Faire les exercices intégrés au chapitre — Kreidler en propose à chaque section, corrigés dans l'[Appendix A. Solutions](http://www.pd-tutorial.com/english/apa.html).
> 3. Faire l'exercice de comparaison shader ↔ Pd indiqué dans ce guide.
> 4. Noter en 3 lignes ce qui est **plus facile** en Pd, plus facile en shader.

**Évaluation possible** : un mini-rapport de 2 pages comparant l'expérience des deux paradigmes, à rendre en fin de semaine 8.

---

## 6. Compléments hors Kreidler

Le tutoriel Kreidler date de 2009 et ne couvre pas certains aspects modernes :

| Manque | Ressource complémentaire |
|---|---|
| Modélisation physique masses-ressorts | Henry, *Basic Physical Modeling Concepts* (dans `bang | Pure Data`, voir [[Pure Data - paralleles|Pure Data - paralleles §3.8]]) |
| Théorie DSP avancée | M. Puckette, *Theory and Technique of Electronic Music* — <http://msp.ucsd.edu/techniques.htm> |
| Pd dans le navigateur | WebPd, Pd-L2Ork |
| Pd pour le live coding | externals `[loops]`, `[else]` |

---

## 7. Notes d'usage

- Le sommaire complet est dans `shaders/music/index.html` (capture locale du site).
- Le **vrai contenu** des chapitres n'est pas dans ce HTML — il faut suivre les liens vers `pd-tutorial.com`.
- Les **patches d'exemple** sont téléchargeables depuis chaque chapitre du site.
- Licence du livre : Creative Commons (libre pour usage pédagogique).

---

## Liens internes

- [[_Index - Shaders Audio]] — sommaire général du module
- [[Pure Data - paralleles]] — note compagnon, parallèles concept par concept
- [[Themes audio - panorama]] — panorama des thèmes audio
- [[Cours 1 - Bases, waveforms et melodie]]
- [[Cours 2 - FM Synthesis, Pad, Lead Synth]]
- [[Cours 3 - Marimba, Saw Bass, Wah Synth]]

#audio #puredata #cours #esgi #parcours #kreidler
