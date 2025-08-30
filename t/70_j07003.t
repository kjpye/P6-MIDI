use v6.d+;

use Test;
plan 15;

use MIDI;
ok 1;

my $in = "j07003.mid";
for "$in", "t/$in", "t\\$in", "t:$in" -> $i {
  if $i.IO.e { $in = $i; last; }
}

die "Can't find $in" unless $in.IO.e;

is $in.IO.s, 3445;

my $o = MIDI::Opus.new( from-file => $in);
ok 1;
print "# Opus: [$o]\n";
ok $o ~~ (MIDI::Opus), "checking opus classitude"; # sanity
is $o.ticks, 96;
is $o.format, 0;


my @t = $o.tracks;
print "# Tracks: [@t]\n";
is +@t, 1, "checking track count"  or die;

my $t = @t[0];
ok $t ~~ (MIDI::Track);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

my @e = $t.events;
my $it;
$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Set-tempo);
# ok scalar( @$it ), 3 or die;  

$it = @e[1];  print "# EVent 1: [@$it]\n";
ok $it ~~ (MIDI::Event::Program-change);
#ok scalar( @$it ), 4 or die;  

$it = @e[2];  print "# Event 2: [@$it]\n";
ok $it ~~ (MIDI::Event::Text-event);
#ok scalar( @$it ), 3 or die;  

$it = @e[3];  print "# Event 3: [@$it]\n";
ok $it ~~ (MIDI::Event::Note-on);
#ok scalar( @$it ), 5 or die;  

$it = @e[4];  print "# Event 4: [@$it]\n";
ok $it ~~ (MIDI::Event::Note-on);
#ok scalar( @$it ), 5 or die;  



print "# Okay, all done!\n";
ok 1;
