use v6.d+;

use Test;

plan 43;

use MIDI;
ok 1;

  my $out = "temp20.mid";
  $out.IO.unlink if $out.IO.e;
  {
   my @events = (
     MIDI::Event::Text-event.new( time => 0, text  => Buf.new('MORE COWBELL'.comb>>.ord)),
     MIDI::Event::Set-tempo.new(  time => 0, tempo => 450_000), # 1qn = .45 seconds
   );
  
   for 1 .. 20 {
     push @events,
       MIDI::Event::Note-on.new(  time => 90, channel => 9, note-number => 56, velocity => 127),
       MIDI::Event::Note-off.new( time =>  6, channel => 9, note-number => 56, velocity => 127),
     ;
   }
   for (1..96).reverse -> $delay {
     push @events:
       MIDI::Event::Note-on.new(  time => 0,      channel => 9, note-number => 56, velocity => 127),
       MIDI::Event::Note-off.new( time => $delay, channel => 9, note-number => 56, velocity => 127),
     ;
   }

   my $cowbell-track = MIDI::Track.new( events => @events );
ok 1;
   my $opus = MIDI::Opus.new(
   format => 0, ticks => 96, tracks => [ $cowbell-track ] );
ok 1;

   $opus.write-to-file( $out );
ok 1;
  }
  sleep 1; # festina lente
ok $out.IO.e or die;
ok $out.IO.s;
ok $out.IO.s >  900;
ok $out.IO.s < 1100;

  my $o = MIDI::Opus.new( from-file => $out );
ok 1;
  say "# Opus: [$o]";
ok $o ~~ MIDI::Opus, "checking opus classitude"; # sanity
is $o.ticks, 96;
  $o.ticks = 123;
is $o.ticks, 123;
is $o.format, 0;
  $o.format = 1;
is $o.format, 1;

  my @t = $o.tracks;
  say "# Tracks: [@t]";
ok +@t, 1;
#ok +@t, 1, "checking track count"  or die;

  my $t = @t[0];
ok $t ~~ MIDI::Track;
is-deeply $t.type, Buf[uint8].new(0x4d, 0x54, 0x72, 0x6b);


ok $o.tracks.defined;
ok $o.tracks ~~ (Array) or die;
ok +$o.tracks, 1;
ok $o.tracks[0], $t; 

ok $t.events.defined;
ok $t.events ~~ (Array) or die;
ok +$t.events, 234;
  my @e = $t.events;
is-deeply @e[0], $t.events[0]; # tests coreference

#  note "# First event: {dd @e[0]}";

ok @e[0] ~~ (MIDI::Event::Text-event);
is @e[0].time, 0;
ok @e[0].text, "MORE COWBELL";

  say "# Second event: [@e[1]]";

ok @e[1] ~~ (MIDI::Event::Set-tempo);
is @e[1].time, 0;
is @e[1].tempo, 450000;

  say "# Third event: [@e[2]]";

ok @e[2] ~~ (MIDI::Event::Note-on);
is @e[2].time,         90;
is @e[2].channel,       9;
is @e[2].note-number,  56;
is @e[2].velocity,    0xffff; # scaled from MIDI 1 value of 127


  say "# Fourth event: [@e[3]]";
ok @e[3] ~~ (MIDI::Event::Note-off);
is @e[3].time,         6;
is @e[3].channel,      9;
is @e[3].note-number, 56;
is @e[3].velocity,   0xffff; # scaled from MIDI 1 value of 127

  $t.type = Buf.new("Muck".comb>>.ord);
is-deeply $t.type, Buf[uint8].new('Muck'.comb>>.ord);

  #unlink $out;
  say "# Okay, all done!\n";
ok 1;
