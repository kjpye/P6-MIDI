use v6.d+;

use Test;
plan 7;

use MIDI;
ok 1;

# make sure midi paradox is handled

my $ifile = "t/t.mid";
my $opus = MIDI::Opus.new(from-file => $ifile);
my $track = $opus.tracks[0];
my $score = MIDI::Score::events-to-score($track.events);
$score.dump-score();
# ['note', 9408, 1344, 0, 69, 96],
# ['note', 9408, 1345, 0, 69, 96],
ok $score.notes[0].duration, 1344 or die;
ok $score.notes[1].duration, 1345 or die;
# now test the reverse (inverse midi paradox)
my $events = $score.events;
#note_on 9408 0 69 96
#note_on 0 0 69 96
#note_off 1344 0 69 0
#note_off 1 0 69 0
is $events[0].time, 9408;
is $events[1].time,    0;
is $events[2].time, 1344;
is $events[3].time,    1;




