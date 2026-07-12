/*
=====================================================================
 DÉCOUVERTE DE SUPERCOLLIDER — ESGI
 D'après le tutoriel de Nick Collins :
 https://composerprogrammer.com/teaching/supercollider/sctutorial/tutorial.html
=====================================================================

MODE D'EMPLOI (à lire avant de toucher au clavier)

 SuperCollider = 2 programmes qui se parlent en réseau (OSC) :
   - sclang : le langage (là où on écrit du code)
   - scsynth : le serveur audio (celui qui calcule les échantillons)

 Raccourcis (Windows/Linux ; sur Mac remplacer Ctrl par Cmd) :
   Ctrl+Entrée  : évaluer la ligne courante OU le bloc entre parenthèses
   Ctrl+.       : PANIC — coupe tout le son immédiatement (à retenir !)
   Ctrl+D       : ouvrir l'aide sur le mot sous le curseur
   Ctrl+M       : ouvrir le serveur / les meters

 On n'exécute JAMAIS tout le fichier d'un coup : on avance bloc par bloc,
 dans l'ordre, en écoutant à chaque fois.
=====================================================================
*/


// ====================================================================
// 0. DÉMARRAGE — on allume le serveur audio
// ====================================================================

s.boot;              // 's' est un raccourci global vers le serveur local ; .boot le démarre
s.meter;             // affiche les vu-mètres entrée/sortie (pratique pour voir si ça sort)
s.plotTree;          // affiche l'arbre des noeuds actifs sur le serveur (vide pour l'instant)

// Vérification que le langage répond (résultat dans la post window, en bas) :
1 + 1;               // évalue à 2 : sclang est un vrai langage, pas juste un séquenceur
"Bonjour ESGI".postln;  // .postln affiche la valeur dans la fenêtre de post


// ====================================================================
// 1. PREMIER SON — l'oscillateur
// ====================================================================

{ SinOsc.ar(440, 0, 0.2) }.play;   // {...} = une fonction ; .play l'envoie au serveur
// SinOsc  : oscillateur sinusoïdal (une UGen : "unit generator", brique de synthèse)
// .ar     : "audio rate" — calculé à la fréquence d'échantillonnage (44100 fois/s)
// 440     : fréquence en Hz (le La du diapason)
// 0       : phase initiale (en radians)
// 0.2     : amplitude — TOUJOURS < 1, sinon saturation + oreilles en danger

// Ctrl+. pour couper. Faites-le maintenant, c'est un réflexe à installer.

// Stéréo : si la fonction renvoie un tableau de 2 signaux, on a 2 canaux
{ [SinOsc.ar(440, 0, 0.2), SinOsc.ar(443, 0, 0.2)] }.play;  // 3 Hz d'écart -> battement audible

// Autres formes d'onde — écoutez la différence de timbre :
{ Saw.ar(200, 0.2) }.play;      // dent de scie : toutes les harmoniques (riche, "buzz")
{ Pulse.ar(200, 0.5, 0.2) }.play;  // carré : harmoniques impaires seulement (creux, "clarinette")
{ WhiteNoise.ar(0.2) }.play;    // bruit blanc : toutes les fréquences, aléatoire


// ====================================================================
// 2. MUL & ADD — comprendre la mise à l'échelle
// ====================================================================
/*
 Un signal audio oscille entre -1 et +1. C'est l'intervalle "naturel".
 mul  = multiplication  -> change l'AMPLITUDE (la taille de l'oscillation)
 add  = addition        -> change l'OFFSET (le centre de l'oscillation)

 Une sinusoïde SinOsc.ar(f, 0, mul, add) oscille donc entre (add - mul) et (add + mul).
 C'est LA formule à connaître pour piloter un paramètre avec un oscillateur.
*/

// Exemple : je veux un LFO qui oscille entre 400 et 800 Hz.
// Milieu = 600 (add), amplitude = 200 (mul).
(
{
	var lfo = SinOsc.kr(1, 0, 200, 600);   // .kr = "control rate" : 64x moins de calculs, suffisant pour un LFO
	SinOsc.ar(lfo, 0, 0.2);                // la sortie du LFO devient la fréquence de l'oscillateur audio
}.play;
)
// Règle : .ar pour ce qu'on entend, .kr pour ce qui module. C'est une optimisation, pas un dogme.

// Même chose écrite avec .range, plus lisible (recommandé) :
(
{
	var lfo = SinOsc.kr(1).range(400, 800);  // .range(min, max) fait le calcul mul/add pour nous
	SinOsc.ar(lfo, 0, 0.2);
}.play;
)

// EXERCICE 1 : faire un trémolo (l'amplitude oscille, pas la fréquence).
// Indice : mettre le LFO à la place du mul, avec .range(0, 0.3).


