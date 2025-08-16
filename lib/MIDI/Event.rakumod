use v6;

my $Debug = 0;

use MIDI::Utility;

sub ber($value is copy){
    my @bytes = $value +& 0x7f;
    $value +>= 7;
    while $value {
        @bytes.push: ($value +& 0x7f) +| 0x80;
	$value +>= 7;
    }
    @bytes.reverse;
}

sub signextendbyte($byte) {
    $byte +& 0x80 ?? $byte - 256 !! $byte;
}

sub getint24($data, $pointer) {
    my $value  = $data[$pointer]   +< 16;
       $value += $data[$pointer+1] +<  8;
       $value += $data[$pointer+2]      ;
    $value;       
}

sub getcompint($data, $pointer is rw) {
    my $value = 0;
    my $byte;
    while ($byte = $data.read-uint8($pointer++)) && $byte +& 0x80 {
	$value +<= 7;
        $value +|= $byte +& 0x7f;
    }
    $value +<= 7;
    $value +|= $byte +& 0x7f;
}

class MIDI::Event::Note-off             { ... }
class MIDI::Event::Note                 { ... }
class MIDI::Event::Note-on              { ... }
class MIDI::Event::Key-after-touch      { ... }
class MIDI::Event::Controller-change    { ... }
class MIDI::Event::Patch-change         { ... }
class MIDI::Event::Channel-after-touch  { ... }
class MIDI::Event::Pitch-wheel-change   { ... }
class MIDI::Event::Set-sequencer-number { ... }
class MIDI::Event::Text-event           { ... }
class MIDI::Event::Copyright            { ... }
class MIDI::Event::Track-name           { ... }
class MIDI::Event::Instrument-name      { ... }
class MIDI::Event::Lyric                { ... }
class MIDI::Event::Marker               { ... }
class MIDI::Event::Cue-point            { ... }
class MIDI::Event::Text-event_08        { ... }
class MIDI::Event::Text-event_09        { ... }
class MIDI::Event::Text-event_0a        { ... }
class MIDI::Event::Text-event_0b        { ... }
class MIDI::Event::Text-event_0c        { ... }
class MIDI::Event::Text-event_0d        { ... }
class MIDI::Event::Text-event_0e        { ... }
class MIDI::Event::Text-event_0f        { ... }
class MIDI::Event::End-track            { ... }
class MIDI::Event::Set-tempo            { ... }
class MIDI::Event::Smpte-offset         { ... }
class MIDI::Event::Time-signature       { ... }
class MIDI::Event::Key-signature        { ... }
class MIDI::Event::Sequencer-specific   { ... }
class MIDI::Event::sysex-f0             { ... }
class MIDI::Event::sysex-f7             { ... }
class MIDI::Event::Song-position        { ... }
class MIDI::Event::Song-select          { ... }
class MIDI::Event::Tune-request         { ... }
class MIDI::Event::Raw                  { ... }

class MIDI::Event {

=begin pod
=head1 NAME

MIDI::Event - MIDI events

=head1 SYNOPSIS

  # Dump a MIDI file's text events
  die "No filename" unless @ARGS;
  use MIDI;  # which "use"s MIDI::Event;
  MIDI::Opus.new(
     from-file                => @ARGS[0],
     exclusive-event-callback => sub{print "$_[2]\n"},
     include                  => @MIDI::Event::Text-events
  ); # These options percolate down to MIDI::Event::decode
  exit;

=head1 DESCRIPTION

Functions and lists to do with MIDI events and MIDI event structures.

An event is an object, with each event type an object in a different class, like:

              MIDI::Event::Note-on(time => 141,
                                   channel => 4,
                                   note-number => 50,
                                   velocity => 64)

An I<event structure> is a list of such events -- an array of objects.

=head1 GOODIES

For your use in code (as in the code in the Synopsis), this module
provides a few lists:

=item $MIDI::Event::MIDI-events

a set of all "MIDI events" AKA voice events -- e.g., 'note-on'

=item $MIDI::Event::Text-events

a set of all text meta-events -- e.g., 'track-name'

=item $Nontext-meta-events

all other meta-events (plus 'raw-data' and F-series events like
'tune-request').

=item $MIDI::Event::Meta-events

the combination of Text-events and Nontext-meta-events.

=item $MIDI::Event::All-events

the combination of all the above lists.

Each Event object has a method I<type> which will return a string which can be used to check whether the event is in one of these sets. For example

