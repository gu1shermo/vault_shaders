/*
=====================================================================
 SONS AQUATIQUES — SuperCollider
 Suite de decouverte_supercollider.scd : gouttes, bulles, vagues,
 ambiance sous-marine. Techniques : bruit filtré, enveloppes courtes,
 comb/allpass (résonance de bulle), LFNoise (mouvement organique).

 Rappel : Ctrl+Entrée sur un bloc, Ctrl+. pour tout couper.
=====================================================================
*/

s.boot;


// ====================================================================
// 1. GOUTTE D'EAU — pitch qui chute + court
// ====================================================================
/*
 Une goutte = une sinusoïde dont la fréquence CHUTE très vite (effet "plop"),
 enveloppée par un perc très court. C'est le même principe que l'exercice
 "kick" du fichier précédent, juste beaucoup plus aigu et plus court.
*/

(
SynthDef(\goutte, { |out = 0, freq = 1200, amp = 0.3, pan = 0|
	var pitchEnv = EnvGen.kr(Env.perc(0.001, 0.12, curve: -8), doneAction: 0).exprange(freq * 0.15, freq);
	var ampEnv   = EnvGen.kr(Env.perc(0.001, 0.15), doneAction: 2);
	var sig = SinOsc.ar(pitchEnv) + SinOsc.ar(pitchEnv * 2.4, 0, 0.3);  // partiel léger = "clic" du plop
	Out.ar(out, Pan2.ar(sig * ampEnv * amp, pan));
}).add;
)

Synth(\goutte);
Synth(\goutte, [\freq, 2000, \pan, -0.5]);

// Pluie : gouttes aléatoires en rafale
(
Pbind(
	\instrument, \goutte,
	\dur, Pexprand(0.03, 0.3),
	\freq, Pexprand(600, 2600),
	\pan, Pwhite(-1.0, 1.0),
	\amp, Pexprand(0.05, 0.25)
).play;
)


// ====================================================================
// 2. BULLE — résonance + montée de pitch
// ====================================================================
/*
 Une bulle qui remonte a une hauteur qui MONTE (inverse de la goutte),
 avec une résonance étroite (BPF très pincé) qui simule la cavité d'air.
*/

(
SynthDef(\bulle, { |out = 0, freq = 400, dur = 0.25, amp = 0.2, pan = 0|
	var pitchEnv = EnvGen.kr(Env.new([freq * 0.6, freq * 1.8, freq * 2.2], [dur * 0.7, dur * 0.3], curve: \exp));
	var excite = WhiteNoise.ar(1) * EnvGen.kr(Env.perc(0.001, 0.01));  // impulsion brève qui excite le filtre
	var sig = BPF.ar(excite, pitchEnv, 0.02) * 40;                    // rq très petit = filtre très résonant -> "ploc"
	var ampEnv = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
	Out.ar(out, Pan2.ar(sig * ampEnv * amp, pan));
}).add;
)

Synth(\bulle);
Synth(\bulle, [\freq, 250, \dur, 0.4]);

// Chapelet de bulles qui remontent (aquarium) :
(
Pbind(
	\instrument, \bulle,
	\dur, Pexprand(0.08, 0.5),
	\freq, Pexprand(150, 900),
	\pan, Pwhite(-0.8, 0.8),
	\amp, Pexprand(0.08, 0.2)
).play;
)


// ====================================================================
// 3. VAGUES — bruit filtré + LFO lent (houle)
// ====================================================================
/*
 Le ressac : du bruit blanc dont l'enveloppe de volume ET la coupure du
 filtre respirent lentement (LFNoise/SinOsc très lents = la houle).
 On superpose 2 échelles de temps : lente (la vague) et rapide (l'écume).
*/

(
{
	var houle = LFNoise1.kr(0.08).range(0.05, 0.5);          // volume qui monte/descend très lentement, irrégulier
	var ecume = WhiteNoise.ar(1);
	var cutoff = LFNoise1.kr(0.15).exprange(400, 3000);      // le filtre s'ouvre/se ferme avec la houle
	var sig = RLPF.ar(ecume, cutoff, 0.3) * houle;
	sig = sig + BPF.ar(WhiteNoise.ar(0.3), 6000, 0.5) * houle;  // un peu de "pschhh" haute fréquence = crête d'écume
	sig ! 2;  // ! 2 = duplique en stéréo (raccourci pour [sig, sig])
}.play;
)

