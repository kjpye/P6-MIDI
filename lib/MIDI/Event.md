NAME
====

MIDI::Event - MIDI events

SYNOPSIS
========

    # Dump a MIDI file's text events
    die "No filename" unless @ARGS;
    use MIDI;  # which "use"s MIDI::Event;
    MIDI::Opus.new(
       from-file                => @ARGS[0],
       exclusive-event-callback => sub{print "$_[2]\n"},
       include                  => @MIDI::Event::Text-events
    ); # These options percolate down to MIDI::Event::decode
    exit;

DESCRIPTION
===========

Functions and lists to do with MIDI events and MIDI event structures.

An event is object, with each event type ab object in a different class, like:

    MIDI::Event::Note-on(time => 141,
                         channel => 4,
                         note=number => 50,
                         velocity => 64)

An *event structure* is a list of such events -- an array of objects.

GOODIES
=======

For your use in code (as in the code in the Synopsis), this module provides a few lists:

  * @MIDI-events

a list of all "MIDI events" AKA voice events -- e.g., 'note-on'

  * @Text-events

a list of all text meta-events -- e.g., 'track-name'

  * @Nontext-meta-events

all other meta-events (plus 'raw-data' and F-series events like 'tune-request').

  * @Meta-events

the combination of Text-events and Nontext-meta-events.

  * @All-events

the combination of all the above lists.

FUNCTIONS
=========

This module provides three functions of interest, which all act upon event structures. As an end user, you probably don't need to use any of these directly, but note that options you specify for MIDI::Opus.new with a from_file or from_handle options will percolate down to these functions; so you should understand the options for the first two of the below functions. (The casual user should merely skim this section.)

  * MIDI::Event::decode( $data, ...options... )

This takes a Buf containing binary MIDI data and decodes it into a new event structure (a LoL), a *reference* to which is returned. Options are:

  * 'include' => LIST

*If specified*, list is interpreted as a list of event names (e.g., 'cue-point' or 'note-off') such that only these events will be parsed from the binary data provided. Events whose names are NOT in this list will be ignored -- i.e., they won't end up in the event structure, and they won't be each passed to any callbacks you may have specified.

  * 'exclude' => LIST

*If specified*, list is interpreted as a list of event names (e.g., 'cue-point' or 'note-off') that will NOT be parsed from the binary stream; they'll be ignored -- i.e., they won't end up in the event structure, and they won't be passed to any callbacks you may have specified. Don't specify both an include and an exclude list. And if you specify *neither*, all events will be decoded -- this is what you probably want most of the time. I've created this include/exclude functionality mainly so you can scan a file rather efficiently for just a few specific event types, e.g., just text events, or just sysexes.

  * 'no-eot-magic' => 0 or 1

See the description of `'end-track'`, in "EVENTS", below.

  * 'event-callback' => CODE

If defined, the code referred to (whether as `\&wanted` or as `sub { BLOCK }`) is called on every event after it's been parsed into an event list (and any EOT magic performed), but before it's added to the event structure. So if you want to alter the event stream on the way to the event structure (which counts as deep voodoo), define 'event-callback' and have it modify its `@_`.

  * 'exclusive-event-callback' => CODE

Just like 'event-callback'; but if you specify this, the callback is called *instead* of adding the events to the event structure. (So the event structure returned by decode() at the end will always be empty.) Good for cases like the text dumper in the Synopsis, above.

  * MIDI::Event::encode( @events, {...options...})

This takes an event structure (an array of Nidi::Event objects) and encodes it as binary data, which it returns in a Buf. Options:

  * 'unknown-callback' => CODE

If this is specified, it's a subroutine to be called when an unknown event name (say, 'macro-10' or something), is seen by encode(). The function is fed all of the event (its name, delta-time, and whatever parameters); the return value of this function is added to the encoded data stream -- so if you don't want to add anything, be sure to return ''.

If no 'unknown-callback' is specified, encode() will `warn` of the unknown event. To merely block that, just set 'unknown-callback' to `sub{return('')}`

  * 'no-eot-magic' => 0 or 1

Determines whether a track-final 0-length text event is encoded as an end-track event -- since a track-final 0-length text event probably started life as an end-track event read in by decode(), above.

  * 'never-add-eot' => 0 or 1

If 1, `encode()` never ever *adds* an end-track (EOT) event to the encoded data generated unless it's *explicitly* there as an 'end-track' in the given event structure. You probably don't ever need this unless you're encoding for *straight* writing to a MIDI port, instead of to a file.

  * 'no-running-status' => 0 or 1

If 1, disables MIDI's "running status" compression. Probably never necessary unless you need to feed your MIDI data to a strange old sequencer that doesn't understand running status.

