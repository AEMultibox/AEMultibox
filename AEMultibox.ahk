#Requires AutoHotkey v2.0
#SingleInstance Force
; Version: v1.0.0

; ================================
; Improved Auto-Update Configuration
; ================================
global APP_VERSION := "v1.0.3"
global UPDATE_CHECK_URL := "https://api.github.com/repos/AEMultibox/AEMultibox/releases/latest"
global UPDATE_CHECK_INTERVAL := 3600000  ; Check every hour
global AUTO_UPDATE_ENABLED := true
global LAST_UPDATE_CHECK := 0
global UPDATE_IN_PROGRESS := false  ; Prevent multiple simultaneous checks

; ================================
; Admin / startup
; ================================
global USE_MEMORY_READING := true

; Check for updates before anything else
CheckForUpdates(true)  ; true = silent check on startup

if !A_IsAdmin {
    result := MsgBox(
        "This script works best with administrator privileges to read game memory for accurate combat detection.`n`n" .
        "Would you like to run as administrator?`n`n" .
        "(If you choose No, the script will use cursor color detection instead)",
        "Admin Recommended", 0x34)
    if (result == "Yes") {
        try {
            Run '*RunAs "' . A_AhkPath . '" /restart "' . A_ScriptFullPath . '"'
        } catch {
            MsgBox("Failed to elevate. Falling back to cursor color detection.", "Notice", 0x30)
            USE_MEMORY_READING := false
        }
        ExitApp
    } else {
        USE_MEMORY_READING := false
    }
}

SetTitleMatchMode(2)
DetectHiddenWindows true
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

; ================================
; Globals
; ================================
global TargetExeName := "AshenEmpires.exe"
global TargetExe := "ahk_exe " . TargetExeName
global Window1Class := "Sandbox:Ashen_empires:WindowsClass"
global Window2Class := "WindowsClass"

; memory addresses
global GlobalManagerAddress := 0x744074
global CombatModeOffset := 0x2A8
global ChatBaseOffset := 0x323084
global ChatFinalOffset := 0x6AC

; state
global isLooping := false
global USE_CHAT_DETECTION := true
global FOLLOW_ENABLED := true

global windowChatModes := Map()

global qPressInverted := false
global lastQPressTime := 0
global doublePressDuration := 300

global selectedFKey := "F8"
global followDirection := "Switching To Sandbox (Main follows Alt)"

global windowCombatStates := Map()
global windowProcessHandles := Map()
global moduleBaseAddresses := Map()

global lastWindowCount := -1
global lastCombatStatus := ""
global lastWindow1Status := ""
global lastWindow2Status := ""
global lastChatStatus := ""

; AEBoost Integration globals
global AEBoostPath := A_ScriptDir . "\AEBoost\AEBoost.exe"
global AutoRuneEnabled := false
global AEBoostProcess := 0

; ================================
; Auto-Update Functions
; ================================
CheckForUpdates(silent := false) {
    global APP_VERSION, UPDATE_CHECK_URL, AUTO_UPDATE_ENABLED, LAST_UPDATE_CHECK
    
    if (!AUTO_UPDATE_ENABLED)
        return
    
    ; Rate limit update checks
    currentTime := A_TickCount
    if (currentTime - LAST_UPDATE_CHECK < 60000)  ; Don't check more than once per minute
        return
    
    LAST_UPDATE_CHECK := currentTime
    
    try {
        ; Create temporary file for version check
        tempFile := A_Temp . "\aemultibox_version_check.json"
        
        ; Download version info using PowerShell
        psCommand := 'Invoke-WebRequest -Uri "' . UPDATE_CHECK_URL . '" -OutFile "' . tempFile . '" -UseBasicParsing'
        RunWait('powershell.exe -ExecutionPolicy Bypass -Command "' . psCommand . '"',, "Hide")
        
        if (!FileExist(tempFile))
            throw Error("Failed to download version information")
        
        ; Read and parse JSON
        jsonContent := FileRead(tempFile)
        
        ; Extract version using regex (simple JSON parsing)
        if (RegExMatch(jsonContent, '"tag_name"\s*:\s*"([^"]+)"', &match)) {
            latestVersion := match[1]
            
            ; Compare versions
            if (CompareVersions(latestVersion, APP_VERSION) > 0) {
                ; Extract download URL
                downloadUrl := ""
                if (RegExMatch(jsonContent, '"browser_download_url"\s*:\s*"([^"]*AEMultibox\.exe[^"]*)"', &urlMatch)) {
                    downloadUrl := urlMatch[1]
                }
                
                if (!silent) {
                    ShowUpdateDialog(latestVersion, downloadUrl)
                } else {
                    ; Show notification for silent check
                    TrayTip("Update Available", "AEMultibox " . latestVersion . " is available!`nCheck Settings tab to update.", "Info")
                }
            } else if (!silent) {
                MsgBox("You are running the latest version (" . APP_VERSION . ")", "No Updates", 0x40)
            }
        }
        
        ; Clean up
        try FileDelete(tempFile)
        
    } catch as err {
        if (!silent) {
            MsgBox("Failed to check for updates: " . err.Message, "Update Check Error", 0x10)
        }
    }
}