// Version stéréo avec léger décalage L/R pour la largeur :
(
{
	var l = LFNoise1.kr(0.08, mul: 0.25, add: 0.3);
	var r = LFNoise1.kr(0.08, mul: 0.25, add: 0.3);          // 2 LFNoise indépendants -> décorrélation stéréo
	var cutL = LFNoise1.kr(0.15).exprange(400, 3000);
	var cutR = LFNoise1.kr(0.15).exprange(400, 3000);
	[
		RLPF.ar(WhiteNoise.ar(1), cutL, 0.3) * l,
		RLPF.ar(WhiteNoise.ar(1), cutR, 0.3) * r
	];
}.play;
)


// ====================================================================
// 4. AMBIANCE SOUS-MARINE — tout est étouffé
// ====================================================================
/*
 Sous l'eau : les hautes fréquences sont fortement atténuées (l'eau absorbe
 les aigus), il reste un "wobble" grave. On combine :
   - un lowpass très bas et fixe (l'étouffement)
   - une modulation lente du volume (la pression qui varie)
   - un soupçon de RM avec un LFO grave (le "glou-glou" filtré)
*/

(
~sousMarin = {
	var src = PinkNoise.ar(0.6) + SinOsc.ar(LFNoise1.kr(0.3).range(40, 90), 0, 0.15);
	var wobble = SinOsc.kr(LFNoise1.kr(0.2).range(0.5, 2)).range(0.6, 1.0);
	var sig = LPF.ar(src, 500);            // étouffement : rien au-dessus de 500 Hz
	sig = sig * wobble;
	sig = sig + AllpassN.ar(sig, 0.05, [0.031, 0.037], 2);  // allpass = épaissit sans colorer -> sensation de volume liquide
	sig ! 2;
}.play;
)

~sousMarin.free;  // évaluer pour couper l'ambiance


// ====================================================================
// 5. SCÈNE COMPLÈTE — tout ensemble
// ====================================================================
/*
 On superpose : ambiance sous-marine (fond), bulles (aquarium), gouttes
 occasionnelles (surface). Bonne base pour un niveau "aquatique" du jam.
*/

(
~sousMarin = {
	var src = PinkNoise.ar(0.5) + SinOsc.ar(LFNoise1.kr(0.3).range(40, 90), 0, 0.12);
	var wobble = SinOsc.kr(LFNoise1.kr(0.2).range(0.5, 2)).range(0.6, 1.0);
	var sig = LPF.ar(src, 500) * wobble;
	sig = sig + AllpassN.ar(sig, 0.05, [0.031, 0.037], 2);
	sig ! 2;
}.play;

~bulles = Pbind(
	\instrument, \bulle,
	\dur, Pexprand(0.3, 1.2),
	\freq, Pexprand(150, 900),
	\pan, Pwhite(-0.8, 0.8),
	\amp, Pexprand(0.06, 0.15)
).play;

~gouttes = Pbind(
	\instrument, \goutte,
	\dur, Pexprand(1.0, 4.0),
	\freq, Pexprand(800, 2200),
	\pan, Pwhite(-1.0, 1.0),
	\amp, Pexprand(0.05, 0.15)
).play;
)

// Arrêt propre :
(
~sousMarin.free;
~bulles.stop;
~gouttes.stop;
)


// ====================================================================
// EXERCICES
// ====================================================================
/*
 1. HYDROPHONE
    Piloter le cutoff de \sousMarin (§4) à la souris (MouseY.kr) pour
    simuler une remontée vers la surface (cutoff qui s'ouvre).

 2. POISSON QUI PASSE
    Faire un Synth bref avec Pan2 dont le pan traverse tout le champ
    stéréo via une Line.kr(-1, 1, dur) — un son qui "nage" de gauche à
    droite.

 3. GRANULAIRE
    Si tu as un fichier .wav de vagues, le charger avec Buffer.read et
    le lire en granulaire (GrainBuf) pour varier texture/vitesse en live.

 4. RELIER À ORCA
    Mapper les notes MIDI d'Orca sur \freq de \bulle, et une CC sur le
    cutoff de \sousMarin — cf. pipeline jam.md.
*/
