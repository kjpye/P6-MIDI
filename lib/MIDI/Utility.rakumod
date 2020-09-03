use v6.d;

unit module MIDI::Utility;

my $Debug = 0; # currently doesn't do anything
my $VERSION = '0.84';

my %number2note = 0 .. 127 Z=> (
# (Do)        (Re)         (Mi)  (Fa)         (So)         (La)        (Ti)
 'C0', 'Cs0', 'D0', 'Ds0', 'E0', 'F0', 'Fs0', 'G0', 'Gs0', 'A0', 'As0', 'B0',
 'C1', 'Cs1', 'D1', 'Ds1', 'E1', 'F1', 'Fs1', 'G1', 'Gs1', 'A1', 'As1', 'B1',
 'C2', 'Cs2', 'D2', 'Ds2', 'E2', 'F2', 'Fs2', 'G2', 'Gs2', 'A2', 'As2', 'B2',
 'C3', 'Cs3', 'D3', 'Ds3', 'E3', 'F3', 'Fs3', 'G3', 'Gs3', 'A3', 'As3', 'B3',
 'C4', 'Cs4', 'D4', 'Ds4', 'E4', 'F4', 'Fs4', 'G4', 'Gs4', 'A4', 'As4', 'B4',
 'C5', 'Cs5', 'D5', 'Ds5', 'E5', 'F5', 'Fs5', 'G5', 'Gs5', 'A5', 'As5', 'B5',
 'C6', 'Cs6', 'D6', 'Ds6', 'E6', 'F6', 'Fs6', 'G6', 'Gs6', 'A6', 'As6', 'B6',
 'C7', 'Cs7', 'D7', 'Ds7', 'E7', 'F7', 'Fs7', 'G7', 'Gs7', 'A7', 'As7', 'B7',
 'C8', 'Cs8', 'D8', 'Ds8', 'E8', 'F8', 'Fs8', 'G8', 'Gs8', 'A8', 'As8', 'B8',
 'C9', 'Cs9', 'D9', 'Ds9', 'E9', 'F9', 'Fs9', 'G9', 'Gs9', 'A9', 'As9', 'B9',
 'C10','Cs10','D10','Ds10','E10','F10','Fs10','G10',
  # Note number 69 reportedly == A440, under a default tuning.
  # and note 60 = Middle C
);

my %note2number = %number2note.reverse;

# Note how I deftly avoid having to figure out how to represent a flat mark
#  in ASCII.

###########################################################################
#  ****     TABLE 1  -  General MIDI Instrument Patch Map      ****
# (groups sounds into sixteen families, w/8 instruments in each family)
#  Note that I call the map 0-127, not 1-128.

my %number2patch = 0 .. 127 Z=> (   # The General MIDI map: patches 0 to 127
#0: Piano
 "Acoustic Grand",         "Bright Acoustic",        "Electric Grand",        "Honky-Tonk",
 "Electric Piano 1",       "Electric Piano 2",       "Harpsichord",           "Clav",
# Chrom Percussion
 "Celesta",                "Glockenspiel",           "Music Box",             "Vibraphone",
 "Marimba",                "Xylophone",              "Tubular Bells",         "Dulcimer",

#16: Organ
 "Drawbar Organ",          "Percussive Organ",       "Rock Organ",            "Church Organ",
 "Reed Organ",             "Accordion",              "Harmonica",             "Tango Accordion",
# Guitar
 "Acoustic Guitar(nylon)", "Acoustic Guitar(steel)", "Electric Guitar(jazz)", "Electric Guitar(clean)",
 "Electric Guitar(muted)", "Overdriven Guitar",      "Distortion Guitar",     "Guitar Harmonics",

#32: Bass
 "Acoustic Bass",          "Electric Bass(finger)",  "Electric Bass(pick)",   "Fretless Bass",
 "Slap Bass 1",            "Slap Bass 2",            "Synth Bass 1",          "Synth Bass 2",
# Strings
 "Violin",                 "Viola",                  "Cello",                 "Contrabass",
 "Tremolo Strings",        "Pizzicato Strings",      "Orchestral Strings",    "Timpani",

#48: Ensemble
 "String Ensemble 1",      "String Ensemble 2",      "SynthStrings 1",        "SynthStrings 2",
 "Choir Aahs",             "Voice Oohs",             "Synth Voice",           "Orchestra Hit",
# Brass
 "Trumpet",                "Trombone",               "Tuba",                  "Muted Trumpet",
 "French Horn",            "Brass Section",          "SynthBrass 1",          "SynthBrass 2",

#64: Reed
 "Soprano Sax",            "Alto Sax",               "Tenor Sax",             "Baritone Sax",
 "Oboe",                   "English Horn",           "Bassoon",               "Clarinet",
# Pipe
 "Piccolo",                "Flute",                  "Recorder",              "Pan Flute",
 "Blown Bottle",           "Skakuhachi",             "Whistle",               "Ocarina",

#80: Synth Lead
 "Lead 1 (square)",        "Lead 2 (sawtooth)",      "Lead 3 (calliope)",     "Lead 4 (chiff)",
 "Lead 5 (charang)",       "Lead 6 (voice)",         "Lead 7 (fifths)",       "Lead 8 (bass+lead)",
# Synth Pad
 "Pad 1 (new age)",        "Pad 2 (warm)",           "Pad 3 (polysynth)",     "Pad 4 (choir)",
 "Pad 5 (bowed)",          "Pad 6 (metallic)",       "Pad 7 (halo)",          "Pad 8 (sweep)",

#96: Synth Effects
 "FX 1 (rain)",            "FX 2 (soundtrack)",      "FX 3 (crystal)",        "FX 4 (atmosphere)",
 "FX 5 (brightness)",      "FX 6 (goblins)",         "FX 7 (echoes)",         "FX 8 (sci-fi)",
# Ethnic
 "Sitar",                  "Banjo",                  "Shamisen",              "Koto",
 "Kalimba",                "Bagpipe",                "Fiddle",                "Shanai",

#112: Percussive
 "Tinkle Bell",            "Agogo",                  "Steel Drums",           "Woodblock",
 "Taiko Drum",             "Melodic Tom",            "Synth Drum",            "Reverse Cymbal",
# Sound Effects
 "Guitar Fret Noise",      "Breath Noise",           "Seashore",              "Bird Tweet",
 "Telephone Ring",         "Helicopter",             "Applause",              "Gunshot",
);

