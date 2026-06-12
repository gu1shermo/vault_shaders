# 16 — La synthèse additive

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 16/30**
> **Tags :** #synthese-sonore #additive #Fourier #ESGI

---

## Principe fondamental

> "La synthèse additive consiste à l'empilage de signaux simples (sinusoïdes) pour créer un son riche."

C'est l'**inverse de la synthèse soustractive** : au lieu de retrancher des éléments d'un signal riche, on **construit** un son complexe en **additionnant** des sons simples.

### Fondement scientifique (Fourier)

Joseph Fourier a démontré que **tout signal sonore complexe peut être réduit à un groupe de sinusoïdes simples** (décomposition spectrale).

La synthèse additive applique le principe **inverse** : reconstituer un son complexe en empilant ses composantes sinusoïdales.

> **Limitation pratique** : aucune analyse n'offre une résolution parfaite → reproduction **identique** d'un son naturel est impossible. On peut en approcher.

---

## Mécanisme

Pour créer un son quelconque, on additionne des sinusoïdes à différentes :
- **Fréquences** (harmoniques et/ou partiels)
- **Amplitudes** (niveau de chaque composante)
- **Phases** (décalage initial de chaque sinusoïde)

Chaque sinusoïde peut avoir sa **propre enveloppe** → le spectre évolue dans le temps (ce qui rend le son "vivant").

---

## Instruments historiques

### Orgue d'église — le premier synthétiseur additif

L'orgue d'église fonctionnait déjà selon le principe additif :
- Chaque **jeu** (groupe de tuyaux) produit une harmonique différente
- Les **registres** permettent d'activer ou désactiver des groupes de tuyaux
- Le **drawbar** (sur les orgues Hammond) contrôle le niveau de chaque harmonique
- En combinant différents jeux → création de timbres variés

→ Le joueur d'orgue était, sans le savoir, un **synthétiste additif** !

### Telharmonium (Thaddeus Cahill, 1896)

- Instrument électromécanique de **7 tonnes**
- Utilisait des **roues phoniques** (disques métalliques tournant devant des capteurs électromagnétiques)
- Chaque roue → une fréquence précise (fondamentale ou harmonique)
- Distribution du son via les lignes **téléphoniques** de l'époque
- Pionnier de la musique électronique distribuée par réseau

### Hammond B3 (Laurens Hammond, années 30)

- Reprenait le principe des roues phoniques du Telharmonium
- **9 drawbars** par manuel = 9 harmoniques contrôlables
  - 16' (sub-octave), 8' (fondamentale), 4' (octave +1), 2' (octave +2), etc.
- Résolution limitée à 9 composantes → timbre moins précis qu'un vrai orgue à tuyaux
- Devenu instrument de jazz et de rock emblématique (Jimmy Smith, Keith Emerson, Jon Lord)

### Bell Labs Digital Synthesizer (Alles Machine, années 70)

- 72 oscillateurs numériques contrôlables indépendamment
- Divisés entre fondamentales et harmoniques
- 32 filtres programmables + 256 générateurs d'enveloppes
- Expérimental, jamais commercialisé

### Kawai K5 (1987)

- Synthétiseur additif commercial accessible
- **126 harmoniques** sélectionnables par fondamentale
- Chaque harmonique possède sa propre enveloppe
- Ergonomie complexe mais possibilités sonores immenses
- Son renommé pour la reproduction de sons d'orgue et de cloches

### Yamaha FS1R (1998)

- Synthèse additive + FM combinées
- 88 opérateurs par voix
- Très rare, apprécié des collectionneurs

---

## Avantages et limitations

### Avantages

- **Contrôle total** du spectre sonore
- Chaque harmonique est modifiable indépendamment
- Possibilité de créer des sons **impossibles** acoustiquement
- Excellente pour les sons évolutifs (morphing spectral)

### Limitations

- **Complexité** : contrôler des dizaines d'oscillateurs est fastidieux
- **Coût CPU** : nécessite un oscillateur par composante fréquentielle
- Reproduction parfaite d'un son naturel **impossible** (limites de l'analyse de Fourier)
- Peu intuitive pour les musiciens habitués à la synthèse soustractive

> Paradoxe : la synthèse additive est la plus ancienne dans ses principes (orgue d'église) mais la plus complexe à implémenter pratiquement.

---

## Résumé

| Aspect | Détail |
|---|---|
| Principe | Empilage de sinusoïdes à fréquences, amplitudes et phases contrôlées |
| Fondement | Théorème de Fourier inverse |
| Matière première | Sinusoïdes simples |
| Contrôle | Amplitude + enveloppe de chaque harmonique |
| Usage | Sons de cloches, orgues, sons spectraux évolutifs |

---

**← Précédent :** [[15 - La synthèse soustractive]]  
**→ Suite :** [[17 - L'échantillonnage]]
