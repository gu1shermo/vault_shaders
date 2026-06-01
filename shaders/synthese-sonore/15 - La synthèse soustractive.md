# 15 — La synthèse soustractive

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 15/30**
> **Tags :** #synthese-sonore #soustractive #filtres #ESGI

---

## Principe fondamental

> "Un signal riche harmoniquement va être taillé dans ses fréquences, grâce à des filtres, afin de sculpter le son."

La synthèse soustractive part d'une source **harmoniquement riche** et **soustrait** des fréquences pour créer le timbre désiré — à l'opposé de la synthèse additive qui construit le son.

---

## La chaîne du signal

```
[Oscillateur(s)]
     ↓
[Mélangeur / Mixer]       ← mixage des oscillateurs + bruit
     ↓
[VCF — Filtre]            ← sculpture du timbre
     ↑
[Enveloppe de filtre]     ← évolution temporelle du timbre
     ↓
[VCA — Amplificateur]     ← contrôle du volume
     ↑
[Enveloppe d'amplificateur (ADSR)]
     ↓
[Sortie audio]
```

---

## Pourquoi la sinusoïde ne fonctionne pas

La sinusoïde n'a **aucun harmonique** → appliquer un filtre dessus n'a qu'un seul effet : **la couper entièrement** (passe ou ne passe pas).

→ La synthèse soustractive requiert impérativement des formes d'ondes **riches en harmoniques** :
- **Dents de scie** : tous les harmoniques → plus utilisée
- **Carrée / rectangulaire** : harmoniques impairs
- **Bruit blanc** : tout le spectre (percussions, textures)

---

## Fonctionnement en pratique

### 1. L'oscillateur fournit la matière brute

Une dents de scie à 440 Hz contient 440 Hz, 880 Hz, 1320 Hz, 1760 Hz…  
→ Son brillant, riche, presque agressif

### 2. Le filtre passe-bas sculpte

- Coupure à 2000 Hz → les harmoniques au-dessus disparaissent → son plus chaud
- Coupure à 500 Hz → son très sombre, presque sourd
- Résonance élevée → pic à la coupure → son nasal caractéristique

### 3. L'enveloppe de filtre "anime" le timbre

```
Temps
0ms : filtre ouvert (brillant)    ← note pressée
200ms : filtre se referme (sombre)  ← decay du filtre
Sustain : filtre partiellement ouvert
Relâché : filtre ferme progressivement ← release
```

→ Simule l'évolution naturelle d'un instrument acoustique (attaque brillante d'une corde pincée, puis assombrissement)

---

## Instruments historiques emblématiques

### Novachord (Hammond, fin années 30)

- Première implémentation industrielle de la synthèse soustractive
- 72 touches, synthèse par tubes à vide
- Timbre évoquant les cordes et les cuivres

### Minimoog (Moog, 1970)

- Premier synthétiseur **commercial transportable** (pas de rack)
- 41 touches, 3 VCOs, 1 générateur de bruit
- Filtre **4 pôles (24 dB/oct)** devenu référence absolue
- Popularisé en concert par Keith Emerson (ELP), Rick Wakeman
- Son de basse caractéristique : encore utilisé aujourd'hui

### Korg MS-20 (1978)

- Synthétiseur **semi-modulaire** avec patching possible
- 36 touches, 2 VCOs, 2 VCFs (un passe-bas, un passe-haut)
- Architecture semi-modulaire → câblage libre entre les modules
- Très populaire pour son aggressivité sonore
- Réédition en 2013 (MS-20 Mini) → confirme son statut culte

---

## Synthèse soustractive analogique vs. numérique

| Aspect | Analogique | Numérique |
|---|---|---|
| Oscillateurs | VCO (légèrement instables, chaleureux) | DO (stables, précis) |
| Filtres | Circuits électroniques analogiques | Algorithmes DSP |
| Son | Chaud, vivant, légèrement imparfait | Précis, propre, froid |
| Stabilité | Dérive avec la température | Parfaitement stable |

---

## Applications modernes

La synthèse soustractive reste la **plus intuitive et la plus utilisée** pour :
- Bass lines
- Lead synths
- Pads
- Sons "vintage" analogiques

Instruments modernes notables : Moog Minimoog Voyager, Dave Smith Prophet-6, Roland JX-3P, Arturia MiniBrute, Korg Minilogue.

---

**← Précédent :** [[14 - Flanger, phaser, chorus et modulation]]  
**→ Suite :** [[16 - La synthèse additive]]