my %patch2number = %number2patch.reverse;

###########################################################################
#     ****    TABLE 2  -  General MIDI Percussion Key Map    ****
# (assigns drum sounds to note numbers. MIDI Channel 9 is for percussion)
# (it's channel 10 if you start counting at 1.  But WE start at 0.)

my %notenum2percussion = 35 .. 81 => (
 'Acoustic Bass Drum', 'Bass Drum 1',   'Side Stick',     'Acoustic Snare', 'Hand Clap',

 # the forties 
 'Electric Snare',     'Low Floor Tom', 'Closed Hi-Hat',  'High Floor Tom', 'Pedal Hi-Hat',
 'Low Tom',            'Open Hi-Hat',   'Low-Mid Tom',    'Hi-Mid Tom',     'Crash Cymbal 1',

 # the fifties
 'High Tom',           'Ride Cymbal 1', 'Chinese Cymbal', 'Ride Bell',      'Tambourine',
 'Splash Cymbal',      'Cowbell',       'Crash Cymbal 2', 'Vibraslap',      'Ride Cymbal 2',

 # the sixties
 'Hi Bongo',           'Low Bongo',     'Mute Hi Conga',  'Open Hi Conga',  'Low Conga',
 'High Timbale',       'Low Timbale',   'High Agogo',     'Low Agogo',      'Cabasa',

 # the seventies
 'Maracas',            'Short Whistle', 'Long Whistle',   'Short Guiro',    'Long Guiro',
 'Claves',             'Hi Wood Block', 'Low Wood Block', 'Mute Cuica',      'Open Cuica',

 # the eighties
 'Mute Triangle',      'Open Triangle',
);

my %percussion2notenum = %notenum2percussion.reverse;

sub dump-quote(*@stuff) is export {
  # Used variously by some MIDI::* modules.  Might as well keep it here.

  return
    join(", ",
	@stuff.map:
	 { # the cleaner-upper function
             when Buf|utf8 {
                 my $string = '';
                 for $_.list -> $byte {
                     given $byte {
                         when 0x20 .. 0x7e {
                             $string ~= .chr;
                         }
                         default {
                             $string ~= "\\x[{sprintf "%02x", $_}]";
                         }
                     }
                 }
                 $string;
             }
             when Num {
                 ~ $_;
             }
             when Str {
	         $_ ~~ s:g/
                       (<-[\x20 \x21 \x23 \x27..\x3F \x41..\x5B \x5D..\x7E]>)
                       /\\x{sprintf "%02x", $0.ord}/;
                 "\"$_\"";
             }
             default {
                 note "Unknown type: {$_.raku}";
                 'Unknown type';
             }
         }
        );
}

###########################################################################