  $object.type ∈ $MIDI::Event::Meta-events

will be true if and only if the object is a meta-event.
  
=end pod

###########################################################################
# Some public-access sets:

our $MIDI-events = Set.new: <
                             note-off
                             note-on                    
                             key-after-touch
                             controller-change
                             patch-change
                             channel-after-touch
                             pitch-wheel-change
                             set-sequence-number
                            >;

our $Text-events = Set.new: <
                             text-event
                             copyright-text-event
                             track-name                   
                             instrument-name              
                             lyric                        
                             marker                       
                             cue-point                    
                             text-event-08
                             text-event-09
                             text-event-0a
                             text-event-0b
                             text-event-0c
                             text-event-0d
                             text-event-0e
                             text-event-0f
                            >;

our $Nontext-meta-events = Set.new: <
                                     end-track
                                     set-tempo
                                     smpte-offset
                                     time-signature
                                     key-signature
                                     sequencer-specific
                                     raw-meta-event
                                     sysex-f0
                                     sysex-f7
                                     song-position
                                     song-select
                                     tune-request
                                     raw-data
                                    >;

# Actually, 'tune-request', for one, is an F-series event, not a
#  strictly-speaking meta-event

our $Meta-events  = $Text-events ∪ $Nontext-meta-events;
our $All-events   = $MIDI-events ∪ $Meta-events;

=begin pod
=head1 FUNCTIONS

This module provides three functions of interest, which all act upon
event structures.  As an end user, you probably don't need to use any
of these directly, but note that options you specify for
MIDI::Opus.new with a from_file or from_handle options will percolate
down to these functions; so you should understand the options for the
first two of the below functions.  (The casual user should merely skim
this section.)

=item MIDI::Event::decode( $data, ...options... )

This takes a Buf containing binary MIDI data and decodes it into a
new event structure, which is returned.

Options are:

=item 'include' => LIST

I<If specified>, list is interpreted as a list of
event names (e.g., 'cue-point' or 'note-off') such that only these
events will be parsed from the binary data provided.  Events whose
names are NOT in this list will be ignored -- i.e., they won't end up
in the event structure, and they won't be each passed to any callbacks
you may have specified.

=item 'exclude' => LIST

I<If specified>, list is interpreted as a list of
event names (e.g., 'cue-point' or 'note-off') that will NOT be parsed
from the binary stream; they'll be ignored -- i.e., they won't end up
in the event structure, and they won't be passed to any callbacks you
may have specified.  Don't specify both an include and an exclude
list.  And if you specify I<neither>, all events will be decoded --
this is what you probably want most of the time.  I've created this
include/exclude functionality mainly so you can scan a file rather
efficiently for just a few specific event types, e.g., just text
events, or just sysexes.

=item 'no-eot-magic' => 0 or 1

See the description of C<'end-track'>, in "EVENTS", below.

=item 'event-callback' => CODE

If defined, the code referred to (whether as C<\&wanted> or as
C<sub { BLOCK }>) is called on every event after it's been parsed into
an event list (and any EOT magic performed), but before it's added to
the event structure.  So if you want to alter the event stream on the
way to the event structure (which counts as deep voodoo), define
'event-callback' and have it modify its C<@_>.

=item 'exclusive-event-callback' => CODE

Just like 'event-callback'; but if you specify this, the callback is
called I<instead> of adding the events to the event structure.  (So
the event structure returned by decode() at the end will always be
empty.)  Good for cases like the text dumper in the Synopsis, above.

=item MIDI::Event::encode( @events, {...options...})

This takes an event structure (an array of Midi::Event objects) and encodes it
as binary data, which it returns in a Buf.  Options:

=item 'unknown-callback' => CODE

If this is specified, it's a subroutine
to be called when an unknown event name (say, 'macro-10' or
something), is seen by encode().  The function is fed all of the event
(its name, delta-time, and whatever parameters); the return value of
this function is added to the encoded data stream -- so if you don't
want to add anything, be sure to return ''.

If no 'unknown-callback' is specified, encode() will C<warn> of the unknown event.  To merely block that, just set
'unknown-callback' to C<sub{return('')}>

=item 'no-eot-magic' => 0 or 1

Determines whether a track-final 0-length text event is encoded as
an end-track event -- since a track-final 0-length text event probably
started life as an end-track event read in by decode(), above.

=item 'never-add-eot' => 0 or 1

If 1, C<encode()> never ever I<adds> an end-track (EOT) event to the
encoded data generated unless it's I<explicitly> there as an
'end-track' in the given event structure.  You probably don't ever
need this unless you're encoding for I<straight> writing to a MIDI
port, instead of to a file.

=item 'no-running-status' => 0 or 1

If 1, disables MIDI's "running status" compression.  Probably never
necessary unless you need to feed your MIDI data to a strange old
sequencer that doesn't understand running status.

Note: If you're encoding just a single event at a time or less than a
whole trackful in any case, then you probably want something like:

          $data = MIDI::Event::encode(
            [
              MIDI::Event::Note-on.new(time => 141,
                                       channel => 4,
                                       note-number => 50,
                                       velocity => 64)
            ],
            'never-add-eot' => 1 );

which just encodes that one event I<as> an event structure of one
event -- i.e., an array that consists of only one element.

But note that running status will not always apply when you're
encoding less than a whole trackful at a time, since running status
works only within an array encoded all at once.  This will result in
non-optimally compressed, but still effective, encoding.

=item MIDI::Event::copy-structure()

This takes an event structure, and returns a copy of it.  If you're
thinking about using this, you probably want to use the more
straightforward

          $track2 = $track.clone

instead.  But it's here if you happen to need it.

=end pod

method raku {
  print( "        [", dump-quote(self), "\n" );
}

# This isn't a method on an object of type Mime::Event. Possibly at the track level
#method copy-structure {
#  # Takes an event structure
#  # and returns a copy of that structure.
#
# return [  map( [@$_], @$events_r )  ];
#}

sub read-u14-bit($in) {
  # Decodes to a value 0 to 16383, as is used for some event encoding
  my ($b1, $b2) = $in.list;
  $b1.ord +| ($b2.ord +< 7);
}

###########################################################################

my $last-status = -1;

method write-u14-bit($in) {
    # encode a 14 bit quantity, as needed for some events
    Buf.new($in +& 0x7F, ($in +> 7) +& 0x7F)
}

