' rle53map 0.2
' fbc rle53map.bas cmdlineparser.bas mtparser.bas

#include "cmdlineparser.bi"
#include "mtparser.bi"

Sub usage 
	Print "usage:"
	Print ""
	Print "rle53map.exe in=map.map out=map.h size=W,H prefix=P [tlock=T] [scrsizes]"
	Print "             [scrsize=w,h] [fixmappy] [nodecos] [t0=N]"
	Print "             in is the input filename."
	Print "             out is the output filename."
	Print "             size is the size, in screens."
	Print "             prefix will be appended to labels."
	Print "             tlock is the tile representing locks/bolts"
	Print "             scrsizes prints screen sizes as comments"
	Print "             scrsize is the size of the screen in tiles. Default is 16x12"
	Print "             fixmappy will substract 1 from every byte read"
	Print "             nodecos will throw away any tile out of range i.o. generating decos"
	Print "             t0 defines # of 1st tile, default = 0"
End Sub

Dim As String mandatory (3) = { "in", "out", "size", "prefix" }
Dim As Integer coords (7), mapW, mapH, scrW, scrH, nPant, maxPants, mapWtiles, fixMappy, realPant
Dim As Integer fIn, fOut, xP, yP, x, y, i, j, tLock, locksI, n, cMapI, ctr, totalBytes, t0, lockssize, screensum
Dim As uByte BigMap (127, 255)
Dim As uByte cMap (127, 255), scrSizes (127)
Dim As String*384 cMapAmalgam (127)
Dim As uByte locks (63)
Dim As uByte d, dp
Dim As uByte scrMaps (127)

' decos
Dim As Integer decosAre, decosize
Dim As uByte decoT, decoCT
Dim As uByte decos (127, 127), decosYX (127, 127), YX (127), decosO (127, 127), decosI (127), decosOI (127)

Print "rle53map v0.2 ";
sclpParseAttrs
If Not sclpCheck (mandatory ()) Then usage: End

parseCoordinatesString sclpGetValue ("size"), coords ()
mapW = coords (0): mapH = coords (1)
maxPants = mapW * mapH

If sclpGetValue ("scrsize") <> "" Then
	parseCoordinatesString sclpGetValue ("scrsize"), coords ()
	scrW = coords (0): scrH = coords (1)
Else 
	scrW = 16: scrH = 12
End If

mapWtiles = mapW * scrW

If sclpGetValue ("tlock") <> "" Then tLock = Val (sclpGetValue ("tlock")) Else tLock = -1

If sclpGetValue ("t0") <> "" Then t0 = Val (sclpGetValue ("t0")) Else t0 = 0

fIn = FreeFile
Open sclpGetValue ("in") For Binary As #fIn
fOut = FreeFile
Open sclpGetValue ("out") For Output As #fOut

Print #fOut, "// " & sclpGetValue ("out") & ", generated by rle53map v0.2"
Print #fOut, "// Copyleft 2017 by The Mojon Twins"
Print #fOut, ""
Print #fOut, "// MAP_W = " & mapW & ", MAP_H = " & mapH & " SCR_W = " & scrW & " SCR_H = " & scrH
Print #fOut, ""

Print "Reading ~ ";

fixMappy = (sclpGetValue ("fixmappy") <> ""): If fixMappy Then Print "[fixmappy] ";

i = 0: locksI = 0: dp = 0
While Not Eof (fIn)
	' Read from file
	Get #fIn, , d
	If fixMappy And d Then d = d - 1
	
	' Screen coordinates
	xP = (i \ scrW) Mod mapW
	yP = i \ (scrW * scrH * mapW)
	
	' Tile coordinates
	x = i Mod scrW
	y = (i \ mapWtiles) Mod scrH
	
	' screen number
	nPant = xp + yp * mapW

	' Next n
	i = i + 1

	' tlock?
	If d = tLock Then
		locks (locksI) = nPant: locksI = locksI + 1
		locks (locksI) = (y Shl 4) Or x: locksI = locksI + 1
	End if

	' Is d a decoration' 
	If d < t0 Or d > t0 + 31 Then
		If Not decosAre Then 
			Print "Found T(s) OOR ";
			If sclpGetValue ("nodecos") <> "" Then Print "(ignored) ~ "; Else Print "(decos) ~ ";
			decosAre = -1
		End If			
		' Write to decos
		decosYX (nPant, decosI (nPant)) = y * 16 + x
		decos (nPant, decosI (nPant)) = d
		decosI (nPant) = decosI (nPant) + 1
		' Reset to previous (so there's more repetitions)
		d = dp
	End If

	' Write
	BigMap (nPant, scrW * y + x) = d - t0
	dp = d
