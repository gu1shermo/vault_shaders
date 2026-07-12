# Correction détaillée v2 — Rendu Fragment Shader (ESGI 5e année)

**Enseignant :** Guillaume Cournet
**Date :** 2026-06-18
**Module :** Computer Graphics / Shaders
**Note :** version rééquilibrée — notation **bienveillante**. Voir « Note méthodologique » ci-dessous.

---

## Note méthodologique (à lire avant les notes)

La consigne demandait **un fragment shader écrit à la main en HLSL (et non en Shader Graph nodal)**. À l'usage, une partie des groupes a fait du nodal au lieu de coder. Plutôt qu'un malentendu purement imputable aux étudiants, on considère ici qu'**une consigne qui se fait massivement mal comprendre engage aussi la responsabilité de l'énoncé**. Le barème est donc **bienveillant** :

- Le fragment shader **en code reste le critère demandé** et il est valorisé.
- Mais l'absence de fragment en code **n'est plus éliminatoire** : on note **le travail technique réellement effectué** (compute shaders, pipeline GPU, ambition visuelle), même quand il passe par du nodal.
- Les notes sont **resserrées vers le haut** : un travail sérieux mais hors-cible ne descend pas sous un plancher de respect.

Conséquence vs la v1 : les groupes « nodal » (3, 5) et le groupe minimal (6) remontent nettement, sans dépasser les groupes qui ont fait exactement ce qui était demandé.

---

## Barème v2 (sur 20)

| Critère | Pondération | Esprit |
|---|---|---|
| **Maîtrise technique GPU démontrée** (compute, pipeline compute→buffer→vert→frag, logique shader) | **7 pts** | le cœur : a-t-il compris le modèle GPU ? |
| **Fragment shader écrit en code HLSL** (la consigne) | **5 pts** | valorisé, **non éliminatoire** |
| **Ambition & richesse visuelle** (procédural, effets, originalité) | **4 pts** | quel que soit le moyen (code ou nodal) |
| **Documentation / clarté, distinction code vs nodal** | **2 pts** | README, nommage, lisibilité du rendu |
| **Propreté du code & cohérence du projet** | **2 pts** | structure, pas de pollution inutile |

> Le plancher implicite d'un travail sérieux mais hors-cible se situe autour de **10/20** (et non plus 5).

---

## Groupe 1 — Lumenfall

**Auteur(s) :** anonyme (README = `# Lumenfall` uniquement)

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/Shaders/ParticleRender.shader` | **Fragment shader code** | Rendu pluie/neige |
| `Assets/Shaders/ParticleSim.compute` | Compute | Simulation particules |
| `Assets/Shaders/Water/...shadergraph` | Nodal | Eau |
| `Assets/VFX/Fire/Fire_Shader_Graph.shadergraph` | Nodal | Feu |
| `Assets/VFX/BOID/UberFish 1.shadergraph` | Nodal | Poisson |

### Analyse du fragment shader (`ParticleRender.shader`)

Pipeline HLSL complet **vert + geom + frag** alimenté par un `StructuredBuffer<Particle>` rempli par le compute, instancié via `SV_InstanceID`. Le champ `type` (0 = rain, 1 = snow) aiguille tout le pipeline.

| Étage | Rôle |
|---|---|
| **vert** | Lit la particule via `SV_InstanceID`, transmet pos/vel/life/type |
| **geom** | Génère un quad billboardé (4 sommets) selon le type |
| **frag** | Dessine le motif (streak ou flake) avec alpha procédural |

**Points techniques remarquables :**
- Pipeline GPU complet sans transfert CPU↔GPU dans la boucle (`Graphics.DrawMeshInstancedIndirect`).
- Geometry shader : pluie étirée le long de la vélocité (motion-blur géométrique via `lerp(0.7,1.6,speed/18)`), neige en billboard caméra pur (`UNITY_MATRIX_I_V`), garde-fou anti-dégénéré, culling des particules mortes.
- **Fragment réellement programmé** : streak en fuseau (`smoothstep` + `sin`), flocon rond avec `discard` du masque circulaire, atténuation par `life`. **Seul rendu des 7 où le fragment fait du procédural conditionnel.**
- États de rendu corrects (`Cull Off`, `ZWrite Off`, `Blend SrcAlpha OneMinusSrcAlpha`, `Queue=Transparent`, `#pragma target 5.0 / require geometry`).