  ###########################################################################
  #
  # One definite assumption is made here: that "variable-length-encoded"
  # quantities MUST NOT exceed 0xFFFFFFF (encoded, "\xFF\xFF\xFF\x7F")
  # -- i.e., must not take more than 4 bytes to encode.
  #
  ###

our sub decode(Buf $data, *%options) { # decode track data into an array of events
  # Calling format: a big chunk of MTrk track data.
  # Returns an array of events.
  # Note that this is a function call, not a constructor method call.

  note "Entering MIDI::Event::decode" if $Debug;
    
  my @events = ();

  my $exclude = ();
  if %options<exclude> {
			$exclude = Set.new: %options<exclude>;
		       } else {
			 # If we get an include (and no exclude), make $exclude a set
			 #  of all possible events, /minus/ what include specifies
			 if %options<include> {
					       $exclude = $All-events ∖ Set.new(%options<include>);
					      }
		       }
  note "Exclusions: ", join ' ', $exclude.keys.sort
    if $Debug;

  my $event-callback = Nil;
  if %options<event-callback> {
			       # TODO
                               fail "event-callback NYI";
			      }
    my $exclusive-event-callback = Nil;
  if %options<exclusive-event-callback> {
					 # TODO
                                         fail "exclusive-event-callback BYI";
					}

    my $Pointer = 0;		# points to where we are in the data
  ######################################################################
  if $Debug  ≥ 1 {
    note "Track data of ", $data.bytes, " bytes.";
  }

=begin pod
=head1 EVENTS AND THEIR DATA TYPES

=head2 DATA TYPES

Events use these data types:

=item channel = a value 0 to 15

=item note = a value 0 to 127

=item dtime = a value 0 to 268,435,455 (0x0FFFFFFF)

=item velocity = a value 0 to 127

=item channel = a value 0 to 15

=item patch = a value 0 to 127

=item sequence = a value 0 to 65,535 (0xFFFF)

=item text = a string of 0 or more bytes of ASCII text (although this module should work with arbitrary utf-8 encoded text)

=item raw = a string of 0 or more bytes of binary data

=item pitch-wheel = a value -8192 to 8191 (0x1FFF)

=item song-pos = a value 0 to 16,383 (0x3FFF)

=item song-number = a value 0 to 127

=item tempo = microseconds, a value 0 to 16,777,215 (0x00FFFFFF)

For data types not defined above, (e.g., I<sf> and I<mi> for
C<'key-signature'>), consult L<MIDI::Filespec> and/or the source for
C<MIDI::Event.pm>.  And if you don't see it documented, it's probably
because I don't understand it, so you'll have to consult a real MIDI
reference.

=head2 EVENTS

And these are the events:

=end pod

  # Things used variously, below.  They're here just for efficiency's sake,
  # to avoid re-mying on each iteration.
  my ($command, $channel, $parameter, $length, $time, $remainder);

  my $event-code = -1;		# used for running status

  my $event-count = 0;
 Event:				# Analyze the event stream.
  while $Pointer + 1 < $data.bytes {
    # loop while there's anything to analyze ...
    my $eot = 0;	# When 1, the event registrar aborts this loop
    ++$event-count;
    note "Reading event $event-count" if $Debug ≥ 1;

    my $E;
    # E for event -- this is what we'll feed to the event registrar
    #  way at the end.

    # Slice off the delta time code, and analyze it

    $time = getcompint($data, $Pointer);
    note "Time: $time" if $Debug;

    # Now let's see what we can make of the command
    my $first-byte = $data[$Pointer];
    note "First byte: {sprintf "%02.2x", $first-byte}" if $Debug;
    # Whatever parses $first-byte is responsible for moving $Pointer
    # forward.

    ######################################################################

    given $first-byte {
	when ^0xf0 {
	    if $first-byte ≥ 0x80 {
		print "Explicit event $first-byte" if $Debug > 2;
		++$Pointer;		# It's an explicit event.
		$event-code = $first-byte;
	    } else {
		# It's a running status mofo -- just use last $event-code value
note "Running status {sprintf "%02.2x", $event-code}" if $Debug;
		if $event-code < 0 {
		    fail "Uninterpretable use of running status; Aborting track."
		    if $Debug;
		    last Event;
	        }
# $event-code is now correct for this event
		# Let the argument-puller-offer move Pointer.
	    }
	    $command = $event-code +& 0xF0;
	    $channel = $event-code +& 0x0F;
	    
	    if $command == 0xC0 || $command == 0xD0 { #  Pull off the 1-byte argument
		$parameter = $data.subbuf($Pointer, 1);
		++$Pointer;
	    } else {                                  #  Pull off the 2-byte argument
		$parameter = $data.subbuf($Pointer, 2);
		$Pointer += 2;
	    }
	    
	    ###################################################################
	    # MIDI events
	    
=begin pod
=item MIDI::Event::Note-off(I<dtime>, I<channel>, I<note>, I<velocity>)

=end pod
            given $command {
              when 0x80 {
		  next if $exclude<note-off>;
		  $E = MIDI::Event::Note-off.new(
		      time          => $time,
		      channel       => $channel,
		      note-number   => $parameter[0],
		      velocity      => scale7to16 $parameter[1],
		  );
	      }
	      
=begin pod
=item MIDI::Event::Note-on(I<dtime>, I<channel>, I<note>, I<velocity>)

=end pod
              when 0x90 {
                  next if $exclude<note-on>;
		  $E = $parameter[1] != 0
                       ??
                       MIDI::Event::Note-on.new(
                           time          => $time,
                           channel       => $channel,
                           note-number   => $parameter[0],
                           velocity      => scale7to16 $parameter[1],
                      )
                      !!
                      MIDI::Event::Note-off.new(
                          time          => $time,
                          channel       => $channel,
                          note-number   => $parameter[0],
                          velocity      => 0,
                      )                      
                  }
                  
=begin pod        
=item MIDI::Event::Key-after-touch(I<dtime>, I<channel>, I<note>, I<velocity>)

=end pod
              when 0xA0 {
                  next if $exclude<key-after-touch>;
		  $E = MIDI::Event::Key-after-touch.new(
		      time        => $time,
		      channel     => $channel,
		      note-number => $parameter[0],
		      aftertouch  => $parameter[1],
		  );
              }

=begin pod
=item MIDI::Event::Controller_change(I<dtime>, I<channel>, I<controller(0-127)>, I<value(0-127)>)

=end pod
              when 0xB0 {
                  next if $exclude<controller-change>;
		  $E = MIDI::Event::Controller-change.new(
		      time       => $time,
		      channel    => $channel,
		      controller => $parameter[0],
		      value      => $parameter[1],
		  );
              }
=begin pod
=item MIDI::Event::Patch-change(I<dtime>, I<channel>, I<patch>)

=end pod
              when 0xC0 {
                  next if $exclude<patch-change>;
		  $E = MIDI::Event::Patch-change.new(
		      time         => $time,
		      channel      => $channel,
		      patch-number => $parameter[0],
		  );
              }

=begin pod
=item MIDI::Event::Channel-after-touch(I<dtime>, I<channel>, I<velocity>)

=end pod
              when 0xD0 {
                  next if $exclude<channel-after-touch>;
		  $E = MIDI::Event::Channel-after-touch.new(
		      time => $time,
		      channel => $channel,
		  );
              }
=begin pod
=item MIDI::Event::Pitch-wheel-change, I<dtime>, I<channel>, I<pitch_wheel>)

=end pod
              when 0xE0 {
                  next if $exclude<pitch-wheel-change>;
		  $E = MIDI::Event::Pitch-wheel-change.new(
		      time => $time,
		      channel => $channel,
		      value => read-u14-bit($parameter) - 0x2000
		  );
              }
              default {
                  note "Track data of ", $data.bytes, " bytes: <", $data ,">";
              }
          } # given $command
        @events.push: $E;

			######################################################################
    } # $first-byte < 0xf0
    when 0xff {	
        note "First byte is 0xFF" if $Debug;
      ++$Pointer;
      $command = $data[$Pointer++];
      note "Command is {sprintf "%02.2x", $command}" if $Debug;
      $length = getcompint($data, $Pointer);
      note "length：$length" if $Debug;

=begin pod
=item MIDI::Event::Set-sequence-number(I<dtime>, I<sequence-number>)

=end pod
      given $command {
			  when 0x00 {
			    $E = MIDI::Event::Set-sequencer-number.new(
								       time            => $time,
								       sequence-number => $data.readuint16($Pointer, BigEndian),
								      );
			    $Pointer += 2;
			  }

			  # Defined text events ----------------------------------------------

=begin pod
=item MIDI::Event::Text-event(I<dtime>, I<text>)

=item MIDI::Event::Copyright-text-event(I<dtime>, I<text>)

=item MIDI::Event::Track-name(I<dtime>, I<text>)

=item MIDI::Event::Instrument_name(I<dtime>, I<text>)

=item MIDI::Event::Lyric(I<dtime>, I<text>)

=item MIDI::Event::Marker(I<dtime>, I<text>)

=item MIDI::Event::Cue-point(I<dtime>, I<text>)

=item MIDI::Event::Text-event_08(I<dtime>, I<text>)

=item MIDI::Event::Text-event_09(I<dtime>, I<text>)

=item MIDI::Event::Text-event_0a)I<dtime>, I<text>)

=item MIDI::Event::Text-event_0b(I<dtime>, I<text>)

=item MIDI::Event::Text-event_0c(I<dtime>, I<text>)

=item MIDI::Event::Text-event_0d(I<dtime>, I<text>)

=item MIDI::Event::Text-event_0e(I<dtime>, I<text>)

=item MIDILLEvent::Text-event_0f(I<dtime>, I<text>)

=end pod
			  when 0x01 {
			    $E =  MIDI::Event::Text-event.new(
							      time => $time,
							      text => $data.subbuf($Pointer, $length)
							     );
			  } 
			  when 0x02 {
			    $E = MIDI::Event::Copyright.new(
							    time => $time,
							    text => $data.subbuf($Pointer, $length)
							   );
			  }
			  when 0x03 {
			    $E = MIDI::Event::Track-name.new(
							     time => $time,
							     text => $data.subbuf($Pointer, $length)
							    );
			  }
			  when 0x04 {
			    $E = MIDI::Event::Instrument-name.new(
								  time => $time,
								  text => $data.subbuf($Pointer, $length)
								 );
			  }
			  when 0x05 {
			    $E = MIDI::Event::Lyric.new(
							time => $time,
							text => $data.subbuf($Pointer, $length)
						       );
			  }
			  when 0x06 {
			    $E = MIDI.Event::Marker.new(
							time => $time,
							text => $data.subbuf($Pointer, $length)
						       );
			  }
			  when 0x07 {
			    $E = MIDI::Event::Cue-point.new(
							    time => $time,
							    text => $data.subbuf($Pointer, $length)
							   );
			  }

			  # Reserved but apparently unassigned text events --------------------

			  when 0x08 {
			    $E = MIDI::Event::Text-event_08.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }
			  when 0x09 {
			    $E = MIDI::Event::Text-event_09.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }
			  when 0x0a {
			    $E = MIDI::Event::Text-event_0a.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }
			  when 0x0b {
			    $E = MIDI::Event::Text-event_0b.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }
			  when 0x0c {
note "text-event_0c: length $length" if $Debug;
			    $E = MIDI::Event::Text-event_0c.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }
			  when 0x0d {
			    $E = MIDI::Event::Text-event_0d.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }
			  when 0x0e {
			    $E = MIDI::Event::Text-event_0e.new(
								time => $time,
								text => $data.subbuf($Pointer, $length)
							       );
			  }

			  # Now the sticky events ---------------------------------------------

=begin pod
=item MIDI::Event::End-track(I<dtime>)

=end pod
			  when 0x2F {
			    $E = MIDI::Event::End-track.new(
							    time => $time,
							   );
			    # The code for handling this oddly comes LATER, in the
			    #  event registrar.
			  }

=begin pod
=item MIDI::Event::Set-tempo(I<dtime>, I<tempo>)

=end pod

			  when 0x51 {
			    $E = MIDI::Event::Set-tempo.new(
							    time => $time,
							    tempo => getint24($data, $Pointer),
							   );
			  }

=begin pod
=item MIDI::Event::Smpte-offset(I<dtime>, I<hr>, I<mn>, I<se>, I<fr>, I<ff>)

=end pod

			  when 0x54 {
			    $E = MIDI::Event::Smpte-offset.new(
							       time    => $time,
							       hours   => $data[$Pointer],
							       minutes => $data[$Pointer+1],
							       seconds => $data[$Pointer+2],
							       fr      => $data[$Pointer+3],
							       ff      => $data[$Pointer+4],
							      );
			  }

=begin pod
=item MIDI::Event::Time-signature(I<dtime>, I<nn>, I<dd>, I<cc>, I<bb>)

=end pod
			  when 0x58 {
			    $E = MIDI::Event::Time-signature.new(
								 time          => $time,
								 numerator     => $data[$Pointer],
								 denominator   => $data[$Pointer+1],
								 ticks         => $data[$Pointer+2],
								 quarter-notes => $data[$Pointer+3],
								);
note "Pointer after time signature is $Pointer" if $Debug;
			  }

=begin pod
=item MIDI::Event::Key-signature(I<dtime>, I<sf>, I<mi>)

=end pod
			  when 0x59 {
note "Pointer is $Pointer before reading arguments";
			    $E = MIDI::Event::Key-signature.new(
								time        => $time,
								sharps      => $data.read-uint8($Pointer),
								major-minor => $data.read-uint8($Pointer+1)
							       );
note $E.raku; 
note "Pointer after key signature is $Pointer" if $Debug;
			  }

=begin pod
=item MIDI::Event::Sequencer-specific(I<dtime>, I<raw>)

=end pod
			  when 0x7F {
			    $E = MIDI::Event::Sequencer-specific.new(
								     time => $time,
								     data => $data.subbuf($Pointer, $length)
								    );
			  }

=begin pod
=item MIDI:E:vent::Raw-meta-event(I<dtime>, I<command>(0-255), I<raw>)

=end pod
			  default {
note "Unhandled command $_";
			    $E = MIDI::Event::Raw.new(
						      time    => $time,
						      command => $command,
						      data    => $data.subbuf($Pointer, $length)
						     );
			    # It's uninterpretable; record it as raw_data.
			  } # End of the meta-event ifcase.
			 }
# FIX:

	  $Pointer += $length;	#  Now move Pointer
          @events.push: $E;

	######################################################################
    }
    when 0xf0 | 0xf7 { # It's a SYSEX
	  # Note that sysexes in MIDI /files/ are different than sysexes in
	  #  MIDI transmissions!!
	  # << The vast majority of system exclusive messages will just use the F0
	  # format.  For instance, the transmitted message F0 43 12 00 07 F7 would
	  # be stored in a MIDI file as F0 05 43 12 00 07 F7.  As mentioned above,
	  # it is required to include the F7 at the end so that the reader of the
	  # MIDI file knows that it has read the entire message. >>
	  # (But the F7 is omitted if this is a non-final block in a multiblock
	  # sysex; but the F7 (if there) is counted in the message's declared
	  # length, so we don't have to think about it anyway.)
	  $command = $data[$Pointer++];
	  $length  = getcompint($data, $Pointer);

=begin pod
=item MIDI::Event::Sysex-f0*I<dtime>, I<raw>)

=item MIDI::Event::Sysex-f7(I<dtime>, I<raw>)

=end pod
	      given $first-byte {
		when 0xf0 {
		    $E = MIDI::Event::Sysex-f0.new(
                                                   time    => $time,
			                           command => $command,
			                           data    => $data.subbuf($Pointer, $length),
		                                  );
                    $Pointer += $length; #  Now move past the data
		}
		when 0xf7 {
		    $E = MIDI::Event::Sysex-f7.new(
                                                   time    => $time,
			                           command => $command,
			                           data    => $data.subbuf($Pointer, $length),
		                                  );
		    $Pointer += $length; #  Now move past the data
		}
                
		######################################################################
		# Now, the MIDI file spec says:
		#  <track data> = <MTrk event>+
		#  <MTrk event> = <delta-time> <event>
		#  <event> = <MIDI event> | <sysex event> | <meta-event>
		# I know that, on the wire, <MIDI event> can include note_on,
		# note_off, and all the other 8x to Ex events, AND Fx events
		# other than F0, F7, and FF -- namely, <song position msg>,
		# <song select msg>, and <tune request>.
		#
		# Whether these can occur in MIDI files is not clear specified from
		# the MIDI file spec.
		#
		# So, I'm going to assume that they CAN, in practice, occur.
		# I don't know whether it's proper for you to actually emit these
		# into a MIDI file.
		#
                @events.push: $E;
    }

=begin pod
=item MIDI::Event::Song-position(I<dtime>)

=end pod
		#  <song position msg> ::=     F2 <data pair>
		when 0xf2 {
		  $E = MIDI::Event::Song-position.new(
						      time  => $time,
						      beats => &read-u14-bit($data.subbuf($Pointer+1, 2) )
						     );
		  $Pointer += 3; # itself, and 2 data bytes
                  @events.push: $E;
		}

=begin pod
=item MIDI::Event:Song-select(I<dtime>, I<song_number>)

=end pod
		#  <song select msg> ::=       F3 <data singlet>
		when 0xf3 {
		  $E = MIDI::Event::Song-select.new(
						    time        => $time,
						    song-number => $data[$Pointer+1],
						   );
		  $Pointer += 2; # itself, and 1 data byte

		  ######################################################################
                  @events.push: $E;
		}

=begin pod
=item MIDI::Event::Tune-request(I<dtime>)

=end pod
		#  <tune request> ::=          F6
		when 0xF6 {    # It's a Tune Request! ################
		  $E = MIDI::Event::Tune-request.new(
						     time => $time
						    );
		  # DTime
		  # What the Sam Scratch would a tune request be doing in a MIDI /file/?
		  ++$Pointer;	# itself
                  @events.push: $E;
		}

