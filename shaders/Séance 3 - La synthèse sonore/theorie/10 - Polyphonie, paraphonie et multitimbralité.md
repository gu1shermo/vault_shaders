# 10 — Polyphonie, paraphonie et multitimbralité

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 10/30**
> **Tags :** #synthese-sonore #polyphonie #paraphonie #multitimbralite #ESGI

---

## Polyphonie

> "La capacité d'un synthétiseur à générer simultanément plusieurs voix, disposant chacune de sa propre chaîne de production et de traitement sonore."

### Mécanisme d'implémentation

La polyphonie repose sur deux systèmes clés :

1. **Scanner de clavier** : utilise des codes binaires pour identifier chaque touche enfoncée indépendamment
2. **Allocation de voix** : distribue les touches actives aux voix disponibles

Quand le nombre de touches dépasse le nombre de voix disponibles → les voix les plus anciennes sont **réattribuées** aux nouvelles notes (voice stealing).

### Histoire de la polyphonie

| Instrument | Année | Particularité |
|---|---|---|
| **Polymoog** (Moog) | 1975 | Premier poly véritablement complet — 71 touches mais très coûteux et peu fiable |
| **Prophet-5** (Sequential Circuits) | 1978 | 5 voix, 61 touches — compromis pratique et financier |
| Synthétiseurs numériques modernes | 1985+ | Jusqu'à **128 voix** en polyphonie |

### Problématique du coût

La polyphonie analogique était **extrêmement coûteuse** à l'origine car chaque voix nécessitait sa propre carte électronique complète (oscillateurs, filtre, ampli, enveloppes).  
→ Le Prophet-5 a popularisé le compromis : 5 voix suffisent pour la plupart des usages musicaux.

---

## Paraphonie

> "Système où chaque oscillateur peut être déclenché individuellement par une note différente, mais les signaux produits partagent ensuite une seule et même chaîne de traitement."

### Différence avec la polyphonie vraie

| Caractéristique | Polyphonie | Paraphonie |
|---|---|---|
| Oscillateurs | Indépendants | Indépendants |
| Filtre | **Un par voix** | **Partagé** |
| Amplificateur | **Un par voix** | **Partagé** |
| Enveloppe ADSR | **Une par voix** | **Une seule pour tous** |

### Comportement spécifique

En paraphonie, les nouvelles notes **ne déclenchent pas leur propre enveloppe** — elles s'intègrent au sustain de l'enveloppe en cours.  
→ L'attaque est partagée : si une note est déjà tenue, la nouvelle note "saute" dans la phase de sustain.

**Exemple d'instrument** : Waldorf Pulse 2 — crée une illusion de polyphonie avec une architecture monodique.

---

## Multitimbralité

> "Capacité à produire simultanément des sons non seulement de natures différentes, mais dont les enveloppes de filtre et d'amplification pourront également être différenciées."

### Différence avec la polyphonie

- **Polyphonie** : plusieurs notes du **même son** simultanément (accord de piano → toutes les notes sonnent pareil)
- **Multitimbralité** : plusieurs sons **différents** simultanément (basse + piano + pad en même temps)

### Implémentation MIDI

La multitimbralité exploite les **16 canaux MIDI** :
- Canal 1 → son de basse
- Canal 2 → son de piano
- Canal 3 → nappe de cordes
- Etc.

**Exemple** : un arrangeur ou workstation pouvant jouer simultanément une basse, un piano, et des cordes avec des enveloppes complètement différentes.

**Instrument pionnier** : Sequential Circuits Six-Trak (1984)

### Cas d'usage typique

```
Main gauche (Canal 1) → Basse synthétiseur
Main droite (Canal 2) → Solo de piano samplé
Pédale (Canal 10)    → Batterie/percussions
```

---

## Tableau comparatif

| Mode | Notes simultanées | Chaînes indépendantes | Timbres différents |
|---|---|---|---|
| **Monodique** | 1 | 1 | 1 |
| **Paraphonie** | Plusieurs | Partiellement | 1 |
| **Polyphonie** | Plusieurs | Oui (voix) | 1 (même son) |
| **Multitimbralité** | Plusieurs | Oui (canaux) | Oui (canaux différents) |

---

**← Précédent :** [[09 - Polyphonie et monodie]]  
**→ Suite :** [[11 - Présentation de la norme MIDI]]
