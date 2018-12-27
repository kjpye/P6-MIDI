use v6.d;

unit class MIDI::Track;

my $Debug = 1;
my $VERSION = '0.83';

use MIDI::Event;

has @.events;
has $.type = Buf.new(0x4d, 0x54, 0x72, 0x6b);
has $.data is rw;

=begin pod
=head1 NAME

MIDI::Track -- functions and methods for MIDI tracks

=head1 SYNOPSIS

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



MIDI::Track provides a constructor and methods for objects
representing a MIDI track.  It is part of the MIDI suite.

MIDI tracks have, currently, three attributes: a type, events, and
data.  Almost all tracks you'll ever deal with are of type "MTrk", and
so this is the type by default.  Events are what make up an MTrk
track.  If a track is not of type MTrk, or is an unparsed MTrk, then
it has (or better have!) data.

When an MTrk track is encoded, if there is data defined for it, that's
what's encoded (and "encoding data" means just passing it thru
untouched).  Note that this happens even if the data defined is ""
(but it won't happen if the data is undef).  However, if there's no
data defined for the MTrk track (as is the general case), then the
track's events are encoded, via a call to C<MIDI::Event::encode>.

(If neither events not data are defined, it acts as a zero-length
track.)

If a non-MTrk track is encoded, its data is encoded.  If there's no
data for it, it acts as a zero-length track.

In other words, 1) events are meaningful only in an MTrk track, 2) you
probably don't want both data and events defined, and 3) 99.999% of
the time, just worry about events in MTrk tracks, because that's all
you ever want to deal with anyway.

=head1 CONSTRUCTOR AND METHODS

MIDI::Track provides...

=over

=cut

###########################################################################

=item the constructor MIDI::Track->new({ ...options... })

This returns a new track object.  By default, the track is of type
MTrk, which is probably what you want.  The options, which are
optional, is an anonymous hash.  There are four recognized options:
C<data>, which sets the data of the new track to the string provided;
C<type>, which sets the type of the new track to the string provided;
C<events>, which sets the events of the new track to the contents of
the list-reference provided (i.e., a reference to a LoL -- see
L<perllol> for the skinny on LoLs); and C<events-r>, which is an exact
synonym of C<events>.

=cut
=end pod

=begin pod
=item the method $new-track = $track->copy

This duplicates the contents of the given track, and returns
the duplicate.  If you are unclear on why you may need this function,
consider:

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

So you have your routines funk-it-up and turn-it-out, and they each
modify the track they're applied to in some way.  But the problem is that
the above code probably does not do what you want -- because the last
track-object of $funk and the last track-object of $samba are the
I<same object>.  An object, you may be surprised to learn, can be in
different opuses at the same time -- which is fine, except in cases like
the above code.  That's where you need to do copy the object.  Change
the above code to read:

          push(@{ $samba->tracks-r }, $bass-track->copy );

and what you want to happen, will.

Incidentally, this potential need to copy also occurs with opuses (and
in fact any reference-based data structure, altho opuses and tracks
should cover almost all cases with MIDI stuff), which is why there's
$opus->copy, for copying entire opuses.

(If you happen to need to copy a single event, it's just $new = [@$old] ;
and if you happen to need to copy an event structure (LoL) outside of a
track for some reason, use MIDI::Event::copy-structure.)

=cut
=end pod

method copy {
  # Duplicate a given track.  Even dupes the events.
  # Call as $new-one = $track.copy

  my $new = self.new;
  # a first crude dupe
  $new.type: $!type;
  $new.events = MIDI::Event::copy-structure( @!events );
  $new.data: $!data;
  return $new;
}

###########################################################################
=begin pod
=item track->skyline({ ...options... })

skylines the entire track.  Modifies the track.  See MIDI::Score for
documentation on skyline

=cut
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
=item the method $track->events( @events )

Returns the list of events in the track, possibly after having set it
to @events, if specified and not empty.  (If you happen to want to set
the list of events to an empty list, for whatever reason, you have to use
"$track->events-r([])".)

