NAME
====

MIDI::Score - MIDI scores

SYNOPSIS
========

    # it's a long story; see below

DESCRIPTION
===========

This module provides functions to do with MIDI scores. It is used as the basis for all the functions in MIDI::Simple. (Incidentally, MIDI::Opus's draw() method also uses some of the functions in here.)

Whereas the events in a MIDI event structure are items whose timing is expressed in delta-times, the timing of items in a score is expressed as an absolute number of ticks from the track's start time. Moreover, pairs of 'note_on' and 'note_off' events in an event structure are abstracted into a single 'note' item in a score structure.

'note' takes the following form:

    ('note_on', I<start_time>, I<duration>, I<channel>, I<note>, I<velocity>)

The problem that score structures are meant to solve is that 1) people definitely don't think in delta-times -- they think in absolute times or in structures based on that (like 'time from start of measure'); 2) people think in notes, not note_on and note_off events.

So, given this event structure:

    ['text_event', 0, 'www.ely.anglican.org/parishes/camgsm/chimes.html'],
    ['text_event', 0, 'Lord through this hour/ be Thou our guide'],
    ['text_event', 0, 'so, by Thy power/ no foot shall slide'],
    ['patch_change', 0, 1, 8],
    ['note_on', 0, 1, 25, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 29, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 27, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 20, 96],
    ['note_off', 192, 0, 1, 0],
    ['note_on', 0, 1, 25, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 27, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 29, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 25, 96],
    ['note_off', 192, 0, 1, 0],
    ['note_on', 0, 1, 29, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 25, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 27, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 20, 96],
    ['note_off', 192, 0, 1, 0],
    ['note_on', 0, 1, 20, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 27, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 29, 96],
    ['note_off', 96, 0, 1, 0],
    ['note_on', 0, 1, 25, 96],
    ['note_off', 192, 0, 1, 0],

here is the corresponding score structure:

    ['text_event', 0, 'www.ely.anglican.org/parishes/camgsm/chimes.html'],
    ['text_event', 0, 'Lord through this hour/ be Thou our guide'],
    ['text_event', 0, 'so, by Thy power/ no foot shall slide'],
    ['patch_change', 0, 1, 8],
    ['note', 0, 96, 1, 25, 96],
    ['note', 96, 96, 1, 29, 96],
    ['note', 192, 96, 1, 27, 96],
    ['note', 288, 192, 1, 20, 96],
    ['note', 480, 96, 1, 25, 96],
    ['note', 576, 96, 1, 27, 96],
    ['note', 672, 96, 1, 29, 96],
    ['note', 768, 192, 1, 25, 96],
    ['note', 960, 96, 1, 29, 96],
    ['note', 1056, 96, 1, 25, 96],
    ['note', 1152, 96, 1, 27, 96],
    ['note', 1248, 192, 1, 20, 96],
    ['note', 1440, 96, 1, 20, 96],
    ['note', 1536, 96, 1, 27, 96],
    ['note', 1632, 96, 1, 29, 96],
    ['note', 1728, 192, 1, 25, 96]

Note also that scores aren't crucially ordered. So this:

    ['note', 768, 192, 1, 25, 96],
    ['note', 960, 96, 1, 29, 96],
    ['note', 1056, 96, 1, 25, 96],

means the same thing as:

    ['note', 960, 96, 1, 29, 96],
    ['note', 768, 192, 1, 25, 96],
    ['note', 1056, 96, 1, 25, 96],

The only exception to this is in the case of things like:

    ['patch_change', 200,     2, 15],
    ['note',         200, 96, 2, 25, 96],

where two (or more) score items happen *at the same time* and where one affects the meaning of the other.

WHAT CAN BE IN A SCORE
======================

Besides the new score structure item `note` (covered above), the possible contents of a score structure can be summarized thus: Whatever can appear in an event structure can appear in a score structure, save that its second parameter denotes not a delta-time in ticks, but instead denotes the absolute number of ticks from the start of the track.

To avoid the long periphrase "items in a score structure", I will occasionally refer to items in a score structure as "notes", whether or not they are actually `note` commands. This leaves "event" to unambiguously denote items in an event structure.