CompareVersions(v1, v2) {
    ; Remove 'v' prefix if present
    v1 := RegExReplace(v1, "^v", "")
    v2 := RegExReplace(v2, "^v", "")
    
    ; Split into parts
    parts1 := StrSplit(v1, ".")
    parts2 := StrSplit(v2, ".")
    
    ; Compare each part
    maxParts := Max(parts1.Length, parts2.Length)
    Loop maxParts {
        p1 := (A_Index <= parts1.Length) ? Integer(parts1[A_Index]) : 0
        p2 := (A_Index <= parts2.Length) ? Integer(parts2[A_Index]) : 0
        
        if (p1 > p2)
            return 1
        else if (p1 < p2)
            return -1
    }
    
    return 0  ; Versions are equal
}

ShowUpdateDialog(newVersion, downloadUrl := "") {
    global APP_VERSION
    
    message := "A new version of AEMultibox is available!`n`n"
    message .= "Current version: " . APP_VERSION . "`n"
    message .= "New version: " . newVersion . "`n`n"
    
    if (downloadUrl != "") {
        message .= "Would you like to download and install the update now?"
        result := MsgBox(message, "Update Available", 0x34)
        
        if (result == "Yes") {
            DownloadAndInstallUpdate(downloadUrl, newVersion)
        }
    } else {
        message .= "Please visit the GitHub releases page to download the update."
        MsgBox(message, "Update Available", 0x40)
    }
}

DownloadAndInstallUpdate(downloadUrl, newVersion) {
    try {
        ; Show progress dialog
        progressGui := Gui("+AlwaysOnTop -MinimizeBox", "Downloading Update...")
        progressGui.Add("Text", "w300 Center", "Downloading AEMultibox " . newVersion . "...")
        progressBar := progressGui.Add("Progress", "w300 h20", 0)
        statusText := progressGui.Add("Text", "w300 Center", "Preparing download...")
        progressGui.Show()
        
        ; Download new version
        tempFile := A_Temp . "\AEMultibox_update.exe"
        backupFile := A_ScriptFullPath . ".backup"
        
        ; Download using PowerShell with progress
        statusText.Text := "Downloading update..."
        psCommand := 'Invoke-WebRequest -Uri "' . downloadUrl . '" -OutFile "' . tempFile . '" -UseBasicParsing'
        RunWait('powershell.exe -ExecutionPolicy Bypass -Command "' . psCommand . '"',, "Hide")
        
        if (!FileExist(tempFile)) {
            throw Error("Download failed")
        }
        
        progressBar.Value := 50
        statusText.Text := "Installing update..."
        
        ; Create updater batch script
        updaterScript := A_Temp . "\aemultibox_updater.bat"
        updaterContent := "@echo off`n"
        updaterContent .= "timeout /t 2 /nobreak > nul`n"  ; Wait for current process to exit
        updaterContent .= 'move /y "' . A_ScriptFullPath . '" "' . backupFile . '"`n'  ; Backup current
        updaterContent .= 'move /y "' . tempFile . '" "' . A_ScriptFullPath . '"`n'  ; Install new
        updaterContent .= 'start "" "' . A_ScriptFullPath . '"`n'  ; Start new version
        updaterContent .= 'del "%~f0"`n'  ; Delete this batch file
        
        FileAppend(updaterContent, updaterScript)
        
        progressBar.Value := 100
        statusText.Text := "Restarting with new version..."
        
        ; Clean up before restart
        progressGui.Destroy()
        
        ; Execute updater and exit
        Run(updaterScript,, "Hide")
        ExitApp()
        
    } catch as err {
        if (IsSet(progressGui))
            progressGui.Destroy()
        MsgBox("Update failed: " . err.Message . "`n`nPlease download the update manually from GitHub.", "Update Error", 0x10)
    }
}

