use v6.d+;

use Test;
plan 36;

use MIDI;
ok 1;

my $in = "hb.mid";
for "$in", "t/$in", "t\\$in", "t:$in" -> $i {
  if $i.IO.e { $in = $i; last; }
}

die "Can't find $in" unless $in.IO.e;

is $in.IO.s, 1310;

my $o = MIDI::Opus.new( from-file => $in );
ok 1;
print "# Opus: [$o]\n";
ok $o ~~ (MIDI::Opus), "checking opus classitude"; # sanity
is $o.ticks,  480;
is $o.format,   1;


my @t = $o.tracks;
print "# Tracks: [@t]\n";
is +@t, 4, "checking track count"  or die;

my $t;

print "#### TRACK 0\n";

$t = @t[0];
ok $t ~~ (MIDI::Track);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

my @e = $t.events;

my $it;

$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Track-name);
#ok scalar( $it and @$it ), 3 or die;  

$it = @e[1];  print "# EVent 1: [@$it]\n";
ok $it ~~ (MIDI::Event::Smpte-offset);
#ok scalar( $it and @$it ), 7 or die;  

$it = @e[2];  print "# Event 2: [@$it]\n";
ok $it ~~ (MIDI::Event::Set-tempo);
is $it.time,       0;
is $it.tempo, 600000;

$it = @e[3];  print "# Event 3: [@$it]\n";
ok $it ~~ (MIDI::Event::Time-signature);
is $it.time,            0;
is $it.numerator,       4;
is $it.denominator,     2;
is $it.ticks,          24;
is $it.quarter-notes,   8;

$it = @e[4];  print "# Event 4: [@$it]\n";
ok $it ~~ (MIDI::Event::Set-tempo);
is $it.time,   11514;
is $it.tempo, 750000;

$it = @e[5];  print "# Event 5: [@$it]\n";
note "Testing track 0, event 5";

ok $it ~~ (MIDI::Event::Text-event);
is        $it.time, 7686;
is-deeply $it.text, Buf.new();

print "#### TRACK 1\n";
$t = @t[1];
ok $t ~~ (MIDI::Track);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

@e = $t.events;
$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Instrument-name);
#ok scalar( $it and @$it ), 3 or die;  


print "#### TRACK 2\n";
$t = @t[2];
ok $t ~~ (MIDI::Track);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

@e = $t.events;

$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Instrument-name);
#ok scalar( $it and @$it ), 3 or die;  

print "#### TRACK 3\n";
$t = @t[3];
ok $t ~~ (MIDI::Track);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

@e = $t.events;
$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Instrument-name);
#ok scalar( $it and @$it ), 3 or die;  



print "# Okay, all done!\n";
ok 1;

