#!/usr/bin/env python3
"""
Long Now Chimes MIDI Player

Implements the Long Now Foundation's 10,000-year chime algorithm in Python.
Generates unique bell sequences for each day using factoradic permutations.

Long Now chimes:  1  2  3  4  5  6   7  8  9  10
MIDI notes:       67 65 64 62 60 58  57 55 53 48
Note names:       G5 F5 E5 D5 C5 Bb4 A4 G4 F4 C4

Usage:
    # List available MIDI ports
    python long_now_chimes.py

    # Play today's unique chime sequence
    python long_now_chimes.py --today --port 0

    # Play chimes for a specific date
    python long_now_chimes.py --date 2024-07-24 --port 0

    # Play a week of chimes
    python long_now_chimes.py --date-range 2024-01-01 2024-01-07 --port 0

    # Show sequence without playing
    python long_now_chimes.py --date 2024-07-24 --show

    # Create MIDI file
    python long_now_chimes.py --today --file today.mid

    # Play custom sequence
    python long_now_chimes.py --sequence 1 3 5 7 9 --port 0
"""

import argparse
import random
import time
from datetime import datetime
from typing import List, Optional
import mido
from mido import Message, MidiFile, MidiTrack


# Bell to MIDI note mapping
BELL_TO_MIDI = {
    1: 67,   # G5
    2: 65,   # F5
    3: 64,   # E5
    4: 62,   # D5
    5: 60,   # C5
    6: 58,   # Bb4
    7: 57,   # A4
    8: 55,   # G4
    9: 53,   # F4
    10: 48,  # C4
}

# MIDI constants
DEFAULT_VELOCITY = 100  # Corresponds to ChucK's 0.6-0.8 noteOn range
MIDI_CHANNEL = 0