Note: If you're encoding just a single event at a time or less than a whole trackful in any case, then you probably want something like:

    $data = MIDI::Event::encode(
      [
        MIDI::Event::Note-on.new(time => 141,
                                 channel => 4,
                                 note-number => 50,
                                 velocity => 64)
      ],
      'never-add-eot' => 1 );

which just encodes that one event *as* an event structure of one event -- i.e., an array thatconsistes of only one element.

But note that running status will not always apply when you're encoding less than a whole trackful at a time, since running status works only within a LoL encoded all at once. This'll result in non-optimally compressed, but still effective, encoding.

  * MIDI::Event::copy-structure()

This takes an event structure, and returns a copy of it. If you're thinking about using this, you probably should want to use the more straightforward

    $track2 = $track.copy

instead. But it's here if you happen to need it.

EVENTS AND THEIR DATA TYPES
===========================

DATA TYPES
----------

Events use these data types:

  * channel = a value 0 to 15

  * note = a value 0 to 127

  * dtime = a value 0 to 268,435,455 (0x0FFFFFFF)

  * velocity = a value 0 to 127

  * channel = a value 0 to 15

  * patch = a value 0 to 127

  * sequence = a value 0 to 65,535 (0xFFFF)

  * text = a string of 0 or more bytes of ASCII text

  * raw = a string of 0 or more bytes of binary data

  * pitch-wheel = a value -8192 to 8191 (0x1FFF)

  * song-pos = a value 0 to 16,383 (0x3FFF)

  * song-number = a value 0 to 127

  * tempo = microseconds, a value 0 to 16,777,215 (0x00FFFFFF)

For data types not defined above, (e.g., *sf* and *mi* for `'key-signature'`), consult [MIDI::Filespec](MIDI::Filespec) and/or the source for `MIDI::Event.pm`. And if you don't see it documented, it's probably because I don't understand it, so you'll have to consult a real MIDI reference.

EVENTS
------

And these are the events:

  * MIDI::Event::Note-off(*dtime*, *channel*, *note*, *velocity*)

  * MIDI::Event::Note-on(*dtime*, *channel*, *note*, *velocity*)

  * MIDILLEvent::Ley_after_touch(*dtime*, *channel*, *note*, *velocity*)

  * MIDI::Event::Control_change(*dtime*, *channel*, *controller(0-127)*, *value(0-127)*)

  * MIDI::Event::Patch-change(*dtime*, *channel*, *patch*)

  * MIDI::Event::Channel_after_touch(*dtime*, *channel*, *velocity*)

  * MIDI::Event::Pitch-wheel-change', *dtime*, *channel*, *pitch_wheel*)

  * MIDI::Event::Set-sequence-number(*dtime*, *sequence-number*)

  * MIDI::Event::Text-event(*dtime*, *text*)

  * MIDI::Event::Copyright-text-event(*dtime*, *text*)

  * MIDI::Event::Track-name(*dtime*, *text*)

  * MIDI::Event::Instrument_name(*dtime*, *text*)

  * MIDI::Event::Lyric(*dtime*, *text*)

  * MIDI::Event::Marker(*dtime*, *text*)

  * MIDI::Event::Cue-point(*dtime*, *text*)

  * MIDI::Event::Text-event_08(*dtime*, *text*)

  * MIDI::Event::Text-event_09(*dtime*, *text*)

  * MIDI::Event::Text-event_0a)*dtime*, *text*)

  * MIDI::Event::Text-event_0b(*dtime*, *text*)

  * MIDI::Event::Text-event_0c(*dtime*, *text*)

  * MIDI::Event::Text-event_0d(*dtime*, *text*)

  * MIDI::Event::Text-event_0e(*dtime*, *text*)

  * MIDILLEvent::Text-event_0f(*dtime*, *text*)

  * MIDI::Event::End-track(*dtime*)

  * MIDI::Event::Set-tempo(*dtime*, *tempo*)

  * MIDI::Event::Smpte_offset(*dtime*, *hr*, *mn*, *se*, *fr*, *ff*)

  * MIDI::Event::Time-signature(*dtime*, *nn*, *dd*, *cc*, *bb*)

  * MIDI::Event::Key-signature(*dtime*, *sf*, *mi*)

  * MIDI::Event::Sequencer-specific(*dtime*, *raw*)

  * MIDI:E:vent::Raw-meta-event(*dtime*, *command*(0-255), *raw*)

  * MIDI::Event::Sysex-f0**dtime*, *raw*)

  * MIDI::Event::Sysex-f7(*dtime*, *raw*)

  * MIDI::Event::Song-position(*dtime*)

  * MIDI::Event:Song-select(*dtime*, *song_number*)

  * MIDI::Event::Tune-request(*dtime*)

  * MIDI::Event::Raw-data(*dtime*, *raw*)

