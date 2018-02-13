#RequireAdmin
#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Change2CUI=N
#AutoIt3Wrapper_Res_Comment=Compiled 01/31/2018 @ 13:35 EST
#AutoIt3Wrapper_Res_Description=NotCPUCores
#AutoIt3Wrapper_Res_Fileversion=1.7.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Robert Maehl, using LGPL 3 License
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <Process.au3>
#include <Constants.au3>
#include <GUIListView.au3>
#include <GuiComboBox.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <ComboConstants.au3>
#include <GUIConstantsEx.au3>
#include <AutoItConstants.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>

#include ".\Includes\_Core.au3"
#include ".\Includes\_WMIC.au3"
#include ".\Includes\_GetSteam.au3"
;#include ".\Includes\_ModeSelect.au3"
#include ".\Includes\_GetLanguage.au3"
#include ".\Includes\_ExtendedFunctions.au3"


Opt("GUICloseOnESC", 0)
Opt("GUIResizeMode", $GUI_DOCKALL)

Global $bInterrupt = False
Global $bRefresh = False

HotKeySet("{F5}", "_Refresh")
HotKeySet("{PAUSE}", "_Interrupt")
HotKeySet("{BREAK}", "_Interrupt")

#cs

To Do

1. Steam Game Auto-Detection and Dropdown (v 2.0)
2. Allow Collapsing of Window/Process List (DONE)
3. Move Back-End Console when running as GUI into a CLOSE-ABLE Window (Console UDF) (Embedded Console Created)
4. Allow Selecting from Window/Process List instead of it just being a guide
5. Allow Optimization of Multiple Processes at once (v 2.0)
6. Convert GUI to a Metro GUI or Allow Themes (v 2.0)
7. Language Translation Options


== 2.0 Idea Master List ==

Options for translation
NCC launches on Start-up, automatically optimizes any processes chosen by user
Upon Launch open a small Metro UI with some options w/ Graphics (Optimize Game, Manage Auto Optimized, Optimize PC) aka Imgburn start-up but smaller

Optimize Game

	Tabbed UI (Select from Steam, Select from GOG, Select from Running)
		Options for Which Services to Stop Temporarily
		More user friendly core selection (Checkboxes?)
		Check-box to add game to games to be automatically optimized

Manage Auto Optimize

	List View/Icon View of Processes set to be automatically optimized

Optimize PC

	Tabbed UI
		Defrag, Trim, Disk Cleanup, Power options
		Delayed auto-run program start
		Advanced Tweaks (Ultimate Windows Tweaker-esque)

#ce

; Set Core Count as Global to Reduce WMIC calls

Global $iCores = _GetCPUInfo(0)
Global $iThreads = _GetCPUInfo(1)

_LoadLanguage()

Main()