		###########################################################################
		## ADD MORE META-EVENTS HERE
		#Done:
		# f0 f7 -- sysexes
		# f2 -- song position
		# f3 -- song select
		# f6 -- tune request
		# ff -- metaevent
		###########################################################################
		#TODO:
		# f1 -- MTC Quarter Frame Message.   one data byte follows.
		#     One data byte follows the Status. It's the time code value, a number
		#     from 0 to 127.
		# f8 -- MIDI clock.  no data.
		# fa -- MIDI start.  no data.
		# fb -- MIDI continue.  no data.
		# fc -- MIDI stop.  no data.
		# fe -- Active sense.  no data.
		# f4 f5 f9 fd -- unallocated

=begin pod
=item MIDI::Event::Raw-data(I<dtime>, I<raw>)

=end pod
# Here we only produce a one-byte piece of raw data.
# But the encoder for 'raw-data' accepts any length of it.
		default {
		  $E = MIDI::Event::Raw.new(
					    command => $first-byte,
					    time    => $time,
					    data    => $data.subbuf($Pointer,1)
					   );
		  # DTime and the Data (in this case, the one Event-byte)
		  ++$Pointer;	# itself
                  @events.push: $E;
		}

		######################################################################
    }
    default { # Fallthru.  How could we end up here? ######################
		note
		  "Aborting track.  Command-byte $first-byte at track offset $Pointer";
		last Event;
             }
}
	  # End of the big if-group


	  #####################################################################
	  ######################################################################
	  ##
	  if $E ~~ (MIDI::Event::End-track) {
	    # This is the code for exceptional handling of the EOT event.
	    $eot = 1;
	    unless %options<no_eot_magic> {
		if $E.time > 0 {
		    $E = MIDI::Event::Text-event.new(
			time => $E.time,
			text => Buf.new(),
		    );
		    # Make up a fictive 0-length text event as a carrier
		    #  for the non-zero delta-time.
		    
		    if ($E ~~ (MIDI::Event::Text-event) and $exclude<text-event>)
		      or ($E ~~ (MIDI::Event::End-track) and $exclude<end-track>) {
                      if $Debug {
                        print " Excluding:\n";
                        dd($E);
		      }
                    } else {
                      if $Debug {
			  print " Processing:\n";
			  dd($E);
		      }
		      if $E {
			  if $exclusive-event-callback {
			      $exclusive-event-callback( $E );
			  } else {
			      $event-callback( $E ) if $event-callback;
			      @events[*-1] = $E;
			  }
		      }
		    }
		    last Event if $eot;
		}
	    }
	      # End of the bigass "Event" while-block
	    
	    return @events;
	  }
	}
    @events;
}

