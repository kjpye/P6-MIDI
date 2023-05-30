use v6.d;

unit class MIDI::Track;

my $Debug = 1;
my $VERSION = '0.83';

use MIDI::Event;
use MIDI::Utility;

has @.events is rw;
has $.type = 'MTrk'.encode;
has $.data is rw;

=begin pod
=head1 NAME

MIDI::Track -- functions and methods for MIDI tracks

=head1 SYNOPSIS

 use MIDI; # ...which "use"s MIDI::Track et al
 $taco-track = MIDI::Track.new;
 $taco-track.events(
     MIDI::Event::Text-event(time => 0, text => "I like tacos!");
     MIDI::Event::Note-on(time => 0, channel => 4, note-number => 50, velocity => 96);
     MIDI::Event::Note-off(time => 300, channel => 4, note-number => 50, velocity => 96);
 );
 $opus = MIDI::Opus->new(format => 0,  ticks => 240,  tracks => @($taco-track));
   ...etc...



MIDI::Track provides a constructor and methods for objects
representing a MIDI track.  It is part of the MIDI suite.

MIDI tracks have, currently, three attributes: a type, events, and
data.  Almost all tracks you'll ever deal with are of type "MTrk", and
so this is the type by default.  Events are what make up an MTrk
track.  If a track is not of type MTrk, or is an unparsed MTrk, then
it has (or better have!) data, which is just a bare Buf; The MIDI modules
do not interpret the data except for parsing it for events.

