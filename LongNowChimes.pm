
# Time-stamp: "2005-02-08 19:53:41 AST"

# This Perl file is for browsing the Clock of the Long Now chimes.
# It functions as a CGI, command-line program, or Perl module.
# See http://interglacial.com/clock/about.html

require 5;
package LongNowChimes;
use strict;
use warnings;
use vars qw(@ISA $VERSION $AUTHOR @EXPORT @EXPORT_OK @CSS_Styles
  @Bellnum2MIDI $MIDIPatch @BellNames $MIDI_Slop $MIDI_Comments
  $DEFAULT_CLI_OUTPUT_FORMAT $CGI_Embed_MIDI $Chime_PCM_Path
  $Mergeafter $Lame $Sox $MP3_Bitrate
);
@ISA = qw(Exporter);
$VERSION = '4.04';
$AUTHOR  = 'sburke@cpan.org';

                     #   q  r  s  t  u   v  w  x  y  z
                     #   1  2  3  4  5   6  7  8  9 10
@Bellnum2MIDI   = qw( - 67 65 64 62 60  58 57 55 53 48 - );
                     #  G5 F5 E5 D5 C5 Bþ4 A4 G4 F4 C4 
                     #              ^^
                     #           "middle C"

$CGI_Embed_MIDI = 0;
$MIDIPatch = 35;  # Some nice ones: 87 35 8 14 107 96 17 46 39 60 33
@BellNames = ('-', 'q' .. 'z');
$MIDI_Slop      = 0 unless defined $MIDI_Slop;
$MIDI_Comments  = 0 unless defined $MIDI_Comments;
$DEFAULT_CLI_OUTPUT_FORMAT = 'mp3';  # or:  txt, wav, pcm, mid

#========================================================================
BEGIN { *DEBUG = sub(){0} unless defined &DEBUG }
use constant MSWIN   => !!$ENV{'WINDIR'} && !$ENV{'SHELL'};
use constant CGI     => !!$ENV{'REQUEST_METHOD'};
use constant CRONTAB => !!$ENV{'MAILTO'};  # good crontabs set MAILTO!
use constant INTERACTIVE  => MSWIN || !(CGI or CRONTAB);
  # (Note that I assume that no-one will ever run this as a CGI
  #  on an MSWin box.  So don't even do that.)

use constant PATHSEP => MSWIN ? "\\" : "/";

$Chime_PCM_Path ||=  "." . PATHSEP;
$Mergeafter ||=  CGI ? "./mergeafter" : "mergeafter";
$Lame ||= "lame";
$Sox ||= "sox";
$MP3_Bitrate = CGI ? 40 : 192;
  # One of: 8 16 24 32 40 48 56 64 80 96 112 128 144 160 192 224 256 320
  # Recommended: between 40 and 192, inclusive

#---------------------------------------------------------------------------

@CSS_Styles = qw| colorbars colorboxesletters uncolored colorboxes  |; #sheetmusic

#use POSIX qw(floor);
use Carp qw(confess);

require Exporter;
@EXPORT = qw( ChimesForDay ChimesForDays ChimesForDayNextDate);
@EXPORT_OK = do { # allow exporting all subs except _* and allcaps ones
  no strict 'refs';
  sort grep { defined(&$_)
   and $_ ne 'confess' and $_ ne 'floor'
   and m/^[a-zA-Z]/s and !m/^[A-Z]{2,}$/s
  } keys %{ __PACKAGE__ . '::'}
};

#========================================================================
# Some rudimentary date-handling stuff:

my $MonthDays = [  # Days in each month in normal and leap years.  Note 1-indexed
 [0, 31, 28, 31,  30, 31, 30,  31, 31, 30,  31, 30, 31],
 [0, 31, 29, 31,  30, 31, 30,  31, 31, 30,  31, 30, 31]
];

use constant MINYEAR => 2000;

sub MatchYearMonthDay ($) {
  my($string) = @_;
  confess "Don't call MatchYearMonthDay in scalar context!" unless wantarray;
  if( $string and  $string =~ m{^(\d\d\d\d\d?)-(\d\d?)-(\d\d?)$}s ) {
    my($y,$m,$d) = ($1,$2,$3);
    return  $y, $m, $d,   sprintf '%05d-%02d-%02d', $y, $m, $d
     if $m > 0 and $m < 13 and $d > 0 and $d < 32;
  }
  return;
}

sub IsLeapYear ($) {
  my $y = $_[0];
  confess "Year too early: $y" if $y < MINYEAR;
  confess "Year must be an integer: $y" if $y != int($y);
  # It's a leapyear iff it's divisible by 4 but not 100 unless also by 400.
  if(0 == $y % 4) {
    if(0 == $y % 100) {
      if(0 == $y % 400) {
        return 1;
      }
      return 0;
    }
    return 1;
  }
  return 0;
}

sub DaysInYear ($) {
  my $y = $_[0];
  confess "Year too early: $y" if $y < MINYEAR;
  confess "Year must be an integer: $y" if $y != int($y);
  # It's a leapyear iff it's divisible by 4 but not 100 unless also by 400.
  if(0 == $y % 4) {
    if(0 == $y % 100) {
      if(0 == $y % 400) {
        return 366;
      }
      return 365;
    }
    return 366;
  }
  return 365;
}

