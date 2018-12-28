use v6.d+;

use Test;
plan 2;

use MIDI;
ok 1;

# make sure events_to_score doesn't change event times

my $ifile = "t/hb.mid";
my $opus = MIDI::Opus.new(from-file => $ifile);
my $track = ($opus.tracks)[0];
my $score = MIDI::Score::events-to-score($track.events);
$score = MIDI::Score::events-to-score($track.events);
$score = MIDI::Score::events-to-score($track.events);
#print MIDI::Score::score_r_time( $score_r );
ok $score.duration, 19200 or die;

 