These, below, are all the items that can appear in a score. This is basically just a repetition of the table in [MIDI::Event](MIDI::Event), with starttime substituting for dtime -- so refer to [MIDI::Event](MIDI::Event) for an explanation of what the data types (like "velocity" or "pitch_wheel"). As far as order, the first items are generally the most important:

  * ('note', *starttime*, *duration*, *channel*, *note*, *velocity*)

  * ('key_after_touch', *starttime*, *channel*, *note*, *velocity*)

  * ('control_change', *starttime*, *channel*, *controller(0-127)*, *value(0-127)*)

  * ('patch_change', *starttime*, *channel*, *patch*)

  * ('channel_after_touch', *starttime*, *channel*, *velocity*)

  * ('pitch_wheel_change', *starttime*, *channel*, *pitch_wheel*)

  * ('set_sequence_number', *starttime*, *sequence*)

  * ('text_event', *starttime*, *text*)

  * ('copyright_text_event', *starttime*, *text*)

  * ('track_name', *starttime*, *text*)

  * ('instrument_name', *starttime*, *text*)

  * ('lyric', *starttime*, *text*)

  * ('marker', *starttime*, *text*)

  * ('cue_point', *starttime*, *text*)

  * ('text_event_08', *starttime*, *text*)

  * ('text_event_09', *starttime*, *text*)

  * ('text_event_0a', *starttime*, *text*)

  * ('text_event_0b', *starttime*, *text*)

  * ('text_event_0c', *starttime*, *text*)

  * ('text_event_0d', *starttime*, *text*)

  * ('text_event_0e', *starttime*, *text*)

  * ('text_event_0f', *starttime*, *text*)

  * ('end_track', *starttime*)

  * ('set_tempo', *starttime*, *tempo*)

  * ('smpte_offset', *starttime*, *hr*, *mn*, *se*, *fr*, *ff*)

  * ('time_signature', *starttime*, *nn*, *dd*, *cc*, *bb*)

  * ('key_signature', *starttime*, *sf*, *mi*)

  * ('sequencer_specific', *starttime*, *raw*)

  * ('raw_meta_event', *starttime*, *command*(0-255), *raw*)

  * ('sysex_f0', *starttime*, *raw*)

  * ('sysex_f7', *starttime*, *raw*)

  * ('song_position', *starttime*)

  * ('song_select', *starttime*, *song_number*)

  * ('tune_request', *starttime*)

  * ('raw_data', *starttime*, *raw*)

FUNCTIONS
=========

This module provides these functions:

  * $score2_r = MIDI::Score::copy_structure($score_r)

This takes a *reference* to a score structure, and returns a *reference* to a copy of it. Example usage:

    @new_score = @{ MIDI::Score::copy_structure( \@old_score ) };

  * $events = $score.events( )

This method returns an array containing the standard MIDI events corresponding to the notes in the scoer.

  * @events = $score.sort()

This method returns an sequence with the notes in the score sorted.

    @sorted-events = $old-score.sort();

  * $score_r = MIDI::Score::events_r_to_score_r( $events_r )

  * ($score_r, $ticks) = MIDI::Score::events_r_to_score_r( $events_r )

This takes a *reference* to an event structure, converts it to a score structure, which it returns a *reference* to. If called in list context, also returns a count of the number of ticks that structure takes to play (i.e., the end-time of the temporally last item).

  * MIDI::Score::dump-score( )

This dumps (via `print`) a text representation of the contents of the event structure you pass a reference to.

  * MIDI::Score::quantize( $score_r )

This takes a *reference* to a score structure, performs a grid quantize on all events, returning a new score reference with new quantized events. Two parameters to the method are: 'grid': the quantization grid, and 'durations': whether or not to also quantize event durations (default off).

When durations of note events are quantized, they can get 0 duration. These events are *not dropped* from the returned score, and it is the responsiblity of the caller to deal with them.

  * MIDI::Score::skyline( $score_r )

This takes a *reference* to a score structure, performs skyline (create a monophonic track by extracting the event with highest pitch at unique onset times) on the score, returning a new score reference. The parameters to the method is: 'clip': whether durations of events are preserved or possibly clipped and modified.

To explain this, consider the following (from Bach 2 part invention no.6 in E major):

    |------e------|-------ds--------|-------d------|...

|****--E-----|-------Fs-------|------Gs-----|...

Without duration cliping, the skyline is E, Fs, Gs...

With duration clipping, the skyline is E, e, ds, d..., where the duration of E is clipped to just the * portion above

COPYRIGHT 
==========

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

AUTHORS
=======

Sean M. Burke `sburke@cpan.org` (until 2010)

Darrell Conklin `conklin@cpan.org` (from 2010)