sub DayNumber ($$$) {
  my($y,$m,$d) = @_;
  
  confess  "Year ($y) has to be an integer!" unless $y == int($y);
  confess "Month ($m) has to be an integer!" unless $m == int($m);
  confess   "Day ($d) has to be an integer!" unless $d == int($d);
  
  confess  "Year $y too early!" if $y < MINYEAR;
  confess "Month $m out of range [1,12]" if $m < 1 or $m > 12;
  confess   "Day $d out of range [1,31]" if $d < 1 or $d > 31;

  my $months_this_year = $MonthDays->[ IsLeapYear( $y ) ];
  my $days_this_month  = $months_this_year->[ $m ];
  confess   "Day $d out of range [1,$days_this_month] for month $m"
   if $d > $days_this_month;
  
  my $daycount = $d - 1;
  for(my $i = 2000; $i <  $y; $i++) { $daycount += DaysInYear($i)          }
  for(my $i =    0; $i <  $m; $i++) { $daycount += $months_this_year->[$i] }
  --$m;

  return $daycount;
}

sub YMDProgress ($$$$) {  # Pretty dates for an N-day period starting y/m/d
  my($y,$m,$d, $daycount) = @_;
  $daycount ||= 1;
  my @out;

  my %yearcal; # our little cache

  for(my $i = 0; $i < $daycount; $i++) {
    push @out, sprintf "%05d-%02d-%02d",  $y, $m, $d;
    ++$d;
    if( $d >
        (
          $yearcal{$y} ||=  $MonthDays->[ IsLeapYear( $y ) ]
        )->[ $m ]
    ) {
      $d = 1; $m++;
    }
    if($m == 13) { ++$y; $m = 1; $d = 1; }
  }
  
  return \@out;
}

sub NowYMD () {
  # Returns the current Y, M, D;
  my @now = gmtime();
  return $now[5] + 1900, $now[4] + 1, $now[3];
}

#========================================================================
# Some utility functions

sub factorial ($) {
  my($i) = $_[0];
  return 1 if $i == 0 or $i == 1;
  confess "Can't factorial $i!" if $i < 0 or int($i) != $i;
  my $x = 1;
  foreach my $factor (2 .. $i) { $x *= $factor }
  return $x;
}

sub _trace {
  my $depth = 0;
  my @x;
  while($depth < 30) {
    @x = caller($depth);
    last unless @x;
    ++$depth;
  }
  @x = caller(1);
  $x[3] =~ s{^LongNowChimes::}{};
  printf " %s %s.%s \n", " ." x $depth, @x[3,2], ;
  return;
}

sub random_month { sprintf "%05d-%02d-01",
  int(2000 + rand(10000)), int(1+rand(12));
}

#=============================================================================
# Finally the real stuff
#
# This is all based on some Mathematica code by Danny Hillis

sub FunnyDigit ($$) {
  my($n,$i) = @_;
  my $x = int( $n / factorial($i - 1) ) % $i; # was POSIX::floor instead of int
  DEBUG > 5 and _trace;
  return $x;
}


sub MakePerm ($$) {
  my($f,$e) = @_;  # both arrayrefs
  my @out;
  for( my $i = @$f - 1; $i >= 0; $i-- ) {
    splice @out, $f->[$i],  0, $e->[$i] ;
  }
  return \@out;
}

#Was:
#sub MakePerm ($$);
#sub MakePerm ($$) { # recursive
#  my($f,$e) = @_;  # both arrayrefs
#  return $f if @$f == 0;
#  
#  DEBUG > 10 and _trace;
#  
#  my $f_first = shift @$f;
#  my $e_first = shift @$e;
#  my $permy = MakePerm($f, $e);
#
#  #Was: Insert( $permy, $e_first, $f_first + 1);
#  
#  splice @$permy, $f_first,  0,  $e_first;
#  
#  return $permy;
#}


sub MakePermutation ($$) {
  my($f, $bells) = @_;  # f is an arrayref, bells is an integer
  DEBUG > 7 and _trace;
  return MakePerm(
    [ reverse @$f ],
    [ reverse( 0 .. $bells ) ]
  );
}

sub NthPermutation ($$) {
  my($n, $bells) = @_;   # both integers
  my $perm = MakePermutation(
    [ map FunnyDigit($n,$_), 1 .. $bells ],
    $bells
  );
  @$perm = reverse @$perm;
  return $perm;
}

sub ChimesForDay ($$$) {  # Should really be "BellsForDay" or "ChimeForDay"
  my($y,$m,$d) = @_;
  DEBUG > 4 and _trace;
  my $x = NthPermutation( DayNumber($y,$m,$d), 10);
  return @$x if wantarray;
  return join ',', @$x;
}

# End of serious goo.
#
#-----------------------------------------------------------------------------

sub ChimesForDays ($$$;$) {  # always returns a list(ref)-of-lists
  my($y,$m,$d, $day_count) = @_;
  $day_count ||= 1;
  DEBUG > 4 and _trace;

  my @chimes;
  my $that_day = DayNumber($y,$m,$d);

  for( my $stop_before = $that_day + $day_count ;
       $that_day < $stop_before ;
       ++$that_day
  ) {
    push @chimes, NthPermutation( $that_day, 10 );
  }

  return \@chimes;
}

#-----------------------------------------------------------------------------