### Compute shader (`ParticleSim.compute`)
Simulation réaliste : gravité, damping, recyclage par vie, collisions plan + sphères (restitution/friction), Wang hash, émission paramétrable, compteur atomique `InterlockedAdd`.

### Faiblesses
- ❌ **README quasi vide** (`# Lumenfall`), **aucun nom d'auteur**.
- ⚠️ Projet pollué par l'asset store **Enviro 3** (shaders tiers) → risque de confusion à l'évaluation.
- Constantes magiques non commentées ; pas de texture (tout procédural) ; pas de HDR.

### Note proposée : **17 / 20**

> Le rendu le plus abouti techniquement (fragment procédural + pipeline complet). Reste pénalisé sur la doc inexistante, l'anonymat et la pollution par assets tiers — sinon ce serait 18-19.

---

## Groupe 2 — Michael Attal

**Auteur :** Michael Attal (rendu individuel)

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/Shaders/Boids.shader` | **Fragment shader code** | Rendu des boids |
| `Assets/Shaders/Boids.compute` | Compute | Simulation boids |
| `Assets/Shaders/Wave.shadergraph` | Nodal (assumé) | Vague sur mesh |
| `Assets/Shaders/VFX.vfx` | VFX Graph | Étoiles filantes |
| `Readme.txt` | Doc | README détaillé |

### Analyse
- Pipeline HLSL `vert` + `frag` correct. **Vertex riche** : reconstruit une matrice de rotation `(right, up, forward)` à partir de la vélocité lue dans un `StructuredBuffer`, instancié via `SV_InstanceID`.
- **Fragment minimaliste** : `return _Color;` — couleur uniforme. Conforme mais sans démonstration de capacité d'écriture fragment (pas de texturing/lighting/procédural).
- **Compute boids** propre et complet : séparation/alignement/cohésion, normalisation des forces, `Limit()`, wrap-around toroïdal.

### Points forts
- ✅ **README excellent** : sépare explicitement code (`Boids.shader`, vertex+fragment), nodal (`Wave.shadergraph`, « avec des nœuds donc ») et VFX Graph. **Consigne comprise et explicitement respectée.**
- ✅ Pipeline `DrawMeshInstancedIndirect` maîtrisée, travail individuel cohérent.

### Note proposée : **16 / 20**

> Consigne comprise et explicitée, pipeline complet maîtrisé, doc exemplaire. Le fragment lui-même (`return _Color`) est trop pauvre pour viser plus haut.

---

## Groupe 3 — RenduProjetAtelierComputerGraphic

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/Boids/BoidsSimulation.compute` | Compute | Boids |
| `Assets/TrouDeVer/Trou_de_ver.shadergraph` | **Nodal** | Trou de ver |
| `Assets/TrouDeVer/BlackHole_Surface.shadergraph` | **Nodal** | Surface du trou noir |
| `Assets/BlackHole.vfx`, `Assets/SampleMesh.vfx` | VFX Graph | Effets |

### Analyse
- ❌ **Aucun fichier `.shader` écrit en code** (les 5 pts « fragment code » sont perdus).
- ✅ **Compute boids solide** : steering forces (`SteerTowards`), bounds steering, clamp speed min/max — un cran au-dessus du groupe 2.
- 🔶 Effets visuels (trou de ver, trou noir) entièrement en **Shader Graph + VFX Graph** : ambition visuelle réelle et aboutie.

### Note proposée : **13 / 20**

> Consigne non remplie sur le fragment en code, mais **travail technique réel et ambitieux** : compute correct + effets visuels poussés. La bienveillance récompense la maîtrise GPU démontrée par ailleurs. À questionner en soutenance sur le choix du nodal.

---

