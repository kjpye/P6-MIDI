use v6;

unit module MIDI::Event;

use PackUnpack;

sub pack-w($val) {
  my @digits = $val.polymod(128 xx *).reverse;
  @digits >>+=>> 128;
  @digits[*-1] -= 128;
  Buf.new(@digits);
}

###########################################################################

my $last-status = -1;

class MIDI::Event {
  
  my $Debug = 0;
  my $VERSION = '0.84';
  
  #First 100 or so lines of this module are straightforward.  The actual
  # encoding logic below that is scary, tho.
  
  # Some helper functions to get data out of a buffer (to replace the original
  # unpack calls.
  
  sub getubyte($data, $pointer is rw) {
      my $byte = $data[$pointer++];
      $byte;
  }
  
  sub signextendbyte($byte) {
      $byte +& 0x80 ?? 127 - $byte !! $byte;
  }
  
  sub getsbyte($data, $pointer is rw) {
      my $byte = $data[$pointer++];
      $byte +& 0x80 ?? 127 - $byte !! $byte;
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
  has $.delta-time = 0;
  has @.args; # event type specific
  
  ###########################################################################
  # Some public-access lists:
  
  my @MIDI-events = <
    note-off note-on key-after-touch control-change patch-change
    channel-after-touch pitch-wheel-change set-sequence-number
  >;
  
  my @Text-events = <
    text-event copyright-text-event track-name instrument-name lyric
    marker cue-point text-event-08 text-event-09 text-event-0a
    text-event-0b text-event-0c text-event-0d text-event-0e text-event-0f
  >;
  
  my @Nontext-meta-events = <
    end-track set-tempo smpte-offset time-signature key-signature
    sequencer-specific raw-meta-event sysex-f0 sysex-f7 song-position
    song-select tune-request raw-data
  >;
  
  # Actually, 'tune-request', for one, is a F-series event, not
  #  strictly-speaking a meta-event
  my @Meta-events = (@Text-events, @Nontext-meta-events).flat;
  my @All-events = (@MIDI-events, @Meta-events).flat;
  
  ###########################################################################
  method dump {
    note "        [", self.dump-quote;
  }
  
  sub copy-structure($events) {
    # Takes a REFERENCE to an event structure (a ref to a LoL),
    # and returns a REFERENCE to a copy of that structure.
  
    $events.clone;
  }
  
  ###########################################################################
  # The module code below this line is full of frightening things, all to do
  # with the actual encoding and decoding of binary MIDI data.
  ###########################################################################
  
  sub read-u14-bit($in) {
    # Decodes to a value 0 to 16383, as is used for some event encoding
    my ($b1, $b2) = $in.comb;
    $b1.ord +| ($b2.ord +< 7);
  }
  
  sub write-u14-bit($in) {
    # encode a 14 bit quantity, as needed for some events
      ($in +& 0x7F) +| (($in +> 7) +& 0x7F)
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
    note "Exclusions: ", join ' ', %exclude.keys.sort
      if $Debug;
  
    my $event-callback = Nil;
    if %options<event-callback> {
  # TODO
    }
    my $exclusive-event-callback = Nil;
    if %options<exclusive-event-callback> {
  # TODO
    }
  
  
    my $Pointer = 0; # points to where I am in the data
    ######################################################################
    if $Debug {
      if $Debug == 1 {
        note "Track data of ", $data.bytes, " bytes.";
      } else {
        note "Track data of ", $data.bytes, " bytes: <", $data ,">";
      }
    }
  
  
    # Things I use variously, below.  They're here just for efficiency's sake,
    # to avoid remying on each iteration.
    my ($command, $channel, $parameter, $length, $time, $remainder);
  
    my $event-code = -1; # used for running status
  
    my $event-count = 0;
   Event:  # Analyze the event stream.
    while $Pointer + 1 < $data.bytes {
      # loop while there's anything to analyze ...
      my $eot = 0; # When 1, the event registrar aborts this loop
      ++$event-count;
  
      my $E;
      # E for event -- this is what we'll feed to the event registrar
      #  way at the end.
  
      # Slice off the delta time code, and analyze it
        #!# print "Chew-code <", $data.subbuf($Pointer,4), ">\n";
      $time = getcompint($data, $Pointer);
        #!# print "Delta-time $time using ", 4 - length($remainder), " bytes\n"
        #!#  if $Debug > 1;
  
      # Now let's see what we can make of the command
      my $first-byte = $data.subbuf( $Pointer, 1).ord;
        # Whatever parses $first-byte is responsible for moving $Pointer
        #  forward.
        #!#print "Event \# $event-count: $first-byte at track-offset $Pointer\n"
        #!#  if $Debug > 1;
  
      ######################################################################
      if $first-byte < 0xF0 { # It's a MIDI event ##########################
        if $first-byte >= 0x80 {
  	note "Explicit event $first-byte" if $Debug > 2;
          ++$Pointer; # It's an explicit event.
          $event-code = $first-byte;
        } else {
          # It's a running status mofo -- just use last $event-code value
          if $event-code == -1 {
            note "Uninterpretable use of running status; Aborting track."
              if $Debug;
            last Event;
          }
          # Let the argument-puller-offer move Pointer.
        }
        $command = $event-code +& 0xF0;
        $channel = $event-code +& 0x0F;
  
        if $command == 0xC0 || $command == 0xD0 {
          #  Pull off the 1-byte argument
          $parameter = getubyte($data, $Pointer);
        } else { # pull off the 2-byte argument
          $parameter = getushort($data, $Pointer);
        }
  
        ###################################################################
        # MIDI events
  
        given $command {
          when 0x80 {
            next if %exclude<note-off>;
              # for sake of efficiency
            $E = MIDI::Event.new( type => 'note-off', delta-time => $time,
                                  args => [$channel,
                                           $parameter[0],
                                           $parameter[1],
  	                                ]
                                );
          }
  	when 0x90 {
  	  next if %exclude<note-on>;
            $E = MIDI::Event.new( type => 'note-on', delta-time => $time,
                                  args => [$channel,
                                           $parameter[0],
                                           $parameter[1]
                                          ]
                                );
          }
          when 0xa0 {
  	  next if %exclude<key-after-touch>;
            $E = MIDI::Event.new( type       => 'key-after-touch',
                                  delta-time => $time,
                                  args       => [$channel,
                                                 $parameter[0],
                                                 $parameter[1],
                                                ]
                                );
          }
          when 0xb0 {
  	  next if %exclude<control-change>;
            $E = MIDI::Event.new( type       => 'control-change',
                                  delta-time => $time,
                                  args       => [$channel,
                                                 $parameter[0],
                                                 $parameter[1],
                                                ]
                                );
          }
          when 0xc0 {
  	  next if %exclude<patch-change>;
            $E = MIDI::Event.new( type       => 'patch-change',
                                  delta-time => $time,
                                  args       => [$channel,
                                                 $parameter[0]
                                                ]
                                );
          }
          when 0xd0 {
  	  next if %exclude<channel-after-touch>;
            $E = MIDI::Event.new( type       => 'channel-after-touch',
                                  delta-time => $time,
                                  args       => [$channel,
                                                 $parameter[0]
                                                ]
                                );
          }
          when 0xe0 {
  	  next if %exclude<pitch-wheel-change>;
            $E = MIDI::Event.new( type       => 'pitch-wheel-change',
                                  delta-time => $time,
                                  args => [$channel,
                                           read-u14-bit($parameter[0]) - 0x2000
                                          ]
                                );
          }
          default {
            note  # Should be QUITE impossible!
             "SPORK ERROR M:E:1 in track-offset $Pointer\n";
          }
        }
  
      ######################################################################
      } elsif $first-byte == 0xFF { # It's a Meta-Event! ##################
        $command = $data[$Pointer++];
        $length = getcompint($data, $Pointer);
  
        given $command {
          when 0x00 {
            $E = MIDI::Event.new( type       => 'set-sequence-number',
  	                        delta-time => $time,
  	                        args       => [getushort($data, $Pointer),
  		                              ]
  	                      );
  
        # Defined text events ----------------------------------------------
          }
          when 0x01 {
            $E =  MIDI::Event.new( type       => 'text-event',
                                   delta-time => $time,
                                   args => [$data.subbuf( $Pointer, $length),
                                           ]
                                 );  # DTime, TData
          }
          when 0x02 {
            $E = MIDI::Event.new( type       => 'copyright-text-event',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x03 {
            $E = MIDI::Event.new( type       => 'track-name',
                                  delta-time => $time, 
                                  args => [$data.subbuf( $Pointer, $length),
                                          ]
                                );  # DTime, TData
          }
          when 0x04 {
            $E = MIDI::Event.new( type       => 'instrument-name',
                                  delta-time => $time,
                                  args => [$data.subbuf( $Pointer, $length),
                                          ]
                                );  # DTime, TData
          }
          when 0x05 {
            $E = MIDI::Event.new( type       => 'lyric',
                                  delta-time => $time,
                                  args => [$data.subbuf( $Pointer, $length),
                                          ]
                                );  # DTime, TData
          }
          when 0x06 {
            $E = MIDI.Event.new( type       => 'marker',
                                 delta-time => $time,
                                 args       => [$data.subbuf( $Pointer, $length),
                                               ]
                               );  # DTime, TData
          }
          when 0x07 {
            $E = MIDI::Event.new( type       => 'cue-point',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
  
        # Reserved but apparently unassigned text events --------------------
          when 0x08 {
            $E = MIDI::Event.new( type       => 'text-event-08',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x09 {
            $E = MIDI::Event.new( type       => 'text-event-09',
                                  delta-time => $time, 
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x0a {
            $E = MIDI::Event.new( type       => 'text-event-0a',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x0b {
            $E = MIDI::Event.new( type       => 'text-event-0b',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ] # DTime, TData
                                );
          }
          when 0x0c {
            $E = MIDI::Event.new( type       => 'text-event-0c',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x0d {
            $E = MIDI::Event.new( type       => 'text-event-0d',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x0e {
            $E = MIDI::Event.new( type       => 'text-event-0e',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
          when 0x0f {
            $E = MIDI::Event.new( type       => 'text-event-0f',
                                  delta-time => $time,
                                  args       => [$data.subbuf( $Pointer, $length),
                                                ]
                                );  # DTime, TData
          }
  
        # Now the sticky events ---------------------------------------------
  
          when 0x2f {
            $E = MIDI::Event.new( type       => 'end-track',
                                  delta-time => $time
                                );  # DTime
             # The code for handling this oddly comes LATER, in the
             #  event registrar.
          }
          when 0x51 {
            $E = MIDI::Event.new( type       => 'set-tempo',
                                  delta-time => $time,
                                  args => [getint24($data),
  		                        ]
                                );  # DTime, Microseconds
          }
          when 0x54 {
            $E = MIDI::Event.new( type       => 'smpte-offset',
                                  delta-time => $time,
                                  args       => [$data[$Pointer],
                                                 $data[$Pointer+1],
                                                 $data[$Pointer+2],
                                                 $data[$Pointer+3],
                                                 $data[$Pointer+4],
                                                ]		   
                                ); # DTime, HR, MN, SE, FR, FF
          }
          when 0x58 {
            $E = MIDI::Event.new( type       => 'time-signature',
                                  delta-time => $time,
                                  args => [$data[$Pointer],
                                           $data[$Pointer+1],
                                           $data[$Pointer+2],
                                           $data[$Pointer+3],
                                          ]
                                ); # DTime, NN, DD, CC, BB
          }
          when 0x59 {
            $E = MIDI::Event.new( type       => 'key-signature',
                                  delta-time => $time,
                                  args       => [signextendbyte($data[0]),
                                                 $data[1], # unsigned
                                                ]
                                ); # DTime, SF(signed), MI
          }
          when 0x7f {
            $E = MIDI::Event.new( type       => 'sequencer-specific',
                                  delta-time => $time,
                                  args => [$data.subbuf( $Pointer, $length),
                                          ]
                                ); # DTime, Binary Data
          }
          default {
            $E = MIDI::Event.new( type       => 'raw-meta-event',
                                  delta-time => $time,
                                  args       => [$command,
                                                 $data.subbuf( $Pointer, $length)
  	       # "[uninterpretable meta-event $command of length $length]"
                                                ]
                                ); # DTime, Command, Binary Data
          }
             # It's uninterpretable; record it as raw-data.
        } # End of the meta-event ifcase.
  
        $Pointer += $length; #  Now move Pointer
  
      ######################################################################
      } elsif $first-byte == 0xF0   # It's a SYSEX
      #########################
          || $first-byte == 0xF7 {
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
  
        $E = MIDI::Event.new( type => $first-byte == 0xF0 ??
            'sysex-f0' !! 'sysex-f7',
            delta-time => $time, args => [$data.subbuf( $Pointer, $length)] );  # DTime, Data
        $Pointer += $length; #  Now move past the data
  
      ######################################################################
      # Now, the MIDI file spec says:
      #  <track data> = <MTrk event>+
      #  <MTrk event> = <delta-time> <event>
      #  <event> = <MIDI event> | <sysex event> | <meta-event>
      # I know that, on the wire, <MIDI event> can include note-on,
      # note-off, and all the other 8x to Ex events, AND Fx events
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
      } elsif $first-byte == 0xF2 { # It's a Song Position ################
  
        #  <song position msg> ::=     F2 <data pair>
        $E = MIDI::Event.new( type => 'song-position',
          delta-time => $time, args => [&read-u14-bit($data.subbuf( $Pointer+1, 2) )]
        ); # DTime, Beats
        $Pointer += 3; # itself, and 2 data bytes
  
      ######################################################################
      } elsif $first-byte == 0xF3 { # It's a Song Select ##################
  
        #  <song select msg> ::=       F3 <data singlet>
        $E = MIDI::Event.new( type       => 'song-select',
  			    delta-time => $time,
                              args       => [
                                              $data[$Pointer+1],
                                            ]
        ); # DTime, Thing (?!) ... song number?  whatever that is
        $Pointer += 2;  # itself, and 1 data byte
  
      ######################################################################
      } elsif $first-byte == 0xF6 { # It's a Tune Request! ################
  
        #  <tune request> ::=          F6
        $E = MIDI::Event.new( type => 'tune-request', delta-time => $time );
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
      } elsif $first-byte > 0xF0 { # Some unknown kinda F-series event ####
  
        # Here we only produce a one-byte piece of raw data.
        # But the encoder for 'raw-data' accepts any length of it.
        $E = MIDI::Event.new( type => 'raw-data',
  	     daleta-time => $time, args => [$data.subbuf($Pointer,1)] );
        # DTime and the Data (in this case, the one Event-byte)
        ++$Pointer;  # itself
  
      ######################################################################
      } else { # Fallthru.  How could we end up here? ######################
        note
          "Aborting track.  Command-byte $first-byte at track offset $Pointer";
        last Event;
      }
      # End of the big if-group
  
  
       #####################################################################
      ######################################################################
      ##
      #   By the Power of Greyskull, I AM THE EVENT REGISTRAR!
      ##
      if $E and  $E.type eq 'end-track' {
        # This's the code for exceptional handling of the EOT event.
        $eot = 1;
        unless %options<no-eot-magic>
  	      and %options<no-eot-magic> {
          if $E.delta-time > 0 {
            $E = MIDI::Event.new( type => 'text-event', $E[1], '');
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
  	if $exclusive-event-callback {
  	  &{ $exclusive-event-callback }( $E );
  	} else {
  	  &{ $event-callback }( $E ) if $event-callback;
  	  @events.push: $E;
  	}
        }
      }
  
  
      last Event if $eot;
    }
    # End of the bigass "Event" while-block
  
    return @events;
  }
  
  method encode-event($last-status is rw, *%options) {
  
    my ($event, $dtime, $event-data, $status, $parameters);
  my @data;
  
    $event-data = '';
  
  $dtime = $!delta-time;
    if   $!type eq 'note-off'
      or $!type eq 'note-on'
      or $!type eq 'key-after-touch'
      or $!type eq 'control-change'
      or $!type eq 'patch-change'
      or $!type eq 'channel-after-touch'
      or $!type eq 'pitch-wheel-change'
    {
      given $!type {
        # $status = $parameters = '';
        # This block is where we spend most of the time.  Gotta be tight.
  
        when 'note-off' {
  	$status = 0x80 +| @!args[0] +& 0x0F;
  	$parameters = pack('C2',
  			   @!args[1] +& 0x7F, @!args[2] +& 0x7F);
        }
        when 'note-on' {
  	$status = 0x90 +| @!args[0] +& 0x0F;
  	$parameters = pack('C2',
  			   @!args[1] +& 0x7F, @!args[2] +& 0x7F);
        }
        when 'key-after-touch' {
  	$status = 0xA0 +| @!args[0] +& 0x0F;
  	$parameters = pack('C2',
  			   @!args[1] +& 0x7F, @!args[2] +& 0x7F);
        }
        when 'control-change' {
  	$status = 0xB0 +| @!args[0] +& 0x0F;
  	$parameters = pack('C2',
  			   @!args[1] +& 0xFF, @!args[2] +& 0xFF);
        }
        when 'patch-change' {
  	$status = 0xC0 +| @!args[0] +& 0x0F;
  	$parameters = pack('C',
  			   @!args[1] +& 0xFF);
        }
        when 'channel-after-touch' {
  	$status = 0xD0 +| @!args[0] +& 0x0F;
  	$parameters = pack('C',
  			   @!args[1] & 0xFF);
        }
        when 'pitch-wheel-change' {
  	$status = 0xE0 +| @!args[0] +& 0x0F;
          $parameters =  write-u14-bit(@!args[1] + 0x2000);
        }
      }
    # And now the encoding
      my $buf = 
  	( ! %options<no-running-status>  and  $status == $last-status)
              ??
                pack('wa*', $dtime, $parameters) # If we can use running status.
              !!
  	        pack('wCa*', $dtime, $status, $parameters)  # If we can't.
        ;
        $last-status = $status;
        return $buf;
      }
  
        # Not a MIDI event.
        # All the code in this block could be more efficient, but frankly,
        # this is not where the code needs to be tight.
        # So we wade thru the cases and eventually hopefully fall thru
        # with $event-data set.
  #print "zaz $event\n";
        $last-status = -1;
  
    given $!type {
      when 'raw-meta-event' {
        $event-data = pack("CCwa*", 0xFF, @!args[0].int, @!args[1].bytes, @!args[1]);
  
        # Text meta-events...
      }
      when 'text-event' {
        $event-data = pack("CCwa*", 0xFF, 0x01, @!args[0].bytes, @!args[0]);
        }
    when 'copyright-text-event' {
  	$event-data = pack("CCwa*", 0xFF, 0x02, @!args[0].bytes, @!args[0]);
        }
    when 'track-name' {
  	$event-data = pack("CCwa*", 0xFF, 0x03, @!args[0].bytes, @!args[0]);
        }
    when 'instrument-name' {
  	$event-data = pack("CCwa*", 0xFF, 0x04, @!args[0].bytes, @!args[0]);
        }
    when 'lyric' {
  	$event-data = pack("CCwa*", 0xFF, 0x05, @!args[0].bytes, @!args[0]);
        }
    when 'marker' {
  	$event-data = pack("CCwa*", 0xFF, 0x06, @!args[0].bytes, @!args[0]);
        }
    when 'cue-point' {
  	$event-data = pack("CCwa*", 0xFF, 0x07, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-08' {
  	$event-data = pack("CCwa*", 0xFF, 0x08, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-09' {
  	$event-data = pack("CCwa*", 0xFF, 0x09, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-0a' {
  	$event-data = pack("CCwa*", 0xFF, 0x0a, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-0b' {
  	$event-data = pack("CCwa*", 0xFF, 0x0b, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-0c' {
  	$event-data = pack("CCwa*", 0xFF, 0x0c, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-0d' {
  	$event-data = pack("CCwa*", 0xFF, 0x0d, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-0e' {
  	$event-data = pack("CCwa*", 0xFF, 0x0e, @!args[0].bytes, @!args[0]);
        }
    when 'text-event-0f' {
  	$event-data = pack("CCwa*", 0xFF, 0x0f, @!args[0].bytes, @!args[0]);
        # End of text meta-events
  
        }
    when 'end-track' {
  	$event-data = "\xFF\x2F\x00";
        }
    when 'set-tempo' {
   	$event-data = pack("CCwa*", 0xFF, 0x51, 3,
  			    pack('N', @!args[0])
                            );
        }
    when 'smpte-offset' {
   	$event-data = pack("CCwCCCCC", 0xFF, 0x54, 5, @!args[0,1,2,3,4] );
        }
    when 'time-signature' {
   	$event-data = pack("CCwCCCC",  0xFF, 0x58, 4, @!args[0,1,2,3] );
        }
    when 'key-signature' {
   	$event-data = pack("CCwcC",    0xFF, 0x59, 2, @!args[0,1]);
        }
    when 'sequencer-specific' {
   	$event-data = pack("CCwa*",    0xFF, 0x7F, @!args[0], @!args[0]);
        # End of Meta-events
  
        # Other Things...
        }
    when 'sysex-f0' {
   	$event-data = pack("Cwa*", 0xF0, @!args[0].bytes, @!args[0]);
        }
    when 'sysex-f7' {
   	$event-data = pack("Cwa*", 0xF7, @!args[0].bytes, @!args[0]);
  
        }
    when 'song-position' {
   	$event-data = "\xF2" ~ write-u14-bit( @!args[0] );
        }
    when 'song-select' {
   	$event-data = pack('CC', 0xF3, @!args[0] );
        }
    when 'tune-request' {
   	$event-data = "\xF6";
        }
    when 'raw-data' {
   	$event-data = @!args[0];
        # End of Other Stuff
  
        }
    default {
  	# The Big Fallthru
  #NYI         if $!unknown-callback {
  #NYI 	  @data.append: $!unknown-callback( $event );
  #NYI         } else {
  #NYI           note "Unknown event: \'$event\'\n";
  #NYI           # To supress complaint here, just set
  #NYI           #  'unknown-callback' => sub { return () }
  #NYI         }
  #NYI 	next;
        }
  
  #print "Event $event encoded part 2\n";
        @data.push: pack('wa*', $dtime, $event-data)
          if $event-data.bytes; # how could $event-data be empty?
      }
    return Buf.new: @data;
  } # method encode-event

} # class Event