sub DaysToMIDI ($;$$$) {# take a LoL like from ChimesForDays
  my($chimes, $comment, $prettydate, $filename) = @_;

  require MIDI;
  require MIDI::Score;

  my $qn  = 96; # one quarter-note
  my $vol = 96; # forte
  my $between = 8.5;  # number of quarter-notes' delay between chimes
  
  my $now = 0;
  my $channel = 0;
  
  #DEBUG > 2 and print "Instrument: $MIDI::number2patch{$MIDIPatch}\n";
  
  my @score;
  push @score, ['text_event', $now, $comment] if $comment;
  push @score, ['set_tempo', 0, 870_000];  # 1 qn => .87 seconds
  push @score, ['patch_change', $now, $channel, $MIDIPatch];
  
  for my $chime ( @$chimes ) {
    push @score, ['text_event', $now,
      join '', "Chime ",  map $BellNames[$_], @$chime
    ] if $MIDI_Comments;
    foreach my $bellnum (@$chime) {
      my $note = $Bellnum2MIDI[ $bellnum ];
      push @score, ['note', $now, $qn * 2, $channel, $note, $vol];
      $now += $qn
       + ($MIDI_Slop ? do{no integer; int(.5 * $MIDI_Slop - rand $MIDI_Slop)} : 0);
         # "Humanize something free of error" -- Oblique Strategies
    }
    $now += ($between - 1) * $qn         # do the pause between chimes
       + ($MIDI_Slop ? do{no integer; int(.5 * $MIDI_Slop - rand $MIDI_Slop)} : 0);
  }
  
  my $events_r = MIDI::Score::score_r_to_events_r( \@score );
  my $chimes_track = MIDI::Track->new({ 'events' => $events_r });
  my $chimes_opus = MIDI::Opus->new(
   { 'format' => 0, 'ticks' => 96, 'tracks' => [ $chimes_track ] } );


  if($filename) {
    $chimes_opus->write_to_file($filename);
  }

  return $chimes_opus;  # yes, returns a MIDI::Opus object.
}

#========================================================================
sub DaysToText ($;$$$) {
  my($chimes, $comment, $prettydate, $filename) = @_;
  if($filename eq '-') {
    *TEXT = *STDOUT; # a hack
  } else {
    open TEXT, ">$filename" or die "Can't write-open $filename: $!";
  }
  $comment and print TEXT $comment, "\n";
  foreach my $c (@$chimes) { print TEXT "@$c\n" }
  close(TEXT) unless $filename eq '-';
  return;
}

#========================================================================
sub DaysToFile ($;$$$) {# take a LoL like from ChimesForDays
  my($chimes, $comment, $prettydate, $filename) = @_;
  
  my $out_format;
  if($filename eq '-') { $out_format = 'txt' }
  elsif($filename =~ m/\.(\w+)$/ ) { $out_format = lc $1 }
  $out_format = 'mid' if $out_format eq 'midi';

  my $desc = join '', "Clock of the Long Now chimes for ",
    (@$chimes == 1) ? () :  ("the ", scalar(@$chimes), " days starting "),
    "$prettydate.  See LongNow.org",
  ;

  if($out_format eq 'mid' or $out_format eq 'midi') {
    DaysToMIDI( $chimes, $desc,     $prettydate, $filename);

  } elsif($out_format eq 'txt') {
    DaysToText( $chimes, "# $desc", $prettydate, $filename );

  } elsif($out_format eq 'wav' or $out_format eq 'pcm' or $out_format eq 'mp3') {
    DaysToAudio( $chimes, $desc,    $prettydate, $filename, $out_format);

  } else {
    die "Output format \"$out_format\" unknown.\n Aborting";
  }

  print "Wrote to $filename, ", -s $filename, " bytes.\n"
   unless $filename eq '-';
  
  return;
}

#========================================================================

sub _run_from_command_line {
  my($date, $daycount, $filename ) = @_;

  $date = random_month()  if $date  and $date eq 'random';
  $date and $date =~ s/^(\d\d\d\d\d?-\d\d)$/$1-01/;
   # allow 'year-month' and a shorthand for 'year-month-01"

  my($y,$m,$d, $prettydate) = $date ? MatchYearMonthDay( $date ) : ();

  unless( $prettydate ) {
    die join '', map "$_\n" =>
      "Usage: $0 yyyyy-mm-dd [ daycount [ outfilename ] ]",
      "   Generate the Clock of the Long Now chimes sequence for that date.",
      "    Or specify 'random' to get a random date.",
      "   Takes an optional number of additional days to generate for.",
      "    (Default: one month's worth.)",
      "   Takes an optional filename to specify a filename to write to.",
      "    or specify '-' to send text to console.",
      "\n   Example:   $0 07003-02-19",
      "\n        " . __PACKAGE__ . " v$VERSION $AUTHOR";
  }

  $daycount = '' if $daycount and $daycount eq 'm';

  if(!$filename and $daycount and $daycount !~ m/^\d+$/) {
    $filename = $daycount;
    $daycount = '';
  }
  
  $daycount ||= _month_duration( $prettydate );
  my $chimes  = ChimesForDays($y,$m,$d, $daycount);
  $filename ||= "$prettydate.$DEFAULT_CLI_OUTPUT_FORMAT";

  DaysToFile($chimes, '', $prettydate, $filename);
  #PlayChimesDirect($chimes);
  return;
}

sub PlayChimesDirect {
  my $chimes = shift;
  for my $chime (@$chimes) {
    system "PlayLongNowPeal @$chime";
  }
}

#========================================================================

sub _run_CGI {
  my $p = _init_CGI();
  return _run_CGI_MIDI($p) if 'midi' eq lc($p->{'format'} || '');
  return _run_CGI_MP3( $p) if 'mp3'  eq lc($p->{'format'} || '');
  return _run_CGI_HTML($p);
}

#========================================================================
sub _month_duration {
  my($y,$m);
  if(   @_ == 1) { ($y,$m) = MatchYearMonthDay($_[0]) }
  elsif(@_  > 1) { ($y,$m) = (@_) }
  else { return 31 }
  return $MonthDays->[ IsLeapYear( $y ) ]->[ $m ];
}

