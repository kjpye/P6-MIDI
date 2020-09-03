use v6.d+;

unit class MIDI::Score;

use MIDI::Event;
    
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
L<MIDI::Event>, with starttime substituting for dtime,
and note-on and note-off replaced by note--
so refer to L<MIDI::Event> for an explanation of what the data types
(like "velocity" or "pitch_wheel") are.
As far as order, the first items are generally the most important:

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

=head1 FUNCTIONS

This module provides these functions:

=item $score2 = MIDI::Score::copy-structure($score)

This takes a score structure, and returns a copy of it. Example usage:

          @new-score = @( MIDI::Score::copy-structure( @old-score ) );

=end pod

has @.notes;
has $.duration = 0;

sub copy-structure {
  return &MIDI::Event::copy-structure(@_);
  # hey, an array of events (sorry -- notes) is an array of events
}
##########################################################################

=begin pod
=item $events = $score.events( )

This method returns an array containing the standard MIDI events
corresponding to the notes in the score.

=end pod

method events {

  my $time = 0;
  my @events = ();

  # create an array of events containing the notes of the score
  # replaced by a pair of note-on and note-off events (but still
  # with the .time field containing absolute time
  for @!notes -> $note {
    if $note ~~ (MIDI::Event::Note) {
	my $note-on  = MIDI::Event::Note-on.new(
	    time        => $note.time,
	    channel     => $note.channel,
	    note-number => $note.note-number,
	    velocity    => $note.velocity
	);
	my $note-off = MIDI::Event::Note-on.new(
	    time        => $note.time + $note.duration,
	    channel     => $note.channel,
	    note-number => $note.note-number,
	    velocity    => 0
	);
      @events.append: $note-on, $note-off;
    } else {
      @events.push: $note;
    }
  }
# Now create a sequence $score containing the events in time order
  my $score = @events.sort({$^a.time <=> $^b.time});

# Now we turn it into an event structure by fiddling the timing
  $time = 0;
  my @newevents;
  for $score.values -> $event {
    next unless $event;
    my $delta = $event.time - $time; # Figure out the delta
    $time = $event.time; # Move it forward
    $event.time = $delta; # Swap it in
    @newevents.push: $event;
  }
  @newevents;
}
###########################################################################

=begin pod
=item @events = $score.sort()

This method returns an sequence with the notes in the score sorted.

          @sorted-events = $old-score.sort();

=end pod

method sort {
  # take a score, and sort it by note start time,
  # and return that sorted list of notes.  Notes from the same
  # time must be left in the order they're found!!!!  That's why we can't
  # just use sort { $a->[1] <=> $b->[1] } (@$score_r)

  # Except in Raku, where sort is stable!

  .notes.sort({$^a.time <=> $^b.time});
}
###########################################################################

=begin pod
=item $score = MIDI::Score::events-to-score( $events )

=item ($score, $ticks) = MIDI::Score::events-to-score( $events )

This takes an event structure, converts it to a
score, which includes a count of the number of ticks that
structure takes to play (i.e., the end-time of the temporally last
item). This can be accessed as $score.duration.

=end pod

sub make-index($a, $b) {
  ($a +< 8) +| $b;
}

our sub events-to-score($events, *%options) {
  # Returns the score, which includes an attribute giving the length (in ticks) of the score

  my $time = 0;
  if %options<no-note-abstraction> {
    my @score;
    my $new-time;
    for $events -> $event {
      # print join(' ', $event), "\n";
      my $nevent = $event.copy;
      $new-time = $time + $event.time;
      $nevent.time = $time;
      $time = $new-time;
    }
    MIDI::Score.new(notes => @score, duration => $time);
  } else {
    my %note = ();
    my @score =
      $events.values.map:
      {
	  temp $_; # copy.
	  $time += .time;
	  if $_ ~~ (MIDI::Event::Note-off)
	     or ($_ ~~ (MIDI::Event::Note-on) && $_.velocity == 0) { # End of a note
              my $index = make-index($_.channel, $_.note);
	       if %note{$index} && %note{$index}[0] {
                  %note{$index}[0].duration += $time;
                  %note{$index}.shift;
               }             
	    next; # Erase this event.
	  } elsif $_ ~~ (MIDI::Event::Note-on) {
	    # Start of a note
              my $index = make-index($_.channel, $_.note);
	      my $newnote = MIDI::Event::Note.new(time        => $time,
						  duration    => -$time,
						  channel     => .channel,
			                          note-number => .note-number,
						  velocity    => .velocity
                                               );
              %note{$index}.push: $newnote;
              $newnote;
	  } else {
              .time = $time;
	      $_;
	  }
      }

    #print "notes remaining on stack: ", %note.elems, "\n"
    #  if values %note;
# 0.82: clean up pending events gracefully
    for %note.values {
	for $_.values {
	    .time += $time;
	}
    }
    MIDI::Score.new(notes => @score, duration => $time);
  }
}

