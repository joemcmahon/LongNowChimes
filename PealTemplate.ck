std.mtof( note_to_midi( $note )) =>  freq;
freq => voc.freq;
chout => "i, freq: " => $note => ", " => freq => endl;
setnotedur();
