use v6.d+;

use Test;
plan 24;

use MIDI;
ok 1;

#print map "#\t$_\n",
# q["I have nothing to say], q[ and I am saying it],
# q[ and that is poetry],    q[ as I needed it"],
# q[     -- John Cage]
#;


my $in = "cage.mid";
for "$in", "t/$in", "t\\$in", "t:$in" -> $i {
  if $i.IO.e { $in = $i; last; }
}

die "Can't find $in" unless $in.IO.e;

is $in.IO.s, 39;

my $o = MIDI::Opus.new( from-file => $in );
ok 1;
print "# Opus: [$o]\n";
ok $o ~~ (MIDI::Opus), "checking opus classitude"; # sanity
is $o.ticks, 96;
is $o.format, 0;


my @t = $o.tracks;
print "# Tracks: [@t]\n";
is +@t, 1, "checking track count"  or die;

my $t = @t[0];
ok $t ~~ (MIDI::Track
);
is-deeply $t.type, Buf[uint8].new('MTrk'.comb>>.ord);

my @e = $t.events;
my $it;
$it = @e[0];  print "# Event 0: [@$it]\n";
ok $it ~~ (MIDI::Event::Patch-change);
is $it.time,         0;
is $it.channel,      0;
is $it.patch-number, 0;


$it = @e[1];  print "# EVent 1: [@$it]\n";
ok $it ~~ (MIDI::Event::Note-off); # MIDI 1 note-on with velocity translated to MIDI 2 note-off
is $it.time,         0;
is $it.channel,      0;
is $it.note-number, 20;
is $it.velocity,     0;


$it = @e[2];  # print "# Event 2: [@$it]\n";
ok $it ~~ (MIDI::Event::Note-off);
is $it.time,       52416;
is $it.channel,        0;
is $it.note-number,   20;
is $it.velocity,       0;




print "# Okay, all done!\n";
ok 1;

