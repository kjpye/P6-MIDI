use v6;
use Test;

plan 47;

use MIDI;
ok 1;

  my $out = "temp20.mid";
#TODO unlink $out if -e $out;
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
  print "# Opus: [$o]\n";
ok $o ~~ MIDI::Opus, "checking opus classitude"; # sanity
say 'ticks: ', $o.ticks;
ok $o.ticks, 96;
  $o.ticks = 123;
ok $o.ticks, 123;
ok $o.format, 0;
  $o.format = 1;
ok $o.format, 1;

  my @t = $o.tracks;
  print "# Tracks: [@t]\n";
ok +@t, 1;
#ok +@t, 1, "checking track count"  or die;

  print "# "; dd @t;
  my $t = @t[0];
ok $t ~~ MIDI::Track;
ok $t.type, "MTrk";


ok $o.tracks.defined;
ok $o.tracks ~~ (Array) or die;
ok +$o.tracks, 1;
ok $o.tracks[0], $t; 

ok $t.events.defined;
ok $t.events ~~ (Array) or die;
ok +$t.events, 234;
  my @e = $t.events;
ok @e[0], $t.events[0]; # tests coreference

  say "# First event: [@e[0]]";

ok @e[0] ~~ (array) or die;
ok @e[0].type, "text-event";
ok @e[0].delta-time, "0";
ok +@e[0].args, 1;
ok @e[0].args[0], "MORE COWBELL";

  say "# Second event: [@e[1]]";

ok @e[1].type, "set-tempo";
ok @e[1].delta-time, "0";
ok +@e[1].args, 1;
ok @e[1].args[0], "450000";

  say "# Third event: [@e[2]]";

ok @e[2].type, "note-on";
ok @e[2].delta-time, "90";
ok +@e[1].args, 3;
ok @e[2].args[0], "9";
ok @e[2].args[1], "56";
ok @e[2].args[2], "127";


  say "# Fourth event: [@e[3]]";
ok @e[3].type, "note-off";
ok @e[3].delta-time, "6";
ok @e[3].args[0], "9";
ok @e[3].args[1], "56";
ok @e[3].args[2], "127";

  $t.type("Muck");
ok $t.type, "Muck";

  #unlink $out;
  say "# Okay, all done!\n";
ok 1;