## Groupe 4 — Sacha

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/VertexShader.shader` | `.shader` (coquille) | Fragment vide |
| `Assets/SachaStuff/Mask3D.shader` | ShaderLab pur | Masque (pas de programme HLSL) |
| `Assets/SachaStuff/ConwaysGameOfLife/GameOfLifeComputeShader.compute` | Compute | Game of Life |
| `Assets/sandCompute.compute` | Compute | Jeu de sable |
| `Assets/SachaStuff/.../WaterPlaneShader.shadergraph` | Nodal | Eau |

### Analyse
- `VertexShader.shader` : `#pragma fragment frag` présent mais `frag()` = `return _Color;` (vide). Vertex **suspect** (sommets en repère pixel sans `UnityObjectToClipPos` → probablement non rendu à l'écran). `RWTexture2D` déclarée non utilisée.
- `Mask3D.shader` : ShaderLab pur (`Blend Zero One`), **pas de programme fragment**.
- **Deux compute shaders réels** : Game of Life + jeu de sable cellulaire — du vrai travail GPU.
- ⚠️ `sandCompute.compute` **identique** à celui du groupe 6 → partage non déclaré à vérifier.

### Note proposée : **12 / 20**

> A **tenté** d'aller dans le sens de la consigne (squelette de shader en code), même si l'exécution du fragment est vide et le vertex non fonctionnel. Sauvé par deux compute shaders réels (Game of Life, sable). Projet dispersé. À faire expliquer en soutenance ; clarifier la duplication du `sandCompute`.

---

## Groupe 4 — Sebastian

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/ParticleShader.shader` | **Fragment shader code** | Rendu particules |
| `Assets/Particles.compute` | Compute | Simulation particules |
| `Assets/Custom_ParticleShader.mat` | Matériau | — |
| `Assets/Particle.prefab` | Prefab | — |

### Analyse
- Pipeline `vert` + `geom` + `frag` complet. Le `geom` génère un **quad billboard** avec correction d'aspect ratio (`_ScreenParams.x / _ScreenParams.y`). Lecture du `StructuredBuffer<ParticleData>` via `SV_InstanceID`.
- Fragment simple : `return fixed4(1,0,0,i.life);` — particule rouge dont l'alpha décroît avec la vie. Lisible et démonstratif. Blending transparence correct.
- **Compute** de qualité (un cran au-dessus du groupe 2) : gravité, sol, collision sphères, friction, `reflect()` pour rebonds avec restitution, RNG xorshift + Wang hash, `CBUFFER_START`.

### Note proposée : **15 / 20**

> **Strictement conforme** à la consigne : chaîne complète compute → buffer → vertex → geometry → fragment, propre. Le fragment manque d'ambition mais le geometry shader (billboarding) compense. Solide.

---

## Groupe 5 — ComputerGraphics

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/ComputeShader/Shader/CrowdCompute.compute` | Compute | Foule |
| `Assets/ComputeShader/Shader/SnowComputeShader.compute` | Compute | Neige |
| `Assets/GrassShaderGraph/.../GrassShader.shadergraph` | **Nodal** | Herbe |
| `Assets/HoloShaderGraph/Shader/Holo.shadergraph` | **Nodal** | Hologramme |
| `Assets/SnowVFX/Shader/*.shadergraph` (×3) | **Nodal** | Neige |
| `Assets/ComputeShader/Shader/SnowURPShader.shadergraph` | **Nodal** | Neige URP |

### Analyse
- ❌ **Aucun fichier `.shader` écrit en code** (5 pts « fragment code » perdus).
- ✅ **Deux compute shaders distincts** (foule + neige) — vrai travail GPU.
- 🔶 Production nodale **volumineuse** (6 graphes : herbe, holo, neige ×4) : gros effort visuel.

### Note proposée : **13 / 20**

> Le **plus gros volume de travail technique** (2 compute + 6 shadergraphs), mais entièrement à côté du critère « fragment en code ». La bienveillance récompense l'effort et la maîtrise GPU réelle ; le plafond reste sous les groupes qui ont codé. À questionner sur le choix systématique du nodal.

---

