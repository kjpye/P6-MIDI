unit class MIDI::Event;

use v6;

my $Debug = 1;
my $VERSION = '0.84';

#First 100 or so lines of this module are straightforward.  The actual
# encoding logic below that is scary, tho.

=begin pod
=head1 NAME

MIDI::Event - MIDI events

=head1 SYNOPSIS

  # Dump a MIDI file's text events
  die "No filename" unless @ARGV;
  use MIDI;  # which "use"s MIDI::Event;
  MIDI::Opus->new( {
     "from_file"                => $ARGV[0],
     "exclusive_event_callback" => sub{print "$_[2]\n"},
     "include"                  => \@MIDI::Event::Text_events
   } ); # These options percolate down to MIDI::Event::decode
  exit;

=head1 DESCRIPTION

Functions and lists to do with MIDI events and MIDI event structures.

An event is a list, like:

  ( 'note_on', 141, 4, 50, 64 )

where the first element is the event name, the second is the
delta-time, and the remainder are further parameters, per the
event-format specifications below.

An I<event structure> is a list of references to such events -- a
"LoL".  If you don't know how to deal with LoLs, you I<must> read
L<perllol>.

=head1 GOODIES

For your use in code (as in the code in the Synopsis), this module
provides a few lists:

=over

=item @MIDI_events

a list of all "MIDI events" AKA voice events -- e.g., 'note_on'

=item @Text_events

a list of all text meta-events -- e.g., 'track_name'

=item @Nontext_meta_events

all other meta-events (plus 'raw_data' and F-series events like
'tune_request').

=item @Meta-events

the combination of Text_events and Nontext_meta_events.

=item @All-events

the combination of all the above lists.

=back

=cut
=end pod

# Some helper functions to get data out of a buffer (to replace the original
# unpack calls.

sub getubyte($data, $pointer is rw) {
    my $byte = $data[$pointer++];
    $byte;
}

sub signextendbyte($byte) {
    if $byte +& 0x80 {
        return $byte - 256;
    }
    $byte;
}

sub getsbyte($data, $pointer is rw) {
    my $byte = $data[$pointer++];
    if $byte +& 0x80 {
        $byte -= 256;
    }
    $byte;
}

sub getushort($data, $pointer is rw) { # network order
    my $value = $data[$pointer++] +< 8;
       $value + $data[$pointer++]     ;
}

sub getint24($data) {
    my $value  = $data[0] +< 16;
       $value += $data[1] +<  8;
       $value +  $data[2]      ;
}

sub getcompint($data, $pointer is rw) {
    my $value = 0;
    my $byte;
    while $byte = $data[$pointer++] +& 0x80 {
	$value +<= 7;
        $value +|= $byte +& 0x7f;
    }
    $value +<= 7;
    $value +|= $byte +& 0x7f;
}

# The contents of an event:
has $.type; # a string
has $!delta-time = 0;
has @.args; # event type specific

###########################################################################
# Some public-access lists:

my @MIDI-events = <
  note_off note_on key_after_touch control_change patch_change
  channel_after_touch pitch_wheel_change set_sequence_number
>;

my @Text-events = <
  text_event copyright_text_event track_name instrument_name lyric
  marker cue_point text_event_08 text_event_09 text_event_0a
  text_event_0b text_event_0c text_event_0d text_event_0e text_event_0f
>;

my @Nontext-meta-events = <
  end_track set_tempo smpte_offset time_signature key_signature
  sequencer_specific raw_meta_event sysex_f0 sysex_f7 song_position
  song_select tune_request raw_data
>;

# Actually, 'tune_request', for one, is is F-series event, not a
#  strictly-speaking meta-event
my @Meta-events = (@Text-events, @Nontext-meta-events).flat;
my @All-events = (@MIDI-events, @Meta-events).flat;

=begin pod
=head1 FUNCTIONS

This module provides three functions of interest, which all act upon
event structures.  As an end user, you probably don't need to use any
of these directly, but note that options you specify for
MIDI::Opus->new with a from_file or from_handle options will percolate
down to these functions; so you should understand the options for the
first two of the below functions.  (The casual user should merely skim
this section.)

=over

=item MIDI::Event::decode( \$data, { ...options... } )

This takes a I<reference> to binary MIDI data and decodes it into a
new event structure (a LoL), a I<reference> to which is returned.
Options are:

=over 16

=item 'include' => LISTREF

I<If specified>, listref is interpreted as a reference to a list of
event names (e.g., 'cue_point' or 'note_off') such that only these
events will be parsed from the binary data provided.  Events whose
names are NOT in this list will be ignored -- i.e., they won't end up
in the event structure, and they won't be each passed to any callbacks
you may have specified.

=item 'exclude' => LISTREF

I<If specified>, listref is interpreted as a reference to a list of
event names (e.g., 'cue_point' or 'note_off') that will NOT be parsed
from the binary stream; they'll be ignored -- i.e., they won't end up
in the event structure, and they won't be passed to any callbacks you
may have specified.  Don't specify both an include and an exclude
list.  And if you specify I<neither>, all events will be decoded --
this is what you probably want most of the time.  I've created this
include/exclude functionality mainly so you can scan a file rather
efficiently for just a few specific event types, e.g., just text
events, or just sysexes.