Wend

Print "Compressing ~ ";
totalBytes = 0
For nPant = 0 To maxPants - 1
	d = BigMap (nPant, 0): n = 1: cMapI = 0
	cMapAmalgam (nPant) = ""
	screensum = 0
	For i = 1 To scrW*scrH-1
		screensum = screensum + BigMap (nPant, i)
		' Different: write, substitute
		If BigMap (nPant, i) <> d Or n = 8 Then
			cMap (nPant, cMapI) = (d And 31) Or ((n - 1) Shl 5)
			cMapAmalgam (nPant) = cMapAmalgam (nPant) & Hex (cMap (nPant, cMapI), 2)
			cMapI = cMapI + 1
			n = 0
		End If
		d = BigMap (nPant, i): n = n + 1
	Next i
	cMap (nPant, cMapI) = (d And 31) Or ((n - 1) Shl 5)
	cMapAmalgam (nPant) = cMapAmalgam (nPant) & Hex (cMap (nPant, cMapI), 2)
	cMapI = cMapI + 1

	realPant = nPant

	' Detect empty screen
	If screensum = 0 Then 
		realPant = 255: cMapI = 0
	Else
		' Search for repeated screens
		For j = 0 To nPant - 1
			If cMapAmalgam (j) = cMapAmalgam (nPant) Then
				realPant = j
				cMapI = 0
				Exit For
			End If
		Next j
	End If

	scrSizes (nPant) = cMapI
	scrMaps (nPant) = realPant '' Fixe here
	totalBytes = totalBytes + cMapI
Next nPant

Print "Writing ~ ";
For nPant = 0 To maxPants - 1
	If scrMaps (nPant) = 255 Then
		Print #fOut, "// Screen " & Lcase (Hex (nPant, 2)) & " is empty."
	ElseIf scrSizes (nPant) Then
		Print #fOut, "const unsigned char scr_" & sclpGetValue ("prefix") & "_" & Lcase (Hex (nPant, 2)) & " [] = {";
		For i = 0 To scrSizes (nPant) - 1
			Print #fOut, "0x" & Lcase (Hex (cMap (nPant, i), 2));
			If i < scrSizes (nPant) - 1 Then Print #fOut, ", ";
		Next i
		Print #fOut, "};"
		If sclpGetValue ("scrsizes") <> "" Then Print #fOut, "// Size = " & scrSizes (nPant) & " bytes."
	Else
		Print #fOut, "// Screen " & Lcase (Hex (nPant, 2)) & " is a copy of screen " & Lcase (Hex (scrMaps (nPant), 2)) & "."
	End If
Next nPant

' Generate index
Print #fOut, ""
Print #fOut, "const unsigned char * const map_" & sclpGetValue ("prefix") & " [] = {"
ctr = 0
For nPant = 0 To maxPants - 1
	If ctr = 0 Then Print #fOut, "	";
	If scrMaps (nPant) = 255 Then
		Print #fOut, Space (Len ("scr_" & sclpGetValue ("prefix") & "_")) & " 0";
	Else
		Print #fOut, "scr_" & sclpGetValue ("prefix") & "_" & Lcase (Hex (scrMaps (nPant), 2));
	Endif
	If nPant < maxPants - 1 Then Print #fOut, ", ";
	ctr = ctr + 1: If ctr = mapW And nPant < maxPants - 1 Then ctr = 0: Print #fOut, ""
	totalBytes = totalBytes + 2