// ====================================================================
// 3. SYNTHÈSE SOUSTRACTIVE — source riche + filtre
// ====================================================================
/*
 Principe historique (Moog, ARP...) : on part d'un son riche en harmoniques
 (saw, bruit) et on SCULPTE en enlevant des fréquences avec un filtre.
*/

(
{
	var source = Saw.ar(80, 0.3);                  // source riche en harmoniques
	var cutoff = SinOsc.kr(0.5).range(200, 3000);  // la fréquence de coupure balaie lentement
	RLPF.ar(source, cutoff, 0.15);                 // filtre passe-bas résonant : coupe au-dessus de cutoff
	                                               // 3e arg = rq : résonance (petit = très résonant)
}.play;
)

// Bruit filtré = un vent / une nappe. Comparez BPF (passe-bande) et RLPF.
(
{
	var bruit = WhiteNoise.ar(0.5);
	BPF.ar(bruit, LFNoise1.kr(0.5).exprange(300, 4000), 0.05);  // LFNoise1 = bruit lent interpolé (mouvement organique)
	                                                            // .exprange : interpolation exponentielle -> correct pour les fréquences
}.play;
)
// Pourquoi exprange pour les fréquences ? Parce que l'oreille perçoit les hauteurs
// de manière logarithmique : 100->200 Hz et 1000->2000 Hz sont le MÊME intervalle (une octave).


// ====================================================================
// 4. SYNTHÈSE ADDITIVE — empiler des sinusoïdes
// ====================================================================
/*
 Théorème de Fourier : n'importe quel son périodique = somme de sinusoïdes.
 L'additive construit le timbre harmonique par harmonique.
*/

(
{
	var n = 12;                                        // nombre d'harmoniques
	var freqs = (1..n) * 110;                          // (1..n) = [1,2,...,12] -> série harmonique sur 110 Hz
	var amps  = (1..n).reciprocal;                     // 1/n : amplitude décroissante -> approxime une dent de scie
	var sines = SinOsc.ar(freqs, 0, amps);             // MULTICANAL AUTOMATIQUE : un tableau en entrée -> 12 SinOsc !
	Mix(sines) * 0.1;                                  // Mix additionne les 12 canaux en un seul
}.play;
)
// "Multichannel expansion" : donner un Array à une UGen la duplique. C'est LE réflexe SuperCollider.

// Variante inharmonique : on casse la série -> son métallique, cloche
(
{
	var n = 8;
	var freqs = (1..n).collect { |i| 220 * (i ** 1.7) };  // exposant non entier = partiels inharmoniques
	var amps  = (1..n).collect { |i| 1 / (i * 2) };
	Mix(SinOsc.ar(freqs, 0, amps)) * 0.2;
}.play;
)


// ====================================================================
// 5. MODULATION — AM, RM et FM
// ====================================================================

// Ring modulation : on multiplie deux signaux audio entre eux
{ SinOsc.ar(440) * SinOsc.ar(300) * 0.3 }.play;  // crée les fréquences somme (740) et différence (140)

// Frequency modulation (FM, façon Yamaha DX7) : un oscillateur module la fréquence d'un autre
(
{
	var carrier = 300;             // porteuse : la hauteur perçue
	var modRatio = 2.001;          // rapport modulante/porteuse : détermine le timbre (entier = harmonique)
	var index = MouseX.kr(0, 800); // index de modulation = profondeur -> pilotée à la SOURIS (axe X)
	var mod = SinOsc.ar(carrier * modRatio, 0, index);  // la modulante, dont l'amplitude EST la profondeur
	SinOsc.ar(carrier + mod, 0, 0.2);                   // on ajoute la modulante à la fréquence de la porteuse
}.play;
)
// Bougez la souris de gauche à droite : plus l'index monte, plus le spectre s'enrichit.
// MouseX/MouseY : les UGens de contrôle les plus rapides à mettre en place pour prototyper.


// ====================================================================
// 6. ENVELOPPES — donner un début et une fin au son
// ====================================================================
/*
 Sans enveloppe, un son démarre et s'arrête brutalement (clic) et ne se libère jamais.
 Env = la forme ; EnvGen = l'UGen qui la joue.
 doneAction: 2 = quand l'enveloppe est finie, le synthé se LIBÈRE de la mémoire du serveur.
 Oublier doneAction, c'est accumuler des synthés zombies jusqu'à saturer le CPU.
*/

(
{
	var env = EnvGen.kr(
		Env.perc(0.01, 1.0),   // percussion : attaque 10 ms, décroissance 1 s
		doneAction: 2          // auto-destruction en fin d'enveloppe
	);
	SinOsc.ar(440, 0, 0.3) * env;  // on multiplie le son par l'enveloppe (amplitude variable dans le temps)
}.play;
)