; ================================
; GUI
; ================================
global MyGui := Gui(, "AE Multi-Window Tool")
MyGui.Opt("+Resize -MaximizeBox +MinSize250x200")
MyGui.SetFont("s10", "Segoe UI")
MyGui.BackColor := "0xF0F0F0"

global Tab := MyGui.Add("Tab3", "w350", ["Main", "Settings", "Info"])

; Main tab
Tab.UseTab(1)
MyGui.SetFont("s11 Bold", "Segoe UI")
global StatusText := MyGui.Add("Text", "w330 Center", "Status: OFF")
StatusText.SetFont("cRed")

MyGui.SetFont("s9 Norm", "Segoe UI")
global WindowCountText := MyGui.Add("Text", "w330 Center y+5", "Windows Found: 0")

global CombatStatusText := MyGui.Add("Text", "w330 Center y+5", "Combat: Unknown")

global Window1CombatText := MyGui.Add("Text", "w330 Center y+5", "Main Window: Unknown")

global Window2CombatText := MyGui.Add("Text", "w330 Center y+5", "Sandbox Window: Unknown")

global ChatStatusText := MyGui.Add("Text", "w330 Center y+5", "Chat: Inactive")

MyGui.Add("Text", "xs y+10 w330", "────────────────────────────────")

global ChatDetectCheckbox := MyGui.Add("CheckBox", "x20 y+5 Checked", "Enable Memory Chat Detection")
ChatDetectCheckbox.OnEvent("Click", (*) => (USE_CHAT_DETECTION := ChatDetectCheckbox.Value))

global FollowCheckbox := MyGui.Add("CheckBox", "x20 y+5 Checked", "Enable Follow Feature (Tab key)")
FollowCheckbox.OnEvent("Click", (*) => (FOLLOW_ENABLED := FollowCheckbox.Value))

MyGui.SetFont("s8", "Segoe UI")
MyGui.Add("Text", "w330 Center y+10 cGray", "Press PgUp to Start/Stop")

; Settings tab
Tab.UseTab(2)
MyGui.SetFont("s9", "Segoe UI")
MyGui.Add("Text", "Section", "Follow Settings:")
MyGui.Add("Text", "xs y+10", "Follow Key:")

global FKeyDropdown := MyGui.Add("DropDownList", "w100 xs+80 yp-2", ["F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"])
FKeyDropdown.Text := "F8"
FKeyDropdown.OnEvent("Change", (*) => (selectedFKey := FKeyDropdown.Text))

MyGui.Add("Text", "xs y+10", "Send Key When:")

global DirectionDropdown := MyGui.Add("DropDownList", "w330 xs", ["Switching To Sandbox (Main follows Alt)", "Switching From Sandbox (Alt follows Main)"])
DirectionDropdown.Choose(1)
DirectionDropdown.OnEvent("Change", (*) => (followDirection := DirectionDropdown.Text))

MyGui.Add("Text", "xs y+10 w330", "────────────────────────────────")
MyGui.Add("Text", "xs y+5", "Q Key Behavior:")

global qPressInvertCheckbox := MyGui.Add("CheckBox", "xs+10 y+5", "Invert (Single=Active, Double=All)")
qPressInvertCheckbox.OnEvent("Click", (*) => (qPressInverted := qPressInvertCheckbox.Value))

MyGui.Add("Text", "xs y+10 w330", "────────────────────────────────")
MyGui.Add("Text", "xs y+5", "Right Alt + Key:")
MyGui.Add("Text", "xs+10 y+5 w310", "Hold Right Alt and press any key to send it to the other game window")

; AEBoost Integration section
MyGui.Add("Text", "xs y+15 w330", "────────────────────────────────")
MyGui.Add("Text", "xs y+5", "AEBoost Integration:")

global AutoRuneButton := MyGui.Add("Button", "xs y+5 w150 h25", "Enable AutoRune")
AutoRuneButton.OnEvent("Click", ToggleAutoRune)

global AutoRuneStatus := MyGui.Add("Text", "x+10 yp+5 w150", "Status: Disabled")
AutoRuneStatus.SetFont("s9")

; Auto-Update section
MyGui.Add("Text", "xs y+15 w330", "────────────────────────────────")
MyGui.Add("Text", "xs y+5", "Auto-Update:")

