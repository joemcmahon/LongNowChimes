// LongNowPeal.ck

// Basic signal path
TubeBell voc=> Echo a => Echo b => Echo c => NRev r => dac;

0.95 => voc.gain;
.8 => r.gain;
.2 => r.mix;
1000::ms => a.max => b.max => c.max;
350::ms => a.delay => b.delay => c.delay;
.30 => a.mix => b.mix => c.mix;
0.0 => float old;

// shred to modulate the mix
fun void vecho_shred( )
{
    0.0 => float decider;
    0.0 => float mix;
    0.0 => float inc;
    0 => int n;

    // time loop
    while( true )
    {
        std.rand2f(0.0,1.0) => decider;

        // adjust mix level
        //  30% of the time, adjust between 0 and .3
        //  30% of the time, adjust between .24 and .48
        //  20% of the time, adjust between .24 and .32
        //  10% of the time, adjust to .15
        if( decider < .3 ) decider => mix;
        else if( decider < .6 ) .08*decider => mix;
        else if( decider < .8 ) .4*decider => mix;
        else .15 => mix;

        // fade from old setting to new
        // find the increment
        (mix-old)/1000.0 => inc;
        1000 => n;
        // do the fade by adjusting the mix by the increment every 1 ms 
        while( n-- ) {
            old + inc => old;
            old => a.mix => b.mix => c.mix;
            1::ms => now;
        }
        // save the current mix setting
        mix => old;

        // wait awhile and then adjust the mix again
        std.rand2(2,6)::second => now;
    }
}

// function to set tone duration
function int setnotedur() {
    // pick a noteon
    std.rand2f( 0.6, 0.8 ) => float onSave => voc.noteOn;

    // duration of the note - adjusted to humanize it a bit
    if( std.randf() > 0.7 )
    { 1000::ms => now; }
    else if( std.randf() > .7 )
    { 1100::ms => now; }
    else if( std.randf() > -0.8 )
    { 1200::ms => now; }
    else { 1300::ms => now; }

  // always successful
  return( 1 );
}

// Long Now chimes      1  2  3  4  5  6   7  8  9  10
// MIDI                 67 65 64 62 60 58  57 55 53 48 
//                      G5 F5 E5 D5 C5 Bb4 A4 G4 F4 C4
fun float note_to_midi( int note ) {
   	if( note == 1 ) { return(67.0); }
   	if( note == 2 ) { return(65.0); }
   	if( note == 3 ) { return(64.0); }
   	if( note == 4 ) { return(62.0); }
   	if( note == 5 ) { return(60.0); }
   	if( note == 6 ) { return(58.0); }
   	if( note == 7 ) { return(57.0); }
   	if( note == 8 ) { return(55.0); }
   	if( note == 9 ) { return(53.0); }
   	if( note == 10 ){ return(48.0); }
}

// play one bell
fun void bell (int bellNum) {
 // set the note's frequency
 std.mtof(note_to_midi(bellNum)) => voc.freq;
 // play it
 setnotedur();
}

// pause between peals
fun void pealPause() {
  3000::ms => now;
}

// let echo shred go
spork ~ vecho_shred();