class LongNowChimes:
    """Long Now Foundation chime MIDI player."""

    def __init__(self, port: Optional[mido.ports.BaseOutput] = None,
                 midi_file: Optional[MidiFile] = None):
        """
        Initialize the chime player.

        Args:
            port: MIDI output port for real-time playback
            midi_file: MidiFile object for writing to file
        """
        self.port = port
        self.midi_file = midi_file
        self.current_track = None
        self.ticks_elapsed = 0

        if midi_file:
            self.current_track = MidiTrack()
            midi_file.tracks.append(self.current_track)

    def note_to_midi(self, bell_num: int) -> int:
        """Convert bell number (1-10) to MIDI note number."""
        if bell_num not in BELL_TO_MIDI:
            raise ValueError(f"Bell number must be 1-10, got {bell_num}")
        return BELL_TO_MIDI[bell_num]

    def get_note_duration(self) -> float:
        """
        Get humanized note duration in seconds.

        Mimics ChucK's setnotedur() randomization:
        - 30% chance: 1000ms
        - 30% chance: 1100ms
        - 30% chance: 1200ms (catch-all for randf() > -0.8)
        - 10% chance: 1300ms
        """
        rand = random.random()
        if rand > 0.7:
            return 1.0
        elif rand > 0.4:
            return 1.1
        elif rand > 0.1:
            return 1.2
        else:
            return 1.3

    def get_note_velocity(self) -> int:
        """Get randomized MIDI velocity (60-80% of max, like ChucK's 0.6-0.8)."""
        # MIDI velocity range: 0-127
        # ChucK uses 0.6-0.8, map to ~76-102
        return int(random.uniform(0.6, 0.8) * 127)

    def send_midi(self, msg: Message, delay: float = 0):
        """
        Send MIDI message to port or file.

        Args:
            msg: MIDI message to send
            delay: Delay in seconds before sending (for real-time playback)
        """
        if self.port:
            if delay > 0:
                time.sleep(delay)
            self.port.send(msg)

        if self.current_track is not None:
            # Convert delay to MIDI ticks (480 ticks per beat, 120 BPM = 0.5s per beat)
            ticks = int(delay * 480 * 2)  # 2 beats per second at 120 BPM
            msg.time = ticks
            self.current_track.append(msg)

    def bell(self, bell_num: int):
        """
        Play one bell with humanized timing.

        Args:
            bell_num: Bell number (1-10)
        """
        midi_note = self.note_to_midi(bell_num)
        velocity = self.get_note_velocity()
        duration = self.get_note_duration()

        # Note on
        note_on = Message('note_on', channel=MIDI_CHANNEL,
                         note=midi_note, velocity=velocity)
        self.send_midi(note_on)

        # Note off after duration
        note_off = Message('note_off', channel=MIDI_CHANNEL,
                          note=midi_note, velocity=0)
        self.send_midi(note_off, delay=duration)

    def peal_pause(self):
        """Pause between peals (3 seconds)."""
        if self.port:
            time.sleep(3.0)
        if self.current_track is not None:
            # Add a rest in the MIDI file
            ticks = int(3.0 * 480 * 2)
            # Add a dummy event with the delay
            msg = Message('note_on', channel=MIDI_CHANNEL, note=0, velocity=0, time=ticks)
            self.current_track.append(msg)

    def play_sequence(self, sequence: List[int]):
        """
        Play a sequence of bells.

        Args:
            sequence: List of bell numbers to play
        """
        for bell_num in sequence:
            self.bell(bell_num)
        self.peal_pause()

    def play_default_sequence(self):
        """Play the default test sequence from sampleChuck.ck."""
        # First peal: 1-10 in order
        self.play_sequence([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

        # Second peal: 2,1,3-10
        self.play_sequence([2, 1, 3, 4, 5, 6, 7, 8, 9, 10])

        # Final pause to let last note die out
        self.peal_pause()


# Date calculation functions (from LongNowPlayer.ck)

MINYEAR = 2000

def is_leap_year(year: int) -> bool:
    """Determine if a year is a leap year."""
    if year < MINYEAR:
        raise ValueError(f"Year {year} is before minimum year {MINYEAR}")

    if year % 4 == 0:
        if year % 100 == 0:
            if year % 400 == 0:
                return True
            return False
        return True
    return False


def days_in_year(year: int) -> int:
    """Get the number of days in a year."""
    return 366 if is_leap_year(year) else 365


def day_number(year: int, month: int, day: int) -> int:
    """
    Convert year/month/day to day number with January 1, 2000 == 0.

    Args:
        year: Year (>= 2000)
        month: Month (1-12)
        day: Day (1-31)

    Returns:
        Day number since January 1, 2000
    """
    month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    if year < MINYEAR:
        raise ValueError(f"Year {year} is before minimum year {MINYEAR}")
    if month < 1 or month > 12:
        raise ValueError(f"Month {month} out of range 1-12")
    if day < 1 or day > 31:
        raise ValueError(f"Day {day} out of range 1-31")

    if is_leap_year(year):
        month_days[1] = 29

    days_this_month = month_days[month - 1]
    if day > days_this_month:
        raise ValueError(f"Day {day} out of range for month {month} (max {days_this_month})")

    # Count days from MINYEAR to this date
    the_day_number = day - 1

    # Add days for complete years
    for y in range(MINYEAR, year):
        the_day_number += days_in_year(y)

    # Add days for complete months in this year
    for m in range(1, month):
        the_day_number += month_days[m - 1]

    return the_day_number


def factorial(x: int) -> int:
    """Compute factorial of x."""
    if x < 0:
        raise ValueError(f"Cannot take factorial of {x}")
    if x <= 1:
        return 1

    result = 1
    for i in range(2, x + 1):
        result *= i
    return result


# Long Now Permutation Algorithm (ported from AppleScript)

def funny_digit(n: int, i: int) -> int:
    """
    Generate one digit in factoradic (factorial base) representation.

    This is the core of the Long Now algorithm - it converts a day number
    into a unique permutation using the factoradic number system.
    """
    return int((n / factorial(i - 1)) % i)


def make_funny_list(n: int, bells: int) -> List[int]:
    """Generate complete factoradic representation for day number n."""
    return [funny_digit(n, i) for i in range(1, bells + 1)]


def insert_bell(the_list: List[int], offset: int, bell: int) -> List[int]:
    """Insert a bell at a specific position in the list."""
    if offset == 0:
        return [bell] + the_list
    else:
        front = the_list[:offset]
        back = the_list[offset:] if offset < len(the_list) else []
        return front + [bell] + back


def make_perm(f: List[int], e: List[int]) -> List[int]:
    """Build a permutation from factoradic list f and element list e."""
    out = []
    for i in range(len(f) - 1, -1, -1):
        out = insert_bell(out, f[i], e[i])
    return out


def make_permutation(f: List[int], bells: int) -> List[int]:
    """Generate permutation from factoradic list and number of bells."""
    # Canonical bell list (0-indexed, but we'll use 1-10 for output)
    bell_list = list(range(bells + 1))  # [0, 1, 2, ..., bells]
    bell_list.reverse()
    f_reversed = list(reversed(f))
    return make_perm(f_reversed, bell_list)


def nth_permutation(n: int, bells: int = 10) -> List[int]:
    """
    Calculate the Nth permutation for the Long Now algorithm.

    This is the main entry point - converts a day number into a unique
    bell sequence that won't repeat for 10,000 years.

    Args:
        n: Day number (0 = January 1, 2000)
        bells: Number of bells (default 10)

    Returns:
        List of bell numbers representing the sequence
    """
    perm = make_permutation(make_funny_list(n, bells), bells)
    return list(reversed(perm))


def chimes_for_day(year: int, month: int, day: int, period_days: int = 1) -> List[List[int]]:
    """
    Generate chime sequences for a date range.

    Args:
        year: Year (>= 2000)
        month: Month (1-12)
        day: Day (1-31)
        period_days: Number of days to generate (default 1)

    Returns:
        List of bell sequences, one for each day
    """
    chime_list = []
    the_day_number = day_number(year, month, day)

    for i in range(period_days):
        # Get permutation for this day, filter out 0 (use bells 1-10)
        new_chime = [b for b in nth_permutation(the_day_number + i, 10) if b > 0]
        chime_list.append(new_chime)

    return chime_list


# CLI functions

def list_midi_ports():
    """List available MIDI output ports."""
    print("\nAvailable MIDI output ports:")
    ports = mido.get_output_names()
    if not ports:
        print("  (no MIDI ports found)")
    for i, port in enumerate(ports):
        print(f"  {i}: {port}")
    print()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Long Now Chimes MIDI Player",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    # Output destination (mutually exclusive)
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument('--port', type=int, metavar='N',
                             help='MIDI output port number (use without args to list ports)')
    output_group.add_argument('--file', type=str, metavar='FILE',
                             help='Write to MIDI file instead of playing')

    # Sequence source (mutually exclusive)
    sequence_group = parser.add_mutually_exclusive_group()
    sequence_group.add_argument('--sequence', type=int, nargs='+', metavar='BELL',
                               help='Custom bell sequence (1-10)')
    sequence_group.add_argument('--date', type=str, metavar='YYYY-MM-DD',
                               help='Play chimes for a specific date')
    sequence_group.add_argument('--date-range', type=str, nargs=2,
                               metavar=('START', 'END'),
                               help='Play chimes for a date range (YYYY-MM-DD YYYY-MM-DD)')
    sequence_group.add_argument('--today', action='store_true',
                               help='Play chimes for today')

    # Other options
    parser.add_argument('--show', action='store_true',
                       help='Show the bell sequence without playing')
    parser.add_argument('--list-ports', action='store_true',
                       help='List available MIDI ports and exit')

    args = parser.parse_args()

    # List ports if requested or if no output specified
    if args.list_ports or (args.port is None and args.file is None and not args.show):
        list_midi_ports()
        if args.list_ports:
            return
        if args.port is None and args.file is None and not args.show:
            print("Specify --port N, --file FILE, or --show to play/display chimes")
            return

    # Parse date arguments and generate sequences
    sequences = []

    if args.date:
        # Parse single date
        try:
            date_obj = datetime.strptime(args.date, '%Y-%m-%d')
            chimes = chimes_for_day(date_obj.year, date_obj.month, date_obj.day, 1)
            sequences = chimes
            print(f"Date: {args.date}")
        except ValueError as e:
            print(f"Error parsing date: {e}")
            return

    elif args.date_range:
        # Parse date range
        try:
            start_date = datetime.strptime(args.date_range[0], '%Y-%m-%d')
            end_date = datetime.strptime(args.date_range[1], '%Y-%m-%d')
            days_diff = (end_date - start_date).days + 1

            if days_diff <= 0:
                print("Error: End date must be after start date")
                return

            chimes = chimes_for_day(start_date.year, start_date.month, start_date.day, days_diff)
            sequences = chimes
            print(f"Date range: {args.date_range[0]} to {args.date_range[1]} ({days_diff} days)")
        except ValueError as e:
            print(f"Error parsing date range: {e}")
            return

    elif args.today:
        # Use today's date
        today = datetime.now()
        chimes = chimes_for_day(today.year, today.month, today.day, 1)
        sequences = chimes
        print(f"Today: {today.strftime('%Y-%m-%d')}")

    elif args.sequence:
        # Custom sequence
        sequences = [args.sequence]

    else:
        # Default test sequence
        sequences = None

    # Show sequences if requested (without playing)
    if args.show:
        if sequences:
            for i, seq in enumerate(sequences):
                if len(sequences) > 1:
                    print(f"Day {i+1}: {seq}")
                else:
                    print(f"Sequence: {seq}")
        else:
            print("Default test sequence:")
            print("  Peal 1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]")
            print("  Peal 2: [2, 1, 3, 4, 5, 6, 7, 8, 9, 10]")
        return

    # Set up output
    port = None
    midi_file = None

    try:
        if args.port is not None:
            output_names = mido.get_output_names()
            if args.port < 0 or args.port >= len(output_names):
                print(f"Error: Port {args.port} out of range")
                list_midi_ports()
                return

            port_name = output_names[args.port]
            print(f"Opening MIDI port {args.port}: {port_name}")
            port = mido.open_output(port_name)

        elif args.file:
            print(f"Creating MIDI file: {args.file}")
            midi_file = MidiFile()

        # Create player
        player = LongNowChimes(port=port, midi_file=midi_file)

        # Play sequences
        if sequences:
            for i, seq in enumerate(sequences):
                if len(sequences) > 1:
                    print(f"Playing day {i+1}/{len(sequences)}: {seq}")
                else:
                    print(f"Playing sequence: {seq}")
                player.play_sequence(seq)
        else:
            print("Playing default test sequence...")
            player.play_default_sequence()

        # Save MIDI file if needed
        if midi_file:
            midi_file.save(args.file)
            print(f"MIDI file saved: {args.file}")

        print("Done!")

    finally:
        if port:
            port.close()


if __name__ == '__main__':
    main()