Func Main()

	; One Time Variable Setting
	Local $aCores
	Local $bInit = True
	Local $iSleep = 100
	Local $sVersion = "1.7.0.0"
	Local $iAllCores
	Local $sPriority = "High"
	Local $aProcesses[1]
	Local $iProcesses = 0
	Local $iProcessCores = 1
	Local $iBroadcasterCores = 0
	Local $iOtherProcessCores = 1

	For $iLoop = 0 To $iThreads - 1
		$iAllCores += 2^$iLoop
	Next

	Local $hGUI = GUICreate("NotCPUCores", 640, 480, -1, -1, BitXOR($GUI_SS_DEFAULT_GUI, $WS_MINIMIZEBOX))

	#Region ; File Menu
	Local $hMenu1 = GUICtrlCreateMenu($_sLang_FileMenu)
	Local $hLoad = GUICtrlCreateMenuItem($_sLang_FileLoad, $hMenu1)
	Local $hSave = GUICtrlCreateMenuItem($_sLang_FileSave, $hMenu1)
	GUICtrlCreateMenuItem("", $hMenu1)
	Local $hQuit = GUICtrlCreateMenuItem($_sLang_FileQuit, $hMenu1)
	#EndRegion

	#Region ; Options Menu
	Local $hMenu2 = GUICtrlCreateMenu($_sLang_OptionsMenu)
	Local $hTimer = GUICtrlCreateMenu($_sLang_SleepMenu, $hMenu2)
	Local $hGetTimer = GUICtrlCreateMenuItem($_sLang_SleepCurrent & ": " & $iSleep & "ms", $hTimer)
	GUICtrlSetState($hGetTimer, $GUI_DISABLE)
	GUICtrlCreateMenuItem("", $hTimer)
	Local $hSetTimer = GUICtrlCreateMenuItem($_sLang_SleepSet, $hTimer)
	#EndRegion

	#Region ; Help Menu
	Local $hMenu3 = GUICtrlCreateMenu($_sLang_HelpMenu)
	Local $hGithub = GUICtrlCreateMenuItem($_sLang_HelpSite, $hMenu3)
	Local $hHowTo = GUICtrlCreateMenuItem($_sLang_HelpHowTo, $hMenu3)
	GUICtrlCreateMenuItem("", $hMenu3)
	Local $hUpdate = GUICtrlCreateMenuItem($_sLang_HelpUpdate, $hMenu3)
	#EndRegion

	Local $hDToggle = GUICtrlCreateButton("D", 260, 0, 20, 20)
		GUICtrlSetTip($hDToggle, $_sLang_DebugTip)

	GUICtrlCreateTab(0, 0, 280, 275)

	#Region ; Work Tab
	;GUICtrlCreateTabItem($_sLang_WorkTab)

	#EndRegion

	#Region ; Play Tab
	GUICtrlCreateTabItem($_sLang_PlayTab)

	GUICtrlCreateLabel($_sLang_PlayText, 5, 25, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	GUICtrlCreateLabel($_sLang_OptimizeProcess & ":", 10, 50, 140, 15)

	Local $hTask = GUICtrlCreateInput("", 150, 45, 100, 20, $ES_UPPERCASE + $ES_RIGHT + $ES_AUTOHSCROLL)
		GUICtrlSetTip(-1, $_sLang_OptimizeTip & @CRLF & _
			$_sLang_Example & ": NOTEPAD.EXE", $_sLang_Usage, $TIP_NOICON)

	Local $hSearch = GUICtrlCreateButton(ChrW(8678), 250, 45, 20, 20)
		GUICtrlSetFont(-1, 12)
		GUICtrlSetTip(-1, $_sLang_ImportTip, $_sLang_Usage, $TIP_NOICON)

	GUICtrlCreateLabel($_sLang_IncludeChildren, 10, 75, 140, 20)

	Local $hChildren = GUICtrlCreateCheckbox("", 150, 70, 120, 20, $BS_RIGHTBUTTON)
		GUICtrlSetTip(-1, $_sLang_ChildrenTip, $_sLang_Usage, $TIP_NOICON)
		GUICtrlSetState(-1, $GUI_DISABLE)

	GUICtrlCreateLabel($_sLang_AllocationMode & ":", 10, 100, 140, 15)

	Local $hAssignMode = GUICtrlCreateCombo("", 150, 95, 120, 20, $CBS_DROPDOWNLIST)
		If $iCores = $iThreads Then
			GUICtrlSetData(-1, "All Cores|First Core|First 2 Cores|First 4 Cores|First Half|Even Cores|Odd Cores|First AMD CCX|Custom", "All Cores")
		Else
			GUICtrlSetData(-1, "All Cores|First Core|First 2 Cores|First 4 Cores|First Half|Physical Cores|Non-Physical Cores|Every Other Pair|First AMD CCX|Custom", "All Cores")
		EndIf

	GUICtrlCreateLabel($_sLang_Assignments & ":", 10, 125, 140, 15)

	Local $hCores = GUICtrlCreateInput("", 150, 120, 120, 20, $ES_UPPERCASE + $ES_RIGHT + $ES_AUTOHSCROLL)
		GUICtrlSetTip(-1, $_sLang_AssignTip1 & @CRLF & _
			$_sLang_AssignTip2 & @CRLF & _
			$_sLang_AssignTip3 & @CRLF & _
			$_sLang_Example & ": 1,3,4-6" & @TAB & @TAB & $_sLang_AssignTip4 & ": " & $iThreads, $_sLang_Usage, $TIP_NOICON)
		If $iThreads <= 4 Then
			GUICtrlSetData(-1, "1-" & $iThreads)
		ElseIf $iThreads <= 6 Then
			GUICtrlSetData(-1, "1-4")
		Else
			GUICtrlSetData(-1, "1-" & Ceiling($iThreads/2))
		EndIf
		GUICtrlSetState(-1, $GUI_DISABLE)

	GUICtrlCreateLabel($_sLang_OptimizePriority & ":", 10, 150, 140, 15)

	Local $hPPriority = GUICtrlCreateCombo("", 150, 145, 120, 20, $CBS_DROPDOWNLIST)
		GUICtrlSetData(-1, "Normal|Above Normal|High|Realtime", "High")
	#EndRegion

	#Region ; Stream Tab
	GUICtrlCreateTabItem($_sLang_StreamTab)

	GUICtrlCreateLabel($_sLang_StreamText, 5, 25, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	GUICtrlCreateLabel($_sLang_AllocationMode & ":", 10, 50, 140, 15)

	Local $hSplitMode = GUICtrlCreateCombo("", 150, 45, 120, 20, $CBS_DROPDOWNLIST)
		If $iCores = $iThreads Then
			GUICtrlSetData(-1, "OFF|Last Core|Last 2 Cores|Last 4 Cores|Last Half|Even Cores|Odd Cores|Every Other Pair|Last AMD CCX|Custom", "OFF")
		Else
			GUICtrlSetData(-1, "OFF|Last Core|Last 2 Cores|Last 4 Cores|Last Half|Physical Cores|Non-Physical Cores|Every Other Pair|Last AMD CCX|Custom", "OFF")
		EndIf

	GUICtrlCreateLabel($_sLang_Assignments & ":", 10, 75, 140, 15)

	Local $hBCores = GUICtrlCreateInput("2", 150, 70, 120, 20, $ES_UPPERCASE + $ES_RIGHT + $ES_AUTOHSCROLL)
		GUICtrlSetTip(-1, $_sLang_AssignTip1 & @CRLF & _
			$_sLang_AssignTip2 & @CRLF & _
			$_sLang_AssignTip3 & @CRLF & _
			$_sLang_Example & ": 1,3,4-6" & @TAB & @TAB & $_sLang_AssignTip4 & ": " & $iThreads, $_sLang_Usage, $TIP_NOICON)
		GUICtrlSetState(-1, $GUI_DISABLE)
		If $iThreads > 2 Then
			If $iThreads = 3 Then
				GUICtrlSetData(-1, "3")
			Else
				GUICtrlSetData(-1, Ceiling($iThreads/2) + 1 & "-" & $iThreads)
			EndIf
		EndIf

	GUICtrlCreateLabel($_sLang_StreamSoftware & ":", 10, 100, 140, 15)

	Local $hBroadcaster = GUICtrlCreateCombo("", 150, 95, 120, 20, $CBS_DROPDOWNLIST)
		GUICtrlSetData(-1, "OBS|XSplit", "OBS")
		GUICtrlSetState(-1, $GUI_DISABLE)

	GUICtrlCreateLabel($_sLang_IncludeChildren, 10, 125, 140, 20)

	Local $hBroChild = GUICtrlCreateCheckbox("", 150, 120, 120, 20, $BS_RIGHTBUTTON)
		GUICtrlSetTip(-1, $_sLang_ChildrenTip, $_sLang_Usage, $TIP_NOICON)
		GUICtrlSetState(-1, $GUI_DISABLE)

	GUICtrlCreateLabel($_sLang_StreamOtherAssign & ":", 10, 150, 140, 20)

	Local $hOAssign = GUICtrlCreateCombo("", 150, 145, 120, 20, $CBS_DROPDOWNLIST)
		GUICtrlSetData(-1, "Broadcaster Cores|Game Cores|Remaining Cores", "Remaining Cores")
		GUICtrlSetState(-1, $GUI_DISABLE)

	#EndRegion

	#Region ; Tools Tab
	GUICtrlCreateTabItem($_sLang_ToolTab)

	GUICtrlCreateLabel($_sLang_GameSection, 5, 25, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	Local $hHPET = GUICtrlCreateButton($_sLang_HPET, 5, 40, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "imageres.dll", -30)
		GUICtrlSetState(-1, $GUI_DISABLE)

	Local $hGameM = GUICtrlCreateButton($_sLang_GameMode, 100, 40, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "shell32.dll", -208)
		If @OSVersion = "WIN_10" Then
			If @OSBuild < 15007 Then GUICtrlSetState(-1, $GUI_DISABLE)
		Else
			GUICtrlSetState(-1, $GUI_DISABLE)
		EndIf

	Local $hPower = GUICtrlCreateButton($_sLang_PowerOptions, 195, 40, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "powercpl.dll", 1)

	GUICtrlCreateLabel($_sLang_DiskSection, 5, 85, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	Local $hDefrag = GUICtrlCreateButton($_sLang_DiskDefrag, 5, 100, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "shell32.dll", -81)

	Local $hCheck = GUICtrlCreateButton($_sLang_DiskCheck, 100, 100, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "shell32.dll", -271)

	GUICtrlCreateLabel($_sLang_StorageSection, 5, 145, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	Local $hCleanup = GUICtrlCreateButton($_sLang_DiskCleanup, 5, 160, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "shell32.dll", -32)

	Local $hSSense = GUICtrlCreateButton($_sLang_StorageSense, 100, 160, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "shell32.dll", -167)
		If @OSVersion = "WIN_10" Then
			If @OSBuild < 16299 Then GUICtrlSetState(-1, $GUI_DISABLE)
		Else
			GUICtrlSetState(-1, $GUI_DISABLE)
		EndIf
	GUICtrlCreateLabel($_sLang_ReliabilitySection, 5, 205, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	Local $hEvents = GUICtrlCreateButton($_sLang_RecentEvents, 5, 220, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "shell32.dll", -208)

	Local $hActions = GUICtrlCreateButton($_sLang_ActionCenter, 100, 220, 80, 40, $BS_MULTILINE)
		GUICtrlSetImage(-1, "ActionCenter.dll", 1)

	#EndRegion

	#Region ; Specs Tab
	GUICtrlCreateTabItem($_sLang_SpecsTab)

	GUICtrlCreateLabel($_sLang_SpecsOSSection, 5, 25, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	GUICtrlCreateLabel($_sLang_SpecsOS & ":", 10, 45, 70, 15)
		GUICtrlCreateLabel(_GetOSInfo(0) & " " & _GetOSInfo(1), 80, 45, 190, 20, $ES_RIGHT)

	GUICtrlCreateLabel($_sLang_SpecsLanguage & ":", 10, 65, 70, 15)
		GUICtrlCreateLabel(_GetLanguage(), 80, 65, 190, 20, $ES_RIGHT)

	GUICtrlCreateLabel($_sLang_SpecsHardwareSection, 5, 90, 270, 15, $SS_CENTER + $SS_SUNKEN)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	GUICtrlCreateLabel($_sLang_SpecsMobo & ":", 10, 110, 70, 15)
		GUICtrlCreateLabel(_GetMotherboardInfo(0) & " " & _GetMotherboardInfo(1), 60, 130, 210, 20, $ES_RIGHT)

	GUICtrlCreateLabel($_sLang_SpecsCPU & ":", 10, 150, 50, 15)
		GUICtrlCreateLabel(_GetCPUInfo(2), 60, 170, 210, 20, $ES_RIGHT)

	GUICtrlCreateLabel($_sLang_SpecsRAM & ":", 10, 190, 70, 15)
		GUICtrlCreateLabel(Round(MemGetStats()[1]/1048576) & " GB @ " & _GetRAMInfo(0) & " MHz", 80, 210, 190, 20, $ES_RIGHT)

	GUICtrlCreateLabel($_sLang_SpecsGPU & ":", 10, 230, 70, 15)
		GUICtrlCreateLabel(_GetGPUInfo(0), 80, 250, 190, 20, $ES_RIGHT)

	#EndRegion

	#Region ; About Tab
	GUICtrlCreateTabItem($_sLang_AboutTab)

	GUICtrlCreateLabel(@CRLF & "NotCPUCores" & @TAB & "v" & $sVersion & @CRLF & _
		$_sLang_AboutDeveloper & " Robert Maehl" & @CRLF & _
		$_sLang_AboutIcon & " /u/ImRealNow", 5, 25, 270, 60, $SS_CENTER)
		GUICtrlSetBkColor(-1, 0xF0F0F0)

	#EndRegion
	GUICtrlCreateTabItem("")

	Local $hReset = GUICtrlCreateButton($_sLang_Restore, 5, 275, 135, 20)
	Local $hOptimize = GUICtrlCreateButton($_sLang_Optimize, 140, 275, 135, 20)

	$hQuickTabs = GUICreate("", 360, 300, 280, 0, $WS_POPUP, $WS_EX_MDICHILD, $hGUI)
	GUICtrlCreateTab(0, 0, 360, 300)

	#Region ; Process List
	GUICtrlCreateTabItem($_sLang_RunningTab)
	Local $bPHidden = False
	Local $hProcesses = GUICtrlCreateListView($_sLang_ProcessList & "|" & $_sLang_ProcessTitle, 0, 20, 360, 280, $LVS_REPORT+$LVS_SINGLESEL, $LVS_EX_GRIDLINES+$LVS_EX_FULLROWSELECT+$LVS_EX_DOUBLEBUFFER+$LVS_EX_FLATSB)
		_GUICtrlListView_RegisterSortCallBack($hProcesses)
		GUICtrlSetTip(-1, $_sLang_RefreshTip, $_sLang_Usage)

	_GetProcessList($hProcesses)
	_GUICtrlListView_SortItems($hProcesses, 0)
	#EndRegion

	#Region ; Games List
	GUICtrlCreateTabItem($_sLang_GamesTab)
	Local $hGames = GUICtrlCreateListView($_sLang_GameName & "|" & $_sLang_GameProcess, 0, 20, 360, 280, $LVS_REPORT+$LVS_SINGLESEL, $LVS_EX_GRIDLINES+$LVS_EX_FULLROWSELECT+$LVS_EX_DOUBLEBUFFER)
		_GUICtrlListView_RegisterSortCallBack($hGames)
		GUICtrlSetTip(-1, $_sLang_RefreshTip, $_sLang_Usage)

	#EndRegion
	$bPHidden = True

	GUICtrlCreateTabItem("")
	GUISwitch($hGUI)

	#Region ; Debug Console
	Local $bCHidden = False
	$hConsole = GUICtrlCreateEdit($_sLang_DebugStart & @CRLF & "---" & @CRLF, 0, 300, 640, 160, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL, $ES_READONLY))
		GUICtrlSetColor(-1, 0xFFFFFF)
		GUICtrlSetBkColor(-1, 0x000000)

	GUICtrlSetState($hConsole, $GUI_HIDE)
	$bCHidden = True
	#EndRegion

	WinMove($hGUI, "", Default, Default, 285, 345, 1)
	GUISetState(@SW_SHOW, $hGUI)

	#Region ; Sleep Timer GUI
	$hTimerGUI = GUICreate($_sLang_SleepSet, 240, 120, -1, -1, $WS_POPUP + $WS_CAPTION, $WS_EX_TOOLWINDOW + $WS_EX_TOPMOST)
	GUICtrlCreateLabel($_sLang_SleepText, 10, 5, 220, 45)
	GUICtrlCreateLabel($_sLang_NewSleep & ":", 10, 60, 110, 20)
	$hSleepTime = GUICtrlCreateInput($iSleep, 120, 55, 40, 20, $ES_RIGHT + $ES_NUMBER)
	GUICtrlSetLimit(-1, 3, 1)
	GUICtrlCreateLabel("ms", 165, 60, 20, 15)
	$hOK = GUICtrlCreateButton("OK", 170, 90, 60, 20)
	#EndRegion

	While 1

		; Optimize first, always
		If Not $iProcesses = 0 Then
			If $bInterrupt = True Then
				$bInterrupt = False
				_ConsoleWrite($_sLang_Interrupt, $hConsole)
				$iProcesses = 1
			ElseIf $iProcesses = 1 Then
				_Restore($iThreads, $hConsole) ; Do Clean Up
				GUICtrlSetData($hOptimize, $_sLang_Optimize)
				For $iLoop = $hTask to $hOptimize Step 1
					If $iLoop = $hChildren Then ContinueLoop
					GUICtrlSetState($iLoop, $GUI_ENABLE)
				Next
				$iProcesses = 0
			Else
				If Not (UBound(ProcessList()) = $iProcesses) Then
					$aProcesses[0] = GUICtrlRead($hTask)
					$iProcesses = _Optimize($iProcesses,$aProcesses[0],$iProcessCores,$iSleep,GUICtrlRead($hPPriority),$hConsole)
					If _OptimizeOthers($aProcesses, $iOtherProcessCores, $iSleep, $hConsole) Then $iProcesses = 1
					If _OptimizeBroadcaster($aProcesses, $iBroadcasterCores, $iSleep, GUICtrlRead($hPPriority), $hConsole) Then $iProcesses = 1
				EndIf
			EndIf
		EndIf

		$hMsg = GUIGetMsg()
		Sleep(10)

		Select

			Case $hMsg = $GUI_EVENT_CLOSE or $hMsg = $hQuit
				_GUICtrlListView_UnRegisterSortCallBack($hGames)
				_GUICtrlListView_UnRegisterSortCallBack($hProcesses)
				GUIDelete($hQuickTabs)
				GUIDelete($hTimerGUI)
				GUIDelete($hGUI)
				Exit
#cs
			Case $hMsg = $LoadLanguage ; LAZINESS!!! D:<
				_GUICtrlListView_UnRegisterSortCallBack($hGames)
				_GUICtrlListView_UnRegisterSortCallBack($hProcesses)
				GUIDelete($hQuickTabs)
				GUIDelete($hTimerGUI)
				GUIDelete($hGUI)
				Main()
#ce
			Case $hMsg = $hDToggle
				If $bCHidden Or $bPHidden Then
					$aPos = WinGetPos($hGUI)
					WinMove($hGUI, "", $aPos[0], $aPos[1], 640, 480)
					$aPos = WinGetPos($hQuickTabs)
					WinMove($hQuickTabs, "", $aPos[0], $aPos[1], 355, 300)
					GUICtrlSetState($hConsole, $GUI_SHOW)
					GUISetState(@SW_SHOW, $hQuickTabs)
					GUICtrlSetPos($hGames, 0, 20, 355, 280)
					GUICtrlSetPos($hConsole, 0, 300, 635, 135)
					GUICtrlSetPos($hProcesses, 0, 20, 355, 280)
					$bCHidden = False
					$bPHidden = False
				Else
					GUICtrlSetState($hConsole, $GUI_HIDE)
					GUISetState(@SW_HIDE, $hQuickTabs)
					$aPos = WinGetPos($hGUI)
					WinMove($hGUI, "", $aPos[0], $aPos[1], 285, 345)
					$bCHidden = True
					$bPHidden = True
				EndIf

			Case $hMsg = $hSetTimer
				GUISetState(@SW_SHOW, $hTimerGUI)

			Case $hMsg = $hOK
				$iSleep = GUICtrlRead($hSleepTime)
				GUICtrlSetData($hGetTimer, $_sLang_SleepCurrent & ": " & $iSleep & "ms")
				GUISetState(@SW_HIDE, $hTimerGUI)

			Case $hMsg = $hSave
				If GUICtrlRead($hTask) = "" Then
					$sFile = "profile.ncc"
				Else
					$sFile = StringLower(GUICtrlRead($hTask)) & ".ncc"
				EndIf
				$hFile = FileSaveDialog($_sLang_SaveProfile, @WorkingDir, "NotCPUCores Profile (*.ncc)", $FD_PROMPTOVERWRITE, $sFile, $hGUI)
				IniWrite($hFile, "General"  , "Process"    , GUICtrlRead($hTask       ))
				IniWrite($hFile, "General"  , "SplitAs"    , GUICtrlRead($hAssignMode ))
				IniWrite($hFile, "General"  , "Threads"    , GUICtrlRead($hCores      ))
				IniWrite($hFile, "General"  , "Children"   , GUICtrlRead($hChildren   ))
				IniWrite($hFile, "General"  , "Priority"   , GUICtrlRead($hPPriority  ))
				IniWrite($hFile, "Streaming", "SplitAs"    , GUICtrlRead($hSplitMode  ))
				IniWrite($hFile, "Streaming", "Threads"    , GUICtrlRead($hBCores     ))
				IniWrite($hFile, "Streaming", "Software"   , GUICtrlRead($hBroadcaster))
				IniWrite($hFile, "Streaming", "Children"   , GUICtrlRead($hBroChild   ))
				IniWrite($hFile, "Streaming", "Assignement", GUICtrlRead($hOAssign    ))

			Case $hMsg = $hProcesses
				$bRefresh = False
				_GetProcessList($hProcesses)
				_GUICtrlListView_SortItems($hProcesses, GUICtrlGetState($hProcesses))

			Case $hMsg = $hGames
				$bRefresh = False
				_GetSteamGames($hGames)
				_GUICtrlListView_SortItems($hGames, GUICtrlGetState($hGames))

			Case $bRefresh = True
				$bRefresh = False
				_GetSteamGames($hGames)
				_GetProcessList($hProcesses)
				_GUICtrlListView_SortItems($hGames, 0)
				_GUICtrlListView_SortItems($hProcesses, 0)

			Case $hMsg = $hSearch
				GUICtrlSetState($hDToggle, $GUI_DISABLE)
				If $bPHidden Then
					GUICtrlSetState($hGames, $GUI_SHOW)
					GUICtrlSetState($hProcesses, $GUI_SHOW)
					$aPos = WinGetPos($hGUI)
					WinMove($hGUI, "", $aPos[0], $aPos[1], 640)
					GUICtrlSetPos($hGames, 280, 20, 355, 280)
					GUICtrlSetPos($hProcesses, 280, 20, 355, 280)
					$bPHidden = False
				Else
					$aTask = StringSplit(GUICtrlRead(GUICtrlRead($hProcesses)), "|", $STR_NOCOUNT)
					If Not $aTask[0] = 0 Then GUICtrlSetData($hTask, $aTask[0])
				EndIf
				GUICtrlSetState($hDToggle, $GUI_ENABLE)

			Case $hMsg = $hLoad
				If GUICtrlRead($hTask) = "" Then
					$sFile = "profile.ncc"
				Else
					$sFile = StringLower(GUICtrlRead($hTask)) & ".ncc"
				EndIf
				$hFile = FileOpenDialog($_sLang_LoadProfile, @WorkingDir, "NotCPUCores Profile (*.ncc)", $FD_FILEMUSTEXIST, $sFile, $hGUI)
				GUICtrlSetData($hTask       , String(_IniRead($hFile, "General"  , "Process"   ,                                      "",                "")))
				GUICtrlSetState($hChildren  , Number(_IniRead($hFile, "General"  , "Children"  ,                                      "",    $GUI_UNCHECKED)))
				GUICtrlSetData($hAssignMode , String(_IniRead($hFile, "General"  , "SplitAs"   , _GUICtrlComboBox_GetList($hAssignMode ),          "Custom")))
				GUICtrlSetData($hCores      , String(_IniRead($hFile, "General"  , "Threads"   ,                                      "",               "1")))
				GUICtrlSetData($hPPriority  , String(_IniRead($hFile, "General"  , "Priority"  , _GUICtrlComboBox_GetList($hPPriority  ),            "High")))
				GUICtrlSetData($hSplitMode  , String(_IniRead($hFile, "Streaming", "SplitAs"   , _GUICtrlComboBox_GetList($hSplitMode  ),             "OFF")))
				GUICtrlSetData($hBCores     , String(_IniRead($hFile, "Streaming", "Threads"   ,                                      "",               "2")))
				GUICtrlSetData($hBroadcaster, String(_IniRead($hFile, "Streaming", "Software"  , _GUICtrlComboBox_GetList($hBroadcaster),             "OBS")))
				GUICtrlSetState($hBroChild  , Number(_IniRead($hFile, "Streaming", "Children"  ,                                      "",    $GUI_UNCHECKED)))
				GUICtrlSetData($hOAssign    , String(_IniRead($hFile, "Streaming", "Assignment", _GUICtrlComboBox_GetList($hOAssign    ), "Remaining Cores")))
				ContinueCase

			Case $bInit = True
				$bInit = False
				ContinueCase

			Case $hMsg = $hBCores
				$iBroadcasterCores = 0
				If Not StringRegExp(GUICtrlRead($hBCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then ;\A[0-9]+?(,[0-9]+)*\Z
					GUICtrlSetColor($hBCores, 0xFF0000)
					GUICtrlSetState($hOptimize, $GUI_DISABLE)
				Else
					GUICtrlSetColor($hBCores, 0x000000)
					If StringRegExp(GUICtrlRead($hCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then GUICtrlSetState($hOptimize, $GUI_ENABLE)
					If StringInStr(GUICtrlRead($hBCores), ",") Or StringInStr(GUICtrlRead($hBCores), "-") Then ; Convert Multiple Cores if Declared to Magic Number
						$aBCores = StringSplit(GUICtrlRead($hBCores), ",", $STR_NOCOUNT)
						For $iLoop1 = 0 To UBound($aBCores) - 1 Step 1
							If StringInStr($aBCores[$iLoop1], "-") Then
								$aRange = StringSplit($aBCores[$iLoop1], "-", $STR_NOCOUNT)
								If $aRange[0] < $aRange[1] Then
									For $iLoop2 = $aRange[0] To $aRange[1] Step 1
										$iBroadcasterCores += 2^($iLoop2-1)
									Next
								Else
									For $iLoop2 = $aRange[1] To $aRange[0] Step 1
										$iBroadcasterCores += 2^($iLoop2-1)
									Next
								EndIf
							Else
								$iBroadcasterCores += 2^($aBCores[$iLoop1]-1)
							EndIf
						Next
					Else
						$iBroadcasterCores = 2^(GUICtrlRead($hBCores)-1)
					EndIf
				EndIf
				ContinueCase

			Case $hMsg = $hBroadcaster
				Switch GUICtrlRead($hBroadcaster)
					Case "OBS"
						ReDim $aProcesses[4]
						$aProcesses[0] = GUICtrlRead($hTask)
						$aProcesses[1] = "obs.exe"
						$aProcesses[2] = "obs32.exe"
						$aProcesses[3] = "obs64.exe"
					Case "XSplit"
						ReDim $aProcesses[5]
						$aProcesses[0] = GUICtrlRead($hTask)
						$aProcesses[1] = "XGS32.exe"
						$aProcesses[2] = "XGS64.exe"
						$aProcesses[3] = "XSplit.Core.exe"
						$aProcesses[4] = "XSplit.xbcbp.exe"
					Case Else
						ReDim $aProcesses[1]
						$aProcesses[0] = GUICtrlRead($hTask)
						_ConsoleWrite("!> " & $_sLang_InvalidBroadcast & @CRLF, $hConsole)

				EndSwitch
				ContinueCase

			Case $hMsg = $hSplitMode
				$iBroadcasterCores = 0
				Switch GUICtrlRead($hSplitMode)

					Case "OFF"
						$iBroadcasterCores = 0
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_DISABLE)
						GUICtrlSetState($hBroadcaster, $GUI_DISABLE)
						ReDim $aProcesses[1]
						$aProcesses[0] = GUICtrlRead($hTask)

					Case "Last Core"
						$iBroadcasterCores = 2^($iThreads - 1)
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Last 2 Cores"
						For $iLoop = ($iThreads - 2) To $iThreads - 1
							$iBroadcasterCores += 2^($iLoop)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Last 4 Cores"
						For $iLoop = ($iThreads-4) To $iThreads - 1
							$iBroadcasterCores += 2^($iLoop)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Last Half"
						For $iLoop = Ceiling(($iThreads - ($iThreads/2))) To $iThreads - 1
							$iBroadcasterCores += 2^($iLoop)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Odd Cores", "Non-Physical Cores"
						For $iLoop = 1 To $iThreads - 1 Step 2
							$iBroadcasterCores += 2^($iLoop)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Even Cores", "Physical Cores"
						For $iLoop = 0 To $iThreads - 1 Step 2
							$iBroadcasterCores += 2^($iLoop)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Every Other Pair"
						For $iLoop = 2 To $iThreads - 1 Step 4
							$iBroadcasterCores += 2^($iLoop)
							$iBroadcasterCores += 2^($iLoop + 1)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Last AMD CCX"
						For $iLoop = ($iThreads - _CalculateCCX()) To $iThreads - 1 Step 2
							$iBroadcasterCores += 2^($iLoop)
						Next
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)

					Case "Custom"
						GUICtrlSetState($hBCores, $GUI_ENABLE)
						GUICtrlSetState($hOAssign, $GUI_ENABLE)
						GUICtrlSetState($hBroadcaster, $GUI_ENABLE)
						If Not StringRegExp(GUICtrlRead($hBCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then ;\A[0-9]+?(,[0-9]+)*\Z
							GUICtrlSetColor($hBCores, 0xFF0000)
							GUICtrlSetState($hOptimize, $GUI_DISABLE)
						Else
							GUICtrlSetColor($hBCores, 0x000000)
							If StringRegExp(GUICtrlRead($hCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then GUICtrlSetState($hOptimize, $GUI_ENABLE)
							If StringInStr(GUICtrlRead($hBCores), ",") Then ; Convert Multiple Cores if Declared to Magic Number
								$aBCores = StringSplit(GUICtrlRead($hBCores), ",", $STR_NOCOUNT)
								For $iLoop1 = 0 To UBound($aBCores) - 1 Step 1
									If StringInStr($aBCores[$iLoop1], "-") Then
										$aRange = StringSplit($aBCores[$iLoop1], "-", $STR_NOCOUNT)
										If $aRange[0] < $aRange[1] Then
											For $iLoop2 = $aRange[0] To $aRange[1] Step 1
												$iBroadcasterCores += 2^($iLoop2-1)
											Next
										Else
											For $iLoop2 = $aRange[1] To $aRange[0] Step 1
												$iBroadcasterCores += 2^($iLoop2-1)
											Next
										EndIf
									Else
										$iBroadcasterCores += 2^($aBCores[$iLoop1]-1)
									EndIf
								Next
							Else
								$iBroadcasterCores = 2^(GUICtrlRead($hBCores)-1)
							EndIf
						EndIf

					Case Else
						GUICtrlSetState($hBCores, $GUI_DISABLE)
						GUICtrlSetState($hOAssign, $GUI_DISABLE)
						GUICtrlSetState($hBroadcaster, $GUI_DISABLE)
						ReDim $aProcesses[1]
						_ConsoleWrite("!> " & $_sLang_InvalidBroadcastCores & @CRLF, $hConsole)

				EndSwitch
				ContinueCase

			Case $hMsg = $hCores
				$iProcessCores = 0
				If Not StringRegExp(GUICtrlRead($hCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then ;\A[0-9]+?(,[0-9]+)*\Z
					GUICtrlSetColor($hCores, 0xFF0000)
					GUICtrlSetState($hOptimize, $GUI_DISABLE)
				Else
					GUICtrlSetColor($hCores, 0x000000)
					If StringRegExp(GUICtrlRead($hBCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then GUICtrlSetState($hOptimize, $GUI_ENABLE)
					If StringInStr(GUICtrlRead($hCores), ",") Or StringInStr(GUICtrlRead($hCores), "-") Then ; Convert Multiple Cores if Declared to Magic Number
						$aCores = StringSplit(GUICtrlRead($hCores), ",", $STR_NOCOUNT)
						For $iLoop1 = 0 To UBound($aCores) - 1 Step 1
							If StringInStr($aCores[$iLoop1], "-") Then
								$aRange = StringSplit($aCores[$iLoop1], "-", $STR_NOCOUNT)
								If $aRange[0] < $aRange[1] Then
									For $iLoop2 = $aRange[0] To $aRange[1] Step 1
										$iProcessCores += 2^($iLoop2-1)
									Next
								Else
									For $iLoop2 = $aRange[1] To $aRange[0] Step 1
										$iProcessCores += 2^($iLoop2-1)
									Next
								EndIf
							Else
								$iProcessCores += 2^($aCores[$iLoop1]-1)
							EndIf
						Next
					Else
						$iProcessCores = 2^(GUICtrlRead($hCores)-1)
					EndIf
				EndIf
				ContinueCase

			Case $hMsg = $hAssignMode
				$iProcessCores = 0
				Switch GUICtrlRead($hAssignMode)

					Case "All Cores"
						$iProcessCores = $iAllCores
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "First Core"
						$iProcessCores = 1
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "First 2 Cores"
						$iProcessCores = 3
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "First 4 Cores"
						$iProcessCores = 15
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "First Half"
						For $iLoop = 0 To (Floor(($iThreads - ($iThreads/2))) - 1)
							$iProcessCores += 2^($iLoop)
						Next
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "Odd Cores", "Non-Physical Cores"
						For $iLoop = 1 To $iThreads - 1 Step 2
							$iProcessCores += 2^($iLoop)
						Next
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "Even Cores", "Physical Cores"
						For $iLoop = 0 To $iThreads - 1 Step 2
							$iProcessCores += 2^($iLoop)
						Next
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "Every Other Pair"
						For $iLoop = 0 To $iThreads - 1 Step 4
							$iProcessCores += 2^($iLoop)
							$iProcessCores += 2^($iLoop + 1)
						Next
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "First AMD CCX"
						For $iLoop = 0 To (_CalculateCCX() - 1) Step 2
							$iProcessCores += 2^($iLoop)
						Next
						GUICtrlSetState($hCores, $GUI_DISABLE)

					Case "Custom"
						GUICtrlSetState($hCores, $GUI_ENABLE)
						If Not StringRegExp(GUICtrlRead($hCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then ;\A[0-9]+?(,[0-9]+)*\Z
							GUICtrlSetColor($hCores, 0xFF0000)
							GUICtrlSetState($hOptimize, $GUI_DISABLE)
						Else
							GUICtrlSetColor($hCores, 0x000000)
							If StringRegExp(GUICtrlRead($hBCores), "^(?:[1-9]\d*-?(?!\d+-)(?:[1-9]\d*)?(?!,$),?)+$") Then GUICtrlSetState($hOptimize, $GUI_ENABLE)
							If StringInStr(GUICtrlRead($hCores), ",") Or StringInStr(GUICtrlRead($hCores), "-") Then ; Convert Multiple Cores if Declared to Magic Number
								$aCores = StringSplit(GUICtrlRead($hCores), ",", $STR_NOCOUNT)
								For $iLoop1 = 0 To UBound($aCores) - 1 Step 1
									If StringInStr($aCores[$iLoop1], "-") Then
										$aRange = StringSplit($aCores[$iLoop1], "-", $STR_NOCOUNT)
										If $aRange[0] < $aRange[1] Then
											For $iLoop2 = $aRange[0] To $aRange[1] Step 1
												$iProcessCores += 2^($iLoop2-1)
											Next
										Else
											For $iLoop2 = $aRange[1] To $aRange[0] Step 1
												$iProcessCores += 2^($iLoop2-1)
											Next
										EndIf
									Else
										$iProcessCores += 2^($aCores[$iLoop1]-1)
									EndIf
								Next
							Else
								$iProcessCores = 2^(GUICtrlRead($hCores)-1)
							EndIf
						EndIf

					Case Else
					_ConsoleWrite("!> " & $_sLang_InvalidProcessCores & @CRLF, $hConsole)
					GUICtrlSetState($hOptimize, $GUI_DISABLE)
					GUICtrlSetState($hCores, $GUI_DISABLE)

				EndSwitch
				ContinueCase

			Case $hMsg = $hOAssign
				$iOtherProcessCores = 0
				Switch GUICtrlRead($hOAssign)

					Case "Broadcaster Cores"
						$iOtherProcessCores = $iBroadcasterCores

					Case "Game Cores"
						$iOtherProcessCores = $iProcessCores

					Case "Remaining Cores"
						$iOtherProcessCores = $iAllCores - BitOR($iProcessCores, $iBroadcasterCores)

					Case Else
						$iOtherProcessCores = 1
						_ConsoleWrite("!> " & $_sLang_InvalidOtherCores & @CRLF, $hConsole)

				EndSwitch

			Case $hMsg = $hReset
				For $Loop = $hTask to $hReset Step 1
					GUICtrlSetState($Loop, $GUI_DISABLE)
				Next
				GUICtrlSetData($hReset, $_sLang_RestoreAlt)
				_Restore($iThreads, $hConsole)
				GUICtrlSetData($hReset, $_sLang_Restore)
				For $iLoop = $hTask to $hOptimize Step 1
					If $iLoop = $hChildren Then ContinueLoop
					GUICtrlSetState($iLoop, $GUI_ENABLE)
				Next

			Case $hMsg = $hOptimize
				For $Loop = $hTask to $hOptimize Step 1
					GUICtrlSetState($Loop, $GUI_DISABLE)
				Next
				GUICtrlSetData($hOptimize, $_sLang_OptimizeAlt)
				$aProcesses[0] = GUICtrlRead($hTask)
				$iProcesses = _Optimize($iProcesses,$aProcesses[0],$iProcessCores,$iSleep,GUICtrlRead($hPPriority),$hConsole)
				If _OptimizeOthers($aProcesses, $iOtherProcessCores, $iSleep, $hConsole) Then $iProcesses = 1
				If _OptimizeBroadcaster($aProcesses, $iBroadcasterCores, $iSleep, GUICtrlRead($hPPriority), $hConsole) Then $iProcesses = 1

			Case $hMsg = $hGameM
				ShellExecute("ms-settings:gaming-gamemode")

			Case $hMsg = $hPower
				Run(@ComSpec & " /c " & 'control powercfg.cpl,,1', "", @SW_HIDE)

			Case $hMsg = $hDefrag
				Run(@ComSpec & " /c " & 'defrag C: /V && pause', "")

			Case $hMsg = $hCheck
				Run(@ComSpec & " /c " & 'chkdsk C: /V && pause', "")

			Case $hMsg = $hCleanup
				Run(@ComSpec & " /c " & 'cleanmgr', "")

			Case $hMsg = $hSSense
				ShellExecute("ms-settings:storagepolicies")

			Case $hMsg = $hEvents
				Run(@ComSpec & " /c " & 'perfmon /rel', "", @SW_HIDE)

			Case $hMsg = $hActions
				Run(@ComSpec & " /c " & 'control wscui.cpl', "", @SW_HIDE)

			Case $hMsg = $hGithub
				ShellExecute("http://www.github.com/rcmaehl/NotCPUCores")

			Case $hMsg = $hHowTo
				ShellExecute("https://github.com/rcmaehl/NotCPUCores/blob/master/FAQ.md#is-it-possible-to-get-the-benefits-of-notcpucores-without-installing-it")

			Case $hMsg = $hUpdate
				ShellExecute("https://github.com/rcmaehl/NotCPUCores/releases/latest")

			Case Else
				Sleep($iSleep /  10)

		EndSelect
	WEnd
EndFunc

Func _CalculateCCX()

	If $iThreads > 16 Then ; Threadripper
		$iDivisor = 4
	Else
		$iDivisor = 2
	EndIf

	Return ($iThreads/$iDivisor)

EndFunc

Func _GetChildProcesses($i_pid) ; First level children processes only
    Local Const $TH32CS_SNAPPROCESS = 0x00000002

    Local $a_tool_help = DllCall("Kernel32.dll", "long", "CreateToolhelp32Snapshot", "int", $TH32CS_SNAPPROCESS, "int", 0)
    If IsArray($a_tool_help) = 0 Or $a_tool_help[0] = -1 Then Return SetError(1, 0, $i_pid)

    Local $tagPROCESSENTRY32 = _
        DllStructCreate _
            ( _
                "dword dwsize;" & _
                "dword cntUsage;" & _
                "dword th32ProcessID;" & _
                "uint th32DefaultHeapID;" & _
                "dword th32ModuleID;" & _
                "dword cntThreads;" & _
                "dword th32ParentProcessID;" & _
                "long pcPriClassBase;" & _
                "dword dwFlags;" & _
                "char szExeFile[260]" _
            )
    DllStructSetData($tagPROCESSENTRY32, 1, DllStructGetSize($tagPROCESSENTRY32))

    Local $p_PROCESSENTRY32 = DllStructGetPtr($tagPROCESSENTRY32)

    Local $a_pfirst = DllCall("Kernel32.dll", "int", "Process32First", "long", $a_tool_help[0], "ptr", $p_PROCESSENTRY32)
    If IsArray($a_pfirst) = 0 Then Return SetError(2, 0, $i_pid)

    Local $a_pnext, $a_children[11][2] = [[10]], $i_child_pid, $i_parent_pid, $i_add = 0
    $i_child_pid = DllStructGetData($tagPROCESSENTRY32, "th32ProcessID")
    If $i_child_pid <> $i_pid Then
        $i_parent_pid = DllStructGetData($tagPROCESSENTRY32, "th32ParentProcessID")
        If $i_parent_pid = $i_pid Then
            $i_add += 1
            $a_children[$i_add][0] = $i_child_pid
            $a_children[$i_add][1] = DllStructGetData($tagPROCESSENTRY32, "szExeFile")
        EndIf
    EndIf

    While 1
        $a_pnext = DLLCall("Kernel32.dll", "int", "Process32Next", "long", $a_tool_help[0], "ptr", $p_PROCESSENTRY32)
        If IsArray($a_pnext) And $a_pnext[0] = 0 Then ExitLoop
        $i_child_pid = DllStructGetData($tagPROCESSENTRY32, "th32ProcessID")
        If $i_child_pid <> $i_pid Then
            $i_parent_pid = DllStructGetData($tagPROCESSENTRY32, "th32ParentProcessID")
            If $i_parent_pid = $i_pid Then
                If $i_add = $a_children[0][0] Then
                    ReDim $a_children[$a_children[0][0] + 11][2]
                    $a_children[0][0] = $a_children[0][0] + 10
                EndIf
                $i_add += 1
                $a_children[$i_add][0] = $i_child_pid
                $a_children[$i_add][1] = DllStructGetData($tagPROCESSENTRY32, "szExeFile")
            EndIf
        EndIf
    WEnd

    If $i_add <> 0 Then
        ReDim $a_children[$i_add + 1][2]
        $a_children[0][0] = $i_add
    EndIf

    DllCall("Kernel32.dll", "int", "CloseHandle", "long", $a_tool_help[0])
    If $i_add Then Return $a_children
    Return SetError(3, 0, 0)
EndFunc

Func _GetProcessList($hControl)

	_GUICtrlListView_DeleteAllItems($hControl)
	Local $aWindows = WinList()
	Do
		$iDelete = _ArraySearch($aWindows, "Default IME")
		_ArrayDelete($aWindows, $iDelete)
	Until _ArraySearch($aWindows, "Default IME") = -1
	Do
		$iDelete = _ArraySearch($aWindows, "")
		_ArrayDelete($aWindows, $iDelete)
	Until _ArraySearch($aWindows, "") = -1
	$aWindows[0][0] = UBound($aWindows)
	For $Loop = 1 To $aWindows[0][0] - 1
		$aWindows[$Loop][1] = _ProcessGetName(WinGetProcess($aWindows[$Loop][1]))
		GUICtrlCreateListViewItem($aWindows[$Loop][1] & "|" & $aWindows[$Loop][0], $hControl)
	Next
	_ArrayDelete($aWindows, 0)
	For $i = 0 To _GUICtrlListView_GetColumnCount($hControl) Step 1
		_GUICtrlListView_SetColumnWidth($hControl, $i, $LVSCW_AUTOSIZE_USEHEADER)
	Next
;	_GUICtrlListView_SortItems($hControl, GUICtrlGetState($hControl))

EndFunc

Func _GetSteamGames($hControl)

	Return ; Return as code isn't ready yet

	Local $aSteamLibraries = _GetSteamLibraries()
	Local $aSteamGames

	$aSteamGames[0][0] = UBound($aSteamGames)
	For $Loop = 1 To $aSteamGames[0][0] - 1
		$aSteamGames[$Loop][1] = _ProcessGetName(WinGetProcess($aSteamGames[$Loop][1]))
		GUICtrlCreateListViewItem($aSteamGames[$Loop][1] & "|" & $aSteamGames[$Loop][0], $hControl)
	Next
	_ArrayDelete($aSteamGames, 0)
	For $i = 0 To _GUICtrlListView_GetColumnCount($hControl) Step 1
		_GUICtrlListView_SetColumnWidth($hControl, $i, $LVSCW_AUTOSIZE_USEHEADER)
	Next

EndFunc

Func _Interrupt()
	$bInterrupt = True
EndFunc

Func _IsChecked($idControlID)
	Return BitAND(GUICtrlRead($idControlID), $GUI_CHECKED) = $GUI_CHECKED
EndFunc   ;==>_IsChecked

Func _Refresh()
	$bRefresh = True
EndFunc