// Enveloppe ADSR, qui a besoin d'un "gate" pour savoir quand relâcher :
// Env.adsr(attack, decay, sustainLevel, release)
(
{
	var env = EnvGen.kr(Env.adsr(0.05, 0.2, 0.4, 1.0), gate: 1, doneAction: 2);
	// gate: 1 -> l'enveloppe démarre ; passer le gate à 0 déclenche la phase de release
	Saw.ar(110, 0.3) * env;
}.play;
)

// L'enveloppe peut moduler AUTRE CHOSE que l'amplitude (ici le filtre) :
(
{
	var ampEnv = EnvGen.kr(Env.perc(0.01, 0.8), doneAction: 2);
	var filtEnv = EnvGen.kr(Env.perc(0.01, 0.3)).exprange(200, 5000);  // le filtre s'ouvre puis se referme
	RLPF.ar(Saw.ar(55), filtEnv, 0.2) * ampEnv * 0.4;                  // -> le classique "pluck" de synthé
}.play;
)


// ====================================================================
// 7. SYNTHDEF — compiler un instrument réutilisable
// ====================================================================
/*
 {...}.play c'est du prototypage. Pour jouer un son 1000 fois, on le COMPILE
 une bonne fois pour toutes en SynthDef, envoyé au serveur, puis instancié avec Synth().
 Les arguments (|...|) deviennent les paramètres pilotables de l'instrument.
*/

(
SynthDef(\pluck, { |out = 0, freq = 440, amp = 0.3, cutoff = 2000, pan = 0, rel = 0.6|
	var env = EnvGen.kr(Env.perc(0.005, rel), doneAction: 2);  // enveloppe d'amplitude
	var sig = Saw.ar(freq);                                     // source
	sig = RLPF.ar(sig, cutoff, 0.3);                            // filtrage
	sig = sig * env * amp;                                      // mise en forme temporelle + volume
	Out.ar(out, Pan2.ar(sig, pan));                             // Pan2 : mono -> stéréo ; Out : écrit sur le bus de sortie
}).add;                                                         // .add compile et envoie la définition au serveur
)

Synth(\pluck);                                              // joue l'instrument avec ses valeurs par défaut
Synth(\pluck, [\freq, 660, \cutoff, 4000, \pan, -1]);       // ... ou avec des paramètres personnalisés

// Un synthé qu'on garde en main pour le modifier en temps réel :
x = Synth(\pluck, [\freq, 110, \rel, 20]);   // 'x' est une variable globale (a..z sont réservées à ça)
x.set(\cutoff, 400);                          // .set change un paramètre du synthé DÉJÀ en train de jouer
x.set(\cutoff, 6000);
x.free;                                       // .free le tue immédiatement


// ====================================================================
// 8. SÉQUENCEMENT — jouer dans le temps
// ====================================================================

// 8a. Routine : du code qui peut faire une pause (.wait) sans bloquer le reste
(
r = Routine({
	10.do { |i|                                    // répète 10 fois, i = 0..9
		Synth(\pluck, [\freq, 110 * (i + 1)]);     // monte la série harmonique
		0.25.wait;                                 // attend 250 ms avant l'itération suivante
	};
}).play;                                           // .play l'inscrit dans l'horloge (TempoClock)
)

// 8b. Patterns : la manière idiomatique de séquencer en SuperCollider.
// Pbind associe des CLÉS (les arguments de la SynthDef) à des FLUX de valeurs.
(
p = Pbind(
	\instrument, \pluck,                                  // quel SynthDef jouer
	\degree, Pseq([0, 2, 4, 7, 4, 2], inf),               // Pseq = séquence, inf = en boucle ; degré dans la gamme
	\scale, Scale.minorPentatonic,                        // gamme utilisée pour convertir degree -> fréquence
	\octave, 4,                                           // registre
	\dur, 0.2,                                            // durée entre deux notes (en beats)
	\cutoff, Pwhite(800, 5000),                           // Pwhite = aléatoire uniforme, une valeur nouvelle par note
	\pan, Pseq([-0.7, 0.7], inf),                         // alterne gauche/droite
	\amp, 0.25
).play;
)

p.stop;   // arrête le pattern

// 8c. Superposer deux patterns = polyphonie / arrangement
(
Pbind(                                                     // basse
	\instrument, \pluck,
	\degree, Pseq([0, 0, 3, 5], inf),
	\octave, 2,
	\dur, 1,
	\rel, 0.9,
	\cutoff, 600,
	\amp, 0.35
).play;

Pbind(                                                     // mélodie par-dessus
	\instrument, \pluck,
	\degree, Prand([0, 2, 4, 5, 7, 9], inf),               // Prand = tirage aléatoire à chaque note
	\scale, Scale.minorPentatonic,
	\octave, 5,
	\dur, Pseq([0.25, 0.25, 0.5], inf),                     // rythme irrégulier
	\cutoff, Pwhite(2000, 7000),
	\amp, 0.15
).play;
)