method encode($use-running-status, $last-status is rw --> Buf) {
  (Buf);
}

method encode-text-event($delta-time, $cmd, $text --> Buf) {
    my $buftext = $text !~~ Buf ?? $text.encode() !! $text;
    Buf.new(
        |ber($delta-time),
	0xff,
	$cmd,
	|ber($buftext.elems)
    ) ~ $buftext;
}

}				# class Event

=begin pod
 Each separate event type has a separate class.

 Each class provides at least the following methods:

1. encode -- which encodes the event to a Buf

1. raku   -- which provides a printable version of the object

1. type   -- which provides a printable version of the event type.

=end pod

 sub scale7to16($sval) {
     my $value = ($sval +& 0x7f) +< 9;
     if $value ≥ 0x8000 {
         my $ext = $sval +& 0x3f;
         $value +|= $ext +< 3;
         $value +|= $ext +> 3;
     }
     $value;
 }
 
 sub mkdeltatime2($time is copy --> Buf) {
     my $dt = Buf.new();
     while $time ≥ 2 +< 20 {
         $dt ~= Buf.new(
             0,
             0x4f,
             0xff,
             0xff
         );
         $time -= 0xffff;
     }
     $dt ~ Buf.new(
         0,
         0x40 +| (($time +> 16) +& 0x0f),
         ($time +> 8) +& 0xff,
         $time +& 0xff
     );
 }
 
