NAME
====

MIDI::Simple - procedural/OOP interface for MIDI composition

SYNOPSIS
========

    use MIDI::Simple;
    new-score;
    text-event 'http://www.ely.anglican.org/parishes/camgsm/bells/chimes.html';
    text-event 'Lord through this hour/ be Thou our guide';
    text-event 'so, by Thy power/ no foot shall slide';
    set-tempo 500000;  # 1 qn => .5 seconds (500,000 microseconds)
    patch-change 1, 8;  # Patch 8 = Celesta

    noop c1, f, o5;  # Setup
    # Now play
    n qn, Cs;    n F;   n Ds;  n hn, Gs_d1;
    n qn, Cs;    n Ds;  n F;   n hn, Cs;
    n qn, F;     n Cs;  n Ds;  n hn, Gs_d1;
    n qn, Gs_d1; n Ds;  n F;   n hn, Cs;

    write_score 'westmister_chimes.mid';

DESCRIPTION
===========

This module sits on top of all the MIDI modules -- notably MIDI::Score (so you should skim [MIDI::Score](MIDI::Score)) -- and is meant to serve as a basic interface to them, for composition. By composition, I mean composing anew; you can use this module to add to or modify existing MIDI files, but that functionality is to be considered a bit experimental.

This module provides two related but distinct bits of functionality: 1) a mini-language (implemented as procedures that can double as methods) for composing by adding notes to a score structure; and 2) simple functions for reading and writing scores, specifically the scores you make with the composition language.

The fact that this module's interface is both procedural and object-oriented makes it a definite two-headed beast. The parts of the guts of the source code are not for the faint of heart.

NOTE ON VERSION CHANGES
=======================

This module is somewhat incompatible with the MIDI::Simple versions before .700 (but that was a *looong* time ago).

OBJECT STRUCTURE
----------------

A MIDI::Simple object is a data structure with the following attributes:

  * Score

This is a list of all the notes (each a listref) that constitute this one-track musical piece. Scores are explained in [MIDI::Score](MIDI::Score). You probably don't need to access the Score attribute directly, but be aware that this is where all the notes you make with `n` events go.

  * Time

This is a non-negative integer expressing the start-time, in ticks from the start-time of the MIDI piece, that the next note pushed to the Score will have.

  * Channel

This is a number in the range [0-15] that specifies the current default channel for note events.

  * Duration

This is a non-negative (presumably nonzero) number expressing, in ticks, the current default length of note events, or rests.

  * Octave

This is a number in the range [0-10], expressing what the current default octave number is. This is used for figuring out exactly what note-pitch is meant by a relative note-pitch specification like "A".

  * Notes

This is a list (presumably non-empty) of note-pitch specifications, *as note numbers* in the range [0-127].

  * Volume

This is an integer in the range [0-127] expressing the current default volume for note events.

  * Tempo

This is an integer expressing the number of ticks a quarter note occupies. It's currently 96, and you shouldn't alter it unless you *really* know what you're doing. If you want to control the tempo of a piece, use the `set_tempo` routine, instead.

  * Cookies

This is a hash that can be used by user-defined object-methods for storing whatever they want.

Each package that you call the procedure `new_score` from, has a default MIDI::Simple object associated with it, and all the above attributes are accessible as:

    @Score $Time $Channel $Duration $Octave
    @Notes $Volume $Tempo %Cookies

