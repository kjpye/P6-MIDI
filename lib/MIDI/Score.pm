use v6.d;

class MIDI::Score {

my $VERSION = '0.84';

use experimental :pack;

=begin pod
=head1 NAME

MIDI::Score - MIDI scores

=head1 SYNOPSIS

  # it's a long story; see below

=head1 DESCRIPTION

This module provides functions to do with MIDI scores.
It is used as the basis for all the functions in MIDI::Simple.
(Incidentally, MIDI::Opus's draw() method also uses some of the
functions in here.)

Whereas the events in a MIDI event structure are items whose timing
is expressed in delta-times, the timing of items in a score is
expressed as an absolute number of ticks from the track's start time.
Moreover, pairs of 'note_on' and 'note_off' events in an event structure
are abstracted into a single 'note' item in a score structure.

'note' takes the following form:

 ('note_on', I<start_time>, I<duration>, I<channel>, I<note>, I<velocity>)

The problem that score structures are meant to solve is that 1)
people definitely don't think in delta-times -- they think in absolute
times or in structures based on that (like 'time from start of measure');
2) people think in notes, not note_on and note_off events.

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

Note also that scores aren't crucially ordered.  So this:

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

where two (or more) score items happen I<at the same time> and where one
affects the meaning of the other.

=head1 WHAT CAN BE IN A SCORE

Besides the new score structure item C<note> (covered above),
the possible contents of a score structure can be summarized thus:
Whatever can appear in an event structure can appear in a score
structure, save that its second parameter denotes not a
delta-time in ticks, but instead denotes the absolute number of ticks
from the start of the track.

To avoid the long periphrase "items in a score structure", I will
occasionally refer to items in a score structure as "notes", whether or
not they are actually C<note> commands.  This leaves "event" to
unambiguously denote items in an event structure.

These, below, are all the items that can appear in a score.
This is basically just a repetition of the table in
L<MIDI::Event>, with starttime substituting for dtime --
so refer to L<MIDI::Event> for an explanation of what the data types
(like "velocity" or "pitch_wheel").
As far as order, the first items are generally the most important:

=over

=item ('note', I<starttime>, I<duration>, I<channel>, I<note>, I<velocity>)

=item ('key_after_touch', I<starttime>, I<channel>, I<note>, I<velocity>)

=item ('control_change', I<starttime>, I<channel>, I<controller(0-127)>, I<value(0-127)>)

=item ('patch_change', I<starttime>, I<channel>, I<patch>)

=item ('channel_after_touch', I<starttime>, I<channel>, I<velocity>)

=item ('pitch_wheel_change', I<starttime>, I<channel>, I<pitch_wheel>)

=item ('set_sequence_number', I<starttime>, I<sequence>)

=item ('text_event', I<starttime>, I<text>)

=item ('copyright_text_event', I<starttime>, I<text>)

=item ('track_name', I<starttime>, I<text>)

=item ('instrument_name', I<starttime>, I<text>)

=item ('lyric', I<starttime>, I<text>)

=item ('marker', I<starttime>, I<text>)

=item ('cue_point', I<starttime>, I<text>)

=item ('text_event_08', I<starttime>, I<text>)

=item ('text_event_09', I<starttime>, I<text>)

=item ('text_event_0a', I<starttime>, I<text>)

=item ('text_event_0b', I<starttime>, I<text>)

=item ('text_event_0c', I<starttime>, I<text>)

=item ('text_event_0d', I<starttime>, I<text>)

=item ('text_event_0e', I<starttime>, I<text>)

=item ('text_event_0f', I<starttime>, I<text>)

=item ('end_track', I<starttime>)

=item ('set_tempo', I<starttime>, I<tempo>)

=item ('smpte_offset', I<starttime>, I<hr>, I<mn>, I<se>, I<fr>, I<ff>)

=item ('time_signature', I<starttime>, I<nn>, I<dd>, I<cc>, I<bb>)

=item ('key_signature', I<starttime>, I<sf>, I<mi>)

=item ('sequencer_specific', I<starttime>, I<raw>)

=item ('raw_meta_event', I<starttime>, I<command>(0-255), I<raw>)

=item ('sysex_f0', I<starttime>, I<raw>)

=item ('sysex_f7', I<starttime>, I<raw>)

=item ('song_position', I<starttime>)

=item ('song_select', I<starttime>, I<song_number>)

=item ('tune_request', I<starttime>)

=item ('raw_data', I<starttime>, I<raw>)

=back


=head1 FUNCTIONS

This module provides these functions:

=over

=item $score2_r = MIDI::Score::copy_structure($score_r)

This takes a I<reference> to a score structure, and returns a
I<reference> to a copy of it. Example usage:

          @new_score = @{ MIDI::Score::copy_structure( \@old_score ) };

=cut
=end pod

has @!notes;

sub copy-structure {
  return &MIDI::Event::copy-structure(@_);
  # hey, a LoL is an LoL
}
##########################################################################

