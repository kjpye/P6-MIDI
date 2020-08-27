NAME
====

MIDI::Opus -- functions and methods for MIDI opuses

SYNOPSIS
========

    use MIDI; # uses MIDI::Opus et al
    foreach $one (@ARGV) {
      my $opus = MIDI::Opus->new({ 'from-file' => $one, 'no-parse' => 1 });
      print "$one has ", scalar( $opus->tracks ) " tracks\n";
    }
    exit;

DESCRIPTION
===========

MIDI::Opus provides a constructor and methods for objects representing a MIDI opus (AKA "song"). It is part of the MIDI suite.

An opus object has three attributes: a format (0 for MIDI Format 0), a tick parameter (parameter "division" in [MIDI::Filespec](MIDI::Filespec)), and a list of tracks objects that are the real content of that opus.

Be aware that options specified for the encoding or decoding of an opus may not be documented in *this* module's documentation, as they may be (and, in fact, generally are) options just passed down to the decoder/encoder in MIDI::Event -- so see [MIDI::Event](MIDI::Event) for an explanation of most of them, actually.

CONSTRUCTOR AND METHODS
=======================

MIDI::Opus provides...

###########################################################################

  * the constructor MIDI::Opus->new({ ...options... })

This returns a new opus object. The options, which are optional, is an anonymous hash. By default, you get a new format-0 opus with no tracks and a tick parameter of 96. There are six recognized options: `format`, to set the MIDI format number (generally either 0 or 1) of the new object; `ticks`, to set its ticks parameter; `tracks`, which sets the tracks of the new opus to the contents of the list-reference provided; `tracks-r`, which is an exact synonym of `tracks`; `from-file`, which reads the opus from the given filespec; and `from-handle`, which reads the opus from the the given filehandle reference (e.g., `*STDIN{IO}`), after having called binmode() on that handle, if that's a problem.

If you specify either `from-file` or `from-handle`, you probably don't want to specify any of the other options -- altho you may well want to specify options that'll get passed down to the decoder in MIDI::Events, such as 'include' => ['sysex-f0', 'sysex-f7'], just for example.

Finally, the option `no-parse` can be used in conjuction with either `from-file` or `from-handle`, and, if true, will block MTrk tracks' data from being parsed into MIDI events, and will leave them as track data (i.e., what you get from $track->data). This is useful if you are just moving tracks around across files (or just counting them in files, as in the code in the Synopsis, above), without having to deal with any of the events in them. (Actually, this option is implemented in code in MIDI::Track, but in a routine there that I've left undocumented, as you should access it only thru here.)

  * the method $new-opus = $opus->copy

This duplicates the contents of the given opus, and returns the duplicate. If you are unclear on why you may need this function, read the documentation for the `copy` method in [MIDI::Track](MIDI::Track).

  * the method $opustracks-r( $tracks-r )

Returns a reference to the list of tracks in the opus, possibly after having set it to $tracks-r, if specified. "$tracks-r" can actually be any listref, whether it comes from a scalar as in `$some-tracks-r`, or from something like `[@tracks]`, or just plain old `\@tracks`

Originally $opus->tracks was the only way to deal with tracks, but I added $opus->tracks-r to make possible 1) setting the list of tracks to (), for whatever that's worth, 2) parallel structure between MIDI::Opus::tracks[_r] and MIDI::Tracks::events[_r] and 3) so you can directly manipulate the opus's tracks, without having to *copy* the list of tracks back and forth. This way, you can say:

    $tracks-r = $opus->tracks-r();
    @some-stuff = splice(@$tracks-r, 4, 6);

But if you don't know how to deal with listrefs like that, that's OK, just use $opus->tracks.

  * the method $new-opus = $opus.quantize

This grid quantizes an opus. It simply calls MIDI::Score::quantize on every track. See docs for MIDI::Score::quantize. Original opus is destroyed, use MIDI::Opus::copy if you want to take a copy first.

  * the method $opus.dump( ...options... )

Dumps the opus object as a bunch of text, for your perusal. Options include: `flat`, if true, will have each event in the opus as a tab-delimited line -- or as delimited with whatever you specify with option `delimiter`; *otherwise*, dump the data as Perl code that, if run, would/should reproduce the opus. For concision's sake, the track data isn't dumped, unless you specify the option `dump-tracks` as true.

  * the method $opus.write-to-file('filespec', { ...options...} )

Writes $opus as a MIDI file named by the given filespec. The options hash is optional, and whatever you specify as options percolates down to the calls to MIDI::Event::encode -- which see. Currently this just opens the file, calls $opus.write-to-handle on the resulting filehandle, and closes the file.

  * the method $opus.write-to-handle(IOREF, ...options... )

