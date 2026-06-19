s.boot;

(
MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(false);
)

(
// Bus de réverbération
~verbBus = Bus.audio(s, 2);
)

(
// Sinus
SynthDef(\sine, {
    |freq=440, amp=0.1|

    var env;
    var sig;

    env = EnvGen.kr(
        Env.perc(0.001, 0.08),
        doneAction: 2
    );

    sig = SinOsc.ar(freq);

    Out.ar(
        ~verbBus,
        (sig * env * amp)!2
    );
}).add;

// Pulse
SynthDef(\pulse, {
    |freq=440, amp=0.1|

    var env;
    var sig;

    env = EnvGen.kr(
        Env.perc(0.001, 0.05),
        doneAction: 2
    );

    sig = Pulse.ar(freq, 0.5);

    Out.ar(
        ~verbBus,
        (sig * env * amp * 0.5)!2
    );
}).add;

// Saw
SynthDef(\saw, {
    |freq=440, amp=0.1|

    var env;
    var sig;

    env = EnvGen.kr(
        Env.perc(0.001, 0.1),
        doneAction: 2
    );

    sig = LPF.ar(
        Saw.ar(freq),
        3000
    );

    Out.ar(
        ~verbBus,
        (sig * env * amp * 0.3)!2
    );
}).add;

// Noise Perc
SynthDef(\noise, {
    |freq=440, amp=0.1|

    var env;
    var sig;

    env = EnvGen.kr(
        Env.perc(0.001, 0.03),
        doneAction: 2
    );

    sig = BPF.ar(
        WhiteNoise.ar,
        freq,
        0.2
    );

    Out.ar(
        ~verbBus,
        (sig * env * amp)!2
    );
}).add;
)

(
// Réverbération globale
~reverb = {
    var sig;

    sig = In.ar(~verbBus, 2);

    sig = JPverb.ar(
        sig,
        t60: 3,
        damp: 0.3
    );

    Out.ar(0, sig);
}.play;
)


(
// Mapping des canaux MIDI

MIDIdef.noteOn(\orca, {
    |vel, note, chan, src|

    var synth;

    synth = switch(chan,

        0, { \sine },

        1, { \pulse },

        2, { \saw },

        3, { \noise },

        { \sine }
    );

    [
        "note", note,
        "vel", vel,
        "chan", chan,
        "instrument", synth
    ].postln;

    Synth(
        synth,
        [
            \freq, note.midicps,
            \amp, vel.linlin(0, 127, 0.02, 0.3)
        ]
    );

});
)

SynthDescLib.global.at(\saw);