class MIDI::Event::Note-off is MIDI::Event {
  has $.time is rw;         # explicit in MIDI 1; synthesised in MIDI 2
  has $.group = 0;          # 4 bits, MIDI 2 only
  has $.channel;            # 4 bits
  has $.note-number;        # 7 bits
  has $.velocity;           # 16 bits (upscaled from 7 bits in MIDI 1)
  has $.attribute-type = 0; # 8 bits
  has $attribute = 0;       # 16 bits

  method !encode1($use-running-status, $last-status is rw --> Buf) {
    my $status = 0x80 +| $!channel +& 0x0f;
    $status +|= 0x10 if $!velocity == 0; # Use note-on command
    my $use-old-status = $use-running-status & ($status == $last-status);
    $last-status = $status;
    $use-old-status
      ?? # we can use running status
        Buf.new(|ber($!time),          $!note-number +& 0x7f,
                                       $!velocity +& 0x7f)
      !! # otherwise
        Buf.new(|ber($!time), $status, $!note-number +& 0x7f,
                                       $!velocity +& 0x7f)
    ;
  }

  method !encode2(--> Buf) {
      my $buf = mkdeltatime2($!time);
      $buf ~ Buf.new(
          0x40 +| ($!group +& 0x0f),
          0x80 +| ($!channel +& 0x0f),
          $!note-number +& 0x7f,
          $!attribute-type +& 0xff,
          ($!velocity +> 8) +& 0xff,
          $!velocity +& 0xff,
          ($!attribute +> 8) +& 0xff,
          $!attribute +& 0xff,
      );
  }

  method encode($use-running-status, $last-status is rw --> Buf) {
      if True {
          self!encode1($use-running-status, $last-status);
      } else {
          self!encode2()
      }
  }

  method raku() {
      "MIDI::Event::Note-off.new(:time($!time), :group($!group), :channel($!channel), :note-number($!note-number), :velocity($!velocity), :attribute-type($!attribute-type) :attribute($!attribute))";
  }

  method type {
      'note-off';
  }
}

class MIDI::Event::Note is MIDI::Event {
    has $.time is rw;
    has $.duration is rw;
    has $.group;
    has $.channel;
    has $.note-number;
    has $.velocity;
    has $.attribute-type;
    has $.attribute;

    # no need for an encode method -- it's not a valid midi message, but we'll provide one for consistency
    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new();
    }
    
    method raku() {
        "MIDI::Event::Note.new(:time($!time), :duration($!duration), :group($!group), :channel($!channel), :note-number($!note-number), :velocity($!velocity), :attribute-type($!attribute-type), :attribute($!attribute))";
    }

    method type {
        'note';
    }
}

class MIDI::Event::Note-on is MIDI::Event {
    has $.time is rw;
    has $.group = 0;
    has $.channel;
    has $.note-number;
    has $.velocity;
    has $.attribute-type = 0;
    has $.attribute = 0;
    
    method !encode1($use-running-status, $last-status is rw --> Buf) {
        my $status = 0x90 +| $!channel +& 0x0f;
        my $use-old-status = $use-running-status & ($status == $last-status);
        $last-status = $status;
        $use-old-status
        ?? # we can use running status
        Buf.new(|ber($!time),          $!note-number +& 0x7f, $!velocity +& 0x7f)
        !! # otherwise
        Buf.new(|ber($!time), $status, $!note-number +& 0x7f, $!velocity +& 0x7f)
        ;
    }
    
  method !encode2(--> Buf) {
      my $buf = mkdeltatime2($!time);
      $buf ~ Buf.new(
          0x40 +| ($!group +& 0x0f),
          0x90 +| ($!channel +& 0x0f),
          $!note-number +& 0x7f,
          $!attribute-type +& 0xff,
          ($!velocity +> 8) +& 0xff,
          $!velocity +& 0xff,
          ($!attribute +> 8) +& 0xff,
          $!attribute +& 0xff,
      );
  }

  method encode($use-running-status, $last-status is rw --> Buf) {
      if True {
          self!encode1($use-running-status, $last-status);
      } else {
          self!encode2()
      }
  }

    method raku() {
        "MIDI::Event::Note-on.new(:time($!time), :channel($!channel), :note-number($!note-number), :velocity($!velocity))";
    }
    
    method type {
        'note-on';
    }
}

class MIDI::Event::Key-after-touch is MIDI::Event {
    has $.time is rw;
    has $.channel;
    has $.note-number;
    has $.aftertouch;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        my $status = 0xa0 +| $!channel +& 0x0f;
        my $use-old-status = $use-running-status & ($status == $last-status);
        $last-status = $status;
        $use-old-status
        ?? # we can use running status
        Buf.new(|ber($!time),          $!note-number +& 0x7f, $!aftertouch +& 0x7f)
        !! # otherwise
        Buf.new(|ber($!time), $status, $!note-number +& 0x7f, $!aftertouch +& 0x7f)
        ;
    }
    
    method raku() {
        "MIDI::Event::Key-after-touch.new(:time($!time), :channel($!channel), :note-number($!note-number), :aftertouch($!aftertouch))";
    }
    
    method type {
        'key-after-touch';
    }
}