In other words: $track->events(@events) is how to set the list of events
(assuming @events is not empty), and @events = $track->events is how to
read the list of events.

=cut
=end pod

=begin pod
=item the method $track->events-r( $event-r )

Returns a reference to the list of events in the track, possibly after
having set it to $events-r, if specified.  Actually, "$events-r" can be
any listref to a LoL, whether it comes from a scalar as in
C<$some-events-r>, or from something like C<[@events]>, or just plain
old C<\@events>

Originally $track->events was the only way to deal with events, but I
added $track->events-r to make possible 1) setting the list of events
to (), for whatever that's worth, and 2) so you can directly
manipulate the track's events, without having to I<copy> the list of
events (which might be tens of thousands of elements long) back
and forth.  This way, you can say:

          $events-r = $track->events-r();
          @some-stuff = splice(@$events-r, 4, 6);

But if you don't know how to deal with listrefs outside of LoLs,
that's OK, just use $track->events.

=cut
=end pod

=begin pod
=item the method $track->type( 'MFoo' )

Returns the type of $track, after having set it to 'MFoo', if provided.
You probably won't ever need to use this method, other than in
a context like:

          if( $track->type eq 'MTrk' ) { # The usual case
            give-up-the-funk($track);
          } # Else just keep on walkin'!

Track types must be 4 bytes long; see L<MIDI::Filespec> for details.

=cut
=end pod

=begin pod
=item the method $track->data( $kooky-binary-data )

Returns the data from $track, after having set it to
$kooky-binary-data, if provided -- even if it's zero-length!  You
probably won't ever need to use this method.  For your information,
$track->data(undef) is how to undefine the data for a track.

=cut
=end pod

###########################################################################

=begin pod
=item the method $track->new-event('event', ...parameters... )

This adds the event ('event', ...parameters...) to the end of the
event list for $track.  It's just sugar for:

          push( @{$this-track->events-r}, [ 'event', ...params... ] )

If you want anything other than the equivalent of that, like some
kinda splice(), then do it yourself with $track->events-r or
$track->events.

=cut
=end pod

method new-event(*@args) {
  # Usage:
  #  $this-track.new-event('text-event', 0, 'Lesbia cum Prono');

  @!events.push: MIDI::Event.new( type => @args[0], delta-time => @args[1], args => @args[2-*] );
}

###########################################################################

=begin pod
=item the method $track.dump( ...options... )

This dumps the track's contents for your inspection.  The dump format
is code that looks like Perl code that you'd use to recreate that track.
This routine outputs with just C<print>, so you can use C<select> to
change where that'll go.  I intended this to be just an internal
routine for use only by the method MIDI::Opus::dump, but I figure it
might be useful to you, if you need to dump the code for just a given
track.
Read the source if you really need to know how this works.

=cut
=end pod

method dump(*%options) { # dump a track's contents

  my $indent = '    ';
  print(
	$indent, 'MIDI::Track->new({', "\n",
	$indent, "  type => ", MIDI::dump-quote($!type), ",\n",
	$!data.defined ??
	  ( $indent, "  data => ",
	    MIDI::dump-quote($!data), ",\n" )
	  !! (),
	$indent, "  events => [  # ", +@!events, " events.\n",
       );
  for @!events -> $event {
    print $indent, $event.dump;
    # was: print( $indent, "    [", &MIDI::-dump-quote(@$event), "],\n" );
  }
  print( "$indent  ]\n$indent}),\n$indent\n" );
  return;
}

