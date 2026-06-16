# 09 — Polyphonie et monodie

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 9/30**
> **Tags :** #synthese-sonore #polyphonie #monodie #ESGI

---

## Avertissement terminologique

> Attention : **monodie** ≠ **monaural** (mono/stéréo)  
> La monodie concerne le **nombre de notes simultanées**, pas le nombre de canaux audio.

---

## Monodie (Monodique)

Un instrument **monodique** (monophonique) ne peut jouer **qu'une seule note à la fois**.

- Frappe deux touches simultanément → seulement **une** note est produite
- Comportement par défaut des premiers synthétiseurs analogiques
- Exemples : Minimoog, ARP Odyssey, TB-303

---

## Polyphonie

Un instrument **polyphonique** peut jouer **plusieurs notes simultanément**.

- Chaque note joue sur une **voix indépendante**
- Chaque voix possède sa propre chaîne de traitement complète

---

## Architecture d'une voix

Une **voix** en synthèse n'est pas simplement un oscillateur. Elle comprend :

| Composant | Rôle |
|---|---|
| Oscillateur(s) | Génère la forme d'onde à la fréquence souhaitée |
| Filtre | Sculpte le timbre |
| Amplificateur | Contrôle le volume |
| Enveloppe de filtre | Fait évoluer le timbre |
| Enveloppe d'ampli | Fait évoluer le volume |
| Trigger CV | Indique quelle touche est enfoncée |
| Gate | Reste actif tant que la touche est tenue |

### Exemple : Moog Little Phatty

Cet instrument est **monodique mais possède 2 oscillateurs** :
- Les 2 oscillateurs peuvent jouer des formes d'ondes différentes et être désaccordés
- Pourtant, les deux répondent à **une seule pression de touche** → une seule voix → monodique

---

## Systèmes de priorité de notes (mode monodique)

En mode mono, si plusieurs touches sont pressées simultanément, un **système de priorité** détermine quelle note est jouée :

| Priorité | Description | Usage courant |
|---|---|---|
| **Note la plus basse** | Joue toujours la note la plus grave | Synthèses américaines des années 70 |
| **Note la plus haute** | Joue toujours la note la plus aiguë | Fabricants japonais |
| **Dernière note pressée** | La plus récente remplace la précédente | Jeu rapide de mélodie |
| **Première note pressée** | La note initiale reste prioritaire | Rare |

> Ces différences de priorité ont fortement influencé les **techniques de jeu** selon les régions du monde dans les années 70.

---

## Mode Legato

En mode **legato** monodique :
- Si on appuie sur une deuxième note **avant de relâcher la première**, l'enveloppe **ne se redéclenche pas**
- Le son glisse directement d'une note à l'autre sans interruption (portamento naturel)
- Utilisé pour les lignes mélodiques legato et les techniques de jeu expressif

---

## Retrigger

En mode **retrigger** :
- L'enveloppe se **redéclenche** à chaque nouvelle note pressée, même en mode legato
- Son plus "claquant" et articulé
- Certains synthétiseurs proposent les deux modes au choix

---

**← Précédent :** [[08 - L'enveloppe ADSR]]  
**→ Suite :** [[10 - Polyphonie, paraphonie et multitimbralité]]