=begin pod
=item MIDI::Score::dump-score( )

This dumps (via C<print>) a text representation of the contents of
the event structure you pass a reference to.

=end pod

method dump-score {
  say .raku;
}

###########################################################################

=begin pod
=item MIDI::Score::quantize( $score )

This takes a score, performs a grid
quantize on all events, returning a new score with new
quantized events.  Two parameters to the method are: 'grid': the
quantization grid, and 'durations': whether or not to also quantize
event durations (default off).

When durations of note events are quantized, they can get 0 duration.
These events are I<not dropped> from the returned score, and it is the
responsiblity of the caller to deal with them.

=end pod

method quantize(*%options) {
  my $grid = %options<grid>;
  if $grid < 1 {fail "bad grid $grid in MIDI::Score::quantize!"; $grid = 1;}
  my $qd = %options<durations>; # quantize durations?
  my @newevents;
  my $n-event;
  for @!notes -> $event {
      $n-event = $event;
      $n-event.time = $grid * ($n-event.time / $grid + 0.5).Int;
      if $qd && $n-event ~~ (MIDI::Event::Note) {
	  $n-event.duration = $grid * ($n-event.duration / $grid + 0.5).Int;
      }
      @newevents.push: $n-event;
  }
  MIDI::Score.new(notes => @newevents);
}

###########################################################################

=begin pod
=item MIDI::Score::skyline( $score )

Note: This method is not yet implemented in this version.
           
This takes a score structure, performs skyline
(create a monophonic track by extracting the event with highest pitch
at unique onset times) on the score, returning a new score reference.
The parameter to the method is: 'clip': whether durations of events
are preserved or possibly clipped and modified.

To explain this, consider the following (from Bach 2 part invention
no.6 in E major):

      |------e------|-------ds--------|-------d------|...
 |****--E-----|-------Fs-------|------Gs-----|...

Without duration clipping, the skyline is E, Fs, Gs...

With duration clipping, the skyline is E, e, ds, d..., where the
duration of E is clipped to just the * portion above

=end pod

# new in 0.83! author DC
method skyline(*%options) {
    my $clip = %options<clip>;
    my @new-events;

    fail "skyline not yet implemented";
    
    my $current-high = -1;
    my $current-note;
    my $current-time;
    my $next-note;
    my $next-time;
    my $next-high = -1;
    my $next-event;
    for @!notes.sort: {$^a.time <=> $^b.time} -> $event {
        if $event.time == $current-time {
            if $event.note-number > $next-high {
                $next-note = $event;
                $next-high = $event.note-number;
            }
        } else {
            @new-events.push: $next-note;
            ########## TODO TODO TODO ##############
        }
    }
    MIDI::Score.new(events => @new-events, duration => @new-events[*-1].time);
}

###########################################################################

=begin pod

=head1 COPYRIGHT 

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

Copyright (c) 2020 Kevin J. Pye. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl or Raku themselves.

=head1 AUTHORS

Sean M. Burke C<sburke@cpan.org> (Perl version until 2010)

Darrell Conklin C<conklin@cpan.org> (Perl version from 2010)

Kevin Pye C<kjpye@cpan.org> (Raku version)
=end pod