sub _init_CGI {
  my $p = {};
  _decode_get_form_to_hash( $p );

  my $daycount_be_month;
  {
    my $daycount = $p->{'daycount'} || 'm';
    $daycount_be_month = 1 if $daycount eq 'm';
    $daycount = (0 + $1) if $daycount =~ m/^(\d{1,2})$/s;
    $daycount ||= 30;
    $p->{'daycount'} = $daycount;
  }

  if(
     ($p->{'y'} ||= '') =~ m/^\d{4,5}$/s   and
     ($p->{'m'} ||='1') =~ m/^\d\d?$/s   and
     ($p->{'d'} ||='1') =~ m/^\d\d?$/s
  ) {
    $p->{'date'} = sprintf '%05d-%02d-%02d', @$p{'y','m','d'};
  }

  my($y,$m,$d, $prettydate);

  # Try whatever, if anything, was specified
  eval {
    @$p{'y','m','d', 'prettydate'} = MatchYearMonthDay( $p->{'date'} )
  };
  
  unless($p->{'prettydate'}) {
    # Default to today!
    @$p{'y','m','d'} = NowYMD();
    $p->{'prettydate'} = YMDProgress( $p->{'y'}, $p->{'m'}, $p->{'d'}, 1 )->[0];
  }

  $$p{'y'} = sprintf "%05d", $$p{'y'};

  $$p{'daycount'} = _month_duration(@$p{'y','m'}) if $daycount_be_month;

  return $p;
}
#========================================================================

sub _run_CGI_HTML {
  my($p) = $_[0] || {};
  my $chimes = _cgi_gen_chimes($p);

  print "Content-type: text/html\n\n";

  _print_HTML_header( $chimes, $p );
  _print_HTML_table(  $chimes, $p );
  _print_HTML_footer( $chimes, $p );

  return;
}


sub _print_HTML_table {
  my($chimes, $p) = @_;
  print _HTML_table($chimes,$p);
  return;
}

sub _HTML_table {
  my($chimes, $p) = @_;

  my $daynames = YMDProgress( $p->{'y'}, $p->{'m'}, $p->{'d'}, $p->{'daycount'} );

  my $out = join '',
    "\n<!-- Table for ",
      join('/', $p->{'y'}, $p->{'m'}, $p->{'d'}, $p->{'daycount'} ),
    " -->\n"
  ;

  $out .= "\n<table width='66%' bgcolor='#d0d0d0' align='center' style='chimetable'>\n";

  my $let;
  foreach my $chime (@$chimes) {
    $out .= join '', "<tr><th>", (shift @$daynames || ''), "</th>\n";
    #$out .= "\t<td class='staff'>&nbsp;</td>\n";
    foreach my $bell (@$chime) {
      $let = $BellNames[$bell];
      #$out .= "\t<td class='$let'><span class='i$let'>\u$let</span></td>\n";
      $out .= "\t<td class='$let'>\u$let</td>\n";
    }
    #$out .= "\t<td class='endbar'>&nbsp;</td>\n";
    $out .= "</tr>\n";
  }
  $out .= "</table>\n";
  return $out;
}