=item 'no_eot_magic' => 0 or 1

See the description of C<'end_track'>, in "EVENTS", below.

=item 'event_callback' => CODEREF

If defined, the code referred to (whether as C<\&wanted> or as
C<sub { BLOCK }>) is called on every event after it's been parsed into
an event list (and any EOT magic performed), but before it's added to
the event structure.  So if you want to alter the event stream on the
way to the event structure (which counts as deep voodoo), define
'event_callback' and have it modify its C<@_>.

=item 'exclusive_event_callback' => CODEREF

Just like 'event_callback'; but if you specify this, the callback is
called I<instead> of adding the events to the event structure.  (So
the event structure returned by decode() at the end will always be
empty.)  Good for cases like the text dumper in the Synopsis, above.

=back

=item MIDI::Event::encode( \@events, {...options...})

This takes a I<reference> to an event structure (a LoL) and encodes it
as binary data, which it returns a I<reference> to.  Options:

=over 16

=item 'unknown_callback' => CODEREF

If this is specified, it's interpreted as a reference to a subroutine
to be called when an unknown event name (say, 'macro_10' or
something), is seen by encode().  The function is fed all of the event
(its name, delta-time, and whatever parameters); the return value of
this function is added to the encoded data stream -- so if you don't
want to add anything, be sure to return ''.

If no 'unknown_callback' is specified, encode() will C<warn> (well,
C<carp>) of the unknown event.  To merely block that, just set
'unknown_callback' to C<sub{return('')}>

=item 'no_eot_magic' => 0 or 1

Determines whether a track-final 0-length text event is encoded as
a end-track event -- since a track-final 0-length text event probably
started life as an end-track event read in by decode(), above.

=item 'never_add_eot' => 0 or 1

If 1, C<encode()> never ever I<adds> an end-track (EOT) event to the
encoded data generated unless it's I<explicitly> there as an
'end_track' in the given event structure.  You probably don't ever
need this unless you're encoding for I<straight> writing to a MIDI
port, instead of to a file.

=item 'no_running_status' => 0 or 1

If 1, disables MIDI's "running status" compression.  Probably never
necessary unless you need to feed your MIDI data to a strange old
sequencer that doesn't understand running status.

=back

Note: If you're encoding just a single event at a time or less than a
whole trackful in any case, then you probably want something like:

          $data_r = MIDI::Event::encode(
            [
              [ 'note_on', 141, 4, 50, 64 ]
            ],
            { 'never_add_eot' => 1} );

which just encodes that one event I<as> an event structure of one
event -- i.e., an LoL that's just a list of one list.

But note that running status will not always apply when you're
encoding less than a whole trackful at a time, since running status
works only within a LoL encoded all at once.  This'll result in
non-optimally compressed, but still effective, encoding.

=item MIDI::Event::copy_structure()

This takes a I<reference> to an event structure, and returns a
I<reference> to a copy of it.  If you're thinking about using this, you
probably should want to use the more straightforward

          $track2 = $track->copy

instead.  But it's here if you happen to need it.

=back

=cut
=end pod
###########################################################################
method dump {
  print( "        [", self._dump-quote, "\n" );
}

method copy-structure {
  # Takes a REFERENCE to an event structure (a ref to a LoL),
  # and returns a REFERENCE to a copy of that structure.

  fail
# TODO  return [  map( [@$_], @$events_r )  ];
}

###########################################################################
# The module code below this line is full of frightening things, all to do
# with the actual encoding and decoding of binary MIDI data.
###########################################################################

sub read-u14-bit($in) {
  # Decodes to a value 0 to 16383, as is used for some event encoding
  my ($b1, $b2) = $in.comb;
  return ($b1.ord | ($b2.ord +< 7));
}

sub write-u14-bit($in) {
  # encode a 14 bit quantity, as needed for some events
  return
    pack("C2",
         ($in +& 0x7F), # lower 7 bits
         (($in +> 7) +& 0x7F), # upper 7 bits
	);
}

###########################################################################
#
# One definite assumption is made here: that "variable-length-encoded"
# quantities MUST NOT exceed 0xFFFFFFF (encoded, "\xFF\xFF\xFF\x7F")
# -- i.e., must not take more than 4 bytes to encode.
#
###

