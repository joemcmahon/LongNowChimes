-- LongNowChimes.applescript
-- LongNowChimes

--  Created by Joe McMahon on 3/4/05.
--  Copyright (c) 2005 by Joe McMahon and the Long Now Foundation. All rights reserved.

-- base year
property MINYEAR : 2000

-- settings window
property panelWIndow : missing value

-- a peal is currently playing
property pealIsPlaying : false

on awake from nib theObject
	set pealIsPlaying to false
	set the contents of text field "peal" to "Enter date as YYYYY MM DD"
	-- load the panel here?
end awake from nib

-- handle clicks in the interface
on clicked theObject
	-- or load it here?
	
	tell window of theObject
		try
			-- attempt to generate and play a peal
			set theChuckProgram to ""
			set theDate to the contents of text field "date"
			set the contents of text field "peal" to "Determining peal ..."
			-- get the date info
			set theYear to word 1 of theDate as integer
			set theMonth to word 2 of theDate as integer
			set theDay to word 3 of theDate as integer
			-- peal length
			set periodDays to title of current menu item of popup button "howLong"
			if (periodDays = "1 month") then
				set periodDays to 30
			else if (periodDays = "2 months") then
				set periodDays to 60
			else if (periodDays = "3 months") then
				set periodDays to 90
			else if (periodDays = "6 months") then
				set periodDays to 180
			else if (periodDays = "1 year") then
				set periodDays to 365
			end if
			-- generate list of peals
			set thePeal to my ChimesForDay(theYear, theMonth, theDay, periodDays)
			set homeDocs to (path to documents folder from user domain as string)
			set the contents of text field "peal" to "Playing peal (press command-. to cancel)"
			-- build chuck program and run it synchronously
			set theChuckProgram to POSIX path of my BuildPealProgram(thePeal, homeDocs)
			set chuckPath to my findChucKBin()
			do shell script chuckPath & " " & theChuckProgram
			
		on error errMessage
			if errMessage = "Can't make word 1 of \"\" into a integer." then
				set the contents of text field "peal" to "Missing date - enter date as YYYYY MM DD"
			else if errMessage = "User canceled." then
				-- command-. to stop peal. Just reset.
				set the contents of text field "peal" to "Enter date as YYYYY MM DD"
			else
				-- oops. show error.
				set the contents of text field "peal" to errMessage
			end if
		end try
		
		-- if program was generated, delete it.
		if (theChuckProgram ­ "") then
			do shell script "rm -f " & theChuckProgram
		end if
	end tell
	-- if the stop button was clicked:
end clicked

-- where's ChucK?
on findChucKBin()
	return POSIX path of ((path to me as string) & "Contents:Resources:chuck")
end findChucKBin

-- build the ChucK program that plays the peal
on BuildPealProgram(thePealList, saveFolder)
	set theOutputFile to saveFolder & "LongNowPeal.ck"
	-- open the output file
	set theHandle to open for access file (theOutputFile as string) with write permission
	-- get the header
	set headerHandle to open for access file ((path to me as string) & "Contents:Resources:PealHeader.ck")
	set theHeader to read headerHandle
	close access headerHandle
	write theHeader to theHandle
	-- write the peal-playing code into the file
	repeat with thePeal in thePealList
		set thePealFragment to my chuckPeal(thePeal)
		write thePealFragment to theHandle starting at eof
	end repeat
	-- add the final bit
	set trailerHandle to open for access ((path to me as string) & "Contents:Resources:PealTrailer.ck")
	set theTrailer to read trailerHandle
	close access trailerHandle
	write theTrailer to theHandle starting at eof
	close access theHandle
	return theOutputFile
end BuildPealProgram

-- write the ChucK code to play the peal
on chuckPeal(theList)
	set theProgram to ""
	repeat with bell in theList
		set theProgram to theProgram & "bell(" & bell & ");"
	end repeat
	theProgram & "pealPause();"
end chuckPeal

-- terminate execution if the window is closed
on should quit after last window closed theObject
	return true