// Ctrl+. pour tout arrêter.


// ====================================================================
// 9. EFFETS ET BUS — chaîner des synthés
// ====================================================================
/*
 Un effet est un synthé qui LIT un bus audio et ÉCRIT sur un autre.
 Problème central : l'ORDRE D'EXÉCUTION. Le serveur calcule les noeuds dans l'ordre
 de l'arbre : si la reverb est calculée AVANT la source, elle traite le buffer vide
 du bloc précédent -> latence, ou silence. D'où \addToTail / \addToHead.
*/

~fxBus = Bus.audio(s, 2);   // '~' = variable d'environnement (globale, nom libre) ; bus audio stéréo privé

(
SynthDef(\reverb, { |in, out = 0, mix = 0.4, room = 0.8|
	var sig = In.ar(in, 2);                        // In.ar : lit 2 canaux depuis le bus d'entrée
	sig = FreeVerb2.ar(sig[0], sig[1], mix, room); // réverbération stéréo
	Out.ar(out, sig);                              // écrit vers la sortie physique
}).add;
)

// On crée l'effet EN QUEUE de l'arbre : il sera calculé APRÈS les sources.
~rev = Synth(\reverb, [\in, ~fxBus], addAction: \addToTail);

// Et on envoie les notes vers ~fxBus au lieu de la sortie 0 (grâce à l'argument 'out' de \pluck) :
(
Pbind(
	\instrument, \pluck,
	\out, ~fxBus,                                  // la sortie du pluck part dans la reverb
	\degree, Pseq([0, 3, 5, 7, 10], inf),
	\scale, Scale.minorPentatonic,
	\octave, 5,
	\dur, 0.5,
	\rel, 1.5,
	\amp, 0.2
).play;
)

s.plotTree;   // observez l'arbre : les Synths \pluck sont AVANT le \reverb. C'est ce qu'on veut.

// Nettoyage :
~rev.free;
~fxBus.free;


// ====================================================================
// 10. INTERACTION — une GUI en 15 lignes
// ====================================================================

(
~drone = { |freq = 100, cutoff = 800|
	RLPF.ar(Saw.ar([freq, freq * 1.01], 0.2), cutoff, 0.2);  // détune léger entre L et R -> épaisseur
}.play;

w = Window("Contrôle du drone", Rect(100, 100, 320, 120)).front;  // fenêtre, position + taille
w.layout = VLayout(                                                // empilement vertical
	Slider(w).action_({ |sl|                                       // .action_ : callback appelé quand on bouge le curseur
		~drone.set(\freq, sl.value.linexp(0, 1, 40, 400));          // linexp : 0..1 (linéaire) -> 40..400 Hz (exponentiel)
	}),
	Slider(w).action_({ |sl|
		~drone.set(\cutoff, sl.value.linexp(0, 1, 200, 8000));
	})
);
w.onClose = { ~drone.free };   // sécurité : fermer la fenêtre libère le synthé
)


// ====================================================================
// EXERCICES
// ====================================================================
/*
 1. TRÉMOLO
    Reprendre le §2 et faire osciller l'amplitude (et non la fréquence).

 2. INSTRUMENT PERSO
    Écrire une SynthDef \kick : SinOsc dont la fréquence descend de 200 à 50 Hz
    via une enveloppe exponentielle courte (Env.perc + .exprange), avec doneAction: 2.
    Indice : la même enveloppe peut piloter à la fois la hauteur et l'amplitude.

 3. RYTHME
    Séquencer ce kick avec un Pbind et \dur, Pseq([0.5, 0.25, 0.25], inf).
    Ajouter un \rest (silence) avec Pseq([0, 0, Rest(), 0], inf) sur la clé \degree.

 4. FM CONTRÔLÉE
    Transformer la FM du §5 en SynthDef avec modRatio et index en arguments,
    puis piloter l'index depuis un Pbind avec Pseq ou Pwhite.

 5. POUR ALLER PLUS LOIN (chap. 5, 6, 12 du tutoriel de Nick Collins)
    - Buffer.read + PlayBuf : jouer un fichier son
    - GrainBuf : synthèse granulaire
    - FFT / PV_* : traitement spectral
*/


// ====================================================================
// AIDE-MÉMOIRE
// ====================================================================
/*
 Ctrl+.          couper tout le son
 Ctrl+D          aide sur le mot sous le curseur (le réflexe n°1 en SC)
 s.boot / s.quit démarrer / arrêter le serveur
 s.meter         vu-mètres
 s.plotTree      arbre des noeuds
 .ar / .kr       taux audio / taux de contrôle
 doneAction: 2   libérer le synthé en fin d'enveloppe (à ne JAMAIS oublier)
 ~nom            variable globale d'environnement
 a..z            variables globales prédéfinies (x = Synth(...))
*/
