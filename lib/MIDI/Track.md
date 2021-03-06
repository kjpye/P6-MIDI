NAME
====

MIDI::Track -- functions and methods for MIDI tracks

SYNOPSIS
========

    use MIDI; # ...which "use"s MIDI::Track et al
    $taco-track = MIDI::Track.new;
    $taco-track.events(
        MIDI::Event::Text-event(time => 0, text => "I like tacos!");
        MIDI::Event::Note-on(time => 0, channel => 4, note-number => 50, velocity => 96);
        MIDI::Event::Note-off(time => 300, channel => 4, note-number => 50, velocity => 96);
    );
    $opus = MIDI::Opus->new(format => 0,  ticks => 240,  tracks => @($taco-track));
      ...etc...

MIDI::Track provides a constructor and methods for objects representing a MIDI track. It is part of the MIDI suite.

MIDI tracks have, currently, three attributes: a type, events, and data. Almost all tracks you'll ever deal with are of type "MTrk", and so this is the type by default. Events are what make up an MTrk track. If a track is not of type MTrk, or is an unparsed MTrk, then it has (or better have!) data, which is just a bare Buf; The MIDI modules do not interpret the data except for parsing it for events.

When an MTrk track is encoded, if there is data defined for it, that's what's encoded (and "encoding data" means just passing it thru untouched). Note that this happens even if the data defined is empty (but it won't happen if the data is undef). However, if there's no data defined for the MTrk track (as is the general case), then the track's events are encoded, via a call to `MIDI::Event::encode`.

(If neither events not data are defined, it acts as a zero-length track.)

If a non-MTrk track is encoded, its data is encoded. If there's no data for it, it acts as a zero-length track.

In other words, #1. events are meaningful only in an MTrk track, #2. you probably don't want both data and events defined, and #3. 99.999% of the time, just worry about events in MTrk tracks, because that's all you ever want to deal with anyway.

CONSTRUCTOR AND METHODS
=======================

MIDI::Track provides...

  * the constructor MIDI::Track.new( ...options... )

This returns a new track object. By default, the track is of type MTrk, which is probably what you want. The options are optional. There are three recognized options: `data`, which sets the data of the new track to the string provided; `type`, which sets the type of the new track to the string provided; `events`, which sets the events of the new track to the contents of the list provided.

  * the method $new-track = $track.copy

This duplicates the contents of the given track, and returns the duplicate. If you are unclear on why you may need this function, consider:

    $funk  = MIDI::Opus.new(from-file => 'funk1.mid');
    $samba = MIDI::Opus.new(from-file => 'samba1.mid');

    $bass-track = ( $funk.tracks )[*-1]; # last track
    $samba.tracks.push: $bass-track;
         # make it the last track

    funk-it-up($funk.tracks[*-1]);
         # modifies the last track of $funk
    turn-it-out($samba.tracks[*-1);
         # modifies the last track of $samba

    $funk.write-to-file('funk2.mid');
    $samba.write-to-file('samba2.mid');
    exit;

So you have your routines funk-it-up and turn-it-out, and they each modify the track they're applied to in some way. But the problem is that the above code probably does not do what you want -- because the last track-object of $funk and the last track-object of $samba are the *same object*. An object, you may be surprised to learn, can be in different opuses at the same time -- which is fine, except in cases like the above code. That's where you need to do copy the object. Change the above code to read:

    $samba.tracks.push: $bass-track.copy;

and what you want to happen, will.

Incidentally, this potential need to copy also occurs with opuses (and in fact any reference-based data structure, although opuses and tracks should cover almost all cases with MIDI stuff), which is why there's $opus.copy, for copying entire opuses.

(If you happen to need to copy a single event, it's just $new = $old.)

  * track.skyline(...options...)

skylines the entire track. Modifies the track. See MIDI::Score for documentation on skyline

Note that this is not yet implemented in this version.

  * the method $track.events( @events )

events is a standard Raku access method for the @!events array in the object.

Thus $track.events is an arrayof events, and the list of events can be set with $track.events = @events;

  * the method $track.type( 'MFoo' )

type is the standard Raku accessor for the track type. Note that the type is **not** a string, but a Buf. So by default $track.type will give 'MTrk'.encode, and you can set the type attribute with $track.type = 'MHdr'.encode for example.

You probably won't ever need to use this method, other than in a context like:

    if( $track.type eq 'MTrk'.encode ) { # The usual case
      give-up-the-funk($track);
    } # Else just keep on walkin'!

Track types must be 4 bytes long; see [MIDI::Filespec](MIDI::Filespec) for details **and must be a Buf**!

  * the method $track.data( $kooky-binary-data )

The standard Raku accessor for the *data* attribute.

Note that, like the *type* attribute, this is not a string, but a Buf. You probably won't ever need to use this method. For your information, $track.data = Nil is how to undefine the data for a track.

  * the method $track.new-event($event)

This adds the event $event to the end of the event list for $track. It's just sugar for:

    $track.events.push: $event;

If you want anything other than the equivalent of that, like some kind of splice(), then do it yourself by directly modifying $track.events.

  * the method $track.raku( ...options... )

This generates a string containing the track's contents for your inspection. The dump format is code that looks like Raku code that you'd use to recreate that track.

COPYRIGHT 
==========

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

Copyright (C) 2020 Kevin J. Pye. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl or Raku themselves.

AUTHOR
======

Sean M. Burke `sburke@cpan.org` (Perl version until 2010)

Darrell Conklin `conklin@cpan.org` (Perl version from 2010)

Kevin Pye `kjpye@cpan.org` (Raku version)