Next nPant
Print #fOut, ""
Print #fOut, "};"
Print #fOut, ""
Print #fOut, "// Total bytes = " & totalBytes
Print #fOut, ""

decosize = 0
If sclpGetValue ("nodecos") = "" And decosAre Then
	Print "Writing decos ~ ";
	For nPant = 0 To maxPants - 1
		If decosI (nPant) Then
			For i = 0 To decosI (nPant) - 1
				decoT = decos (nPant, i)
				
				If decoT <> &Hff Then
					decoCT = 1
					YX (0) = decosYX (nPant, i)
					' Find more:
					For j = i + 1 To decosI (nPant) - 1
						If decos (nPant, i) = decos (nPant, j) Then
							' Found! DESTROY!
							YX (decoCT) = decosYX (nPant, j)
							decoCT = decoCT + 1
							decos (nPant, j) = &Hff
						End If
					Next j
					If decoCT = 1 Then
						' T | 128, YX
						decosO (nPant, decosOI (nPant)) = decoT Or 128: decosOI (nPant) = decosOI (nPant) + 1
						decosO (nPant, decosOI (nPant)) = YX (0): decosOI (nPant) = decosOI (nPant) + 1
					Else
						' T N YX YX YX YX...
						decosO (nPant, decosOI (nPant)) = decoT: decosOI (nPant) = decosOI (nPant) + 1
						decosO (nPant, decosOI (nPant)) = decoCT: decosOI (nPant) = decosOI (nPant) + 1
						For j = 0 To decoCT - 1
							decosO (nPant, decosOI (nPant)) = YX (j): decosOI (nPant) = decosOI (nPant) + 1
						Next j
					End If
				End If
			Next i
		End If
	Next nPant

	Print #fOut, "// Decorations"
	Print #fOut, "// Format: [T N YX YX YX YX... (T < 128) | T YX (T >= 128)]"
	Print #fOut, ""
	For nPant = 0 To maxPants - 1
		If decosOI (nPant) Then
			Print #fOut, "const unsigned char map_" & sclpGetValue ("prefix") & "_decos_" & Lcase (Hex (nPant, 2)) & " [] = { ";
			For i = 0 To decosOI (nPant) - 1
				Print #fOut, "0x" & Lcase (Hex (decosO (nPant, i), 2)) & ", " ;
				decosize = decosize + 1
			Next i
			Print #fOut, "0x00 }; "
		End If
	Next nPant
	Print #fOut, ""
	Print #fOut, "const unsigned char * const map_" & sclpGetValue ("prefix") & "_decos [] = {"
	For y = 0 To mapH - 1
		Print #fOut, "	";
		For x = 0 To mapW - 1
			nPant = x + y * mapW
			If decosOI (nPant) Then
				Print #fOut, "map_" & sclpGetValue ("prefix") & "_decos_" & Lcase (Hex (nPant, 2));
			Else 
				Print #fOut, "0";
			End If
			decosize = decosize + 2
			If x < mapW - 1 Or y < mapH - 1 Then Print #fOut, ", ";
		Next x
		Print #fOut, ""
	Next y
	Print #fOut, "};"
	Print #fOut, ""
	Print #fOut, "// Total decorations size in bytes is " & decosize
	Print #fOut, ""
End If
totalBytes = totalBytes + decosize

' Write locks
lockssize = 0
If locksI Then
	Print #fOut, "const unsigned char map_" & sclpGetValue ("prefix") & "_locks [] = {"
	Print #fOut, "	";
	For i = 0 To locksI - 1
		Print #fOut, "0x" & Lcase (Hex (locks (i), 2));
		If i < locksI - 1 Then Print #fOut, ", ";
		lockssize = lockssize + 1
	Next i
	Print #fOut, ""
	Print #fOut, "};"
	Print #fOut, ""
End If
totalBytes = totalBytes + lockssize

Print #fOut, "// Total map data in bytes is " & totalBytes
Print #fOut, ""

Close #fOut, #fIn


Print "DONE! " & totalBytes & " bytes." 
