// LongNowPeal.ck

TubeBell voc=> NRev r => Echo a => Echo b => Echo c => dac;

// was 220.0
880.0 => voc.freq;
0.95 => voc.gain;
.8 => r.gain;
.2 => r.mix;
1000::ms => a.max => b.max => c.max;
750::ms => a.delay => b.delay => c.delay;
.40 => a.mix => b.mix => c.mix;

// shred to modulate the mix
fun void vecho_shred( )
{
    0.0 => float decider;
    0.0 => float mix;
    0.0 => float old;
    0.0 => float inc;
    0 => int n;

    // time loop
    while( true )
    {
        std.rand2f(0.0,1.0) => decider;
        if( decider < .3 ) 0.1*decider => mix;
        else if( decider < .6 ) .08*decider => mix;
        else if( decider < .8 ) .4*decider => mix;
        else .15 => mix;

        // find the increment
        (mix-old)/1000.0 => inc;
        1000 => n;
        while( n-- )
        {
            old + inc => old;
            old => a.mix => b.mix => c.mix;
            1::ms => now;
        }
        mix => old;
        std.rand2(2,6)::second => now;
    }
}

// let echo shred go
spork ~ vecho_shred();

// function to set tone duration
function int setnotedur() {
    std.rand2f( 0.6, 0.8 ) => float onSave => voc.noteOn;
    // report
    // voc.freq => stdout;
    // onSave => stdout;

    // duration
    if( std.randf() > 0.7 )
    { 1000::ms => now; }
    else if( std.randf() > .7 )
    { 1100::ms => now; }
    else if( std.randf() > -0.8 )
    { 1200::ms => now; }
    else
    {
        0 => int i;
        2 * std.rand2( 1, 3 ) => int pick;
        0 => int pick_dir;
        0.0 => float pluck;

	for( ; i < pick; i++ )
        {
            std.rand2f(.4,.6) + (float)i*.035 => pluck;
            pluck + 0.03 * (float)(i * pick_dir) => voc.noteOn;
            !pick_dir => pick_dir;
            1300::ms => now;
        }
    }

    // report
    // machine.status();
  return( 1 );
}

0 => int i;
0.0 => float freq;
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

// our main program
float freq;
