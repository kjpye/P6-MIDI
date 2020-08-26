NAME
====

MIDI::Event - MIDI events

SYNOPSIS
========

    # Dump a MIDI file's text events
    die "No filename" unless @ARGV;
    use MIDI;  # which "use"s MIDI::Event;
    MIDI::Opus.new( {
       "from_file"                => $ARGV[0],
       "exclusive_event_callback" => sub{print "$_[2]\n"},
       "include"                  => \@MIDI::Event::Text_events
     } ); # These options percolate down to MIDI::Event::decode
    exit;

DESCRIPTION
===========

Functions and lists to do with MIDI events and MIDI event structures.

An event is a list, like:

    ( 'note_on', 141, 4, 50, 64 )

where the first element is the event name, the second is the delta-time, and the remainder are further parameters, per the event-format specifications below.

An *event structure* is a list of references to such events -- a "LoL". If you don't know how to deal with LoLs, you *must* read [perllol](perllol).

GOODIES
=======

For your use in code (as in the code in the Synopsis), this module provides a few lists:

over
====



  * @MIDI_events

a list of all "MIDI events" AKA voice events -- e.g., 'note_on'

  * @Text_events

a list of all text meta-events -- e.g., 'track_name'

  * @Nontext_meta_events

all other meta-events (plus 'raw_data' and F-series events like 'tune_request').

  * @Meta-events

the combination of Text_events and Nontext_meta_events.

  * @All-events

the combination of all the above lists.

back
====



FUNCTIONS
=========

This module provides three functions of interest, which all act upon event structures. As an end user, you probably don't need to use any of these directly, but note that options you specify for MIDI::Opus->new with a from_file or from_handle options will percolate down to these functions; so you should understand the options for the first two of the below functions. (The casual user should merely skim this section.)

over
====



  * MIDI::Event::decode( \$data, { ...options... } )

This takes a Buf containing binary MIDI data and decodes it into a new event structure (a LoL), a *reference* to which is returned. Options are:

over
====

16

  * 'include' => LISTREF

*If specified*, listref is interpreted as a reference to a list of event names (e.g., 'cue_point' or 'note_off') such that only these events will be parsed from the binary data provided. Events whose names are NOT in this list will be ignored -- i.e., they won't end up in the event structure, and they won't be each passed to any callbacks you may have specified.

  * 'exclude' => LISTREF

*If specified*, listref is interpreted as a reference to a list of event names (e.g., 'cue_point' or 'note_off') that will NOT be parsed from the binary stream; they'll be ignored -- i.e., they won't end up in the event structure, and they won't be passed to any callbacks you may have specified. Don't specify both an include and an exclude list. And if you specify *neither*, all events will be decoded -- this is what you probably want most of the time. I've created this include/exclude functionality mainly so you can scan a file rather efficiently for just a few specific event types, e.g., just text events, or just sysexes.

  * 'no_eot_magic' => 0 or 1

See the description of `'end_track'`, in "EVENTS", below.

  * 'event_callback' => CODEREF

If defined, the code referred to (whether as `\&wanted` or as `sub { BLOCK }`) is called on every event after it's been parsed into an event list (and any EOT magic performed), but before it's added to the event structure. So if you want to alter the event stream on the way to the event structure (which counts as deep voodoo), define 'event_callback' and have it modify its `@_`.

  * 'exclusive_event_callback' => CODEREF

Just like 'event_callback'; but if you specify this, the callback is called *instead* of adding the events to the event structure. (So the event structure returned by decode() at the end will always be empty.) Good for cases like the text dumper in the Synopsis, above.

back
====



  * MIDI::Event::encode( \@events, {...options...})

This takes a *reference* to an event structure (a LoL) and encodes it as binary data, which it returns a *reference* to. Options:

over
====

16

  * 'unknown_callback' => CODEREF

If this is specified, it's interpreted as a reference to a subroutine to be called when an unknown event name (say, 'macro_10' or something), is seen by encode(). The function is fed all of the event (its name, delta-time, and whatever parameters); the return value of this function is added to the encoded data stream -- so if you don't want to add anything, be sure to return ''.

If no 'unknown_callback' is specified, encode() will `warn` (well, `carp`) of the unknown event. To merely block that, just set 'unknown_callback' to `sub{return('')}`

  * 'no_eot_magic' => 0 or 1

Determines whether a track-final 0-length text event is encoded as a end-track event -- since a track-final 0-length text event probably started life as an end-track event read in by decode(), above.

  * 'never_add_eot' => 0 or 1

