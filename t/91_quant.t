use v6.d+;

use Test;
plan 2;

use MIDI;
ok 1;

# test score quantize

my $ifile = "t/dr_m.mid";
my $opus = MIDI::Opus.new(from-file => $ifile);

$opus.quantize(grid => 25, durations => 1);
my $score = MIDI::Score::events-to-score($opus.tracks[0].events);
my $ticks = $score.duration;
$score.dump-score;
is $ticks, 5950;