When an MTrk track is encoded, if there is data defined for it, that's
what's encoded (and "encoding data" means just passing it thru
untouched).  Note that this happens even if the data defined is empty
(but it won't happen if the data is undef).  However, if there's no
data defined for the MTrk track (as is the general case), then the
track's events are encoded, via a call to C<MIDI::Event::encode>.

(If neither events not data are defined, it acts as a zero-length
track.)

If a non-MTrk track is encoded, its data is encoded.  If there's no
data for it, it acts as a zero-length track.

In other words,
#1. events are meaningful only in an MTrk track,
#2. you probably don't want both data and events defined, and
#3. 99.999% of the time, just worry about events in MTrk tracks,
because that's all you ever want to deal with anyway.

=head1 CONSTRUCTOR AND METHODS

MIDI::Track provides...

=item the constructor MIDI::Track.new( ...options... )

This returns a new track object.  By default, the track is of type
MTrk, which is probably what you want.  The options are optional.
There are three recognized options:
C<data>, which sets the data of the new track to the string provided;
C<type>, which sets the type of the new track to the string provided;
C<events>, which sets the events of the new track to the contents of
the list provided.

=end pod

=begin pod
=item the method $new-track = $track.copy

This duplicates the contents of the given track, and returns
the duplicate.  If you are unclear on why you may need this function,
consider:

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

So you have your routines funk-it-up and turn-it-out, and they each
modify the track they're applied to in some way.  But the problem is that
the above code probably does not do what you want -- because the last
track-object of $funk and the last track-object of $samba are the
I<same object>.  An object, you may be surprised to learn, can be in
different opuses at the same time -- which is fine, except in cases like
the above code.  That's where you need to do copy the object.  Change
the above code to read:

          $samba.tracks.push: $bass-track.copy;

and what you want to happen, will.

Incidentally, this potential need to copy also occurs with opuses (and
in fact any reference-based data structure, although opuses and tracks
should cover almost all cases with MIDI stuff), which is why there's
$opus.copy, for copying entire opuses.

(If you happen to need to copy a single event, it's just $new = $old.)

=end pod

method copy {
  # Duplicate a given track.  Even dupes the events.
  # Call as $new-one = $track.copy

  my $new = .clone;
  $new.events = MIDI::Event::copy-structure( @!events );
  return $new;
}

###########################################################################
=begin pod
=item track.skyline(...options...)

skylines the entire track.  Modifies the track.  See MIDI::Score for
documentation on skyline

Note that this is not yet implemented in this version.
=end pod

method skyline(*%options) {

    my $score = MIDI::Score::events-to-score(@!events);
    my $new-score = MIDI::Score::skyline($score, |%options);
    my $events = MIDI::Score::score-to-events($new-score);
    self.events: $events;
}

###########################################################################
# These three modify all the possible attributes of a track

=begin pod
=item the method $track.events( @events )

events is a standard Raku access method for the @!events array in the object.

Thus $track.events is an arrayof events, and the list of events can be set with
    $track.events = @events;

=end pod

=begin pod
=item the method $track.type( 'MFoo' )

type is the standard Raku accessor for the track type. Note that the type is
B<not> a string, but a Buf. So by default $track.type will give 'MTrk'.encode,
and you can set the type attribute with
    $track.type = 'MHdr'.encode
for example.

You probably won't ever need to use this method, other than in
a context like:

          if( $track.type eq 'MTrk'.encode ) { # The usual case
            give-up-the-funk($track);
          } # Else just keep on walkin'!

Track types must be 4 bytes long; see L<MIDI::Filespec> for details
B<and must be a Buf>!

=end pod

=begin pod
=item the method $track.data( $kooky-binary-data )

The standard Raku accessor for the I<data> attribute.

Note that, like the I<type> attribute, this is not a string, but a Buf.
You probably won't ever need to use this method.  For your information,
$track.data = Nil is how to undefine the data for a track.

=end pod

###########################################################################

=begin pod
=item the method $track.new-event($event)

This adds the event $event to the end of the
event list for $track.  It's just sugar for:

          $track.events.push: $event;

If you want anything other than the equivalent of that, like some
kind of splice(), then do it yourself by directly modifying $track.events.

=end pod

method new-event($event) {
  @!events.push: $event;
}

###########################################################################

=begin pod
=item the method $track.raku( ...options... )

This generates a string containing the track's contents for your inspection.
The dump format is code that looks like Raku code that you'd use to recreate
that track.

=end pod

method raku(*%options) { # dump a track's contents

  my $indent = '    ';
  my $string = $indent ~ 'MIDI::Track->new(%(' ~ "\n" ~
	$indent ~ '  type => ' ~ dump-quote($!type) ~ ",\n";
  if $!data.defined {
      $string ~=  $indent ~ '  data => ' ~ dump-quote($!data) ~ ",\n";
  }
  $string ~= $indent ~ '  events => @(  # ' ~ +@!events ~ " events.\n";
  for @!events -> $event {
    $string ~=  $indent ~ $event.raku ~ ',';
  }
  $string ~= "$indent  }\n$indent)),\n$indent\n";
}

sub encode-events($events, *%options) { # encode an array of events, presumably for writing to a file
  # Calling format:
  #   $data = encode(@events, ...options... );
  # Returns an array of track data.

  # If you want to use this to encode a /single/ event,
  # you still have to do it as an array events
  # that just happens to have just one event.  I.e.,
  #   encode-events( @($event) ) or encode-events( @( MIDI::Event::Note-on.new(:time(100), :channel(5), :note-number(24), :velocity:(64)) ) )
  # If you're doing this, consider the never-add-eot track option, as in
  #   MIDI.put encode-events( @($event), never-add-eot => 1 );

  my $last-status = -1;
 
  my @events = $events.clone;

  my $unknown-callback = Nil;
  $unknown-callback = %options<unknown-callback>;

  unless %options<never-add-eot> {
    # One way or another, tack on an 'end-track'
    if +@events { # If there are any events...
      my $last = @events[ *-1 ];
      unless $last ~~ (MIDI::Event::End-track) { # ...And there's no end-track already
        if $last ~~ (MIDI::Event::Text-event) and +$last.text == 0 {
	  # 0-length text event at track-end.
	  if %options<no-eot-magic> {
	    # Exceptional case: don't mess with track-final
	    # 0-length text-events; just peg on an end-track
	    @events.push: MIDI::Event::End-track.new;
	  } else {
	    # NORMAL CASE: replace it with an end-track, leaving the DTime
            @events[*-1] = MIDI::Event::End-track.new(time => $last.time);
	  }
        } else {
          # last event was neither a 0-length text-event nor an end-track
	  @events.push: MIDI::Event::End-track.new();
        }
      }
    } else { # an eventless track!
      @events = @( MIDI::Event::End-track.new() );
    }
  }

  my $maybe-running-status = not %options<no-running-status>;
  $last-status = -1;

 [~] @events.map: { .encode($maybe-running-status, $last-status) };

}

###########################################################################

# CURRENTLY UNDOCUMENTED -- no end-user ever needs to call this as such
#
# Actually, the pod above refers to this.

method encode(*%options) { # encode a track object into track data (not a chunk)
  # Calling format:
  #  $data = $track.encode( .. options .. )
  # Returns a Buf containing the encoded track.
  #

  if $!data.defined and $!data {
    # It might be 0-length, by the way.  Might this be problematic?
    $!data;
    # warn "Encoding 0-length track data!" unless length $data;
  } else { # Data is not defined for this track.  Parse the events
    if $!type eq 'MTrk'.encode  or  +$!data == 0
        and @!events.defined
             # not just exists -- but DEFINED!
    {
      # note "Encoding ", @!events if $Debug;
      encode-events(@!events, |%options);
    } else {
      warn "Spork 8851\n" if $Debug;
      Buf.new(); # what else to do?
    }
  }
}

###########################################################################

# CURRENTLY UNDOCUMENTED -- no end-user ever needs to call this as such
#
our sub decode($type, $data, *%options) is export { # returns a new object, but doesn't accept constructor syntax
  # decode track data (not a chunk) into a new track object
  # Calling format:
  #  $new-track = 
  #   MIDI::Track::decode($type, $track-data, { .. options .. })
  # Returns a new track-object.
  # The options are, well, optional

  my $track = MIDI::Track.new( type => $type );
  
  if $type eq 'MTrk'.encode and not %options<no-parse> {
    $track.events = MIDI::Event::decode($data, |%options);
        # And that's where all the work happens
  } else {
    $track.data = $data;
  }
  $track;
}

###########################################################################

=begin pod

=head1 COPYRIGHT 

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

Copyright (C) 2020 Kevin J. Pye. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl or Raku themselves.

=head1 AUTHOR

Sean M. Burke C<sburke@cpan.org> (Perl version until 2010)

Darrell Conklin C<conklin@cpan.org> (Perl version from 2010)

Kevin Pye C<kjpye@cpan.org> (Raku version)
=end pod