## Groupe 6 — rendu

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Assets/sandCompute.compute` | Compute | Jeu de sable |
| `Assets/sandScript.cs` | C# | Driver |
| `Assets/sandMat.mat` | Matériau | — |

### Analyse
- ❌ Aucun fragment shader en code, ❌ aucun ShaderGraph.
- ✅ Un compute shader fonctionnel : jeu de sable cellulaire (non trivial en soi).
- ⚠️ `sandCompute.compute` **identique** à celui de Sacha (groupe 4) → partage non déclaré à vérifier. **Ce point peut faire baisser la note** s'il s'avère que le travail n'est pas le leur.

### Note proposée : **10 / 20** *(sous réserve de la vérification de la duplication)*

> Le rendu le plus minimal, mais un compute cellulaire qui tourne reste du vrai travail GPU → plancher de bienveillance à 10. **Si la duplication avec Sacha révèle une reprise non déclarée, redescendre vers 6-7.** À trancher en soutenance.

---

## Groupe 7 — CircuitFloorURP

**Archive :** `ESGI_fragmentshader_E1_05-04-09.09.03_Shaderdetravail-groupe7.shader` (fichier `.shader` seul)

### Fichiers étudiants pertinents

| Fichier | Type | Contenu |
|---|---|---|
| `Shaderdetravail-groupe7.shader` | **Fragment shader code (pur)** | Sol procédural type circuit imprimé / PCB |

### Analyse du fragment shader (`Custom/CircuitFloorURP`)

**Le seul rendu où tout le travail est concentré dans un fragment shader écrit à la main** — pas de compute, pas de nodal, pas de geometry. Le `vert` est le boilerplate URP standard (`GetVertexPositionInputs`, instancing/stereo) ; **tout l'effet est dans le `frag()`**, calculé à partir de la position monde XZ.

**Richesse du fragment (de loin la plus élevée des 8 rendus) :**
- **Bibliothèque de SDF/masques maison** : `lineBand`, `diagonalLine(Inv)`, `circleMask`, `diamondMask`/`diamondBorder`, `rectMask` (SDF de rectangle correct), `viaMask`, `hSeg`/`vSeg`, `chamfer45`, `dotGridWorld`.
- **Bruit procédural** : `hash21` (hash 2D→1D) pour l'aléa déterministe des cellules.
- **Motif PCB multi-échelle** : `axisTraces` (bus principaux + secondaires + diagonales à 45°), `pcbBranches` (cellules de circuit aléatoires sur voisinage 5×5 avec vias, coudes, chamfers), `microCircuit` (détail fin), tout fondu par distance (`_CircuitFadeStart/End`, `_MicroFadeStart/End`).
- **Animation** : `pulseFlow` (flux lumineux qui parcourt les bus via `frac((p + t)*…)`) + pulsation globale `sin(t * _PulseSpeed)`.
- **Composition d'émission** type bloom-ready : accumulation de `lineEmission`, `coreEmission`, `glowEmission`, `borderEmission`, `dotEmission`, `flowEmission` (sortie HDR > 1, pensée pour un post-process glow).
- **Code soigné** : branchless via `step()` pondérés (`w0..w3`) pour éviter le branching divergent, `CBUFFER_START(UnityPerMaterial)` correct, ~30 propriétés exposées à l'inspecteur, commentaires pertinents (« voisinage réduit pour éviter les erreurs de compilation »).

**Setup technique correct :** URP `UniversalForward`, `Core.hlsl`, `#pragma target 3.5`, instancing + stereo, `RenderType=Opaque`.

### Faiblesses
- ❌ **Aucun README, aucun nom d'auteur** (fichier nommé « Shaderdetravail »).
- ⚠️ **Livré comme fichier `.shader` isolé** : pas de projet/scène pour vérifier le rendu in-situ (le code est néanmoins valide et cohérent). À faire démontrer en soutenance.
- Constantes magiques nombreuses (`0.015`, `0.35`, `15.31`…) — inhérent au procédural mais peu commentées.
- Voisinage 5×5 × nombreux SDF par pixel = coût fragment élevé (acceptable pour un sol, à surveiller en plein écran).

### Note proposée : **18 / 20**

> **Le rendu qui colle le mieux à la consigne** : un fragment shader riche, entièrement écrit à la main, procédural et animé, sans béquille compute/nodal. Niveau nettement au-dessus de la moyenne de la promo sur la compétence visée. Pénalisé uniquement par l'absence totale de doc/nom et la livraison hors-projet — sinon 19-20.

---

## Tableau récapitulatif v2

