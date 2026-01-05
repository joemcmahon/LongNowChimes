# Long Now Chimes - Python MIDI Player

A Python implementation of the Long Now Foundation's 10,000-year chime algorithm. Generates unique MIDI bell sequences for each day using factoradic permutations.

## Installation

1. **Create a virtual environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

**Note:** Remember to activate the virtual environment (`source venv/bin/activate`) each time you want to run the script in a new terminal session.

## Quick Start

### Play Today's Unique Chimes

```bash
# Show today's sequence without playing
python long_now_chimes.py --today --show

# Play to MIDI port
python long_now_chimes.py --today --port 0

# Save to MIDI file
python long_now_chimes.py --today --file today.mid
```

### Play Chimes for Specific Dates

```bash
# Play chimes for a specific date
python long_now_chimes.py --date 2024-07-24 --port 0

# Show the sequence without playing
python long_now_chimes.py --date 2000-01-01 --show

# Play a week of chimes
python long_now_chimes.py --date-range 2024-01-01 2024-01-07 --port 0
```

### List Available MIDI Ports

```bash
python long_now_chimes.py
```

You'll need a software synthesizer like:
- **macOS**: Built-in IAC Driver, Ableton Live, or third-party synths
- **Linux**: FluidSynth, timidity
- **Windows**: Virtual MIDI cables + synth

### Custom Sequences

```bash
# Play any custom bell sequence
python long_now_chimes.py --port 0 --sequence 1 3 5 7 9
```

## Bell Mapping

| Bell | MIDI Note | Note Name |
|------|-----------|-----------|
| 1    | 67        | G5        |
| 2    | 65        | F5        |
| 3    | 64        | E5        |
| 4    | 62        | D5        |
| 5    | 60        | C5        |
| 6    | 58        | Bb4       |
| 7    | 57        | A4        |
| 8    | 55        | G4        |
| 9    | 53        | F4        |
| 10   | 48        | C4        |

## Features

- **Long Now Algorithm**: Implements the factoradic permutation algorithm for 10,000 years of unique sequences
- **Date-Based Generation**: Play chimes for any date from 2000 onwards
- **Humanized Timing**: Random note durations (1.0-1.3s) and velocities
- **Multiple Outputs**: Real-time MIDI or file generation
- **Flexible Interface**: Dates, date ranges, custom sequences, or test patterns

## How It Works

The Long Now Foundation's chime algorithm uses **factoradic (factorial base) permutations** to generate unique bell sequences:

1. **Day Number**: Each date is converted to a day number (Jan 1, 2000 = 0)
2. **Factoradic Conversion**: The day number is converted to factoradic representation
3. **Permutation**: The factoradic number maps to a unique permutation of the 10 bells
4. **Uniqueness**: This ensures no two days have the same sequence for 10,000 years!

Example:
```bash
# January 1, 2000 (day 0) - the canonical sequence
$ python long_now_chimes.py --date 2000-01-01 --show
Sequence: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Today's unique sequence
$ python long_now_chimes.py --today --show
Today: 2026-01-05
Sequence: [7, 4, 2, 3, 1, 6, 8, 5, 9, 10]
```

## Setting Up Software Synth (macOS)

1. Open **Audio MIDI Setup** (in Applications/Utilities)
2. Window → Show MIDI Studio
3. Double-click **IAC Driver**
4. Check "Device is online"
5. You now have a virtual MIDI port!

Then use a synth like:
- GarageBand (connect to IAC Driver)
- Logic Pro
- Any AU/VST synth that accepts MIDI input

## Ideas for Extension

The core algorithm is implemented. You could extend it further:
- **Change Ringing Patterns**: Implement traditional English bell ringing methods (Plain Hunt, Grandsire, etc.)
- **MIDI Control Messages**: Add CC messages for expression, reverb, or other effects
- **Interactive Mode**: Real-time keyboard control or web interface
- **Visualization**: Display permutation patterns or factoradic representations
- **Audio Synthesis**: Integrate with synthesis libraries for standalone playback without external synths
- **Scheduling**: Automatically play chimes at specific times (cron job, system service)

## Original ChucK Code

This project ports the ChucK audio synthesis code to Python MIDI events. The original ChucK code is preserved in `*.ck` files.