Writes $opus as a MIDI file to the IO handle you pass a reference to (example: `*STDOUT{IO}`). The options hash is optional, and whatever you specify as options percolates down to the calls to MIDI::Event::encode -- which see. Note that this is probably not what you'd want for sending music to `/dev/sequencer`, since MIDI files are not MIDI-on-the-wire.

  * the method $opus.draw({ ...options...})

This currently experimental method returns a new GD image object that's a graphic representation of the notes in the given opus. Options include: `width` -- the width of the image in pixels (defaults to 600); `bgcolor` -- a six-digit hex RGB representation of the background color for the image (defaults to $MIDI::Opus::BG-color, currently '000000'); `channel-colors` -- a reference to a list of colors (in six-digit hex RGB) to use for representing notes on given channels. Defaults to @MIDI::Opus::Channel-colors. This list is a list of pairs of colors, such that: the first of a pair (color N*2) is the color for the first pixel in a note on channel N; and the second (color N*2 + 1) is the color for the remaining pixels of that note. If you specify only enough colors for channels 0 to M, notes on a channels above M will use 'recycled' colors -- they will be plotted with the color for channel "channel-number % M" (where `%` = the MOD operator).

This means that if you specify

    channel-colors => ['00ffff','0000ff']

then all the channels' notes will be plotted with an aqua pixel followed by blue ones; and if you specify

    channel-colors => ['00ffff','0000ff', 'ff00ff','ff0000']

then all the *even* channels' notes will be plotted with an aqua pixel followed by blue ones, and all the *odd* channels' notes will be plotted with a purple pixel followed by red ones.

As to what to do with the object you get back, you probably want something like:

    $im = $chachacha->draw;
    open(OUT, ">$gif-out"); binmode(OUT);
    print OUT $im->gif;
    close(OUT);

Using this method will cause a `die` if it can't successfully `use GD`.

I emphasise that `draw` is expermental, and, in any case, is only meant to be a crude hack. Notably, it does not address well some basic problems: neither volume nor patch-selection (nor any notable aspects of the patch selected) are represented; pitch-wheel changes are not represented; percussion (whether on percussive patches or on channel 10) is not specially represented, as it probably should be; notes overlapping are not represented at all well.

WHERE'S THE DESTRUCTOR?
=======================

Because MIDI objects (whether opuses or tracks) do not contain any circular data structures, you don't need to explicitly destroy them in order to deallocate their memory. Consider this code snippet:

    use MIDI;
    foreach $one (@ARGV) {
      my $opus = MIDI::Opus->new({ 'from-file' => $one, 'no-parse' => 1 });
      print "$one has ", scalar( $opus->tracks ) " tracks\n";
    }

At the end of each iteration of the foreach loop, the variable $opus goes away, along with its contents, a reference to the opus object. Since no other references to it exist (i.e., you didn't do anything like push(@All-opuses,$opus) where @All-opuses is a global), the object is automagically destroyed and its memory marked for recovery.

If you wanted to explicitly free up the memory used by a given opus object (and its tracks, if those tracks aren't used anywhere else) without having to wait for it to pass out of scope, just replace it with a new empty object:

    $opus = MIDI::Opus->new;

or replace it with anything at all -- or even just undef it:

    undef $opus;

Of course, in the latter case, you can't then use $opus as an opus object anymore, since it isn't one.

NOTE ON TICKS
=============

If you want to use "negative" values for ticks (so says the spec: "If division is negative, it represents the division of a second represented by the delta-times in the file,[...]"), then it's up to you to figure out how to represent that whole ball of wax so that when it gets `pack()`'d as an "n", it comes out right. I think it'll involve something like:

    $opus->ticks(  (unpack('C', pack('c', -25)) << 8) & 80  );

for bit resolution (80) at 25 f/s.

But I've never tested this. Let me know if you get it working right, OK? If anyone *does* get it working right, and tells me how, I'll try to support it natively.

NOTE ON WARN-ING AND DIE-ING
============================

In the case of trying to parse a malformed MIDI file (which is not a common thing, in my experience), this module (or MIDI::Track or MIDI::Event) may warn() or die() (Actually, carp() or croak(), but it's all the same in the end). For this reason, you shouldn't use this suite in a case where the script, well, can't warn or die -- such as, for example, in a CGI that scans for text events in a uploaded MIDI file that may or may not be well-formed. If this *is* the kind of task you or someone you know may want to do, let me know and I'll consider some kind of 'no-die' parameter in future releases. (Or just trap the die in an eval { } around your call to anything you think you could die.)

COPYRIGHT 
==========

Copyright (c) 1998-2002 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

AUTHORS
=======

Sean M. Burke `sburke@cpan.org` (until 2010)

Darrell Conklin `conklin@cpan.org` (from 2010)

