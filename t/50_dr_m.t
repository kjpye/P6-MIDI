use v6.d+;

use Test;
plan 44;

use MIDI;
ok 1;

my $in = "dr_m.mid";
for "$in", "t/$in", "t\\$in", "t:$in" -> $i {
  if $i.IO.e { $in = $i; last; }
}

die "Can't find $in" unless $in.IO.e;

is $in.IO.s, 254;

my $o = MIDI::Opus.new( from-file => $in );
ok 1;
print "# Opus: [$o]\n";
ok $o~~ (MIDI::Opus), "checking opus classitude"; # sanity
is $o.ticks, 384;
is $o.format, 0;


my @t = $o.tracks;
print "# Tracks: [@t]\n";
is +@t, 1, "checking track count"  or die;

my $t = @t[0];
ok $t ~~ (MIDI::Track);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

# And just test the first few events...

my @e = $t.events;
my $it;
$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Copyright);
is $it.time,  0;
is $it.text, Buf[uint8].new();

$it = @e[1];  print "# EVent 1: [@$it]\n";
ok $it ~~ (MIDI::Event::Track-name);
is $it.time, 0;
is $it.text, Buf[uint8].new('MIDI by MidiGen 0.9'.comb>>.ord);


$it = @e[2];  print "# Event 2: [@$it]\n";
ok $it ~~ (MIDI::Event::Controller-change);
is $it.time,         0;
is $it.channel,      0;
is $it.controller,   7;
is $it.value,      127;


ok($it = @e[3]) or die;  print "# Event 3: [@$it]\n";
ok $it ~~ (MIDI::Event::Set-tempo);
is $it.time,       0;
is $it.tempo, 400000;


$it = @e[4];  print "# Event 4: [@$it]\n";
ok $it ~~ (MIDI::Event::Patch-change);
is $it.time,         0;
is $it.channel,      0;
is $it.patch-number, 1;



$it = @e[5];  print "# Event 5: [@$it]\n";

ok $it ~~ (MIDI::Event::Note-on);
is $it.time,          0;
is $it.channel,       0;
is $it.note-number,  69;
is $it.velocity,    51492; # scaled from MIDI 1 value of 100

$it = @e[6];  print "# Event 6: [@$it]\n";

ok $it ~~ (MIDI::Event::Note-off);
is $it.time,       192;
is $it.channel,      0;
is $it.note-number, 69;
is $it.velocity,     0;

$it = @e[7];  print "# Event 7: [@$it]\n";

ok $it ~~ (MIDI::Event::Note-on);
is $it.time,          0;
is $it.channel,       0;
is $it.note-number,  68;
is $it.velocity,    51492; # scaled from MIDI 1 value of 100


print "# Okay, all done!\n";
ok 1;