global AutoUpdateCheckbox := MyGui.Add("CheckBox", "xs y+5 Checked", "Check for updates automatically")
AutoUpdateCheckbox.OnEvent("Click", (*) => (AUTO_UPDATE_ENABLED := AutoUpdateCheckbox.Value))

global UpdateButton := MyGui.Add("Button", "xs y+5 w150 h25", "Check for Updates")
UpdateButton.OnEvent("Click", (*) => CheckForUpdates(false))

global VersionText := MyGui.Add("Text", "x+10 yp+5 w150", "Version: " . APP_VERSION)
VersionText.SetFont("s9")

; Info tab
Tab.UseTab(3)
MyGui.SetFont("s8", "Segoe UI")
MyGui.Add("Text", "w330", "HOTKEYS:")
MyGui.Add("Text", "w330", "• PgUp: Start/Stop (Global)")
MyGui.Add("Text", "w330", "• Tab: Switch Windows (if Follow enabled)")
MyGui.Add("Text", "w330", "• Q / Double Q: Toggles combat")
MyGui.Add("Text", "w330", "  (Default: Single=All, Double=Active)")
MyGui.Add("Text", "w330", "• Right Alt + Any Key: Send to other window")
MyGui.Add("Text", "w330", "• Enter: Toggle chat mode")
MyGui.Add("Text", "w330", "• Esc: Exit chat mode & combat")
MyGui.Add("Text", "w330 y+10", "AEBOOST:")
MyGui.Add("Text", "w330", "• AutoRune: Automatically swaps and refreshes runes")
MyGui.Add("Text", "w330", "• Enable from Settings tab")
MyGui.Add("Text", "w330 y+10", "AUTO-UPDATE:")
MyGui.Add("Text", "w330", "• Checks for updates on startup")
MyGui.Add("Text", "w330", "• Manual check in Settings tab")
MyGui.Add("Text", "w330", "• Automatic download and install")

; Tab / Close handlers
Tab.UseTab()
Tab.OnEvent("Change", OnTabChange)
MyGui.OnEvent("Close", CleanupAndExit)
MyGui.Show("w370")
; Force initial height to EXACT Main height after Show
Tab.Value := 1
OnTabChange()

; ================================
; Init
; ================================
if (USE_MEMORY_READING)
    InitializeWindowHandles()
UpdateWindowCount()
SetTimer(CheckCombatState, 150)
SetTimer(UpdateChatDisplay, 100)
SetTimer(() => CheckForUpdates(true), UPDATE_CHECK_INTERVAL)  ; Periodic update check

; ================================
; Event Handlers / Helpers / Core
; ================================
OnTabChange(*) {
    global Tab, MyGui
    currentTab := Tab.Value
    ; Per-tab window heights
    targetHeight := 310           ; Main (tab 1) - tighter
    if (currentTab == 2)
        targetHeight := 550       ; Settings (tab 2) - tallest for AEBoost and Update sections
    else if (currentTab == 3)
        targetHeight := 520       ; Info (tab 3) - more room for hotkeys and update info
    MyGui.GetPos(&x, &y, &w, &h)
    if (h != targetHeight)
        MyGui.Move(, , , targetHeight)
}

CleanupAndExit(*) {
    global AEBoostProcess
    if (AEBoostProcess) {
        try {
            ProcessClose(AEBoostProcess)
        } catch {
        }
    }
    ExitApp()
}