end should quit after last window closed

on choose menu item theObject
	(*Add your script here.*)
end choose menu item

-- calculate whether the year is a leap year or not
on IsLeapYear(year)
	if year < MINYEAR then
		error "Year too early"
	end if
	if year mod 4 = 0 then
		if year mod 100 = 0 then
			if year mod 400 = 0 then
				return true
			end if
			return false
		end if
		return true
	end if
	return false
end IsLeapYear

-- how many days a year has
on DaysInYear(year)
	if my IsLeapYear(year) then return 366
	return 365
end DaysInYear

-- convert a year/month/day to a day number with January 1, 2000 == 0
on DayNumber(theYear, theMonth, theDay)
	set monthDays to {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	if theYear < MINYEAR then error "Year " & theYear & " too early!"
	if (theMonth < 1) then error "Month " & theMonth & " out of range [1,12]"
	if (theMonth > 12) then error "Month " & theMonth & " out of range [1,12]"
	if theDay < 1 or theDay > 31 then error "Day " & theDay & " out of range [1,31]"
	
	if my IsLeapYear(theYear) then set item 2 of monthDays to 29
	set daysThisMonth to item theMonth of monthDays
	if theDay > daysThisMonth then error "Day " & theDay & " out of range [1," & daysThisMonth & "] for month " & theMonth
	
	set theDayNumber to theDay - 1
	set i to MINYEAR
	repeat while i < theYear
		set theDayNumber to theDayNumber + (my DaysInYear(i))
		set i to i + 1
	end repeat
	set i to 1
	repeat while i < theMonth
		set theDayNumber to theDayNumber + (item i of monthDays)
		set i to i + 1
	end repeat
	
	return theDayNumber
end DayNumber

-- compute a factorial
on factorial(x)
	if x < 0 then error "Can't take factorial of " & x
	
	if x = 0 then return 1
	if x = 1 then return 1
	
	set result to 1
	repeat with i from 2 to x
		set result to result * i
	end repeat
	
	return result
end factorial

-- handle bell insertions into the current list of bells
on insertBell(theList, theOffset, theBell)
	if theOffset = 0 then
		set theList to theBell & theList
	else
		set theFront to items 1 thru theOffset of theList
		if theOffset + 1 > length of theList then
			set theBack to {}
		else
			set theBack to items (theOffset + 1) thru -1 of theList
		end if
		set theList to theFront & theBell & theBack
	end if
	
end insertBell

-- Generate peprmutation record
on makeFunnyList(n, bells)
	set funnyList to {}
	repeat with i from 1 to bells
		set funnyList to funnyList & (my FunnyDigit(n, i))
	end repeat
	funnyList
end makeFunnyList

-- generate permutation record number for the current daynumber
on FunnyDigit(n, i)
	round ((n / (my factorial(i - 1))) mod i) rounding down
end FunnyDigit

-- build a permutation from the permuation record and a bell list
on MakePerm(f, e)
	-- f and e are both lists
	set out to {}
	repeat with i from (length of f) to 1 by -1
		set out to my insertBell(out, (item i of f), (item i of e))
	end repeat
	return out
end MakePerm

-- generate permutation from canonical bell list and daynumber
on MakePermutation(f, bells)
	-- f is a list, bells is an integer
	set bellList to reverse of {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	return my MakePerm((reverse of f), bellList)
end MakePermutation

-- calculate permutation from daynumber
on NthPermutation(n, bells)
	reverse of (my MakePermutation(my makeFunnyList(n, bells), bells))
end NthPermutation

-- generate the requisite number of peals from the given starting daynumber
on ChimesForDay(theYear, theMonth, theDay, periodDays)
	set chimeList to {}
	set theDayNumber to DayNumber(theYear, theMonth, theDay)
	repeat with i from 0 to periodDays - 1
		set newChime to NthPermutation(theDayNumber + i, 10)
		copy newChime to end of chimeList
	end repeat
	chimeList
end ChimesForDay