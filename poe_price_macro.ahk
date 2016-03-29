; POE Simple Price Check
; Version: 5.1 (2015/08/11)
;
; Written by Pete Waterman aka trackpete on reddit, pwx* in game
; http://exiletools.com (used to be http://poe.pwx.me)

; For a list of valid leagues, go here and scroll down to "Active Leagues:"
; http://api.exiletools.com/ladder


; == Startup Options ===========================================
#SingleInstance force
#NoEnv 
#Persistent ; Stay open in background
SendMode Input 
StringCaseSense, On ; Match strings with case.
#NoTrayIcon

If (A_AhkVersion <= "1.1.22")
{
    msgbox, You need AutoHotkey v1.1.22 or later to run this script. `n`nPlease go to http://ahkscript.org/download and download a recent version.
    exit
}

; == Variables and Options and Stuff ===========================

; *******************************************************************
; *******************************************************************
;                      SET LEAGUENAME BELOW!!
; *******************************************************************
; *******************************************************************
; Option for LeagueName - this must be specified.
; Remove the ; from in front of the line that has the leaguename you
; want, or just change the uncommented line to say what you want.
; Make sure all other LeagueName lines have a ; in front of them (commented)
; or are removed

global LeagueName := "perandushc"

; showDays - This filters results to items that are in shops which have been updated
; without the last # of days. The default is 7. There is not really any need to change
; this unless you really want the freshest prices, then you can try setting this to 3 or 4.
; Any lower and it will start to return a much smaller result set.
global showDays := "7"

; runVersion - Sets the internal run version so that I can warn you if this macro
; is out of date.
global runVersion := "5.1"

; Decoder URL - DO NOT CHANGE THIS! This is a development option. 
; Instead of doing all the processing in AHK, this script simply sends basic
; item information to a decoder service which checks for price information against
; my own item index.
Global URL = "http://api.exiletools.com/item-report-text"

; How much the mouse needs to move before the hotkey goes away, not a big deal, change to whatever
MouseMoveThreshold := 40
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen

; There are multiple hotkeys to run this script now, defaults set as follows:
; ^p (CTRL-p) - Sends the item information to my server, where a price check is performed. Levels and quality will be automatically processed.
; ^i (CTRL-i) - Pulls up an interactive search box that goes away after 30s or when you hit enter/ok
;
; To modify these, you will need to modify the function call headers below
; see http://www.autohotkey.com/docs/Hotkeys.htm for hotkey options


; Price check w/ auto filters
^p::
IfWinActive, Path of Exile ahk_class Direct3DWindowClass 
{
  FunctionReadItemFromClipboard()
}
return

; Custom Input String Search
/* Commented Out interactive mode
^i::
IfWinActive, Path of Exile ahk_class Direct3DWindowClass 
{
  ; This grabs a text message from my server so that I can add functionality
  ; to the interactive search and document it without users having to download
  ; a new macro.
  gettxt := ComObjCreate("WinHttp.WinHttpRequest.5.1")
  gettxt.Open("GET", "http://exiletools.com/price-macro-input.txt")
  gettxt.Send
  macroprompt := gettxt.ResponseText
    
  Prompt := macroprompt
  Global X
  Global Y
  MouseGetPos, X, Y	
  InputBox,ItemName,Interactive Price Search,%Prompt%,,500,300,X-160,Y - 250,,30,
  if ItemName {
	Global PostData = "v=" . runVersion . "&interactiveSearch=" . ItemName . "&league=" . LeagueName . "&showDays=" . showDays . ""
    FunctionPostItemData(URL, "null", "isInteractive")
  }
}
return
*/

; == Function Stuff =======================================