If 1, `encode()` never ever *adds* an end-track (EOT) event to the encoded data generated unless it's *explicitly* there as an 'end_track' in the given event structure. You probably don't ever need this unless you're encoding for *straight* writing to a MIDI port, instead of to a file.

  * 'no_running_status' => 0 or 1

If 1, disables MIDI's "running status" compression. Probably never necessary unless you need to feed your MIDI data to a strange old sequencer that doesn't understand running status.

back
====



Note: If you're encoding just a single event at a time or less than a whole trackful in any case, then you probably want something like:

    $data_r = MIDI::Event::encode(
      [
        MIDI::Event::Note-on.new(time => 141,
                                 channel => 4,
                                 note-number => 50,
                                 velocity => 64)
      ],
      'never_add_eot' => 1 );

which just encodes that one event *as* an event structure of one event -- i.e., an LoL that's just a list of one list.

But note that running status will not always apply when you're encoding less than a whole trackful at a time, since running status works only within a LoL encoded all at once. This'll result in non-optimally compressed, but still effective, encoding.

  * MIDI::Event::copy_structure()

This takes an event structure, and returns a copy of it. If you're thinking about using this, you probably should want to use the more straightforward

    $track2 = $track.copy

instead. But it's here if you happen to need it.

back
====



EVENTS AND THEIR DATA TYPES
===========================

DATA TYPES
----------

Events use these data types:

over
====



  * channel = a value 0 to 15

  * note = a value 0 to 127

  * dtime = a value 0 to 268,435,455 (0x0FFFFFFF)

  * velocity = a value 0 to 127

  * channel = a value 0 to 15

  * patch = a value 0 to 127

  * sequence = a value 0 to 65,535 (0xFFFF)

  * text = a string of 0 or more bytes of of ASCII text

  * raw = a string of 0 or more bytes of binary data

  * pitch_wheel = a value -8192 to 8191 (0x1FFF)

  * song_pos = a value 0 to 16,383 (0x3FFF)

  * song_number = a value 0 to 127

  * tempo = microseconds, a value 0 to 16,777,215 (0x00FFFFFF)

back
====



For data types not defined above, (e.g., *sf* and *mi* for `'key_signature'`), consult [MIDI::Filespec](MIDI::Filespec) and/or the source for `MIDI::Event.pm`. And if you don't see it documented, it's probably because I don't understand it, so you'll have to consult a real MIDI reference.

EVENTS
------

And these are the events:

over
====



  * ('note_off', *dtime*, *channel*, *note*, *velocity*)

  * ('note_on', *dtime*, *channel*, *note*, *velocity*)

  * ('key_after_touch', *dtime*, *channel*, *note*, *velocity*)

  * ('control_change', *dtime*, *channel*, *controller(0-127)*, *value(0-127)*)

  * ('patch_change', *dtime*, *channel*, *patch*)

  * ('channel_after_touch', *dtime*, *channel*, *velocity*)

  * ('pitch_wheel_change', *dtime*, *channel*, *pitch_wheel*)

  * ('set_sequence_number', *dtime*, *sequence*)

  * ('text_event', *dtime*, *text*)

  * ('copyright_text_event', *dtime*, *text*)

  * ('track_name', *dtime*, *text*)

  * ('instrument_name', *dtime*, *text*)

  * ('lyric', *dtime*, *text*)

  * ('marker', *dtime*, *text*)

  * ('cue_point', *dtime*, *text*)

  * ('text_event_08', *dtime*, *text*)

  * ('text_event_09', *dtime*, *text*)

  * ('text_event_0a', *dtime*, *text*)

  * ('text_event_0b', *dtime*, *text*)

  * ('text_event_0c', *dtime*, *text*)

  * ('text_event_0d', *dtime*, *text*)

  * ('text_event_0e', *dtime*, *text*)

  * ('text_event_0f', *dtime*, *text*)

  * ('end_track', *dtime*)

  * ('set_tempo', *dtime*, *tempo*)

  * ('smpte_offset', *dtime*, *hr*, *mn*, *se*, *fr*, *ff*)

  * ('time_signature', *dtime*, *nn*, *dd*, *cc*, *bb*)

  * ('key_signature', *dtime*, *sf*, *mi*)

  * ('sequencer_specific', *dtime*, *raw*)

  * ('raw_meta_event', *dtime*, *command*(0-255), *raw*)

  * ('sysex_f0', *dtime*, *raw*)

  * ('sysex_f7', *dtime*, *raw*)

  * ('song_position', *dtime*)

  * ('song_select', *dtime*, *song_number*)

  * ('tune_request', *dtime*)

  * ('raw_data', *dtime*, *raw*)