(Although I doubt you'll use these from any package other than "main".) If you don't know what a package is, don't worry about it. Just consider these attributes synonymous with the above-listed variables. Just start your programs with

    use MIDI::Simple;
    new_score;

and you'll be fine.

Routine/Method/Procedure
------------------------

MIDI::Simple provides some pure functions (i.e., things that take input, and give a return value, and that's all they do), but what you're mostly interested in its routines. By "routine" I mean a subroutine that you call, whether as a procedure or as a method, and that affects data structures other than the return value.

Here I'm using "procedure" to mean a routine you call like this:

    name(parameters...);
    # or, just maybe:
    name;

(In technical terms, I mean a non-method subroutine that can have side effects, and which may not even provide a useful return value.) And I'm using "method" to mean a routine you call like this:

    $object->name(parameters);

So bear these terms in mind when you see routines below that act like one, or the other, or both.

MAIN ROUTINES
-------------

These are the most important routines:

  * new_score() or $obj = MIDI::Simple->new_score()

As a procedure, this initializes the package's default object (Score, etc.). As a method, this is a constructor, returning a new MIDI::Simple object. Neither form takes any parameters.

  * n(...parameters...) or $obj.n(...parameters...)

This uses the parameters given (and/or the state variables like Volume, Channel, Notes, etc) to add a new note to the Score -- or several notes to the Score, if Notes has more than one element in it -- or no notes at all, if Notes is empty list.

Then it moves Time ahead as appropriate. See the section "Parameters For n/r/noop", below.

  * r(...parameters...) or $obj->r(...parameters...)

This is exactly like `n`, except it never pushes anything to Score, but moves ahead Time. (In other words, there is no such thing as a rest-event; it's just a item during which there are no note-events playing.)

  * noop(...parameters...) or $obj->noop(...parameters...)

This is exactly like `n` and `r`, except it never alters Score, *and* never changes Time. It is meant to be used for setting the other state variables, i.e.: Channel, Duration, Octave, Volume, Notes.

Parameters for n/r/noop
-----------------------

A parameter in an `n`, `r`, or `noop` call is meant to change an attribute (AKA state variable), namely Channel, Duration, Octave, Volume, or Notes.

Here are the kinds of parameters you can use in calls to n/r/noop:

* A numeric **volume** parameter. This has the form "V" followed by a positive integer in the range 0 (completely inaudible?) to 127 (AS LOUD AS POSSIBLE). Example: "V90" sets Volume to 90.

* An alphanumeric **volume** parameter. This is a key from the hash %MIDI::Simple::Volume. Current legal values are "ppp", "pp", "p", "mp", "mezzo" (or "m"), "mf", "f", "ff", and "fff". Example: "ff" sets Volume to 112. (Note that "m" isn't a good bareword, so use "mezzo" instead, or just always remember to use quotes around "m".)

* A numeric **channel** parameter. This has the form "c" followed by a positive integer 0 to 15. Example: "c2", to set Channel to 2.

* A numeric **duration** parameter. This has the form "d" followed by a positive (presumably nonzero) integer. Example: "d48", to set Duration to 48.

* An alphabetic (or in theory, possibly alphanumeric) **duration** parameter. This is a key from the hash %MIDI::Simple::Length. Current legal values start with "wn", "hn", "qn", "en", "sn" for whole, half, quarter, eighth, or sixteenth notes. Add "d" to the beginning of any of these to get "dotted..." (e.g., "dqn" for a dotted quarter note). Add "dd" to the beginning of any of that first list to get "double-dotted..." (e.g., "ddqn" for a double-dotted quarter note). Add "t" to the beginning of any of that first list to get "triplet..." (e.g., "tsn" for a triplet sixteenth note -- i.e. a note such that 3 of them add up to something as long as one eighth note). You may add to the contents of %MIDI::Simple::Length to support whatever abbreviations you want, as long as the parser can't mistake them for any other kind of n/r/noop parameter.

* A numeric, absolute **octave** specification. This has the form: an "o" (lowercase oh), and then an integer in the range 0 to 10, representing an octave 0 to 10. The Octave attribute is used only in resolving relative note specifications, as explained further below in this section. (All absolute note specifications also set Octave to whatever octave they occur in.)

* A numeric, relative **octave** specification. This has the form: "o_d" ("d" for down) or "o_u" ("u" for down), and then an integer. This increments, or decrements, Octave. E.g., if Octave is 6, "o_d2" will decrement Octave by 2, making it 4. If this moves Octave below 0, it is forced to 0. Or if it moves Octave above 10, it is forced to 10. (For more information, see the section "Invalid or Out-of-Range Parameters to n/r/noop", below.)

* A numeric, absolute **note** specification. This has the form: an optional "n", and then an integer in the range 0 to 127, representing a note ranging from C0 to G10. The source to [MIDI](MIDI) has a useful reference table showing the meanings of given note numbers. Examples: "n60", or "60", which each add a 60 to the list Notes.

Since this is a kind of absolute note specification, it sets Octave to whatever octave the given numeric note occurs in. E.g., "n60" is "C5", and therefore sets Octave to 5.

The setting of the Notes list is a bit special, compared to how setting the other attributes works. If there are any note specifications in a given parameter list for n, r, or noop, then all those specifications together are assigned to Notes.

If there are no note specifications in the parameter list for n, r, or noop, then Notes isn't changed. (But see the description of "rest", at the end of this section.)

So this:

    n mf, n40, n47, n50;

sets Volume to 80, and Notes to (40, 47, 50). And it sets Octave, first to 3 (since n40 is in octave 3), then to 3 again (since n47 = B3), and then finally to 4 (since n50 = D4).

Note that this is the same as:

    n n40, n47, n50, mf;

The relative orders of parameters is **usually** irrelevant; but see the section "Order of Parameters in a Call to n/r/noop", below.

* An alphanumeric, absolute **note** specification. 

These have the form: a string denoting a note within the octave (as determined by %MIDI::Simple::Note -- see below, in the description of alphanumeric, relative note specifications), and then a number denoting the octave number (in the range 0-10). Examples: "C3", "As4" or "Asharp4", "Bf9" or "Bflat9".

Since this is a kind of absolute note specification, it sets Octave to whatever octave the given numeric note occurs in. E.g., "C3" sets Octave to 3, "As4" sets Octave to 4, and "Bflat9" sets Octave to 9.

This:

    n E3, B3, D4, mf;

does the same as this example of ours from before:

    n n40, n47, n50, mf;

* An alphanumeric, relative **note** specification. 

These have the form: a string denoting a note within the octave (as determined by %MIDI::Simple::Note), and then an optional parameter "_u[number]" meaning "so many octaves up from the current octave" or "_d[parameter]" meaning "so many octaves down from the current octave".

Examples: "C", "As" or "Asharp", "Bflat" or "Bf", "C_d3", "As_d1" or "Asharp_d1", "Bflat_u3" or "Bf_u3".

In resolving what actual notes these kinds of specifications denote, the current value of Octave is used.

What's a legal for the first bit (before any optional octave up/down specification) comes from the keys to the hash %MIDI::Simple::Note. The current acceptable values are:

    C                                 (maps to the value 0)
    Cs or Df or Csharp or Dflat       (maps to the value 1)
    D                                 (maps to the value 2)
    Ds or Ef or Dsharp or Eflat       (maps to the value 3)
    E                                 (maps to the value 4)
    F                                 (maps to the value 5)
    Fs or Gf or Fsharp or Gflat       (maps to the value 6)
    G                                 (maps to the value 7)
    Gs or Af or Gsharp or Aflat       (maps to the value 8)
    A                                 (maps to the value 9)
    As or Bf or Asharp or Bflat       (maps to the value 10)
    B                                 (maps to the value 11)

(Note that these are based on the English names for these notes. If you prefer to add values to accommodate other strings denoting notes in the octave, you may do so by adding to the hash %MIDI::Simple::Note like so:

    use MIDI::Simple;
    %MIDI::Simple::Note =
      (%MIDI::Simple::Note,  # keep all the old values
       'H' => 10,
       'Do' => 0,
       # ...etc...
      );

But the values you add must not contain any characters outside the range [A-Za-z\x80-\xFF]; and your new values must not look like anything that could be any other kind of specification. E.g., don't add "mf" or "o3" to %MIDI::Simple::Note.)

Consider that these bits of code all do the same thing:

    n E3, B3, D4, mf;       # way 1

    n E3, B,  D_u1, mf;     # way 2

    n o3, E, B,  D_u1, mf;  # way 3

    noop o3, mf;            # way 4
    n     E, B,  D_u1;

or even

    n o3, E, B, o4, D, mf;       # way 5!

    n o6, E_d3, B_d3, D_d2, mf;  # way 6!

If a "_d[number]" would refer to a note in an octave below 0, it is forced into octave 0. If a "_u[number]" would refer to a note in an octave above 10, it is forced into octave 10. E.g., if Octave is 8, "G_u4" would resolve to the same as "G10" (not "G12" -- as that's out of range); if Octave is 2, "G_d4" would resolve to the same as "G0". (For more information, see the section "Invalid or Out-of-Range Parameters to n/r/noop", below.)

* The string "`rest`" acts as a sort of note specification -- it sets Notes to empty-list. That way you can make a call to `n` actually make a rest:

    n qn, G;    # makes a G quarter-note
    n hn, rest; # half-rest -- alters Notes, making it ()
    n C,G;      # half-note chord: simultaneous C and G
    r;          # half-rest -- DOESN'T alter Notes.
    n qn;       # quarter-note chord: simultaneous C and G
    n rest;     # quarter-rest
    n;          # another quarter-rest

(If you can follow the above code, then you understand.)

A "`rest`" that occurs in a parameter list with other note specs (e.g., "n qn, A, rest, G") has **no effect**, so don't do that.

Order of Parameters in a Call to n/r/noop
-----------------------------------------

The order of parameters in calls to n/r/noop is not important except insofar as the parameters change the Octave parameter, which may change how some relative note specifications are resolved. For example:

    noop o4, mf;
    n G, B, A3, C;

is the same as "n mf, G4, B4, A3, C3". But just move that "C" to the start of the list:

    noop o4, mf;
    n C, G, B, A3;

and you something different, equivalent to "n mf, C4, G4, B4, A3".

But note that you can put the "mf" anywhere without changing anything.

But **stylistically**, I strongly advise putting note parameters at the **end** of the parameter list:

    n mf, c10, C, B;  # 1. good
    n C, B, mf, c10;  # 2. bad
    n C, mf, c10, B;  # 3. so bad!

3 is particularly bad because an uninformed/inattentive reader may get the impression that the C may be at a different volume and on a different channel than the B.

(Incidentally, "n C5,G5" and "n G5,C5" are the same for most purposes, since the C and the G are played at the same time, and with the same parameters (channel and volume); but actually they differ in which note gets put in the Score first, and therefore which gets encoded first in the MIDI file -- but this makes no difference at all, unless you're manipulating the note-items in Score or the MIDI events in a track.)

Invalid or Out-of-Range Parameters to n/r/noop
----------------------------------------------

If a parameter in a call to n/r/noop is uninterpretable, Perl dies with an error message to that effect.

If a parameter in a call to n/r/noop has an out-of-range value (like "o12" or "c19"), Perl dies with an error message to that effect.

As somewhat of a merciful exception to this rule, if a parameter in a call to n/r/noop is a relative specification (whether like "o_d3" or "o_u3", or like "G_d3" or "G_u3") which happens to resolve to an out-of-range value (like "G_d3" given an Octave value of 2), then Perl will **not** die, but instead will silently try to bring that note back into range, by forcing it up to octave 0 (if it would have been lower), or down into 9 or 10 (if it would have been an octave higher than 10, or a note higher than G10), as appropriate.

(This becomes strange in that, given an Octave of 8, "G_u4" is forced down to G10, but "A_u4" is forced down to an A9. But that boundary has to pop up someplace -- it's just unfortunate that it's in the middle of octave 10.)

ATTRIBUTE METHODS
-----------------

The object attributes discussed above are readable and writeable with object methods. For each attribute there is a read/write method, and a read-only method that returns a reference to the attribute's value:

    Attribute ||  R/W-Method ||   RO-R-Method
    ----------++-------------++--------------------------------------
    Score     ||  Score      ||   Score_r      (returns a listref)
    Notes     ||  Notes      ||   Notes_r      (returns a listref)
    Time      ||  Time       ||   Time_r       (returns a scalar ref)
    Duration  ||  Duration   ||   Duration_r   (returns a scalar ref)
    Channel   ||  Channel    ||   Channel_r    (returns a scalar ref)
    Octave    ||  Octave     ||   Octave_r     (returns a scalar ref)
    Volume    ||  Volume     ||   Volume_r     (returns a scalar ref)
    Tempo     ||  Tempo      ||   Tempo_r      (returns a scalar ref)
    Cookies   ||  Cookies    ||   Cookies_r    (returns a hashref)

To read any of the above via a R/W-method, call with no parameters, e.g.:

    $notes = $obj.Notes;  # same as $obj.Notes()

The above is the read-attribute ("get") form.

To set the value, call with parameters:

    $obj.Notes(13,17,22);

The above is the write-attribute ("put") form. Incidentally, when used in write-attribute form, the return value is the same as the parameters, except for Score or Cookies. (In those two cases, I've suppressed it for efficiency's sake.)

Alternately (and much more efficiently), you can use the read-only reference methods to read or alter the above values;

    $notes = $obj.Notes;
    # to read:
    @old_notes = @$notes_r;
    # to write:
    @$notes_r = (13,17,22);

And this is the only way to set Cookies, Notes, or Score to a (), like so:

    $notes_r = $obj->Notes_r;
    @$notes_r = ();

Since this:

    $obj->Notes;

is just the read-format call, remember?

Like all methods in this class, all the above-named attribute methods double as procedures that act on the default object -- in other words, you can say:

    Volume 10;              # same as:  $Volume = 10;
    @score_copy = Score;    # same as:  @score_copy = @Score
    Score @new_score;       # same as:  @Score = @new_score;
    $score_ref = Score_r;   # same as:  $score_ref = \@Score
    Volume(Volume + 10)     # same as:  $Volume += 10

But, stylistically, I suggest not using these procedures -- just directly access the variables instead.

MIDI EVENT ROUTINES
-------------------

These routines, below, add a MIDI event to the Score, with a start-time of Time. Example:

    text_event "And now the bongos!";  # procedure use

    $obj->text_event "And now the bongos!";  # method use

These are named after the MIDI events they add to the score, so see [MIDI::Event](MIDI::Event) for an explanation of what the data types (like "velocity" or "pitch_wheel") mean. I've reordered this list so that what I guess are the most important ones are toward the top:

  * patch_change *channel*, *patch*;

  * key_after_touch *channel*, *note*, *velocity*;

  * channel_after_touch *channel*, *velocity*;

  * control_change *channel*, *controller(0-127)*, *value(0-127)*;

  * pitch_wheel_change *channel*, *pitch_wheel*;

  * set_tempo *tempo*; (See the section on tempo, below.)

  * smpte_offset *hr*, *mn*, *se*, *fr*, *ff*;

  * time_signature *nn*, *dd*, *cc*, *bb*;

  * key_signature *sf*, *mi*;

  * text_event *text*;

  * copyright_text_event *text*;

  * track_name *text*;

  * instrument_name *text*;

  * lyric *text*;

  * set_sequence_number *sequence*;

  * marker *text*;

  * cue_point *text*;

  * sequencer_specific *raw*;

  * sysex_f0 *raw*;

  * sysex_f7 *raw*;

And here's the ones I'll be surprised if anyone ever uses:

  * text_event_08 *text*;

  * text_event_09 *text*;

  * text_event_0a *text*;

  * text_event_0b *text*;

  * text_event_0c *text*;

  * text_event_0d *text*;

  * text_event_0e *text*;

  * text_event_0f *text*;

  * raw_meta_event *command*(0-255), *raw*;

  * song_position *starttime*;

  * song_select *song_number*;

  * tune_request *starttime*;

  * raw_data *raw*;

  * end_track *starttime*;

  * note *duration*, *channel*, *note*, *velocity*;

About Tempo
-----------

The chart above shows that tempo is set with a method/procedure that takes the form set_tempo(*tempo*), and [MIDI::Event](MIDI::Event) says that *tempo* is "microseconds, a value 0 to 16,777,215 (0x00FFFFFF)". But at the same time, you see that there's an attribute of the MIDI::Simple object called "Tempo", which I've warned you to leave at the default value of 96. So you may wonder what the deal is.

The "Tempo" attribute (AKA "Divisions") is an integer that specifies the number of "ticks" per MIDI quarter note. Ticks is just the notional timing unit all MIDI events are expressed in terms of. Calling it "Tempo" is misleading, really; what you want to change to make your music go faster or slower isn't that parameter, but instead the mapping of ticks to actual time -- and that is what `set_tempo` does. Its one parameter is the number of microseconds each quarter note should get.

Suppose you wanted a tempo of 120 quarter notes per minute. In terms of microseconds per quarter note:

    set_tempo 500_000; # you can use _ like a thousands-separator comma

In other words, this says to make each quarter note take up 500,000 microseconds, namely .5 seconds. And there's 120 of those half-seconds to the minute; so, 120 quarter notes to the minute.

If you see a "[quarter note symbol] = 160" in a piece of sheet music, and you want to figure out what number you need for the `set_tempo`, do:

    60_000_000 / 160  ... and you get:  375_000

Therefore, you should call:

    set_tempo 375_000;

So in other words, this general formula:

    set_tempo int(60_000_000 / $quarter_notes_per_minute);

should do you fine.

As to the Tempo/Duration parameter, leave it alone and just assume that 96 ticks-per-quarter-note is a universal constant, and you'll be happy.

(You may wonder: Why 96? As far as I've worked out, all purmutations of the normal note lengths (whole, half, quarter, eighth, sixteenth, and even thirty-second notes) and tripletting, dotting, or double-dotting, times 96, all produce integers. For example, if a quarter note is 96 ticks, then a double-dotted thirty-second note is 21 ticks (i.e., 1.75 * 1/8 * 96). But that'd be a messy 10.5 if there were only 48 ticks to a quarter note. Now, if you wanted a quintuplet anywhere, you'd be out of luck, since 96 isn't a factor of five. It's actually 3 * (2 ** 5), i.e., three times two to the fifth. If you really need quintuplets, then you have my very special permission to mess with the Tempo attribute -- I suggest multiples of 96, e.g., 5 * 96.)

(You may also have read in [MIDI::Filespec](MIDI::Filespec) that `time_signature` allows you to define an arbitrary mapping of your concept of quarter note, to MIDI's concept of quarter note. For your sanity and mine, leave them the same, at a 1:1 mapping -- i.e., with an '8' for `time_signature`'s last parameter, for "eight notated 32nd-notes per MIDI quarter note". And this is relevant only if you're calling `time_signature` anyway, which is not necessarily a given.)

########################################################################### ###########################################################################

MORE ROUTINES
-------------

  * $opus = write_score *filespec*

  * $opus = $obj->write_score(*filespec*)

Writes the score to the filespec (e.g, "../../samples/funk2.midi", or a variable containing that value), with the score's Ticks as its tick parameters (AKA "divisions"). Among other things, this function calls the function `make_opus`, below, and if you capture the output of write_score, you'll get the opus created, if you want it for anything. (Also: you can also use a filehandle-reference instead of the filespec: `write_score *STDOUT{IO}`.)

  * read_score *filespec*

  * $obj = MIDI::Simple->read_score('foo.mid'))

In the first case (a procedure call), does `new_score` to erase and initialize the object attributes (Score, Octave, etc), then reads from the file named. The file named has to be a MIDI file with exactly one eventful track, or Perl dies. And in the second case, `read_score` acts as a constructor method, returning a new object read from the file.

Score, Ticks, and Time are all affected:

Score is the event form of all the MIDI events in the MIDI file. (Note: *Seriously* deformed MIDI files may confuse the routine that turns MIDI events into a Score.)

Ticks is set from the ticks setting (AKA "divisions") of the file.

Time is set to the end time of the latest event in the file.

(Also: you can also use a filehandle-reference instead of the filespec: `read_score *STDIN{IO}`.)

If ever you have to make a Score out of a single track from a *multitrack* file, read the file into an $opus, and then consider something like:

    new_score;
    $opus = MIDI::Opus->new({ 'from_file' => "foo2.mid" });
    $track = ($opus->tracks)[2]; # get the third track

    ($score_r, $end_time) =
      MIDI::Score::events_r_to_score_r($track->events_r);

    $Ticks = $opus->ticks;
    @Score =  @$score_r;
    $Time = $end_time;

  * synch( LIST of coderefs )

  * $obj->synch( LIST of coderefs )

LIST is a list of coderefs (whether as a series of anonymous subs, or as a list of items like `(\&foo, \&bar, \&baz)`, or a mixture of both) that `synch` calls in order to add to the given object -- which in the first form is the package's default object, and which in the second case is `$obj`. What `synch` does is:

* remember the initial value of Time, before calling any of the routines;

* for each routine given, reset Time to what it was initially, call the routine, and then note what the value of Time is, after each call;

* then, after having called all of the routines, set Time to whatever was the greatest (equals latest) value of Time that resulted from any of the calls to the routines.

The coderefs are all called with one argument in `@_` -- the object they are supposed to affect. All these routines should/must therefore use method calls instead of procedure calls. Here's an example usage of synch:

    my $measure = 0;
    my @phrases =(
      [ Cs, F,  Ds, Gs_d1 ], [Cs,    Ds, F, Cs],
      [ F,  Cs, Ds, Gs_d1 ], [Gs_d1, Ds, F, Cs]
    );

    for(1 .. 20) { synch(\&count, \&lalala); }

    sub count {
      my $it = $_[0];
      $it->r(wn); # whole rest
      # not just "r(wn)" -- we want a method, not a procedure!
      ++$measure;
    }

    sub lalala {
      my $it = $_[0];
      $it->noop(c1,mf,o3,qn); # setup
      my $phrase_number = ($measure + -1) % 4;
      my @phrase = @{$phrases[$phrase_number]};
      foreach my $note (@phrase) { $it->n($note); }
    }

  * $opus = make_opus or $opus = $obj->make_opus

Makes an opus (a MIDI::Opus object) out of Score, setting the opus's tick parameter (AKA "divisions") to $ticks. The opus is, incidentally, format 0, with one track.

  * dump_score or $obj->dump_score

Dumps Score's contents, via `print` (so you can `select()` an output handle for it). Currently this is in this somewhat uninspiring format:

    ['note', 0, 96, 1, 25, 96],
    ['note', 96, 96, 1, 29, 96],

as it is (currently) just a call to &MIDI::Score::dump_score; but in the future I may (should?) make it output in `n`/`r` notation. In the meantime I assume you'll use this, if at all, only for debugging purposes.

FUNCTIONS
---------

These are subroutines that aren't methods and don't affect anything (i.e., don't have "side effects") -- they just take input and/or give output.

  * interval LISTREF, LIST

This takes a reference to a list of integers, and a list of note-pitch specifications (whether relative or absolute), and returns a list consisting of the given note specifications transposed by that many half-steps. E.g.,

    @majors = interval [0,4,7], C, Bflat3;

which returns the list `(C,E,G,Bf3,D4,F4)`.

Items in LIST which aren't note specifications are passed thru unaltered.

  * note_map { BLOCK } LIST

This is pretty much based on (or at least inspired by) the normal Perl `map` function, altho the syntax is a bit more restrictive (i.e., `map` can take the form `map {BLOCK} LIST` or `map(EXPR,LIST)` -- the latter won't work with `note_map`).

`note_map {BLOCK} (LIST)` evaluates the BLOCK for each element of LIST (locally setting $_ to each element's note-number value) and returns the list value composed of the results of each such evaluation. Evaluates BLOCK in a list context, so each element of LIST may produce zero, one, or more elements in the returned value. Moreover, besides setting $_, `note_map` feeds BLOCK (which it sees as an anonymous subroutine) three parameters, which BLOCK can access in @_ :

    $_[0]  :  Same as $_.  I.e., The current note-specification,
              as a note number.
              This is the result of having fed the original note spec
              (which you can see in $_[2]) to is_note_spec.

    $_[1]  :  The absoluteness flag for this note, from the
              above-mentioned call to is_note_spec.
              0 = it was relative (like 'C')
              1 = it was absolute (whether as 'C4' or 'n41' or '41')

    $_[2] : the actual note specification from LIST, if you want
              to access it for any reason.

Incidentally, any items in LIST that aren't a note specification are passed thru unchanged -- BLOCK isn't called on it.

So, in other words, what `note_map` does, for each item in LIST, is:

* It calls `is_note_spec` on it to test whether it's a note specification at all. If it isn't, just passes it thru. If it is, then `note_map` stores the note number and the absoluteness flag that `is_note_spec` returned, and...

* It calls BLOCK, providing the note number in $_ and $_[0], the absoluteness flag in $_[1], and the original note specification in $_[2]. Stores the return value of calling BLOCK (in a list context of course) -- this should be a list of note numbers.

* For each element of the return value (which is actually free to be an empty list), converts it from a note number to whatever **kind** of specification the original note value was. So, for each element, if the original was relative, `note_map` interprets the return value as a relative note number, and calls `number_to_relative` on it; if it was absolute, `note_map` will try to restore it to the correspondingly formatted absolute specification type.

An example is, I hope, helpful:

This:

    note_map { $_ - 3, $_ + 2 }  qw(Cs3 n42 50 Bf)

returns this:

    ('Bf2', 'Ef3', 'n39', 'n44', '47', '52', 'G', 'C_u1')

Or, to line things up:

    Cs3       n42       50      Bf
     |         |        |       |

    /-----\   /-----\   /---\   /----\
    Bf2 Ef3   n39 n44   47 52   G C_u1

Now, of course, this is the same as what this:

    interval [-3, 2], qw(Cs3 n42 50 Bf)

returns. This is fitting, as `interval`, internally, is basically a simplified version of `note_map`. But `interval` only lets you do unconditional transposition, whereas `note_map` lets you do anything at all. For example:

    @note_specs = note_map { $funky_lookup_table{$_} }
                           C, Gf;

or

    @note_specs = note_map { $_ + int(rand(2)) }
                           @stuff;

`note_map`, like `map`, can seem confusing to beginning programmers (and many intermediate ones, too), but it is quite powerful.

  * number_to_absolute NUMBER

This returns the absolute note specification (in the form "C5") that the MIDI note number in NUMBER represents.

This is like looking up the note number in %MIDI::number2note -- not exactly the same, but effectively the same. See the source for more details.

  * the function number_to_relative NUMBER

This returns the relative note specification that NUMBER represents. The idea of a numerical representation for `relative` note specifications was necessitated by `interval` and `note_map` -- since without this, you couldn't meaningfully say, for example, interval [0,2] 'F'. This should illustrate the concept:

    number_to_relative(-10)   =>   "D_d1"
    number_to_relative( -3)   =>   "A_d1"
    number_to_relative(  0)   =>   "C"
    number_to_relative(  5)   =>   "F"
    number_to_relative( 10)   =>   "Bf"
    number_to_relative( 19)   =>   "G_u1"
    number_to_relative( 40)   =>   "E_u3"

  * is_note_spec STRING

If STRING is a note specification, `is_note_spec(STRING)` returns a list of two elements: first, a flag of whether the note specification is absolute (flag value 1) or relative (flag value 0); and second, a note number corresponding to that note specification. If STRING is not a note specification, `is_note_spec(STRING)` returns an empty list (which in a boolean context is FALSE).

Implementationally, `is_note_spec` just uses `is_absolute_note_spec` and `is_relative_note_spec`.

Example usage:

    @note_details = is_note_spec($thing);
    if(@note_details) {
      ($absoluteness_flag, $note_num) = @note_details;
      ...stuff...
    } else {
      push @other_stuff, $thing;  # or whatever
    }

  * is_relative_note_spec STRING

If STRING is an relative note specification, returns the note number for that specification as a one-element list (which in a boolean context is TRUE). Returns empty-list (which in a boolean context is FALSE) if STRING is NOT a relative note specification.

To just get the boolean value:

    print "Snorf!\n" unless is_relative_note_spec($note);

But to actually get the note value:

    ($note_number) = is_relative_note_spec($note);

Or consider this:

    @is_rel = is_relative_note_spec($note);
    if(@is_rel) {
      $note_number = $is_rel[0];
    } else {
      print "Snorf!\n";
    }

(Author's note, two years later: all this business of returning lists of various sizes, with this and other functions in here, is basically a workaround for the fact that there's not really any such thing as a boolean context in Perl -- at least, not as far as user-defined functions can see. I now think I should have done this with just returning a single scalar value: a number (which could be 0!) if the input is a number, and undef/emptylist (`return;`) if not -- then, the user could test:

    # Hypothetical --
    # This fuction doesn't actually work this way:
    if(defined(my $note_val = is_relative_note_spec($string))) {
       ...do things with $note_val...
    } else {
       print "Hey, that's no note!\n";
    }

However, I don't anticipate users actually using these messy functions often at all -- I basically wrote these for internal use by MIDI::Simple, then I documented them on the off chance they *might* be of use to anyone else.)

  * is_absolute_note_spec STRING

Just like `is_relative_note_spec`, but for absolute note specifications instead of relative ones.

  * Self() or $obj->Self();

Presumably the second syntax is useless -- it just returns $obj. But the first syntax returns the current package's default object.

Suppose you write a routine, `funkify`, that does something-or-other to a given MIDI::Simple object. You could write it so that acts on the current package's default object, which is fine -- but, among other things, that means you can't call `funkify` from a sub you have `synch` call, since such routines should/must use only method calls. So let's say that, instead, you write `funkify` so that the first argument to it is the object to act on. If the MIDI::Simple object you want it to act on is it `$sonata`, you just say

    funkify($sonata)

However, if you want it to act on the current package's default MIDI::Simple object, what to say? Simply,

    $package_opus = Self;
    funkify($package_opus);

COPYRIGHT 
==========

Copyright (c) 1998-2005 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

AUTHOR
======

Sean M. Burke `sburke@cpan.org`