| Groupe | Archive déposée | Fichier principal évalué | Frag shader code | Compute | Nodal | Ambition | README | **Note v2** |
|---|---|---|:-:|:-:|:-:|:-:|:-:|:-:|
| 7 — CircuitFloorURP | `…05-04-09.09.03_Shaderdetravail-groupe7.shader` | `Shaderdetravail-groupe7.shader` | ✅✅ pur & riche | ❌ | ❌ | ★★★ | ❌ | **18** |
| 1 — Lumenfall | `…05-02-16.06.34_CodeZipé_groupe1.zip` | `ParticleRender.shader` | ✅ excellent | ✅ | nombreux | ★★★ | ❌ | **17** |
| 2 — Attal | `…04-15-15.26.35_Shaders-groupe2.zip` | `Boids.shader` | ✅ valide (minimal) | ✅ | 1 (Wave) | ★★ | ✅ excellent | **16** |
| 4 — Sebastian | `…05-03-14.14.10_RenduSebastian-groupe4.rar` | `ParticleShader.shader` | ✅ valide | ✅ qualité | ❌ | ★★ | partiel | **15** |
| 3 — Atelier CG | `…05-03-16.18.31_renduliengit-groupe3.txt` (lien Git) | `Trou_de_ver.shadergraph` (+ `BoidsSimulation.compute`) | ❌ | ✅ solide | trou de ver | ★★★ | partiel | **13** |
| 5 — ComputerGraphics | `…05-04-01.35.52_rendu-groupe5.zip` | `GrassShader.shadergraph` (+ `CrowdCompute.compute`) | ❌ | ✅✅ | 6 graphes | ★★★ | ❌ | **13** |
| 4 — Sacha | `…05-03-10.27.51_RenduSacha-groupe4.zip` | `VertexShader.shader` | 🔶 coquille vide | ✅ (×2) | 2 | ★ | ❌ | **12** |
| 6 — rendu | `…05-03-16.44.07_rendu-groupe6.rar` | `sandCompute.compute` | ❌ | ✅ (dupliqué ?) | ❌ | ★ | ❌ | **10*** |

*Sous réserve de la vérification de la duplication `sandCompute` (Sacha ↔ groupe 6).
**Groupe 3 :** pas d'archive déposée — un fichier texte contenant un lien dépôt Git.

---

## Observations transversales

### Le groupe 7 est le seul vraiment dans la cible
`CircuitFloorURP` est le **seul rendu centré sur un fragment shader pur écrit à la main** (ni compute ni nodal), avec une vraie richesse procédurale. C'est l'étalon de ce que la consigne attendait → note la plus haute (18). Les groupes 1, 2 et 4-Sebastian respectent aussi la consigne mais via un pipeline particules (le fragment y est plus secondaire).

### La consigne a été partiellement mal comprise — responsabilité partagée
3 rendus sur 8 (3, 5, 6) n'ont écrit aucun fragment en code. Vu l'ampleur, on traite cela comme une **ambiguïté d'énoncé** autant que comme une erreur d'étudiants → notation bienveillante. Pour l'an prochain, **donner `CircuitFloorURP` (groupe 7) comme exemple-type** de rendu attendu, et :
- Donner un **squelette de `.shader`** au début du TD pour ancrer le format attendu.
- **Interdire explicitement Shader Graph** dans la consigne écrite.
- Imposer un **minimum mesurable** : « le `.shader` doit contenir ≥ 30 lignes de HLSL et ≥ 3 fonctions intrinsèques ».
- Imposer un **effet non trivial dans le fragment** (gradient procédural, noise, fresnel, toon…).

### Les fragments rendus restent pauvres
Seul le groupe 1 fait du procédural conditionnel dans le fragment. Les groupes 2 et 4-Sebastian se contentent de `return _Color` / `return rouge` — conforme mais minimal.

### Suspicion de partage non déclaré
`sandCompute.compute` identique entre groupe 4-Sacha et groupe 6. **À vérifier impérativement en soutenance** (impacte la note du groupe 6).

---

## Suggestions pour la soutenance

1. **Faire pointer à chaque groupe le bloc `HLSLPROGRAM` qu'ils ont écrit** — tranche immédiatement code vs nodal.
2. Groupes 1, 2, 4-Sebastian : faire **expliquer le pipeline** compute → buffer → vert → frag et les sémantiques (`SV_InstanceID`, `SV_Target`, `SV_DispatchThreadID`).
3. Groupes 3, 5 : « pourquoi le nodal alors que la consigne demandait du code ? » — la réponse distingue malentendu sincère et évitement (et peut moduler la note dans la fourchette de bienveillance).
4. **Vérifier la duplication** `sandCompute.compute` entre Sacha et groupe 6.
5. Groupe 1 (anonyme) : **identifier les auteurs** et faire distinguer leur code de l'asset store Enviro 3.