=begin pod
=item $events_r = MIDI::Score::score_r_to_events_r( $score_r )

=item ($events_r, $ticks) = MIDI::Score::score_r_to_events_r( $score_r )

This takes a I<reference> to a score structure, and converts it to an
event structure, which it returns a I<reference> to.  In list context,
also returns a second value, a count of the number of ticks that
structure takes to play (i.e., the end-time of the temporally last
item).

=cut
=end pod

method to-events {
  # list context: Returns the events AND the total tick time
  # scalar context: Returns events

  my $time = 0;
  my @events = ();

  # First, turn instances of 'note' into 'note_on' and 'note_off':
  for @!notes -> $note {
    if $note ~~ (MIDI::Event::Note) {
	my $note-on  = MIDI::Event::Note-on.new(
	    time     => $note.time,
	    channel  => $note.channel,
	    note     => $note.note,
	    velocity => $note.velocity
	);
	my $note-off = MIDI::Event::Note-off.new(
	    time     => $note.time,
	    channel  => $note.channel,
	    note     => $note.note,
	    velocity => 0
	);
      @events.push: $note-on, $note-off;
      #dd $note-on;
      #dd $note-off;
    } else {
      @events.push: $note;
    }
  }
  # warn scalar(@events), " events in $score_r";
  my $score = @events.sort({$^a.time <=> $^b.time});
  # warn scalar(@$score_r), " events in $score_r";

  # Now we turn it into an event structure by fiddling the timing
  $time = 0;
  for $score -> $event {
    next unless $event;
    my $delta = $event.time - $time; # Figure out the delta
    $time = $event.time; # Move it forward
    $event.time = $delta; # Swap it in
  }
  return ($score, $time);
}
###########################################################################

=begin pod
=item $score2_r = MIDI::Score::sort_score_r( $score_r)

This takes a I<reference> to a score structure, and returns a
I<reference> to a sorted (by time) copy of it. Example usage:

          @sorted_score = @{ MIDI::Score::sort_score_r( \@old_score ) };

=end pod

sub sort-score($score) {
  # take a reference to a score LoL, and sort it by note start time,
  # and return a reference to that sorted LoL.  Notes from the same
  # time must be left in the order they're found!!!!  That's why we can't
  # just use sort { $a->[1] <=> $b->[1] } (@$score_r)

  # Except in Perl6, where sort is stable!

  $score.sort({$^a.time <=> $^b.time});
}
###########################################################################

=begin pod
=item $score_r = MIDI::Score::events_r_to_score_r( $events_r )

=item ($score_r, $ticks) = MIDI::Score::events_r_to_score_r( $events_r )

This takes a I<reference> to an event structure, converts it to a
score structure, which it returns a I<reference> to.  If called in
list context, also returns a count of the number of ticks that
structure takes to play (i.e., the end-time of the temporally last
item).

=end pod

method events-to-score(*%options) {
  # Returns the score AND the total tick time

  my $time = 0;
  if %options<no_note_abstraction> {
    my $score = MIDI::Event::copy_structure(@!notes);
    my $new-time;
    for $score -> $event {
      # print join(' ', $event), "\n";
      $new-time = $time + $event.time;
      $event.time = $time;
      $time = $new-time;
    }
    return $score, $time;
  } else {
    my %note = ();
    my @score =
      @!notes.map:
      {
#	if !ref($_) {
#	  ();
#	} else {
# 0.82: the following must be declared local
	  temp $_; # copy.
#	  $_.time = ($time += $_.time) if ref($_);

	  if $_ ~~ (MIDI::Event::Note_off)
	     or ($_ ~~ (MIDI::Event::Note-on) &&
		 $_.velocity == 0) { # End of a note
	    # print "Note off : @$_\n";
# 0.82: handle multiple prior events with same chan/note.
	       if (
		   %note{pack 'CC', $_.channel, $_.note}.exists
		   && @(%note{pack 'CC', $_.channel, $_.note})
		  ) {
		  shift(@(%note{pack 'CC', $_.channel, $_.note})).note += $time;
		  unless @(%note{pack 'CC', $_.channel, $_.note}) {%note{pack 'CC', $_.channel, $_.note}:delete;}
	      }
	    (); # Erase this event.
	  } elsif $! ~~ (midi::Event::Note-on) {
	    # Start of a note
	    $_ = [@$_];

	    push(@(%note{ pack 'CC', $_.channel, $_.note}),$_);
#	    splice(@$_, 2, 0, -$time);
	    # ('note', Starttime, Duration, Channel, Note, Veloc)
	    MIDI::Event::Note.new(time => $_.time, duration => -$time, channel => $_.channel,
				  note => $_.note,  velocity => $_.velocity
				 );
	  } else {
	    $_;
	  }
#	}
      };

    #print "notes remaining on stack: ", %note.elems, "\n"
    #  if values %note;
# 0.82: clean up pending events gracefully
    for %note.keys -> $k {
	for @(%note{$k}) -> $one {
	    $one.time += $time;
	}
    }
#    return(@score, $time) if wantarray;
    return @score;
  }
}
###########################################################################