class MIDI::Event::Controller-change is MIDI::Event {
    has $.time is rw;
    has $.channel;
    has $.controller;
    has $.value;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        my $status = 0xb0 +| $!channel +& 0x0f;
        my $use-old-status = $use-running-status & ($status == $last-status);
        $last-status = $status;
        $use-old-status
        ?? # we can use running status
        Buf.new(|ber($!time),          $!controller +& 0x7f, $!value +& 0x7f)
        !! # otherwise
        Buf.new(|ber($!time), $status, $!controller +& 0x7f, $!value +& 0x7f)
        ;
    }
    
    method raku() {
        "MIDI::Event::Controller-change.new(:time($!time), :channel($!channel), :controller($!controller), :value($!value))";
    }

  method type {
      'controller-change';
  }
}

class MIDI::Event::Patch-change is MIDI::Event {
  has $.time is rw;
  has $.channel;
  has $.patch-number;

  method encode($use-running-status, $last-status is rw --> Buf) {
    my $status = 0xc0 +| $!channel +& 0x0f;
    my $use-old-status = $use-running-status & ($status == $last-status);
    $last-status = $status;
    $use-old-status
      ?? # we can use running status
        Buf.new(|ber($!time),          $!patch-number +& 0x7f)
      !! # otherwise
        Buf.new(|ber($!time), $status, $!patch-number +& 0x7f)
    ;
  }

  method raku() {
      "MIDI::Event::Patch-change.new(:time($!time), :channel($!channel), :patch-number($!patch-number))";
  }

  method type {
      'patch-change';
  }
}

class MIDI::Event::Channel-after-touch is MIDI::Event {
    has $.time is rw;
    has $.channel;
    has $.aftertouch;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        my $status = 0xd0 +| $!channel +& 0x0f;
        my $use-old-status = $use-running-status & ($status == $last-status);
        $last-status = $status;
        $use-old-status
        ?? # we can use running status
        Buf.new(|ber($!time),          $!channel    +& 0x7f, $!aftertouch +& 0x7f)
        !! # otherwise
        Buf.new(|ber($!time), $status, $!channel    +& 0x7f, $!aftertouch +& 0x7f)
    }
    
    method raku() {
        "MIDI::Event::Channel-after-touch(:time($!time), :channel($!channel), :aftertouch($!aftertouch))";
    }
    
    method type {
        'channel-after-touch';
    }
}

class MIDI::Event::Pitch-wheel-change is MIDI::Event {
    has $.time is rw;
    has $.channel;
    has $.value;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        my $status = 0xd0 +| $!channel +& 0x0f;
        my $use-old-status = $use-running-status & ($status == $last-status);
        $last-status = $status;
        $use-old-status
        ?? # we can use running status
        Buf.new(|ber($!time),           ($!value + 0x2000)       +& 0x7f, (($!value + 0x2000) +> 7) +& 0x7f)
        !! # otherwise
        Buf.new(|ber($!time), $status,  ($!value + 0x2000)       +& 0x7f, (($!value + 0x2000) +> 7) +& 0x7f)
    }
    
    method raku() {
        "MIDI::Event::Pitch-wheel-change.new(:time($!time), :channel($!channel), :value($!value))";
    }
    
    method type {
        'pitch-wheel-change';
    }
}

class MIDI::Event::Set-sequencer-number is MIDI::Event {
    has $.time is rw;
    has $.sequence-number;
    
    method raku() {
        "MIDI::Event::Set-sequence-number.new(:time($!time), :sequence-number($!sequence-number))";
    }   
    
    method type {
        'set-sequence-number';
    }
}

class MIDI::Event::Text-event is MIDI::Event {
    has $.time is rw;
    has Buf $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x01, $!text;
    }
    
    method raku() {
        "MIDI::Event::Text-event.new(:time($!time), :text(\"$!text.decode('latin1')\")";
    }
    
    method type {
        'text-event';
    }
}

class MIDI::Event::Copyright is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x02, $!text;
    }
    
    method raku() {
        "MIDI::Event::Copyright.new(:time($!time), :text($!text.decode('latin1')))";
    }
    
    method type {
        'copyright';
    }
}

class MIDI::Event::Track-name is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x03, $!text;
    }
    
    method raku() {
        "MIDI::Event::Track-name.new(:time($!time), :text($!text.decode('latin1')))";
    }
    
    method type {
        'track-name';
    }
}

class MIDI::Event::Instrument-name is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x04, $!text;
    }
    
    method raku() {
        "MIDI::Event::Instrument-name.new(:time($!time), :text($!text.decode('latin1'))";
    }
    
    method type {
        'instrument-name';
    }
}

class MIDI::Event::Lyric is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x05, $!text;
    }
    
    method raku() {
        "MIDI::Event::Lyric.new(:time($!time), :text({dump-quote($!text)})";
    }
    
    method type {
        'lyric';
    }
}

class MIDI::Event::Marker is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x06, $!text;
    }
    
    method raku() {
        "MIDI::Event::Marker.new(:time($!time), :text(\"$!text.decode('lartin1')\"))";
    }
    
    method type {
        'marker';
    }
}

class MIDI::Event::Cue-point is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x07, $!text;
    }
    
    method raku() {
        "MIDI::Event::Cue-point.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }
    
    method type {
        'cue-point';
    }
}

class MIDI::Event::Text-event_08 is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x08, $!text;
    }
    
    method raku() {
        "MIDI::Event::Text-event_08.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }
    
    method type {
        'text-event_08';
    }
}

class MIDI::Event::Text-event_09 is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x09, $!text;
    }
    
    method raku() {
        "MIDI::Event::Text-event_09.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }
    
    method type {
        'text-event_09';
    }
}

class MIDI::Event::Text-event_0a is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x0a, $!text;
    }
    
    method raku() {
        "MIDI::Event::Text-event_0a.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }
    
    method type {
        'text-event_0a';
    }
}