sub decode(Buf $data, *%options) { # decode track data into an array of events
  # Calling format: a REFERENCE to a big chunka MTrk track data.
  # Returns an array of events.
  # Note that this is a function call, not a constructor method call.

  my @events = ();

  my %exclude = ();
  if %options<exclude> {
      %exclude = %options<exclude> Z=> 1;
  } else {
    # If we get an include (and no exclude), make %exclude a list
    #  of all possible events, /minus/ what include specifies
    if %options<include> {
	%exclude = @All-events Z=> 1;
        for %options<include> -> $type {
          %exclude{$type}:delete;
        }
    }
  }
  print "Exclusions: ", join(' ', map("<$_>", sort keys %exclude)), "\n"
    if $Debug;

  my $event_callback = Nil;
  if %options<event_callback> {
# TODO
  }
  my $exclusive_event_callback = Nil;
  if %options<exclusive_event_callback> {
# TODO
  }


  my $Pointer = 0; # points to where I am in the data
  ######################################################################
  if $Debug {
    if $Debug == 1 {
      print "Track data of ", $data.bytes, " bytes.\n";
    } else {
      print "Track data of ", $data.bytes, " bytes: <", $data ,">\n";
    }
  }

=begin pod
=head1 EVENTS AND THEIR DATA TYPES

=head2 DATA TYPES

Events use these data types:

=over

=item channel = a value 0 to 15

=item note = a value 0 to 127

=item dtime = a value 0 to 268,435,455 (0x0FFFFFFF)

=item velocity = a value 0 to 127

=item channel = a value 0 to 15

=item patch = a value 0 to 127

=item sequence = a value 0 to 65,535 (0xFFFF)

=item text = a string of 0 or more bytes of of ASCII text

=item raw = a string of 0 or more bytes of binary data

=item pitch_wheel = a value -8192 to 8191 (0x1FFF)

=item song_pos = a value 0 to 16,383 (0x3FFF)

=item song_number = a value 0 to 127

=item tempo = microseconds, a value 0 to 16,777,215 (0x00FFFFFF)

=back

For data types not defined above, (e.g., I<sf> and I<mi> for
C<'key_signature'>), consult L<MIDI::Filespec> and/or the source for
C<MIDI::Event.pm>.  And if you don't see it documented, it's probably
because I don't understand it, so you'll have to consult a real MIDI
reference.

=head2 EVENTS

And these are the events:

=over

=cut
=end pod

  # Things I use variously, below.  They're here just for efficiency's sake,
  # to avoid re-mying on each iteration.
  my ($command, $channel, $parameter, $length, $time, $remainder);

  my $event_code = -1; # used for running status

  my $event_count = 0;
Event:  # Analyze the event stream.
  while $Pointer + 1 < $data.bytes {
    # loop while there's anything to analyze ...
    my $eot = 0; # When 1, the event registrar aborts this loop
    ++$event_count;

    my $E;
    # E for event -- this is what we'll feed to the event registrar
    #  way at the end.

    # Slice off the delta time code, and analyze it
      #!# print "Chew-code <", substr($$data_r,$Pointer,4), ">\n";
    $time = getcompint($data, $Pointer);
      #!# print "Delta-time $time using ", 4 - length($remainder), " bytes\n"
      #!#  if $Debug > 1;

    # Now let's see what we can make of the command
    my $first_byte = subbuf($data, $Pointer, 1).ord;
      # Whatever parses $first_byte is responsible for moving $Pointer
      #  forward.
      #!#print "Event \# $event_count: $first_byte at track-offset $Pointer\n"
      #!#  if $Debug > 1;

    ######################################################################
    if $first_byte < 0xF0 { # It's a MIDI event ##########################
      if $first_byte >= 0x80 {
	print "Explicit event $first_byte" if $Debug > 2;
        ++$Pointer; # It's an explicit event.
        $event_code = $first_byte;
      } else {
        # It's a running status mofo -- just use last $event_code value
        if $event_code == -1 {
          note "Uninterpretable use of running status; Aborting track."
            if $Debug;
          last Event;
        }
        # Let the argument-puller-offer move Pointer.
      }
      $command = $event_code +& 0xF0;
      $channel = $event_code +& 0x0F;

      if $command == 0xC0 || $command == 0xD0 {
        #  Pull off the 1-byte argument
        $parameter = $data.subbuf($Pointer, 1);
        ++$Pointer;
      } else { # pull off the 2-byte argument
        $parameter = $data.subbuf($Pointer, 2);
        $Pointer += 2;
      }

      ###################################################################
      # MIDI events

=begin pod
=item ('note_off', I<dtime>, I<channel>, I<note>, I<velocity>)

=cut 
=end pod
      if $command      == 0x80 {
	next if %exclude<note_off>;
        # for sake of efficiency
        $E = MIDI::Event.new( type       => 'note_off',
			      delta-time => $time,
			      args       => [
					     $channel,
					     $parameter[0],
					     $parameter[1],
					    ]
			    );

=begin pod
=item ('note_on', I<dtime>, I<channel>, I<note>, I<velocity>)

=cut 
=end pod
      } elsif $command == 0x90 {
	next if %exclude<note_on>;
        $E = MIDI::Event.new( type       => 'note_on',
			      delta-time => $time,
			      args => [
				       $channel,
				       $parameter[0],
				       $parameter[1]
				      ]
			    );

=begin pod
=item ('key_after_touch', I<dtime>, I<channel>, I<note>, I<velocity>)

=cut 
=end pod
      } elsif $command == 0xA0 {
	next if %exclude<key_after_touch>;
        $E = MIDI::Event.new( type       => 'key_after_touch',
                              delta-time => $time,
                              args       => [$channel,
                                             $parameter[0],
                                             $parameter[1],
                                            ]
                            );

=begin pod
=item ('control_change', I<dtime>, I<channel>, I<controller(0-127)>, I<value(0-127)>)

=cut 
=end pod
      } elsif $command == 0xB0 {
	next if %exclude<control_change>;
        $E = MIDI::Event.new( type       => 'control_change',
                              delta-time => $time,
                              args       => [$channel,
                                             $parameter[0],
                                             $parameter[1],
                                            ]
                            );

=begin pod
=item ('patch_change', I<dtime>, I<channel>, I<patch>)

=cut 
=end pod
      } elsif $command == 0xC0 {
	next if %exclude<patch_change>;
        $E = MIDI::Event.new( type       => 'patch_change',
			      delta-time => $time,
			      args       => [
					     $channel,
					     $parameter[0],
					    ]
			    );

=begin pod
=item ('channel_after_touch', I<dtime>, I<channel>, I<velocity>)

=cut 
=end pod
      } elsif $command == 0xD0 {
	next if %exclude<channel_after_touch>;
        $E = MIDI::Event.new( type       => 'channel_after_touch',
			      delta-time => $time,
			      args       => [
					     $channel,
					     $parameter[0],
					    ]
			    );

=begin pod
=item ('pitch_wheel_change', I<dtime>, I<channel>, I<pitch_wheel>)

=cut 
=end pod
      } elsif $command == 0xE0 {
	next if %exclude<pitch_wheel_change>;
        $E = MIDI::Event.new( type       => 'pitch_wheel_change',
			      delta-time => $time,
			      args       => [
					     $channel,
					     &read-u14-bit($parameter) - 0x2000
					    ]
			    );
      } else {
        note  # Should be QUITE impossible!
         "SPORK ERROR M:E:1 in track-offset $Pointer\n";
      }

    ######################################################################
    } elsif $first_byte == 0xFF { # It's a Meta-Event! ##################
      $command = $data[$Pointer++];
      $length = getcompint($data, $Pointer);

=begin pod
=item ('set_sequence_number', I<dtime>, I<sequence>)

=cut 
=end pod
  given $command {
      when 0x00 {
         $E = MIDI::Event.new( type       => 'set_sequence_number',
                               delta-time => $time,
                               args       => [
					       getushort($data, $Pointer),
					     ]
                             );

      # Defined text events ----------------------------------------------

=begin pod
=item ('text_event', I<dtime>, I<text>)

=item ('copyright_text_event', I<dtime>, I<text>)

=item ('track_name', I<dtime>, I<text>)

=item ('instrument_name', I<dtime>, I<text>)

=item ('lyric', I<dtime>, I<text>)

=item ('marker', I<dtime>, I<text>)

=item ('cue_point', I<dtime>, I<text>)

=item ('text_event_08', I<dtime>, I<text>)

=item ('text_event_09', I<dtime>, I<text>)

=item ('text_event_0a', I<dtime>, I<text>)

=item ('text_event_0b', I<dtime>, I<text>)

=item ('text_event_0c', I<dtime>, I<text>)

=item ('text_event_0d', I<dtime>, I<text>)

=item ('text_event_0e', I<dtime>, I<text>)

=item ('text_event_0f', I<dtime>, I<text>)

=cut 
'
=end pod
      } 
      when 0x01 {
         $E =  MIDI::Event.new( type       => 'text_event',
                                delta-time => $time,
                                args       => [
                                                subbuf($data, $Pointer, $length)
                                              ]
                              );  # DTime, TData
      } 
      when 0x02 {
         $E = MIDI::Event.new( type       => 'copyright_text_event',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x03 {
         $E = MIDI::Event.new( type       => 'track_name',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x04 {
         $E = MIDI::Event.new( type       => 'instrument_name',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x05 {
         $E = MIDI::Event.new( type       => 'lyric',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x06 {
         $E = MIDI.Event.new( type       => 'marker',
                              delta-time => $time,
                              args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                            );  # DTime, TData
      }
      when 0x07 {
         $E = MIDI::Event.new( type       => 'cue_point',
                               delta-time => $time,
                               args       => [
                                              subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData

      # Reserved but apparently unassigned text events --------------------
      }
      when 0x08 {
         $E = MIDI::Event.new( type       => 'text_event_08',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                            );  # DTime, TData
      }
      when 0x09 {
         $E = MIDI::Event.new( type       => 'text_event_09',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x0a {
         $E = MIDI::Event.new( type       => 'text_event_0a',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x0b {
         $E = MIDI::Event.new( type       => 'text_event_0b',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ] # DTime, TData
                             );
      }
      when 0x0c {
         $E = MIDI::Event.new( type       => 'text_event_0c',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x0d {
         $E = MIDI::Event.new( type       => 'text_event_0d',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                            );  # DTime, TData
      }
      when 0x0e {
         $E = MIDI::Event.new( type       => 'text_event_0e',
                               delta-time => $time,
                               args       => [
                                                 subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData
      }
      when 0x0f {
         $E = MIDI::Event.new( type       => 'text_event_0f',
                               delta-time => $time,
                               args       => [
                                              subbuf($data, $Pointer, $length)
                                             ]
                             );  # DTime, TData

      # Now the sticky events ---------------------------------------------

=begin pod
=item ('end_track', I<dtime>)

=cut
=end pod
      }
      when 0x2F {
         $E = MIDI::Event.new( type       => 'end_track',
                               delta-time => $time
                             );  # DTime
           # The code for handling this oddly comes LATER, in the
           #  event registrar.

=begin pod
=item ('set_tempo', I<dtime>, I<tempo>)

=cut
=end pod
      }
      when 0x51 {
         $E = MIDI::Event.new( type       => 'set_tempo',
                               delta-time => $time,
                               args       => [
                                               getint24($data),
                                             ]
                             );  # DTime, Microseconds

=begin pod
=item ('smpte_offset', I<dtime>, I<hr>, I<mn>, I<se>, I<fr>, I<ff>)

=cut
=end pod
      }
      when 0x54 {
         $E = MIDI::Event.new( type       => 'smpte_offset',
                               delta-time => $time,
                               args       => [
                                               $data[$Pointer],
                                               $data[$Pointer+1],
                                               $data[$Pointer+2],
                                               $data[$Pointer+3],
                                               $data[$Pointer+4],
                                            ]
                             ); # DTime, HR, MN, SE, FR, FF

=begin pod
=item ('time_signature', I<dtime>, I<nn>, I<dd>, I<cc>, I<bb>)

=cut
=end pod
      }
      when 0x58 {
         $E = MIDI::Event.new( type       => 'time_signature',
                               delta-time => $time,
                               args       => [
                                               $data[$Pointer],
                                               $data[$Pointer+1],
                                               $data[$Pointer+2],
                                               $data[$Pointer+3],
                                            ]
                            ); # DTime, NN, DD, CC, BB

=begin pod
=item ('key_signature', I<dtime>, I<sf>, I<mi>)

=cut
=end pod
      }
      when 0x59 {
         $E = MIDI::Event.new( type       => 'key_signature',
                               delta-time => $time,
                               args       => [
                                               signextendbyte($data[0]),
                                               $data[1], # unsigned
                                             ]
                            ); # DTime, SF(signed), MI

=begin pod
=item ('sequencer_specific', I<dtime>, I<raw>)

=cut
=end pod
      }
      when 0x7F {
         $E = MIDI::Event.new( type       => 'sequencer_specific',
                               delta-time => $time,
                               args       => [
                                               subbuf($data, $Pointer, $length)
                                             ]
                             ); # DTime, Binary Data

=begin pod
=item ('raw_meta_event', I<dtime>, I<command>(0-255), I<raw>)

=cut
=end pod
      }
    default {
         $E = MIDI::Event.new( type       => 'raw_meta_event',
                       	       delta-time => $time,
                   	       args       => [
                                               $command,
                                               subbuf($data, $Pointer, $length)
                                                 # "[uninterpretable meta-event $command of length $length]"
                                             ]
                            ); # DTime, Command, Binary Data
           # It's uninterpretable; record it as raw_data.
      } # End of the meta-event ifcase.
    }

      $Pointer += $length; #  Now move Pointer

    ######################################################################
    } elsif $first_byte == 0xF0   # It's a SYSEX
    #########################
        || $first_byte == 0xF7 {
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
=item ('sysex_f0', I<dtime>, I<raw>)

=item ('sysex_f7', I<dtime>, I<raw>)

=cut
=end pod
      $E = MIDI::Event.new( type       => $first_byte == 0xF0 ??
			                      'sysex_f0' !!
                                              'sysex_f7',
                            delta-time => $time,
			    args       => [subbuf($data, $Pointer, $length)] );  # DTime, Data
      $Pointer += $length; #  Now move past the data

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
    
    ######################################################################
    } elsif $first_byte == 0xF2 { # It's a Song Position ################

=begin pod
=item ('song_position', I<dtime>)

=cut
=end pod
      #  <song position msg> ::=     F2 <data pair>
      $E = MIDI::Event.new( type       => 'song_position',
                            delta-time => $time,
			    args        => [
					     &read-u14-bit(subbuf($data, $Pointer+1, 2) )
					   ]
      ); # DTime, Beats
      $Pointer += 3; # itself, and 2 data bytes

    ######################################################################
    } elsif $first_byte == 0xF3 { # It's a Song Select ##################

=begin pod
=item ('song_select', I<dtime>, I<song_number>)

=cut
=end pod
      #  <song select msg> ::=       F3 <data singlet>
      $E = MIDI::Event.new( type       => 'song_select',
			    delta-time => $time,
                            args       => [
                                            $data[$Pointer+1],
                                          ]
      ); # DTime, Thing (?!) ... song number?  whatever that is
      $Pointer += 2;  # itself, and 1 data byte

    ######################################################################
    } elsif $first_byte == 0xF6 { # It's a Tune Request! ################

=begin pod
=item ('tune_request', I<dtime>)

=cut
=end pod
      #  <tune request> ::=          F6
  $E = MIDI::Event.new( type       => 'tune_request',
			delta-time => $time
		      );
      # DTime
      # What the Sam Scratch would a tune request be doing in a MIDI /file/?
      ++$Pointer;  # itself

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

    ######################################################################
    } elsif $first_byte > 0xF0 { # Some unknown kinda F-series event ####

=begin pod
=item ('raw_data', I<dtime>, I<raw>)

=cut
=end pod
      # Here we only produce a one-byte piece of raw data.
      # But the encoder for 'raw_data' accepts any length of it.
      $E = MIDI::Event.new( type       => 'raw_data',
                            delta-time => $time,
			    args       => [
					    subbuf($data,$Pointer,1)
					  ]
			  );
      # DTime and the Data (in this case, the one Event-byte)
      ++$Pointer;  # itself

    ######################################################################
    } else { # Fallthru.  How could we end up here? ######################
      note
        "Aborting track.  Command-byte $first_byte at track offset $Pointer";
      last Event;
    }
    # End of the big if-group


     #####################################################################
    ######################################################################
    ##
    #   By the Power of Greyskull, I AM THE EVENT REGISTRAR!
    ##
    if $E and  $E.type eq 'end_track' {
      # This's the code for exceptional handling of the EOT event.
      $eot = 1;
      unless %options<no_eot_magic>
	      and %options<no_eot_magic> {
        if $E.delta-time > 0 {
          $E = MIDI::Event.new( type       => 'text_event',
				delta-time => $E[1]
			      );
          # Make up a fictive 0-length text event as a carrier
          #  for the non-zero delta-time.
        } else {
          # EOT with a delta-time of 0.  Ignore it!
          $E = Nil;
        }
      }
    }

    if $E and  %exclude{$E.type} {
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
	if $exclusive_event_callback {
	  &{ $exclusive_event_callback }( $E );
	} else {
	  &{ $event_callback }( $E ) if $event_callback;
	  @events.push: $E;
	}
      }
    }

=begin pod
=back

Three of the above events are represented a bit oddly from the point
of view of the file spec:

The parameter I<pitch_wheel> for C<'pitch_wheel_change'> is a value
-8192 to 8191, although the actual encoding of this is as a value 0 to
16,383, as per the spec.

Sysex events are represented as either C<'sysex_f0'> or C<'sysex_f7'>,
depending on the status byte they are encoded with.

C<'end_track'> is a bit stranger, in that it is almost never actually
found, or needed.  When the MIDI decoder sees an EOT (i.e., an
end-track status: FF 2F 00) with a delta time of 0, it is I<ignored>!
If in the unlikely event that it has a nonzero delta-time, it's
decoded as a C<'text_event'> with whatever that delta-time is, and a
zero-length text parameter.  (This happens before the
C<'event_callback'> or C<'exclusive_event_callback'> callbacks are
given a crack at it.)  On the encoding side, an EOT is added to the
end of the track as a normal part of the encapsulation of track data.

I chose to add this special behavior so that you could add events to
the end of a track without having to work around any track-final
C<'end_track'> event.

However, if you set C<no_eot_magic> as a decoding parameter, none of
this magic happens on the decoding side -- C<'end_track'> is decoded
just as it is.

And if you set C<no_eot_magic> as an encoding parameter, then a
track-final 0-length C<'text_event'> with non-0 delta-times is left as
is.  Normally, such an event would be converted from a C<'text_event'>
to an C<'end_track'> event with thath delta-time.

Normally, no user needs to use the C<no_eot_magic> option either in
encoding or decoding.  But it is provided in case you need your event
LoL to be an absolutely literal representation of the binary data,
and/or vice versa.

=cut
=end pod

    last Event if $eot;
  }
  # End of the bigass "Event" while-block

  return @events;
}

###########################################################################

my $last_status = -1;

sub encode(*@events, *%options) { # encode an event structure, presumably for writing to a file
 # Calling format:
  #   $data_r = MIDI::Event::encode( \@event_lol, { options } );
  # Takes a REFERENCE to an event structure (a LoL)
  # Returns an (unblessed) REFERENCE to track data.

  # If you want to use this to encode a /single/ event,
  # you still have to do it as a reference to an event structure (a LoL)
  # that just happens to have just one event.  I.e.,
  #   encode( [ $event ] ) or encode( [ [ 'note_on', 100, 5, 42, 64] ] )
  # If you're doing this, consider the never_add_eot track option, as in
  #   print MIDI ${ encode( [ $event], { 'never_add_eot' => 1} ) };

  my $data = ''; # what I'll join @data all together into

  my $unknown_callback = Nil;
  $unknown_callback = %options<unknown_callback>;

  unless %options<never_add_eot> {
    # One way or another, tack on an 'end_track'
    if +@events { # If there are any events...
      my $last = @events[ *-1 ];
      unless $last.type eq 'end_track' { # ...And there's no end_track already
        if $last.type eq 'text_event' and $last.args[2] == 0 {
	  # 0-length text event at track-end.
	  if %options<no_eot_magic> {
	    # Exceptional case: don't mess with track-final
	    # 0-length text_events; just peg on an end_track
	    @events.push: MIDI::Event.new(type => 'end_track');
	  } else {
	    # NORMAL CASE: replace it with an end_track, leaving the DTime
	    $last.type('end_track');
	  }
        } else {
          # last event was neither a 0-length text_event nor an end_track
	  @events.push: MIDI::Event.new(type => 'end_track');
        }
      }
    } else { # an eventless track!
      @events = [ MIDI::Event.new(type => 'end_track') ];
    }
  }

#print "--\n";
#foreach(@events){ MIDI::Event::dump($_) }
#print "--\n";

  my $maybe_running_status = not %options<no_running_status>;
  $last_status = -1;

  join '', @events.map: { .encode-event };
}

method encode-event(*%options) {

  my ($event, $dtime, $event_data, $status, $parameters);
my @data;

  $event_data = '';

  if   $!type eq 'note_off'
    or $!type eq 'note_on'
    or $!type eq 'key_after_touch'
    or $!type eq 'control_change'
    or $!type eq 'patch_change'
    or $!type eq 'channel_after_touch'
    or $!type eq 'pitch_wheel_change'
  {
    given $!type {
      # $status = $parameters = '';
      # This block is where we spend most of the time.  Gotta be tight.

      when 'note_off' {
	$status = 0x80 | @!args[0].int +& 0x0F;
	$parameters = pack('C2',
			   @!args[1].int +& 0x7F, @!args[2].int +& 0x7F);
      }
      when 'note_on' {
	$status = 0x90 | @!args[0].int +& 0x0F;
	$parameters = pack('C2',
			   @!args[1].int +& 0x7F, @!args[2].int +& 0x7F);
      }
      when 'key_after_touch' {
	$status = 0xA0 | @!args[0].int +& 0x0F;
	$parameters = pack('C2',
			   @!args[1].int +& 0x7F, @!args[2].int +& 0x7F);
      }
      when 'control_change' {
	$status = 0xB0 | @!args[0].int +& 0x0F;
	$parameters = pack('C2',
			   @!args[1].int +& 0xFF, @!args[2].int +& 0xFF);
      }
      when 'patch_change' {
	$status = 0xC0 | @!args[0].int +& 0x0F;
	$parameters = pack('C',
			   @!args[1].int +& 0xFF);
      }
      when 'channel_after_touch' {
	$status = 0xD0 | @!args[0].int +& 0x0F;
	$parameters = pack('C',
			   @!args[1].int & 0xFF);
      }
      when 'pitch_wheel_change' {
	$status = 0xE0 | @!args[0] +& 0x0F;
        $parameters =  write-u14-bit(@!args[1].int + 0x2000);
      }
    }
  # And now the encoding
    @data.push:
	( ! %options<no_running_status>  and  $status == $last_status) ??
        pack('wa*', $dtime, $parameters) !!  # If we can use running status.
	pack('wCa*', $dtime, $status, $parameters)  # If we can't.
      ;
      $last_status = $status;
      return Buf.new: @data;
    }

      # Not a MIDI event.
      # All the code in this block could be more efficient, but frankly,
      # this is not where the code needs to be tight.
      # So we wade thru the cases and eventually hopefully fall thru
      # with $event_data set.
#print "zaz $event\n";
      $last_status = -1;

  given $!type {
    when 'raw_meta_event' {
      $event_data = pack("CCwa*", 0xFF, @!args[0].int, @!args[1].bytes, @!args[1]);

      # Text meta-events...
    }
    when 'text_event' {
      $event_data = pack("CCwa*", 0xFF, 0x01, @!args[0].bytes, @!args[0]);
      }
  when 'copyright_text_event' {
	$event_data = pack("CCwa*", 0xFF, 0x02, @!args[0].bytes, @!args[0]);
      }
  when 'track_name' {
	$event_data = pack("CCwa*", 0xFF, 0x03, @!args[0].bytes, @!args[0]);
      }
  when 'instrument_name' {
	$event_data = pack("CCwa*", 0xFF, 0x04, @!args[0].bytes, @!args[0]);
      }
  when 'lyric' {
	$event_data = pack("CCwa*", 0xFF, 0x05, @!args[0].bytes, @!args[0]);
      }
  when 'marker' {
	$event_data = pack("CCwa*", 0xFF, 0x06, @!args[0].bytes, @!args[0]);
      }
  when 'cue_point' {
	$event_data = pack("CCwa*", 0xFF, 0x07, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_08' {
	$event_data = pack("CCwa*", 0xFF, 0x08, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_09' {
	$event_data = pack("CCwa*", 0xFF, 0x09, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_0a' {
	$event_data = pack("CCwa*", 0xFF, 0x0a, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_0b' {
	$event_data = pack("CCwa*", 0xFF, 0x0b, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_0c' {
	$event_data = pack("CCwa*", 0xFF, 0x0c, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_0d' {
	$event_data = pack("CCwa*", 0xFF, 0x0d, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_0e' {
	$event_data = pack("CCwa*", 0xFF, 0x0e, @!args[0].bytes, @!args[0]);
      }
  when 'text_event_0f' {
	$event_data = pack("CCwa*", 0xFF, 0x0f, @!args[0].bytes, @!args[0]);
      # End of text meta-events

      }
  when 'end_track' {
	$event_data = "\xFF\x2F\x00";
      }
  when 'set_tempo' {
 	$event_data = pack("CCwa*", 0xFF, 0x51, 3,
			    subbuf( pack('N', @!args[0]), 1, 3
                          ));
      }
  when 'smpte_offset' {
 	$event_data = pack("CCwCCCCC", 0xFF, 0x54, 5, @!args[0,1,2,3,4] );
      }
  when 'time_signature' {
 	$event_data = pack("CCwCCCC",  0xFF, 0x58, 4, @!args[0,1,2,3] );
      }
  when 'key_signature' {
 	$event_data = pack("CCwcC",    0xFF, 0x59, 2, @!args[0,1]);
      }
  when 'sequencer_specific' {
 	$event_data = pack("CCwa*",    0xFF, 0x7F, @!args[0], @!args[0]);
      # End of Meta-events

      # Other Things...
      }
  when 'sysex_f0' {
 	$event_data = pack("Cwa*", 0xF0, @!args[0].bytes, @!args[0]);
      }
  when 'sysex_f7' {
 	$event_data = pack("Cwa*", 0xF7, @!args[0].bytes, @!args[0]);

      }
  when 'song_position' {
 	$event_data = "\xF2" ~ write-u14-bit( @!args[0] );
      }
  when 'song_select' {
 	$event_data = pack('CC', 0xF3, @!args[0] );
      }
  when 'tune_request' {
 	$event_data = "\xF6";
      }
  when 'raw_data' {
 	$event_data = @!args[0];
      # End of Other Stuff

      }
  default {
	# The Big Fallthru
#NYI         if $!unknown_callback {
#NYI 	  @data.append: $!unknown_callback( $event );
#NYI         } else {
#NYI           note "Unknown event: \'$event\'\n";
#NYI           # To supress complaint here, just set
#NYI           #  'unknown_callback' => sub { return () }
#NYI         }
#NYI 	next;
      }

#print "Event $event encoded part 2\n";
      @data.push: pack('wa*', $dtime, $event_data)
        if $event_data.bytes; # how could $event_data be empty
    }
  return Buf.new: @data;
}

###########################################################################

###########################################################################

=begin pod
=head1 MIDI BNF

For your reference (if you can make any sense of it), here is a copy
of the MIDI BNF, as I found it in a text file that's been floating
around the Net since the late 1980s.

Note that this seems to describe MIDI events as they can occur in
MIDI-on-the-wire.  I I<think> that realtime data insertion (i.e., the
ability to have E<lt>realtime byteE<gt>s popping up in the I<middle>
of messages) is something that can't happen in MIDI files.

In fact, this library, as written, I<can't> correctly parse MIDI data
that has such realtime bytes inserted in messages.  Nor does it
support representing such insertion in a MIDI event structure that's
encodable for writing to a file.  (Although you could theoretically
represent events with embedded E<lt>realtime byteE<gt>s as just
C<raw_data> events; but then, you can always stow anything
at all in a C<raw_data> event.)

 1.  <MIDI Stream> ::=           <MIDI msg> < MIDI Stream>
 2.  <MIDI msg> ::=              <sys msg> | <chan msg>
 3.  <chan msg> ::=              <chan 1byte msg> |
                                 | <chan 2byte msg>
 4.  <chan 1byte msg> ::=        <chan stat1 byte> <data singlet>
                                   <running singlets>
 5.  <chan 2byte msg> ::=        <chan stat2 byte> <data pair>
                                   <running pairs>
 6.  <chan stat1 byte> ::=       <chan voice stat1 nibble>
                                   <hex nibble>
 7.  <chan stat2 byte> ::=       <chan voice stat2 nibble>
                                   <hex nibble>
 8.  <chan voice stat1 nyble>::= C | D
 9.  <chan voice stat2 nyble>::= 8 | 9 | A | B | E
 10. <hex nyble> ::=             0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
                                 | 8 | 9 | A | B | C | D | E | F
 11. <data pair> ::=             <data singlet> <data singlet>
 12. <data singlet> ::=          <realtime byte> <data singlet> |
                                 | <data byte>
 13. <running pairs> ::=         <empty> | <data pair> <running pairs>
 14. <running singlets> ::=      <empty> |
                                 | <data singlet> <running singlets>
 15. <data byte> ::=             <data MSD> <hex nyble>
 16. <data MSD> ::=              0 | 1 | 2 | 3 | 4 | 5 | 6 | 7
 17. <realtime byte> ::=         F8 | FA | FB | FC | FE | FF
 18. <sys msg> ::=               <sys common msg> |
                                 | <sysex msg> |
                                 | <sys realtime msg>
 19. <sys realtime msg> ::=      <realtime byte>
 20. <sysex msg> ::=             <sysex data byte>
                                   <data singlet> <running singlets>
                                   <eox byte>
 21. <sysex stat byte> ::=       F0
 22. <eox byte> ::=              F7
 23. <sys common msg> ::=        <song position msg> |
                                 | <song select msg> |
                                 | <tune request>
 24. <tune request> ::=          F6
 25. <song position msg> ::=     <song position stat byte>
                                   <data pair>
 26. <song select msg> ::=       <song select stat byte>
                                   <data singlet>
 27. <song position stat byte>::=F2
 28. <song select stat byte> ::= F3

=head1 COPYRIGHT 

Copyright (c) 1998-2005 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Sean M. Burke C<sburke@cpan.org>  (Except the BNF --
who knows who's behind that.)

=cut
=end pod