method encode-events(*%options) { # encode an array of events, presumably for writing to a file
  # Calling format:
  #   $data = MIDI::Event::encode( @events, options );
  # Returns an array of track data.

  # If you want to use this to encode a /single/ event,
  # you still have to do it as a reference to an event structure (a LoL)
  # that just happens to have just one event.  I.e.,
  #   encode( [ $event ] ) or encode( [ [ 'note-on', 100, 5, 42, 64] ] )
  # If you're doing this, consider the never-add-eot track option, as in
  #   print MIDI ${ encode( [ $event], { 'never-add-eot' => 1} ) };

  my $last-status = -1;
 
  my @events = @!events.clone;

#  my $data = ''; # what I'll join @data all together into

  my $unknown-callback = Nil;
  $unknown-callback = %options<unknown-callback>;

  unless %options<never-add-eot> {
    # One way or another, tack on an 'end-track'
    if +@events { # If there are any events...
      my $last = @events[ *-1 ];
      unless $last ~~ (MIDI::Event::End-track) { # ...And there's no end-track already
        if $last ~~ (MIDI::Event::Text-event) and $last.text.chars == 0 {
	  # 0-length text event at track-end.
	  if %options<no-eot-magic> {
	    # Exceptional case: don't mess with track-final
	    # 0-length text-events; just peg on an end-track
	    @events.push: MIDI::Event::End-track.new;
	  } else {
	    # NORMAL CASE: replace it with an end-track, leaving the DTime
	    $last.type('end-track');
	  }
        } else {
          # last event was neither a 0-length text-event nor an end-track
	  @events.push: MIDI::Event::End-track.new();
        }
      }
    } else { # an eventless track!
      @events = [ MIDI::Event::End-track.new() ];
    }
  }

#print "--\n";
#foreach(@events){ MIDI::Event::dump($_) }
#print "--\n";

  my $maybe-running-status = not %options<no-running-status>;
  $last-status = -1;

  # This is what I wanted the next pice of code to be. Unfortunately it gives errors about using Str on a Buf
  #[~] @events.map: { .encode($maybe-running-status, $last-status) };
  my $ret = Buf.new();
  for @events -> $event {
    $ret = $ret ~ $event.encode($maybe-running-status, $last-status);
  }
  $ret;
}

###########################################################################

# CURRENTLY UNDOCUMENTED -- no end-user ever needs to call this as such
#
method encode(*%options) { # encode a track object into track data (not a chunk)
  # Calling format:
  #  $data = $track->encode( .. options .. )
  # The (optional) argument is an anonymous hash of options.
  # Returns a REFERENCE to track data.
  #

  my $data = '';

  if $!data.defined and $!data {
    # It might be 0-length, by the way.  Might this be problematic?
    $data = $!data;
    # warn "Encoding 0-length track data!" unless length $data;
  } else { # Data is not defined for this track.  Parse the events
    if $!type eq Buf.new(0x4d, 0x54, 0x72, 0x6b) or  $data.chars == 0
        and @!events.defined
             # not just exists -- but DEFINED!
    {
      # note "Encoding ", @!events if $Debug;
      $data = self.encode-events(|%options);
    } else {
      $data = ''; # what else to do?
      warn "Spork 8851\n" if $Debug;
    }
  }
  return $data;
}

###########################################################################

# CURRENTLY UNDOCUMENTED -- no end-user ever needs to call this as such
#
our sub decode($type, $data, *%options) is export { # returns a new object, but doesn't accept constructor syntax
  # decode track data (not a chunk) into a new track object
  # Calling format:
  #  $new-track = 
  #   MIDI::Track::decode($type, \$track-data, { .. options .. })
  # Returns a new track-object.
  # The anonymous hash of options is, well, optional

  my $track = MIDI::Track.new( type => $type );
  
  if $type eq Buf.new(0x4d, 0x54, 0x72, 0x6b) and not %options<no-parse> {
    $track.events = MIDI::Event::decode($data, |%options);
        # And that's where all the work happens
  } else {
    $track.data = $data;
  }
  $track;
}

###########################################################################

=begin pod
=back

=head1 COPYRIGHT 

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

modify it under the same terms as Perl itself.

=head1 AUTHOR

Sean M. Burke C<sburke@cpan.org> (until 2010)

Darrell Conklin C<conklin@cpan.org> (from 2010)

=cut
=end pod