ToggleAutoRune(*) {
    global AutoRuneEnabled, AEBoostProcess, AEBoostPath, AutoRuneButton, AutoRuneStatus
    
    if (!AutoRuneEnabled) {
        ; Check if AEBoost.exe exists
        if (!FileExist(AEBoostPath)) {
            MsgBox("AEBoost.exe not found!`n`nPlease place AEBoost files in:`n" . A_ScriptDir . "\AEBoost\", "Error", 0x10)
            return
        }
        
        ; Check if game is running
        if (!WinExist("ahk_exe AshenEmpires.exe")) {
            MsgBox("Ashen Empires must be running first!", "Notice", 0x30)
            return
        }
        
        try {
            ; Run AEBoost with command-line arguments for AutoRune only
            ; /autorune enables only the AutoRune mod
            ; /silent runs without GUI in background
            Run(AEBoostPath . " /autorune /silent", A_ScriptDir . "\AEBoost", "Hide", &AEBoostProcess)
            
            ; Give it a moment to initialize
            Sleep(500)
            
            ; Verify the process is running
            if (!ProcessExist(AEBoostProcess)) {
                throw Error("AEBoost failed to start")
            }
            
            AutoRuneEnabled := true
            AutoRuneButton.Text := "Disable AutoRune"
            AutoRuneStatus.Text := "Status: ACTIVE"
            AutoRuneStatus.SetFont("cGreen")
            
            SoundBeep(1000, 100)
            
            ; Notify user
            ToolTip("AutoRune Enabled - Running in background", , , 1)
            SetTimer(() => ToolTip(, , , 1), -3000)
            
        } catch as err {
            MsgBox("Failed to start AEBoost: " . err.Message, "Error", 0x10)
            if (AEBoostProcess) {
                try ProcessClose(AEBoostProcess)
                AEBoostProcess := 0
            }
            AutoRuneEnabled := false
        }
    } else {
        ; Stop AEBoost
        if (AEBoostProcess) {
            try {
                ProcessClose(AEBoostProcess)
            } catch {
                ; Process might already be closed
            }
        }
        
        AutoRuneEnabled := false
        AutoRuneButton.Text := "Enable AutoRune"
        AutoRuneStatus.Text := "Status: Disabled"
        AutoRuneStatus.SetFont("cBlack")
        AEBoostProcess := 0
        
        SoundBeep(600, 100)
        
        ; Notify user
        ToolTip("AutoRune Disabled", , , 1)
        SetTimer(() => ToolTip(, , , 1), -2000)
    }
}

InitializeWindowHandles() {
    global windowProcessHandles, windowCombatStates, windowChatModes, TargetExe, Window1Class, Window2Class
    global moduleBaseAddresses
    windowProcessHandles.Clear()
    windowCombatStates.Clear()
    windowChatModes.Clear()
    moduleBaseAddresses.Clear()
    for hwnd in WinGetList(TargetExe) {
        try {
            className := WinGetClass("ahk_id " . hwnd)
            if (className != Window1Class && className != Window2Class)
                continue
            pid := WinGetPID("ahk_id " . hwnd)
            hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", false, "UInt", pid, "Ptr")
            if (hProcess) {
                windowProcessHandles[hwnd] := hProcess
                windowCombatStates[hwnd] := false
                windowChatModes[hwnd] := false
                moduleBaseAddresses[hwnd] := 0x400000
            }
        } catch {
            continue
        }
    }
}

CheckCombatState() {
    global windowProcessHandles, windowCombatStates, GlobalManagerAddress, CombatModeOffset
    global Window1CombatText, Window2CombatText, CombatStatusText, Window1Class, Window2Class
    global lastCombatStatus, lastWindow1Status, lastWindow2Status
    global windowChatModes, ChatBaseOffset, ChatFinalOffset, USE_CHAT_DETECTION
    global moduleBaseAddresses

    if (!USE_MEMORY_READING)
        return false

    anyInCombat := false
    newWindow1Status := ""
    newWindow2Status := ""

    for hwnd, hProcess in windowProcessHandles.Clone() {
        if !WinExist("ahk_id " . hwnd) {
            CleanupWindow(hwnd)
            continue
        }
        try {
            className := WinGetClass("ahk_id " . hwnd)
            if (className != Window1Class && className != Window2Class)
                continue

            ; read combat flag
            managerPtrAddress := GlobalManagerAddress
            objBuf := Buffer(4)
            ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", managerPtrAddress, "Ptr", objBuf, "UInt", 4, "Ptr*", &bytesRead := 0)
            if (ok && bytesRead == 4) {
                objAddr := NumGet(objBuf, 0, "UInt")
                if (objAddr) {
                    combatAddr := objAddr + CombatModeOffset
                    combatBuf := Buffer(1)
                    ok2 := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", combatAddr, "Ptr", combatBuf, "UInt", 1, "Ptr*", &bytesRead := 0)
                    if (ok2 && bytesRead == 1) {
                        isInCombat := (NumGet(combatBuf, 0, "UChar") != 0)
                        windowCombatStates[hwnd] := isInCombat
                        if (isInCombat)
                            anyInCombat := true
                    }
                }
            }

            ; read chat state (optional)
            if (USE_CHAT_DETECTION && moduleBaseAddresses.Has(hwnd)) {
                base := moduleBaseAddresses[hwnd]
                if (base > 0) {
                    basePtrBuf := Buffer(4)
                    if (DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", base + ChatBaseOffset, "Ptr", basePtrBuf, "UInt", 4, "Ptr*", &bytesRead) && bytesRead == 4) {
                        basePtr := NumGet(basePtrBuf, 0, "UInt")
                        if (basePtr > 0x10000 && basePtr < 0xFFFF0000) {
                            finalAddr := basePtr + ChatFinalOffset
                            chatBuf := Buffer(1)
                            if (DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", finalAddr, "Ptr", chatBuf, "UInt", 1, "Ptr*", &bytesRead) && bytesRead == 1) {
                                chatVal := NumGet(chatBuf, 0, "UChar")
                                windowChatModes[hwnd] := (chatVal == 0)
                            }
                        }
                    }
                }
            }

            statusText := (windowCombatStates.Has(hwnd) && windowCombatStates[hwnd]) ? "COMBAT" : "Safe"
            if (className == Window2Class)
                newWindow1Status := "Main Window: " . statusText
            else if (className == Window1Class)
                newWindow2Status := "Sandbox Window: " . statusText
        } catch {
            continue
        }
    }

    newCombatStatus := anyInCombat ? "Combat: ACTIVE (Memory)" : "Combat: Inactive (Memory)"
    if (newCombatStatus != lastCombatStatus) {
        CombatStatusText.Text := newCombatStatus
        CombatStatusText.SetFont(anyInCombat ? "cRed" : "cGreen")
        lastCombatStatus := newCombatStatus
    }
    if (newWindow1Status != "" && newWindow1Status != lastWindow1Status) {
        Window1CombatText.Text := newWindow1Status
        Window1CombatText.SetFont(InStr(newWindow1Status, "COMBAT") ? "cRed" : "cGreen")
        lastWindow1Status := newWindow1Status
    }
    if (newWindow2Status != "" && newWindow2Status != lastWindow2Status) {
        Window2CombatText.Text := newWindow2Status
        Window2CombatText.SetFont(InStr(newWindow2Status, "COMBAT") ? "cRed" : "cGreen")
        lastWindow2Status := newWindow2Status
    }

    return anyInCombat
}

CleanupWindow(hwnd) {
    global windowProcessHandles, windowCombatStates, windowChatModes, moduleBaseAddresses
    if (windowProcessHandles.Has(hwnd)) {
        try DllCall("CloseHandle", "Ptr", windowProcessHandles[hwnd])
        windowProcessHandles.Delete(hwnd)
    }
    if (windowCombatStates.Has(hwnd)) windowCombatStates.Delete(hwnd)
    if (windowChatModes.Has(hwnd)) windowChatModes.Delete(hwnd)
    if (moduleBaseAddresses.Has(hwnd)) moduleBaseAddresses.Delete(hwnd)
    UpdateWindowCount()
}

UpdateChatDisplay() {
    global windowChatModes, ChatStatusText, TargetExe, lastChatStatus
    try {
        if WinActive(TargetExe) {
            activeHwnd := WinGetID("A")
            isInChat := windowChatModes.Has(activeHwnd) && windowChatModes[activeHwnd]
            newChatStatus := "Chat: " . (isInChat ? "ACTIVE (This Window)" : "Inactive")
            if (newChatStatus != lastChatStatus) {
                ChatStatusText.Text := newChatStatus
                ChatStatusText.SetFont(isInChat ? "cRed" : "cBlack")
                lastChatStatus := newChatStatus
            }
        }
    } catch {
    }
}

SendTheKey() {
    global isLooping, windowCombatStates, windowChatModes, TargetExe, USE_MEMORY_READING
    if (!isLooping)
        return
    if WinActive(TargetExe) {
        activeHwnd := WinGetID("A")
        if (windowChatModes.Has(activeHwnd) && windowChatModes[activeHwnd])
            return
    }
    anyInCombat := false
    if (USE_MEMORY_READING) {
        for _, state in windowCombatStates {
            if (state) {
                anyInCombat := true
                break
            }
        }
    }
    if (!anyInCombat)
        return
    for hwnd in WinGetList(TargetExe) {
        try {
            if (USE_MEMORY_READING && (!windowCombatStates.Has(hwnd) || !windowCombatStates[hwnd]))
                continue
            if (windowChatModes.Has(hwnd) && windowChatModes[hwnd])
                continue
            ControlSend("{``}", , "ahk_id " . hwnd)
            Sleep(20)
        } catch {
            continue
        }
    }
}

UpdateWindowCount() {
    global lastWindowCount, WindowCountText, TargetExe, Window1Class, Window2Class
    count := 0
    for hwnd in WinGetList(TargetExe) {
        try {
            className := WinGetClass("ahk_id " . hwnd)
            if (className == Window1Class || className == Window2Class)
                count++
        } catch {
            continue
        }
    }
    if (count != lastWindowCount) {
        WindowCountText.Text := "Windows Found: " . count
        lastWindowCount := count
    }
}

SendToInactiveWindows(key) {
    global TargetExe, Window1Class, Window2Class, windowChatModes
    activeHwnd := WinGetID("A")
    for hwnd in WinGetList(TargetExe) {
        try {
            if (hwnd == activeHwnd)
                continue
            if (key == "q" && windowChatModes.Has(hwnd) && windowChatModes[hwnd])
                continue
            className := WinGetClass("ahk_id " . hwnd)
            if (className == Window1Class || className == Window2Class)
                ControlSend(key, , "ahk_id " . hwnd)
        } catch {
            continue
        }
    }
}

SendToOtherWindow(key) {
    global TargetExe, Window1Class, Window2Class
    activeHwnd := WinGetID("A")
    for hwnd in WinGetList(TargetExe) {
        try {
            if (hwnd == activeHwnd)
                continue
            className := WinGetClass("ahk_id " . hwnd)
            if (className == Window1Class || className == Window2Class) {
                ControlSend(key, , "ahk_id " . hwnd)
                return
            }
        } catch {
            continue
        }
    }
}

StartStopHandler(*) {
    global isLooping, StatusText
    isLooping := !isLooping
    if (isLooping) {
        if (USE_MEMORY_READING)
            InitializeWindowHandles()
        UpdateWindowCount()
        SetTimer(SendTheKey, 500)
        StatusText.Text := "Status: ON"
        StatusText.SetFont("cGreen")
        SoundBeep(800, 150)
    } else {
        SetTimer(SendTheKey, 0)
        StatusText.Text := "Status: OFF"
        StatusText.SetFont("cRed")
        SoundBeep(600, 150)
    }
}

ToggleChatState(hwnd) {
    global windowChatModes
    if (windowChatModes.Has(hwnd)) {
        windowChatModes[hwnd] := !windowChatModes[hwnd]
        UpdateChatDisplay()
    }
}

ClearCombatStates() {
    global windowCombatStates
    for hwnd in windowCombatStates
        windowCombatStates[hwnd] := false
}

; ================================
; Hotkeys
; ================================
PgUp::StartStopHandler()

#HotIf WinActive(TargetExe)

~*q:: {
    global lastQPressTime, doublePressDuration, qPressInverted, windowChatModes
    activeHwnd := WinGetID("A")
    if (windowChatModes.Has(activeHwnd) && windowChatModes[activeHwnd])
        return
    now := A_TickCount
    isDouble := (now - lastQPressTime <= doublePressDuration)
    lastQPressTime := isDouble ? 0 : now
    sendToOthers := (!qPressInverted && !isDouble) || (qPressInverted && isDouble)
    if (sendToOthers)
        SendToInactiveWindows("q")
    if (isDouble)
        SoundBeep(1000, 100)
}

~*Enter:: {
    global windowChatModes, USE_CHAT_DETECTION, TargetExe
    if (!WinActive(TargetExe))
        return
    if (!USE_CHAT_DETECTION) {
        activeHwnd := WinGetID("A")
        if (!windowChatModes.Has(activeHwnd))
            windowChatModes[activeHwnd] := false
        SetTimer(() => ToggleChatState(activeHwnd), 150)
    }
}

~*Esc:: {
    global windowChatModes, windowCombatStates, TargetExe, USE_MEMORY_READING, USE_CHAT_DETECTION
    if (!WinActive(TargetExe))
        return
    activeHwnd := WinGetID("A")
    if (!USE_CHAT_DETECTION) {
        if (windowChatModes.Has(activeHwnd) && windowChatModes[activeHwnd]) {
            windowChatModes[activeHwnd] := false
            UpdateChatDisplay()
        }
    }
    anyInCombat := false
    if (USE_MEMORY_READING) {
        for _, state in windowCombatStates {
            if (state) {
                anyInCombat := true
                break
            }
        }
    }
    if (anyInCombat) {
        Sleep(50)
        for hwnd in WinGetList(TargetExe) {
            try {
                if (hwnd == activeHwnd)
                    continue
                if (windowChatModes.Has(hwnd) && windowChatModes[hwnd])
                    continue
                ControlSend("q", , "ahk_id " . hwnd)
                Sleep(30)
            } catch {
                continue
            }
        }
        SetTimer(() => ClearCombatStates(), 200)
    }
}

~*Tab:: {
    global selectedFKey, followDirection, Window1Class, Window2Class, TargetExe, FOLLOW_ENABLED
    if (!FOLLOW_ENABLED)
        return
    static lastTab := 0
    if (A_TickCount - lastTab < 100)
        return
    lastTab := A_TickCount
    try {
        activeHwnd := WinGetID("A")
        if !activeHwnd
            return
        windows := WinGetList(TargetExe)
        other := 0
        for hwnd in windows {
            className := WinGetClass("ahk_id " . hwnd)
            if ((className == Window1Class || className == Window2Class) && hwnd != activeHwnd) {
                other := hwnd
                break
            }
        }
        if (other) {
            original := activeHwnd
            curClass := WinGetClass("ahk_id " . original)
            tgtClass := WinGetClass("ahk_id " . other)
            shouldSend := (followDirection == "Switching To Sandbox (Main follows Alt)" && tgtClass == Window1Class)
                        || (followDirection != "Switching To Sandbox (Main follows Alt)" && curClass == Window1Class)
            WinActivate("ahk_id " . other)
            if (shouldSend) {
                Sleep(50)
                ControlSend("{" . selectedFKey . "}", , "ahk_id " . original)
            }
            SoundBeep(700, 50)
        }
    } catch {
    }
}

; Right Alt + Key functionality
>!a::SendToOtherWindow("a")
>!b::SendToOtherWindow("b")
>!c::SendToOtherWindow("c")
>!d::SendToOtherWindow("d")
>!e::SendToOtherWindow("e")
>!f::SendToOtherWindow("f")
>!g::SendToOtherWindow("g")
>!h::SendToOtherWindow("h")
>!i::SendToOtherWindow("i")
>!j::SendToOtherWindow("j")
>!k::SendToOtherWindow("k")
>!l::SendToOtherWindow("l")
>!m::SendToOtherWindow("m")
>!n::SendToOtherWindow("n")
>!o::SendToOtherWindow("o")
>!p::SendToOtherWindow("p")
>!q::SendToOtherWindow("q")
>!r::SendToOtherWindow("r")
>!s::SendToOtherWindow("s")
>!t::SendToOtherWindow("t")
>!u::SendToOtherWindow("u")
>!v::SendToOtherWindow("v")
>!w::SendToOtherWindow("w")
>!x::SendToOtherWindow("x")
>!y::SendToOtherWindow("y")
>!z::SendToOtherWindow("z")
>!1::SendToOtherWindow("1")
>!2::SendToOtherWindow("2")
>!3::SendToOtherWindow("3")
>!4::SendToOtherWindow("4")
>!5::SendToOtherWindow("5")
>!6::SendToOtherWindow("6")
>!7::SendToOtherWindow("7")
>!8::SendToOtherWindow("8")
>!9::SendToOtherWindow("9")
>!0::SendToOtherWindow("0")
>!Space::SendToOtherWindow("{Space}")
>!Enter::SendToOtherWindow("{Enter}")
>!Escape::SendToOtherWindow("{Escape}")
>!Tab::SendToOtherWindow("{Tab}")
>!Backspace::SendToOtherWindow("{Backspace}")
>!Delete::SendToOtherWindow("{Delete}")
>!Up::SendToOtherWindow("{Up}")
>!Down::SendToOtherWindow("{Down}")
>!Left::SendToOtherWindow("{Left}")
>!Right::SendToOtherWindow("{Right}")
>!F1::SendToOtherWindow("{F1}")
>!F2::SendToOtherWindow("{F2}")
>!F3::SendToOtherWindow("{F3}")
>!F4::SendToOtherWindow("{F4}")
>!F5::SendToOtherWindow("{F5}")
>!F6::SendToOtherWindow("{F6}")
>!F7::SendToOtherWindow("{F7}")
>!F8::SendToOtherWindow("{F8}")
>!F9::SendToOtherWindow("{F9}")
>!F10::SendToOtherWindow("{F10}")
>!F11::SendToOtherWindow("{F11}")
>!F12::SendToOtherWindow("{F12}")

#HotIf