=begin pod
=item $ticks = MIDI::Score::score_r_time( $score_r )

This takes a I<reference> to a score structure, and returns 
a count of the number of ticks that structure takes to play
(i.e., the end-time of the temporally last item).

=end pod

sub score_r_time {
  # returns the duration of the score you pass a reference to
  my $score = $_[0];
#  fail "arg 1 of MIDI::Score::score_r_time isn't a ref" unless ref $score;
  my $track_time = 0;
  for @$score -> $event {
    next unless @$event;
    my $event_end_time = ($event ~~ (MIDI::Event::Note)) ??
      ($event.channel + $event.note)  !!  $event.channel ;
    #print "event_end_time: $event_end_time\n";
    $track_time = $event_end_time if $event_end_time > $track_time;
  }
  return $track_time;
}
###########################################################################

=begin pod
=item MIDI::Score::dump_score( $score_r )

This dumps (via C<print>) a text representation of the contents of
the event structure you pass a reference to.

=end pod

sub dump_score {
  my $score = $_[0];
  print "\@notes = (   # ", @$score.elems, " notes...\n";
  for @$score -> $note {
    print " [", &MIDI::_dump_quote(@$note), "],\n" if @$note;
  }
  print ");\n";
  return;
}

###########################################################################

=begin pod
=item MIDI::Score::quantize( $score_r )

This takes a I<reference> to a score structure, performs a grid
quantize on all events, returning a new score reference with new
quantized events.  Two parameters to the method are: 'grid': the
quantization grid, and 'durations': whether or not to also quantize
event durations (default off).

When durations of note events are quantized, they can get 0 duration.
These events are I<not dropped> from the returned score, and it is the
responsiblity of the caller to deal with them.

=end pod

sub quantize($score, *%options) {
  my $grid = %options<grid>;
  if $grid < 1 {fail "bad grid $grid in MIDI::Score::quantize!"; $grid = 1;}
  my $qd = %options<durations>; # quantize durations?
  my $new_score = [];
  my $n_event;
  for @($score) -> $event {
      my $n_event = [];
      @($n_event) = @($event);
      $n_event[1] = $grid * int(($n_event[1] / $grid) + 0.5);
      if ($qd && $n_event[0] eq 'note') {
	  $n_event[2] = $grid * int(($n_event[2] / $grid) + 0.5);
      }
      push @($new_score), $n_event;
  }
  $new_score;
}

###########################################################################

=begin pod
=item MIDI::Score::skyline( $score_r )

This takes a I<reference> to a score structure, performs skyline
(create a monophonic track by extracting the event with highest pitch
at unique onset times) on the score, returning a new score reference.
The parameters to the method is: 'clip': whether durations of events
are preserved or possibly clipped and modified.

To explain this, consider the following (from Bach 2 part invention
no.6 in E major):

     |------e------|-------ds--------|-------d------|...
|****--E-----|-------Fs-------|------Gs-----|...

Without duration cliping, the skyline is E, Fs, Gs...

With duration clipping, the skyline is E, e, ds, d..., where the
duration of E is clipped to just the * portion above

=end pod

# new in 0.83! author DC
sub skyline($score, *%options) {
    my $clip = %options<clip>;
    my $new_score = @();
    my %events = %();
    my $n_event;
    my ($typeidx,$stidx,$duridx,$pitchidx) = (0,1,2,4); # create some nicer event indices
# gather all note events into an onset-index hash.  push all others directly into the new score.
    for @($score) -> $event {
	if ($event[$typeidx] eq "note") {push @(%events{$event[$stidx]}), $event;}
	else {push @($new_score), $event;}
    }
    my $loff = 0; my $lev = [];
# iterate over increasing onsets
    for %events.keys.sort: {$^a <=> $^b} -> $onset {
        # find highest pitch at this onset
        my $ev = {@(%events{$onset}).sort: {$^b[$pitchidx] <=> $^a[$pitchidx]}}[0] ;
	if $onset >= ($lev[$stidx] + $lev[$duridx]) {
	    @($new_score).push: $ev;
	    $lev = $ev;
	}
	elsif ($clip) {
	    if $ev[$pitchidx] > $lev[$pitchidx] {
		$lev[$duridx] = $ev[$stidx] - $lev[$stidx];
		@($new_score).push: $ev;
		$lev = $ev;
	    }
	}
    }
    $new_score;
}

###########################################################################

=begin pod

=head1 COPYRIGHT 

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHORS

Sean M. Burke C<sburke@cpan.org> (until 2010)

Darrell Conklin C<conklin@cpan.org> (from 2010)

=end pod

}