sub _print_HTML_header {
  my($chimes, $p) = @_;

  my(@types) = ('stylesheet');
  my $styles_head = join '',
    map sprintf(
     qq{\t<link rel="%s" type="text/css" title="%s" href="./%s.css" >\n},
     shift(@types) || 'alternate stylesheet', $_, $_,
    ), @CSS_Styles
  ;

#onclick="setActiveStyleSheet('default'); return false;"

  print

qq[<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html><head>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
  <title>$$p{'prettydate'} : Clock of the Long Now chimes browser</title>
  <meta name="robots" content="noindex,nofollow"> 
  <base		href="http://interglacial.com/clock/"	>
  
  <link rel="alternate" type="application/rss+xml"
   href="http://interglacial.com/rss/clock_of_the_long_now.rss"
   title="Daily Long Now chimes" >
$styles_head
  <script type="text/javascript" src="./styleswitcher.js"></script>

</head>
<body lang='en-US' class='chimey'>
<p style="text-align: center"
 class='noscreen'>http://interglacial.com/d/clock/</p>

];

  _print_HTML_intro($chimes,$p);

  return;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub _print_HTML_intro {
  my($chimes, $p) = @_;

  my $current = $$p{'prettydate'};

  my $midi_url =
   sprintf "%s?date=%s&amp;format=midi",
    $ENV{'SCRIPT_NAME'} || "WHOME",
    $$p{'prettydate'},
  ;
  my $mp3_url =
   sprintf "%s?date=%s&amp;format=mp3",
    $ENV{'SCRIPT_NAME'} || "WHOME",
    $$p{'prettydate'},
  ;

  my $styles_links = join '',
    map sprintf(
     qq{<a href="#_javascript" onclick="setActiveStyleSheet('%s'); return false;" title="Switch to %s style" >&#164;</a> },
     $_, $_
    ), @CSS_Styles
  ;

  print qq[

<div class='navvyform'>
<form action='$ENV{'SCRIPT_NAME'}' method='GET'>

year <input type=text name="y" value="$$p{'y'}"  size=7 maxlength=6
 accesskey='y' title='year'>
&nbsp;
&nbsp;
month <input type=text name="m" value="$$p{'m'}"  size=7 maxlength=6
 accesskey='m' title='month'>

&nbsp;
&nbsp;
day <input type=text name="d" value="$$p{'d'}"  size=7 maxlength=6
  accesskey='m' title='day'>

&nbsp;
&nbsp;

<select name="daycount"> 
 <option value="1">For 1 day</option> 
 <option value="7">For 7 days</option> 
 <option value="10">For 10 days</option> 
 <option value="m" selected >For a month</option> 
 <option value="31">For 31 days</option> 
</select>

&nbsp;
&nbsp;

<input type="submit" value="&raquo; Go &raquo;"
 accesskey='g' title="click to go to the date you've specified"> 
</form>
</div>

]
  ;

  if( $CGI_Embed_MIDI ) {
    print qq[<div class='showmidi withembed'><embed
      src="$midi_url&amp;dummy=.mid"
      type="audio/midi"
      hidden="false" autostart="true" autoplay="true" volume="75%"
     ></embed>&nbsp;&nbsp;];
  } else {
    print qq[<div class='showmidi withoutembed'>];
  }

  print qq[<a href="$midi_url">Hear $current as midi</a>
<br><a href="$mp3_url">Hear $current as mp3</a>

<br><br><a href="./about.html">About</a>

</div>

<div class="peals">
<p class='stylelist'>( Styles: $styles_links )</p>

]
  ;

  return;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub _print_HTML_footer {
  my($chimes, $p) = @_;
  print "\n</div>\n\n</body></html>\n";
  return;
}

#========================================================================

sub _run_CGI_MIDI {
  my($p) = $_[0] || {};
  
  my $chimes = _cgi_gen_chimes($p);
  my $midi = DaysToMIDI(
    $chimes,
    "Clock of the Long Now chimes for $$p{'prettydate'}.  See LongNow.org"
  );
  
  my $file_name = "coln$$p{'prettydate'}.mid";
  print "Content-type: audio/midi; name=$file_name\n",
   "Content-Disposition: inline; filename=$file_name\n",
   "\n";
  $midi->write_to_handle( *STDOUT{IO} );
  
  return;
}

#------------------------------------------------------------------------

sub _run_CGI_MP3 {
  my($p) = $_[0] || {};
  my $chimes = _cgi_gen_chimes($p);
  $$p{'prettydate'} or confess "What input?";
  DaysToAudio( $chimes, '', $$p{'prettydate'}, '', 'mp3');
  return;
}

#========================================================================

sub _cgi_gen_chimes {
  my($p) = @_;
  my $chimes;
  eval { $chimes = ChimesForDays( $p->{'y'}, $p->{'m'}, $p->{'d'},
    $p->{'daycount'}
    )
  };

  if($@) { # check for errors
    print "Status: 500 Internal Server Error\nContent-type: text/plain\n\n",
      "Can't generate chimes for ", 
      $p->{'prettydate'} || "any such date",
      ":\n", $@, "\n",  ;
    exit;
  }
  return $chimes;
}

#========================================================================

sub _decode_get_form_to_hash { # good enough
  my($hash_r, $name, $value) = $_[0];
  return $hash_r unless $ENV{'QUERY_STRING'};
  foreach my $pair (split m/[&;]/, $ENV{'QUERY_STRING'} ) {
    foreach ( ($name, $value) = split('=', $pair) ) {
      tr/+/ /;  s/%([a-fA-F0-9]{2})/pack("C", hex($1))/eg;
    }
    $hash_r->{$name} = $value;
  }
}

#-----------------------------------------------------------------------------

if(caller) {
  # Normal use -- I'm being called as a module.
}
# Otherwise, I'm being called as a program, so let's get bizzay!
elsif( $ENV{'SCRIPT_NAME'} ) {
  _run_CGI();
} else {
  _run_from_command_line( @ARGV );
}

###########################################################################
# Here comes the pain.

sub DaysToAudio ($;$$$$) {
  my($chimes, $comment, $prettydate, $filename, $format) = @_;

  #
  # This routine is horrendous and ugly because it has to call an external
  #  program to mix the bell samples together (mergeafter) for each peal, and
  #  then another program (lame or sex) to convert to the desired format.
  # This is made even uglier by the fact that I've made it run under Unix
  #  shell (the Bourne shell) as well as under MSWin.
  # 
  # This assumes that you have mergeafter (or mergeafter.exe) installed,
  #  and: sox if you're going to make .wav files; or lame installed if
  #  you're going to make .mp3 files.
  # And that you have the q.pcm - z.pcm files in the $Chime_PCM_Path dir.
  #
  #
  # One good thing about this is that under Unix, it doesn't generate any
  #  temp files -- it just streams to the output file, or to STDOUT
  #  if we're running as a CGI.  If, as a CGI, the browser aborts, then
  #  the mp3 encoding and everything aborts too.
  #

  my $daycount = @$chimes;
  my $samples_per_sec = 44_000;
  my $peal_length = int( 17.6 * $samples_per_sec );
  my(@start_times) = map int($samples_per_sec * .87 * $_), 0 .. 9;

  $filename ||= "$prettydate.$format";

  my $temp_pcm = MSWIN ? "temp$^T.pcm" : "temp$^T-$$.pcm";

  DEBUG and print "Chimes starting $prettydate:\n";

  my(@to_run);
  my $count = scalar @$chimes;
  my $sofar = 1;

  if(MSWIN) {
    push @to_run, qq[\@echo off
rem 
rem MSWin batch file to generate chimes for $prettydate
rem


if exist $temp_pcm del $temp_pcm
rem > $temp_pcm
echo _______ Generating $count peals, starting $prettydate _______
];
  } else {
    push @to_run,
      "(",
     INTERACTIVE ? 
     "echo '_______ Generating $count peals, starting $prettydate _______' 1>&2;"
       : ()
  }



  foreach my $c (@$chimes) {
    @$c = map $LongNowChimes::BellNames[$_], @$c;
    DEBUG > 2 and print " peal: @$c\n";

    if(MSWIN) {
      push @to_run, sprintf "echo %s : %02d/%02d",
       join('', @$c),
           $sofar,        $count,
    } elsif(INTERACTIVE) {
      push @to_run, sprintf "echo ' %s : %02d/%02d  |%s%s|' 1>&2;",
       join('', @$c),
           $sofar,        $count,
       '#' x $sofar, '-' x ($count - $sofar),
    }

    my(@starts) = (@start_times);
    push @to_run, join ' ',
      "$Mergeafter $peal_length ",
      (map {; $Chime_PCM_Path . "$_.pcm", shift @starts } @$c),
      MSWIN ? ">>$temp_pcm"  : ';'
    ;

    ++$sofar;
  }


  if(MSWIN) {
    push @to_run, qq[
echo.
echo      Preparing $filename ...
echo.
];

    push @to_run,
     ($format eq 'mp3') ?
      qq[$Lame -r -x -b$MP3_Bitrate --ta Eno/LongNow --tt "$prettydate + $daycount days" $temp_pcm $filename]

     : ($format eq 'wav') ?
      qq[$Sox -t raw -r 44100 -s -w -c 2   $temp_pcm $filename]
       #
       # There's actually a simpler and slightly faster way to do this:
       #  just start off with a raw WAV header with a blank length
       #  pointer, then stream the PCM data into it, then once we're all
       #  done, go back into the file and change the length header to have
       #  the correct figure, based on the filesize.  (And maybe is there
       #  some sequence to append to the end to make it a good WAV file?)
       # However, sox is simple and on-hand, so we use that.
       #

     : ($format eq 'pcm') ?     # a harmless hack:
      ( "if exist $filename del $filename", "rename $temp_pcm $filename", "rem > $temp_pcm")

     : die "Unknown output format $format!  Aborting"
    ;

    push @to_run, qq[
del $temp_pcm
echo.
dir $filename
echo.
echo Done.
];
   # A longer "lame" line might overflow the stupid MSWin shell
   #  line-length limit.  So we keep it short.
    
  } else {
    my $lameto = $filename;
    $lameto = '-' if CGI;
    my $nice = CGI ? "nice " : "";
    push @to_run,
     ($format eq 'mp3') ? qq[
 ) |
$nice$Lame -r -x -b$MP3_Bitrate --quiet
  --tt '$prettydate + $daycount days'
  --ta 'Brian Eno'  --ty 2005  --tg Ambient
  --tl 'Chimes of the Clock of the Long Now'
  --tc 'tech: Danny Hillis, Sean Burke; http://interglacial.com/d/clock'
  - $lameto  2>/dev/null
;
]
     : ($format eq 'wav') ? qq[\n) |\n$Sox -t raw -r 44100 -s -w -c 2   - $filename]
         # see note above, about sox
     : ($format eq 'pcm') ? ") > $filename"
     : die "Unknown output format $format!  Aborting"
    ;


  }

  my $to_run = join "\n", @to_run;

  unless(MSWIN) {
    $to_run =~ s/^\s+//s;
    $to_run =~ s/\s+$//s;
    $to_run =~ s/\n/ \\\n/g; # sh's "line continues" symbol

    CGI and  $to_run = qq[echo Status: 200 OK
echo "Content-Type: audio/mp3; name=$filename"
echo "Content-Disposition: attachment; filename=$filename"
#echo "Content-Encoding: gzip"
echo ""
] . $to_run 
    ;

    $to_run = "\n# Bourne shell script to generate peals for $prettydate\n\n" . $to_run;
    INTERACTIVE and $to_run .= "\necho 'Done' 1>&2;\nls -l '$filename' 1>&2;\n";
  }

  DEBUG and print "To run: $to_run\n";
  if(DEBUG > 10) {
    print "(Not actually running)\n";
    return;
  }

#1 and print "Content-type: text/plain\n\nOkay so far...\n\n$to_run\n"; return;

  if(MSWIN) {  
    my $bat = ($ENV{TEMP} || $ENV{TMP} || '.') . "\\temp_$^T.bat";
    open BAT, ">", $bat or die "Can't write-open $bat: $!";
    print BAT $to_run;
    close(BAT);
    sleep 0;
    system "command.com", "/c", $bat;
  } else {
  
    CGI and $|++; 
    open SH, "|sh" or die "Can't open a channel to the shell";
    print SH $to_run;
    close(SH);
  }
  
  return;
}

#========================================================================

1;

__END__


#
# And here, so it doesn't go missing, is the C source code for "mergeafter":
#


/*
 * Abhijit Menon-Sen <ams@wiw.org>
 * 2004-11-22
 */

/*
 * a simple 'gcc -o mergeafter mergeafter.c' should compile this nicely
 */

#include <stdio.h>
#include <stdlib.h>

int main( int argc, char *argv[] )
{
    int i, j, n;
    int outlength;

    FILE **inputs;
    int *delays;


    if ( argc < 4 || argc%2 == 1 ) {
        fprintf( stderr,
                 "Usage: mergeafter outlength "
                 "x1.pcm 12345 x2.pcm 23456 [filename delay] ...\n" );
        exit( -1 );
    }


    n = (argc-2)/2;
    if ( ( inputs = malloc( n * sizeof( FILE * ) ) ) == 0 ||
         ( delays = malloc( n * sizeof( int ) ) ) == 0 )
    {
        fprintf( stderr, "Couldn't allocate memory.\n" );
        exit( -1 );
    }


    outlength = atoi( argv[1] );

    i = 2;
    j = 0;
    while ( i < argc ) {
        inputs[j] = fopen( argv[i], "r" );
        if ( !inputs[j] ) {
            fprintf( stderr, "Can't open input file %s", argv[i] );
            exit( -1 );
        }
        delays[j] = atoi( argv[i+1] );
        i += 2;
        j++;
    }


    while ( outlength-- ) {
        unsigned char buf[4];
        unsigned short int l = 0;
        unsigned short int r = 0;

        i = 0;
        while ( i < n ) {
            if ( ( delays[i] <= 0 || delays[i]-- == 0 ) &&
                 inputs[i] )
            {
                if ( fread( buf, 1, 4, inputs[i] ) < 4 ) {
                    fclose( inputs[i] );
                    inputs[i] = 0;
                    continue;
                }

                l += ( buf[1] << 8 | buf[0] );
                r += ( buf[3] << 8 | buf[2] );
            }

            i++;
        }

        buf[0] = l & 0xff;
        buf[1] = ( l >> 8 ) & 0xff;
        buf[2] = r & 0xff;
        buf[3] = ( r >> 8 ) & 0xff;

        fwrite( buf, 1, 4, stdout );
    }

    return 0;
}

====== And now a basic tests file for the LongNow chimes code ======

require 5;
use strict;
use warnings;
use LongNowChimes qw(/^/);
use Test::More tests => 53;

ok 1, "Running $0 under Perl $]";

print "# LongNowChimes v$LongNowChimes::VERSION\n";

is_deeply 
  [ map NthPermutation($_,3), 0 .. ( factorial(3) - 1 ) ],
  [
   map {; @$_ = reverse @$_; $_}
   [3,2,1],[3,1,2],[2,3,1],[1,3,2],[2,1,3],[1,2,3]],
  "NthPermutation"
;
 
is_deeply
  NthPermutation(1567806,10),
  [reverse 7,5,9,3,10,4,6,2,1,8], # because from .nb
  "NthPermutation"
;

is_deeply
  [ map NthPermutation($_,10), 1567806 .. 1567816 ],
  [
   map {; @$_ = reverse @$_; $_}  # because these chimes from the .nb file are backwards
   [7,5,9,3,10,4,6,2,1,8], [7,5,9,3,10,4,6,1,2,8],
   [7,5,9,2,10,4,6,3,1,8], [7,5,9,1,10,4,6,3,2,8], [7,5,9,2,10,4,6,1,3,8],
   [7,5,9,1,10,4,6,2,3,8], [7,5,9,3,10,2,6,4,1,8], [7,5,9,3,10,1,6,4,2,8],
   [7,5,9,2,10,3,6,4,1,8], [7,5,9,1,10,3,6,4,2,8], [7,5,9,2,10,1,6,4,3,8]],
  'NthPermutation'
;

is_deeply(
[map NthPermutation($_,10), 1827308 .. 1827308+31],
[
   map {; @$_ = reverse @$_; $_}  # because these chimes from the .nb file are backwards
	[9,2,3,8,5,10,7,1,4,6],[9,1,3,8,5,10,7,2,4,6],
	[9,2,1,8,5,10,7,3,4,6],[9,1,2,8,5,10,7,3,4,6],[9,4,3,8,2,10,7,5,1,6],
	[9,4,3,8,1,10,7,5,2,6],[9,4,2,8,3,10,7,5,1,6],[9,4,1,8,3,10,7,5,2,6],
	[9,4,2,8,1,10,7,5,3,6],[9,4,1,8,2,10,7,5,3,6],[9,3,4,8,2,10,7,5,1,6],
	[9,3,4,8,1,10,7,5,2,6],[9,2,4,8,3,10,7,5,1,6],[9,1,4,8,3,10,7,5,2,6],
	[9,2,4,8,1,10,7,5,3,6],[9,1,4,8,2,10,7,5,3,6],[9,3,2,8,4,10,7,5,1,6],
	[9,3,1,8,4,10,7,5,2,6],[9,2,3,8,4,10,7,5,1,6],[9,1,3,8,4,10,7,5,2,6],
	[9,2,1,8,4,10,7,5,3,6],[9,1,2,8,4,10,7,5,3,6],[9,3,2,8,1,10,7,5,4,6],
	[9,3,1,8,2,10,7,5,4,6],[9,2,3,8,1,10,7,5,4,6],[9,1,3,8,2,10,7,5,4,6],
	[9,2,1,8,3,10,7,5,4,6],[9,1,2,8,3,10,7,5,4,6],[9,4,3,8,2,10,7,1,5,6],
	[9,4,3,8,1,10,7,2,5,6],[9,4,2,8,3,10,7,1,5,6],[9,4,1,8,3,10,7,2,5,6]],
"seq1"
);

sub R($){ join ',', reverse split m/,/, $_[0] }

is_deeply scalar ChimesForDay( 7003,1, 1), R '9,2,3,8,5,10,7,1,4,6', "Chimes 07003-01-01";
is_deeply scalar ChimesForDay( 7003,1, 2), R '9,1,3,8,5,10,7,2,4,6', "Chimes 07003-01-02";
is_deeply scalar ChimesForDay( 7003,1, 3), R '9,2,1,8,5,10,7,3,4,6', "Chimes 07003-01-03";
is_deeply scalar ChimesForDay( 7003,1, 4), R '9,1,2,8,5,10,7,3,4,6', "Chimes 07003-01-04";
is_deeply scalar ChimesForDay( 7003,1, 5), R '9,4,3,8,2,10,7,5,1,6', "Chimes 07003-01-05";
is_deeply scalar ChimesForDay( 7003,1, 6), R '9,4,3,8,1,10,7,5,2,6', "Chimes 07003-01-06";
is_deeply scalar ChimesForDay( 7003,1, 7), R '9,4,2,8,3,10,7,5,1,6', "Chimes 07003-01-07";
is_deeply scalar ChimesForDay( 7003,1, 8), R '9,4,1,8,3,10,7,5,2,6', "Chimes 07003-01-08";
is_deeply scalar ChimesForDay( 7003,1, 9), R '9,4,2,8,1,10,7,5,3,6', "Chimes 07003-01-09";
is_deeply scalar ChimesForDay( 7003,1,10), R '9,4,1,8,2,10,7,5,3,6', "Chimes 07003-01-10";

is_deeply scalar ChimesForDay( 7003,1,11), R '9,3,4,8,2,10,7,5,1,6', "Chimes 07003-01-11";
is_deeply scalar ChimesForDay( 7003,1,12), R '9,3,4,8,1,10,7,5,2,6', "Chimes 07003-01-12";
is_deeply scalar ChimesForDay( 7003,1,13), R '9,2,4,8,3,10,7,5,1,6', "Chimes 07003-01-13";
is_deeply scalar ChimesForDay( 7003,1,14), R '9,1,4,8,3,10,7,5,2,6', "Chimes 07003-01-14";
is_deeply scalar ChimesForDay( 7003,1,15), R '9,2,4,8,1,10,7,5,3,6', "Chimes 07003-01-15";
is_deeply scalar ChimesForDay( 7003,1,16), R '9,1,4,8,2,10,7,5,3,6', "Chimes 07003-01-16";
is_deeply scalar ChimesForDay( 7003,1,17), R '9,3,2,8,4,10,7,5,1,6', "Chimes 07003-01-17";
is_deeply scalar ChimesForDay( 7003,1,18), R '9,3,1,8,4,10,7,5,2,6', "Chimes 07003-01-18";
is_deeply scalar ChimesForDay( 7003,1,19), R '9,2,3,8,4,10,7,5,1,6', "Chimes 07003-01-19";
is_deeply scalar ChimesForDay( 7003,1,20), R '9,1,3,8,4,10,7,5,2,6', "Chimes 07003-01-20";

is_deeply scalar ChimesForDay( 7003,1,21), R '9,2,1,8,4,10,7,5,3,6', "Chimes 07003-01-21";
is_deeply scalar ChimesForDay( 7003,1,22), R '9,1,2,8,4,10,7,5,3,6', "Chimes 07003-01-22";
is_deeply scalar ChimesForDay( 7003,1,23), R '9,3,2,8,1,10,7,5,4,6', "Chimes 07003-01-23";
is_deeply scalar ChimesForDay( 7003,1,24), R '9,3,1,8,2,10,7,5,4,6', "Chimes 07003-01-24";
is_deeply scalar ChimesForDay( 7003,1,25), R '9,2,3,8,1,10,7,5,4,6', "Chimes 07003-01-25";
is_deeply scalar ChimesForDay( 7003,1,26), R '9,1,3,8,2,10,7,5,4,6', "Chimes 07003-01-26";
is_deeply scalar ChimesForDay( 7003,1,27), R '9,2,1,8,3,10,7,5,4,6', "Chimes 07003-01-27";
is_deeply scalar ChimesForDay( 7003,1,28), R '9,1,2,8,3,10,7,5,4,6', "Chimes 07003-01-28";
is_deeply scalar ChimesForDay( 7003,1,29), R '9,4,3,8,2,10,7,1,5,6', "Chimes 07003-01-29";
is_deeply scalar ChimesForDay( 7003,1,30), R '9,4,3,8,1,10,7,2,5,6', "Chimes 07003-01-30";

is_deeply scalar ChimesForDay( 7003,1,31), R '9,4,2,8,3,10,7,1,5,6', "Chimes 07003-01-31";
is_deeply scalar ChimesForDay( 7003,2, 1), R '9,4,1,8,3,10,7,2,5,6', "Chimes 07003-02-01";







is_deeply scalar ChimesForDay( 2000, 1, 1), '1,2,3,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay( 2000, 1, 2), '2,1,3,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay( 2000, 1, 3), '1,3,2,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay( 2000, 1, 4), '2,3,1,4,5,6,7,8,9,10';

is_deeply scalar ChimesForDay( 3000, 1, 1), '3,5,2,7,4,6,1,8,10,9';
is_deeply scalar ChimesForDay( 3000,12,10), '4,6,1,7,5,2,3,8,10,9';

is_deeply scalar ChimesForDay(11000, 1, 1), '10,4,3,6,8,2,1,7,5,9';
is_deeply scalar ChimesForDay(11900, 1, 1), '10,9,2,4,8,5,7,1,3,6';

is_deeply scalar ChimesForDay(11935, 4,24), '10,9,8,7,6,5,4,2,3,1';
is_deeply scalar ChimesForDay(11935, 4,25), '10,9,8,7,6,5,4,3,1,2';
is_deeply scalar ChimesForDay(11935, 4,26), '10,9,8,7,6,5,4,3,2,1';
is_deeply scalar ChimesForDay(11935, 4,27), '1,2,3,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay(11935, 4,28), '2,1,3,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay(11935, 4,29), '1,3,2,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay(11935, 4,30), '2,3,1,4,5,6,7,8,9,10';
is_deeply scalar ChimesForDay(11935, 5, 1), '3,1,2,4,5,6,7,8,9,10';

# That's it.
