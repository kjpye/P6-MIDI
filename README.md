[![Actions Status](https://github.com/kjpye/P6-MIDI/workflows/test/badge.svg)](https://github.com/kjpye/P6-MIDI/actions)

NAME
====

MIDI - read, compose, modify, and write MIDI files

SYNOPSIS
========

    use MIDI;

    my @events = (
      MIDI::Event::Text-event.new(time => 0,
                                  text => 'MORE COWBELL'),
      MIDI::Event::Set-tempo.new(time  => 0,
                                 tempo => 450_000), # 1qn = .45 seconds
    );

    for ^20 {
      @events.append:
        MIDI::Event::Note-on.new(time => 90,
                                 channel => 9,
                                 note-number => 56,
                                 velocity => 127
                                ),
        MIDI::Event::Note-off.new(time => 6,
                                  channel => 9,
                                  note-number => 56,
                                  velocity => 127
                                 ),
      ;
    }
    for (1..89).reverse -> $delay {
      @events.append:
        MIDI::Event::Note-on.new(time => 0,
                                 channel => 9,
                                 note-number => 56,
                                 velocity => 127
                                ),
        MIDI::Event::Note-off.new(time => $delay;
                                 channel => 9,
                                 note-number => 56,
                                 velocity => 127
                                ),
      ;
    }

    my $cowbell-track = MIDI::Track.new({ 'events' => @events });
    my $opus = MIDI::Opus.new(format => 0,
                              ticks => 96,
                              tracks => [ $cowbell-track ]
                             );
    $opus.write-to-file( 'cowbell.mid' );

DESCRIPTION
===========

This suite of modules provides routines for reading, composing, modifying, and writing MIDI files.

From FOLDOC (`http://foldoc.org/`):

**MIDI, Musical Instrument Digital Interface**

<music, hardware, protocol, file format> (MIDI /mi'-dee/, /mee'-dee/) A hardware specification and protocol used to communicate note and effect information between synthesisers, computers, music keyboards, controllers and other electronic music devices. [...]

The basic unit of information is a "note on/off" event which includes a note number (pitch) and key velocity (loudness). There are many other message types for events such as pitch bend, patch changes and synthesizer-specific events for loading new patches etc.

There is a file format for expressing MIDI data which is like a dump of data sent over a MIDI port. [...]

COMPONENTS
==========

The MIDI-Perl suite consists of these modules:

[MIDI](MIDI) (which you're looking at), [MIDI::Opus](MIDI::Opus), [MIDI::Track](MIDI::Track), [MIDI::Event](MIDI::Event), [MIDI::Score](MIDI::Score), and [MIDI::Simple](MIDI::Simple). All of these contain documentation in pod6 format. You should read all of these pods.

The order you want to read them in will depend on what you want to do with this suite of modules: if you are focused on manipulating the guts of existing MIDI files, read the pods in the order given above.

But if you aim to compose music with this suite, read this pod, then [MIDI::Score](MIDI::Score) and [MIDI::Simple](MIDI::Simple), and then skim the rest.

Note that [MIDI::Simple](MIDI::Simple) is not currently part of this distribution. If and when it is released it is likely to look significantly different from the Perl version.

INTRODUCTION
============

This suite of modules is basically object-oriented, with the exception of MIDI::Simple. MIDI opuses ("songs") are represented as objects belonging to the class MIDI::Opus. An opus contains tracks, which are objects belonging to the class MIDI::Track. A track will generally contain a list of events, where each event is an object containing a delta-time and other information depending on the type of event. In other words, opuses, tracks and events are objects.

Furthermore, for some purposes it's useful to analyze the totality of a track's events as a "score" -- where a score consists of notes where each event is a list consisting of a command, a time offset from the start of the track, and some number of parameters. This is the level of abstraction that MIDI::Score and MIDI::Simple deal with. (In this case, the attribute of an event which normally refers to a delta-time (from the previous event) now contains a time-offset from the beginning of the track.)

While there are some options that deal with the guts of MIDI encoding, you can (I hope) get along just fine with just a basic grasp of the MIDI "standard". I have tried, at various points in this documentation, to point out what things are not likely to be of use to the casual user.

GOODIES
=======

The bare module MIDI.pm doesn't *do* much more than `use` the necessary component submodules (i.e., all except MIDI::Simple).

[MIDI::Utilities](MIDI::Utilities) contains a few utilities which you might find useful:

**Note numbers <--> a representation of them**

  * `%note2number` and `%number2note`

`%number2note` correponds MIDI note numbers to a more comprehensible representation (e.g., 68 to 'Gs4', for G-sharp, octave 4); `%note2number` is the reverse. Have a look at the source to see the contents of the hash.

  * `%patch2number` and `%number2patch`

`%number2patch` relates General MIDI patch numbers (0 to 127) to English names (e.g., 79 to 'Ocarina'); `%patch2number` is the reverse. Have a look at the source to see the contents of the hash.

  * `%MIDI::notenum2percussion` and `%MIDI::percussion2notenum`

`%notenum2percussion` correponds General MIDI Percussion Keys to English names (e.g., 56 to 'Cowbell') -- but note that only numbers 35 to 81 (inclusive) are defined; `%percussion2notenum` is the reverse. Have a look at the source to see the contents of the hash.

BRIEF GLOSSARY
==============

This glossary defines just a few terms, just enough so you can (hopefully) make some sense of the documentation for this suite of modules. If you're going to do anything serious with these modules, however, you *should really* invest in a good book about the MIDI standard -- see the References.

**channel**: a logical channel to which control changes and patch changes apply, and in which MIDI (note-related) events occur.

**control**: one of the various numeric parameters associated with a given channel. Like S registers in Hayes-set modems, MIDI controls consist of a few well-known registers, and beyond that, it's patch-specific and/or sequencer-specific.

**delta-time**: the time (in ticks) that a sequencer should wait between playing the previous event and playing the current event.

**meta-event**: any of a mixed bag of events whose common trait is merely that they are similarly encoded. Most meta-events apply to all channels, unlike events, which mostly apply to just one channel.

**note**: my oversimplistic term for items in a score structure.

**opus**: the term I prefer for a piece of music, as represented in MIDI. Most specs use the term "song", but I think that this falsely implies that MIDI files represent vocal pieces.

**patch**: an electronic model of the sound of a given notional instrument.

**running status**: a form of modest compression where an event lacking an event command byte (a "status" byte) is to be interpreted as having the same event command as the preceding event -- which may, in turn, lack a status byte and may have to be interpreted as having the same event command as *its* previous event, and so on back.

**score**: a structure of notes like an event structure, but where notes are represented as single items, and where timing of items is absolute from the beginning of the track, instead of being represented in delta-times.

**song**: what some MIDI specs call a song, I call an opus.

**sequencer**: a device or program that interprets and acts on MIDI data. This prototypically refers to synthesizers or drum machines, but can also refer to more limited devices, such as mixers or even lighting control systems.

**status**: a synonym for "event".

**sysex**: a chunk of binary data encapsulated in the MIDI data stream, for whatever purpose.

**text event**: any of the several meta-events (one of which is actually called 'text_event') that conveys text. Most often used to just label tracks, note the instruments used for a track, or to provide metainformation about copyright, performer, and piece title and author.

**tick**: the timing unit in a MIDI opus.

**variable-length encoding**: an encoding method identical to what Perl calls the 'w' (BER, Basic Encoding Rules) pack/unpack format for integers.

SEE ALSO
========

[http://interglacial.com/~sburke/midi-perl/](http://interglacial.com/~sburke/midi-perl/) -- the MIDI-Perl homepage on the Interwebs!

[http://search.cpan.org/search?m=module&q=MIDI&n=100](http://search.cpan.org/search?m=module&q=MIDI&n=100) -- All the MIDI things in CPAN!

REFERENCES
==========

Christian Braut. *The Musician's Guide to Midi.* ISBN 0782112854. [This one is indispensible, but sadly out of print. Look at abebooks.com for it maybe --SMB]

Langston, Peter S. 1998. "Little Music Languages", p.587-656 in: Salus, Peter H,. editor in chief, /Handbook of Programming Languages/, vol. 3. MacMillan Technical, 1998. [The volume it's in is probably not worth the money, but see if you can at least glance at this article anyway. It's not often you see 70 pages written on music languages. --SMB]

COPYRIGHT 
==========

Copyright (c) 1998-2005 Sean M. Burke. All rights reserved.

Copyright (c) 2020 Kevin J. Pye. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl or Raku itself.

AUTHORS
=======

Sean M. Burke `sburke@cpan.org` (Perl version until 2010)

Darrell Conklin `conklin@cpan.org` (Perl version from 2010)

Kevin Pye `kjpye@cpan.org` (Raku version)

