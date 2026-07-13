# Commandes Orca (commander — `Ctrl+K`)

Liste des commandes du *commander* d'Orca (le champ de saisie ouvert par `Ctrl+K`).
Vérifiée dans le code source : [`desktop/sources/scripts/commander.js`](https://github.com/hundredrabbits/Orca/blob/master/desktop/sources/scripts/commander.js).

## Syntaxe

```
nom:argument
nom:arg1;arg2;arg3
```

- Le séparateur entre le **nom** et l'**argument** est le **deux-points** `:` — donc `bpm:140`,
  **pas** `bpm140` (sans `:`, Orca ne reconnaît pas la commande).
- Les valeurs multiples d'un même argument sont séparées par des **points-virgules** `;`.
- Parsing réel : `cmd = msg.split(':')[0]` ; `val = msg.substr(cmd.length + 1)`.
- **Raccourci** : les 2 premières lettres marchent aussi (`bp:140`, `mi:1`). ⚠️ collisions possibles
  (`co` → `color` écrase `copy`) — en cas de doute, tape le nom complet.

---

## Transport / lecture

| Commande | Exemple | Effet |
|---|---|---|
| `play`   | `play`     | Démarre la lecture |
| `stop`   | `stop`     | Arrête la lecture |
| `run`    | `run`      | Exécute **une seule** frame (pas à pas) |

## Tempo & temps

| Commande | Exemple | Effet |
|---|---|---|
| `bpm`    | `bpm:140`  | Règle le tempo **immédiatement** |
| `apm`    | `apm:160`  | Règle le tempo de façon **progressive/animée** (transition douce) |
| `frame`  | `frame:0`  | Saute à la frame indiquée |
| `skip`   | `skip:2`   | Avance de N frames |
| `rewind` | `rewind:2` | Recule de N frames |
| `time`   | `time`     | Écrit l'heure formatée dans la grille |

## Édition / curseur

| Commande | Exemple | Effet |
|---|---|---|
| `copy`   | `copy`            | Copie la sélection |
| `paste`  | `paste`           | Colle |
| `erase`  | `erase`           | Efface la sélection |
| `find`   | `find:aV`         | Sélectionne la prochaine occurrence de la chaîne |
| `select` | `select:3;4;5;6`  | Définit la sélection `x;y;largeur;hauteur` |
| `inject` | `inject:pattern;12;34` | Insère un snippet enregistré `nom;x;y` |
| `write`  | `write:H;12;34`   | Écrit un glyphe `glyphe;x;y` |

## Sortie MIDI / OSC / UDP (routage vers SuperCollider)

| Commande | Exemple | Effet |
|---|---|---|
| `midi`   | `midi:1;2`        | Choisit les périphériques MIDI `sortie;entrée` (indices) |
| `udp`    | `udp:1234;5678`   | Configure UDP `port_sortie;port_entrée` (entrée optionnelle) |
| `osc`    | `osc:1234`        | Choisit le port OSC |
| `ip`     | `ip:127.0.0.1`    | Définit l'IP cible |
| `cc`     | `cc:0`            | **Décalage des CC** (voir note ci-dessous) |
| `pg`     | `pg:1;0;0;5`      | Program Change `canal;bank;sub;program` |

## Thème

| Commande | Exemple | Effet |
|---|---|---|
| `color`  | `color:f00;0f0;00f` | Couleurs du thème (valeurs hex `bas;moyen;haut`) |

---

## Notes pour ce projet (`pipeline_osck`)

- **`cc:` = le fameux "offset de 64".** L'opérateur `!` d'Orca (MIDI CC) ajoute ce décalage au
  numéro de knob. Par défaut l'offset vaut **64** (d'où knob 0 → CC 64, knob 1 → CC 65…). La
  commande `cc:0` le ramènerait à 0 (knob 0 → CC 0). On **garde 64** ici puisque le mapping
  `~fxCC` de `sc_test.scd` attend CC 64–74. Ne pas changer sans aligner le code SC.
- **`midi:`** sert à router la sortie d'Orca vers SuperCollider — c'est le branchement de base de
  la chaîne Orca → SC. Repère l'indice du bon périphérique (loopMIDI / IAC / port SC).
- **`bpm:` / `apm:`** : `bpm` saute net au tempo, `apm` y glisse en douceur — pratique en live pour
  accélérer/ralentir sans à-coup.

## Rappel : opérateurs de grille (≠ commander)

Le commander (`Ctrl+K`) configure la session ; les **opérateurs** se posent dans la grille. Les plus
utiles ici (détaillés dans `CLAUDE.md`) :
- `:` — note MIDI (`canal octave note vélocité length`)
- `!` — MIDI CC (`canal knob valeur`) → pilote les effets master (offset +64 sur le knob)
- `D` delay/horloge · `R` random · `T`/`O`/etc. — voir la doc Orca.

> ⚠️ Knobs ≥ 10 en base36 : le knob est **une seule case**. Knob 10 = `a`, 11 = `b`, 12 = `c`…
> Donc `choRate` (knob 10) se pilote avec `!0ax`, **pas** `!10x`.