FunctionPostItemData(URL, ItemData, InteractiveCheck)
{
  ; This is for debug purposes, it should be commented out in normal use
  ; MsgBox, %URL%
  ; MsgBox, %ItemData%
  
  ; URI Encode ItemData to avoid any problem
  ItemData := FunctionUriEncode(ItemData)
  
  if (InteractiveCheck = "isInteractive") {
    temporaryContent = Submitting interactive search to exiletools.com...
    FunctionShowToolTipPriceInfo(temporaryContent)	
  } else {
    temporaryContent = Submitting item information to exiletools.com...
    FunctionShowToolTipPriceInfo(temporaryContent)
    ; Create PostData
    Global PostData = "v=" . runVersion . "&itemData=" . ItemData . "&league=" . LeagueName . "&showDays=" . showDays . ""  
  }
  
  ; Send the PostData to my server and check the response!
  whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
  whr.Open("POST", URL)
  whr.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
  whr.Send(PostData)
  rawcontent := whr.ResponseText
  
  ; The return data has a special line that can be pasted into chat/etc., this
  ; separates that out and copies it to the clipboard.
  StringSplit, responsecontent, rawcontent,^ 
  clipboard = %responsecontent2%
  
  FunctionShowToolTipPriceInfo(responsecontent1)    
}

; This is for the tooltip, so it shows it and starts a timer that watches mouse movement.
; I imagine there's a better way of doing this. The crazy long name is to avoid
; overlap with other scripts in case people try to combine these into one big script.

FunctionShowToolTipPriceInfo(responsecontent)
{
    ; Get position of mouse cursor
    Sleep, 2
	Global X
    Global Y
    MouseGetPos, X, Y	
	gui, font, s15, Verdana 
    ToolTip, %responsecontent%, X - 135, Y + 30
    SetTimer, SubWatchCursorPrice, 100     

}

; == The Goods =====================================

; Watches the mouse cursor to get rid of the tooltip after too much movement
SubWatchCursorPrice:
  MouseGetPos, CurrX, CurrY
  MouseMoved := (CurrX - X)**2 + (CurrY - Y)**2 > MouseMoveThreshold**2
  If (MouseMoved)
  {
    SetTimer, SubWatchCursorPrice, Off
    ToolTip
  }
return


FunctionReadItemFromClipboard() {
  ; Only does anything if POE is the window with focus
  IfWinActive, Path of Exile ahk_class Direct3DWindowClass
  {
    ; Send a ^C to copy the item information to the clipboard
	; Note: This will trigger any Item Info/etc. script that monitors the clipboard
    Send ^c
    ; Wait 250ms - without this the item information doesn't get to the clipboard in time
    Sleep 250
	; Get what's on the clipboard
    ClipBoardData = %clipboard%
    ; Split the clipboard data into strings to make sure it looks like a properly
	; formatted item, looking for the Rarity: tag in the first line. Just in case
	; something weird got copied to the clipboard.
	StringSplit, data, ClipBoardData, `n, `r
		
	; Strip out extra CR chars so my unix side server doesn't do weird things
	StringReplace RawItemData, ClipBoardData, `r, , A

	; If the first line on the clipboard has Rarity: it is probably some item
	; information from POE, so we'll send it to my server to process. Otherwise
	; we just don't do anything at all.
    IfInString, data1, Rarity:
    {
	  ; Do POST / etc.	  
	  FunctionPostItemData(URL, RawItemData, "notInteractive")
	
	} 	
  }  
}



; Stole this from here: http://www.autohotkey.com/board/topic/75390-ahk-l-unicode-uri-encode-url-encode-function/
; Hopefully it works right!
FunctionUriEncode(Uri, Enc = "UTF-8")
{
	StrPutVar(Uri, Var, Enc)
	f := A_FormatInteger
	SetFormat, IntegerFast, H
	Loop
	{
		Code := NumGet(Var, A_Index - 1, "UChar")
		If (!Code)
			Break
		If (Code >= 0x30 && Code <= 0x39 ; 0-9
			|| Code >= 0x41 && Code <= 0x5A ; A-Z
			|| Code >= 0x61 && Code <= 0x7A) ; a-z
			Res .= Chr(Code)
		Else
			Res .= "%" . SubStr(Code + 0x100, -1)
	}
	SetFormat, IntegerFast, %f%
	Return, Res
}
StrPutVar(Str, ByRef Var, Enc = "")
{
	Len := StrPut(Str, Enc) * (Enc = "UTF-16" || Enc = "CP1200" ? 2 : 1)
	VarSetCapacity(Var, Len, 0)
	Return, StrPut(Str, &Var, Enc)
}
