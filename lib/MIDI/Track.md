NAME
====

MIDI::Track -- functions and methods for MIDI tracks

SYNOPSIS
========

    use MIDI; # ...which "use"s MIDI::Track et al
    $taco-track = MIDI::Track->new;
    $taco-track->events(
     ['text-event', 0, "I like tacos!"],
     ['note-on',    0, 4, 50, 96 ],
     ['note-off', 300, 4, 50, 96 ],
    );
    $opus = MIDI::Opus->new(
     {  'format' => 0,  'ticks' => 240,  'tracks' => [ $taco-track ] }
    );
      ...etc...

MIDI::Track provides a constructor and methods for objects representing a MIDI track. It is part of the MIDI suite.

MIDI tracks have, currently, three attributes: a type, events, and data. Almost all tracks you'll ever deal with are of type "MTrk", and so this is the type by default. Events are what make up an MTrk track. If a track is not of type MTrk, or is an unparsed MTrk, then it has (or better have!) data.

When an MTrk track is encoded, if there is data defined for it, that's what's encoded (and "encoding data" means just passing it thru untouched). Note that this happens even if the data defined is "" (but it won't happen if the data is undef). However, if there's no data defined for the MTrk track (as is the general case), then the track's events are encoded, via a call to `MIDI::Event::encode`.

(If neither events not data are defined, it acts as a zero-length track.)

If a non-MTrk track is encoded, its data is encoded. If there's no data for it, it acts as a zero-length track.

In other words, 1) events are meaningful only in an MTrk track, 2) you probably don't want both data and events defined, and 3) 99.999% of the time, just worry about events in MTrk tracks, because that's all you ever want to deal with anyway.

CONSTRUCTOR AND METHODS
=======================

MIDI::Track provides...

###########################################################################

  * the constructor MIDI::Track->new({ ...options... })

This returns a new track object. By default, the track is of type MTrk, which is probably what you want. The options, which are optional, is an anonymous hash. There are four recognized options: `data`, which sets the data of the new track to the string provided; `type`, which sets the type of the new track to the string provided; `events`, which sets the events of the new track to the contents of the list-reference provided (i.e., a reference to a LoL -- see [perllol](perllol) for the skinny on LoLs); and `events-r`, which is an exact synonym of `events`.

  * the method $new-track = $track->copy

This duplicates the contents of the given track, and returns the duplicate. If you are unclear on why you may need this function, consider:

    $funk  = MIDI::Opus->new({'from-file' => 'funk1.mid'});
    $samba = MIDI::Opus->new({'from-file' => 'samba1.mid'});

    $bass-track = ( $funk->tracks )[-1]; # last track
    push(@{ $samba->tracks-r }, $bass-track );
         # make it the last track

    &funk-it-up(  ( $funk->tracks )[-1]  );
         # modifies the last track of $funk
    &turn-it-out(  ( $samba->tracks )[-1]  );
         # modifies the last track of $samba

    $funk->write-to-file('funk2.mid');
    $samba->write-to-file('samba2.mid');
    exit;

So you have your routines funk-it-up and turn-it-out, and they each modify the track they're applied to in some way. But the problem is that the above code probably does not do what you want -- because the last track-object of $funk and the last track-object of $samba are the *same object*. An object, you may be surprised to learn, can be in different opuses at the same time -- which is fine, except in cases like the above code. That's where you need to do copy the object. Change the above code to read:

    push(@{ $samba->tracks-r }, $bass-track->copy );

and what you want to happen, will.

Incidentally, this potential need to copy also occurs with opuses (and in fact any reference-based data structure, altho opuses and tracks should cover almost all cases with MIDI stuff), which is why there's $opus->copy, for copying entire opuses.

(If you happen to need to copy a single event, it's just $new = [@$old] ; and if you happen to need to copy an event structure (LoL) outside of a track for some reason, use MIDI::Event::copy-structure.)

  * track->skyline({ ...options... })

skylines the entire track. Modifies the track. See MIDI::Score for documentation on skyline

  * the method $track->events( @events )

Returns the list of events in the track, possibly after having set it to @events, if specified and not empty. (If you happen to want to set the list of events to an empty list, for whatever reason, you have to use "$track->events-r([])".)

In other words: $track->events(@events) is how to set the list of events (assuming @events is not empty), and @events = $track->events is how to read the list of events.

  * the method $track->events-r( $event-r )

Returns a reference to the list of events in the track, possibly after having set it to $events-r, if specified. Actually, "$events-r" can be any listref to a LoL, whether it comes from a scalar as in `$some-events-r`, or from something like `[@events]`, or just plain old `\@events`

Originally $track->events was the only way to deal with events, but I added $track->events-r to make possible 1) setting the list of events to (), for whatever that's worth, and 2) so you can directly manipulate the track's events, without having to *copy* the list of events (which might be tens of thousands of elements long) back and forth. This way, you can say:

    $events-r = $track->events-r();
    @some-stuff = splice(@$events-r, 4, 6);

But if you don't know how to deal with listrefs outside of LoLs, that's OK, just use $track->events.

  * the method $track->type( 'MFoo' )

Returns the type of $track, after having set it to 'MFoo', if provided. You probably won't ever need to use this method, other than in a context like:

    if( $track->type eq 'MTrk' ) { # The usual case
      give-up-the-funk($track);
    } # Else just keep on walkin'!

Track types must be 4 bytes long; see [MIDI::Filespec](MIDI::Filespec) for details.

  * the method $track->data( $kooky-binary-data )

Returns the data from $track, after having set it to $kooky-binary-data, if provided -- even if it's zero-length! You probably won't ever need to use this method. For your information, $track->data(undef) is how to undefine the data for a track.

  * the method $track->new-event('event', ...parameters... )

This adds the event ('event', ...parameters...) to the end of the event list for $track. It's just sugar for:

    push( @{$this-track->events-r}, [ 'event', ...params... ] )

If you want anything other than the equivalent of that, like some kinda splice(), then do it yourself with $track->events-r or $track->events.

  * the method $track.dump( ...options... )

This dumps the track's contents for your inspection. The dump format is code that looks like Perl code that you'd use to recreate that track. This routine outputs with just `print`, so you can use `select` to change where that'll go. I intended this to be just an internal routine for use only by the method MIDI::Opus::dump, but I figure it might be useful to you, if you need to dump the code for just a given track. Read the source if you really need to know how this works.

COPYRIGHT 
==========

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

modify it under the same terms as Perl itself.

AUTHOR
======

Sean M. Burke `sburke@cpan.org` (until 2010)

Darrell Conklin `conklin@cpan.org` (from 2010)