class MIDI::Event::Text-event_0b is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x0b, $!text;
    }
    
    method raku() {
        "MIDI::Event::Text-event_0b.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }
    
    method type {
        'text-event_0b';
    }
}

class MIDI::Event::Text-event_0c is MIDI::Event {
    has $.time is rw;
    has $.text;
    
    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x0c, $!text;
    }
    
    method raku() {
        "MIDI::Event::Text-event_0c.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }

    method type {
        'text-event_0c';
    }
}

class MIDI::Event::Text-event_0d is MIDI::Event {
    has $.time is rw;
    has $.text;

    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x0d, $!text;
    }

    method raku() {
        "MIDI::Event::Text-event_0d.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }

    method type {
        'text-event_0d';
    }
}

class MIDI::Event::Text-event_0e is MIDI::Event {
    has $.time is rw;
    has $.text;

    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x0e, $!text;
    }

    method raku() {
        "MIDI::Event::Text-event_0e.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }

    method type {
        'text-event_0e';
    }
}

class MIDI::Event::Text-event_0f is MIDI::Event {
    has $.time is rw;
    has $.text;

    method encode($use-running-status, $last-status is rw --> Buf) {
        self.encode-text-event: $!time, 0x0f, $!text;
    }

    method raku() {
        "MIDI::Event::Text-event_0f.new(:time($!time), :text(\"$!text.decode('latin1')\"))";
    }

    method type {
        'text-event_0f';
    }
}

class MIDI::Event::End-track is MIDI::Event {
    has $.time is rw;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(0x00, 0xff, 0x2f, 0x00);
    }

    method raku() {
        "MIDI::Event::End-track.new(:time($!time))";
    }

    method type {
        'end-track';
    }
}

class MIDI::Event::Set-tempo is MIDI::Event {
    has $.time is rw;
    has $.tempo; # microseconds/quarter note

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(|ber($!time),
                0xff,
	        0x51,
	        3,
                ($!tempo +> 16) +& 0xff,
	        ($!tempo +>  8) +& 0xff,
	        ($!tempo      ) +& 0xff;
	       );
    }

    method raku() {
        "MIDI::Event::Set-tempo.new(:time($!time), :tempo($!tempo))";
    }

    method type {
        'set-tempo';
    }
}

class MIDI::Event::Smpte-offset is MIDI::Event {
    has $.time is rw;
    has $.hours;
    has $.minutes;
    has $.seconds;
    has $.fr;
    has $.ff; 

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xff,
	    0x51,
	    5,
	    $!hours,
	    $!minutes,
	    $!seconds,
	    $!fr,
	    $!ff
        );
    }

    method raku() {
        "MIDI::Event::Smpte-offset.new(:time($!time), :hours($!hours), :minutes($!minutes), :seconds($!seconds), :fr($!fr), :ff($!ff))";
    }

    method type {
        'smpte-offset';
    }
}

class MIDI::Event::Time-signature is MIDI::Event {
    has $.time is rw;
    has $.numerator;
    has $.denominator;
    has $.ticks;
    has $.quarter-notes;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xff,
	    0x58,
	    4,
	    $!numerator,
	    $!denominator,
	    $!ticks,
	    $!quarter-notes
        );
    }

    method raku() {
        "MIDI::Event::Time-signature.new(:time($!time), :numerator($!numerator), :denominator($!denominator), :ticks($!ticks), :quarter-notes($!quarter-notes))";
    } 

    method type {
        'time-signature';
    }
}

class MIDI::Event::Key-signature is MIDI::Event {
    has $.time is rw;
    has $.sharps;
    has $.major-minor;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xff,
	    0x59,
	    2,
	    $!sharps,
	    $!major-minor
        );
    }

    method raku() {
        "MIDI::Event::Key-signature.new(:time($!time), :sharps($!sharps), :major-minor($!major-minor))";
    }

    method type {
        'key-signature';
    }
}

class MIDI::Event::Sequencer-specific is MIDI::Event {
    has $.time is rw;
    has $.data;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xff,
	    0x7f,
	    |ber($!data.bytes),
	    $!data
        ); # FIX
    }

    method raku() {
        "MIDI::Event::Sequencer-specific.mew(:time($!time), :data(Buf.new($!data)))";
    }

    method type {
        'sequencer-specific';
    }
}

class MIDI::Event::sysex-f0 is MIDI::Event {
    has $.time is rw;
    has $.data;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xf0,
	    |ber($!data.bytes),
	    $!data
        );
    }

    method raku() {
        "MIDI::Event::sysex-f0.new(:time($!time), :data(Buf.new($!data)))";
    }

    method type {
        'sysex-f0';
    }
}

class MIDI::Event::sysex-f7 is MIDI::Event {
    has $.time is rw;
    has $.data;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xf7,
	    |ber($!data.bytes),
	    $!data
        );
    }

    method raku() {
        "MIDI::Event::sysex-f7.new(:time($!time), :data(Buf.new($!data)))";
    }

    method type {
        'sysex-f7';
    }
}

class MIDI::Event::Song-position is MIDI::Event {
    has $.time is rw;
    has $.beats;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(|ber($!time), 0xf2) ~ self.write-u14-bit($!beats);
    }

    method raku() {
        "MIDI::Event::Song-position.new(:time($!time), :beats($!beats))";
    }

    method type {
        'song-position';
    }
}

class MIDI::Event::Song-select is MIDI::Event {
    has $.time is rw;
    has $.song-number;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
            0xf1,
	    $!song-number
        );
    }

    method raku() {
        "MIDI::Event::Song-select.new(:time($!time), :song-number($!song-number))";
    }

    method type {
        'song-select';
    }
}

class MIDI::Event::Tune-request is MIDI::Event {
    has $.time is rw;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(|ber($!time), 0xf6);
    }

    method raku() {
        "MIDI::Event::Tune-request.new(:time($!time))";
    }

    method type {
        'tune-request';
    }
}

class MIDI::Event::Raw is MIDI::Event {
    has $.time is rw;
    has $.command;
    has $.data;

    method encode($use-running-status, $last-status is rw --> Buf) {
        Buf.new(
            |ber($!time),
	    0xff,
	    $!command,
	    |ber($!data.length),
	    $!data
        );
    }

    method raku() {
        "MIDI::Event::Raw.new(:time($!time), :command($!command), :data(Buf.new($!data)))";
    }

    method type {
        'raw';
    }
}
