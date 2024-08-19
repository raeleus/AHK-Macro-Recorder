#Requires AutoHotkey v2.0+
;#NoTrayIcon
#SingleInstance Off
Thread("NoTimers")
CoordMode("ToolTip")
SetTitleMatchMode(2)
DetectHiddenWindows(true)
;--------------------------
if (A_Args.Length < 1) {
  A_Args.Push("~Record1.ahk")
}

if (A_Args.Length < 2) {
  A_Args.Push("F1")
}

LogFile := A_Temp "\" A_Args[1]
UpdateSettings
Recording := false
Playing := false
ActionKey := A_Args[2]

Hotkey(ActionKey, KeyAction)
return

ShowTip(s := "", pos := "y35", color := "Red|00FFFF") {
  static bak := "", idx := 0, ShowTip := Gui(), RecordingControl
  if (bak = color "," pos "," s)
    return
  bak := color "," pos "," s
  SetTimer(ShowTip_ChangeColor, 0)
  ShowTip.Destroy()
  if (s = "")
    return

  ShowTip := Gui("+LastFound +AlwaysOnTop +ToolWindow -Caption +E0x08000020", "ShowTip")
  WinSetTransColor("FFFFF0 150")
  ShowTip.BackColor := "cFFFFF0"
  ShowTip.MarginX := 10
  ShowTip.MarginY := 5
  ShowTip.SetFont("q3 s20 bold cRed")
  RecordingControl := ShowTip.Add("Text", , s)
  ShowTip.Show("NA " . pos)
  SetTimer(ShowTip_ChangeColor, 1000)

  ShowTip_ChangeColor() {
    r := StrSplit(SubStr(bak, 1, InStr(bak, ",") - 1), "|")
    RecordingControl.SetFont("q3 c" r[idx := Mod(Round(idx), r.Length) + 1])
    return
  }
}

;============ Hotkey =============

KeyAction(HotkeyName) {
  if (Recording) {
    Stop
    return
  }

  KeyDown := A_TickCount
  loop {
    Duration := A_TickCount - KeyDown
    if (Duration < 400) {
      ShowTip
      if (!GetKeyState(ActionKey)) {
        ShowTip
        PlayKeyAction
        break
      }
    } else if (Duration < 1400) {
      ShowTip("RECORD")
      if (!GetKeyState(ActionKey)) {
        ShowTip
        RecordKeyAction
        break
      }
    } else {
      ShowTip("SHOW SOURCE")
      if (!GetKeyState(ActionKey)) {
        ShowTip
        EditKeyAction
        break
      }
    }
  }
}

RecordKeyAction() {
  if (Recording) {
    Stop()
    return
  }
  #SuspendExempt
  RecordScreen()
}

RecordScreen() {
  global LogArr := []
  global oldid := ""
  global Recording := false
  global RelativeX, RelativeY

  if (Recording || Playing)
    return
  UpdateSettings()
  LogArr := []
  oldid := ""
  Log()
  Recording := true
  SetHotkey(1)
  CoordMode("Mouse", "Screen")
  MouseGetPos(&RelativeX, &RelativeY)
  ShowTip("Recording")
  return
}

UpdateSettings() {
  global MouseMode, RecordSleep
  if (FileExist(LogFile)) {
    LogFileObject := FileOpen(LogFile, "r")

    Loop 3 {
      LogFileObject.ReadLine()
    }
    MouseMode := RegExReplace(LogFileObject.ReadLine(), ".*=")

    LogFileObject.ReadLine()
    RecordSleep := RegExReplace(LogFileObject.ReadLine(), ".*=")

    LogFileObject.Close()
  } else {
    MouseMode := "screen"
    RecordSleep := "false"
  }

  if (MouseMode != "screen" && MouseMode != "window" && MouseMode != "relative")
    MouseMode := "screen"

  if (RecordSleep != "true" && RecordSleep != "false")
    RecordSleep := "false"
}

Stop() {
  global LogArr, Recording, isPaused
  #SuspendExempt
  if (Recording) {
    if (LogArr.Length > 0) {
      UpdateSettings()

      s := ";Press " ActionKey " to play. Hold to record. Long hold to edit`n;#####SETTINGS#####`n;What is the preferred method of recording mouse coordinates (screen,window,relative)`n;MouseMode=" MouseMode "`n;Record sleep between input actions (true,false)`n;RecordSleep=" RecordSleep "`nLoop(1)`n{`n`nSetKeyDelay(30)`nSendMode(`"Event`")`nSetTitleMatchMode(2)"

      if (MouseMode == "window") {
        s .= "`n;CoordMode(`"Mouse`", `"Screen`")`nCoordMode(`"Mouse`", `"Window`")`n"
      } else {
        s .= "`nCoordMode(`"Mouse`", `"Screen`")`n;CoordMode(`"Mouse`", `"Window`")`n"
      }

      For k, v in LogArr
        s .= "`n" v "`n"
      s .= "`n`n}`n"
      s := RegExReplace(s, "\R", "`n")
      if (FileExist(LogFile))
        FileDelete(LogFile)
      FileAppend(s, LogFile, "UTF-16")
      s := ""
    }
    Recording := 0
    LogArr := ""
    SetHotkey(0)
  }

  ShowTip()
  Suspend(false)
  Pause(false)
  isPaused := false
  return
}

PlayKeyAction() {
  #SuspendExempt
  if (Recording || Playing)
    Stop()
  ahk := A_IsCompiled ? A_ScriptDir "\AutoHotkey.exe" : A_AhkPath
  if (!FileExist(ahk))
  {
    MsgBox("Can't Find " ahk " !", "Error", 4096)
    Exit()
  }
  Run(ahk " /restart `"" LogFile "`"")
  return
}

EditKeyAction() {
  #SuspendExempt
  Stop()
  Run("`"" EnvGet("LocalAppData") "\Programs\Microsoft VS Code\Code.exe`" `"" LogFile "`"")
  return
}

;============ Functions =============

SetHotkey(f := false) {
  f := f ? "On" : "Off"
  Loop 254
  {
    k := GetKeyName(vk := Format("vk{:X}", A_Index))
    if (!(k ~= "^(?i:|Control|Alt|Shift)$"))
      Hotkey("~*" vk, LogKey, f)
  }
  For i, k in StrSplit("NumpadEnter|Home|End|PgUp" . "|PgDn|Left|Right|Up|Down|Delete|Insert", "|")
  {
    sc := Format("sc{:03X}", GetKeySC(k))
    if (!(k ~= "^(?i:|Control|Alt|Shift)$"))
      Hotkey("~*" sc, LogKey, f)
  }

  if (f = "On") {
    SetTimer(LogWindow)
    LogWindow()
  } else
    SetTimer(LogWindow, 0)
}

LogKey(HotkeyName) {
  Critical()
  k := GetKeyName(vksc := SubStr(A_ThisHotkey, 3))
  k := StrReplace(k, "Control", "Ctrl"), r := SubStr(k, 2)
  if (r ~= "^(?i:Alt|Ctrl|Shift|Win)$")
    LogKey_Control(k)
  else if (k ~= "^(?i:LButton|RButton|MButton)$")
    LogKey_Mouse(k)
  else {
    if (k = "NumpadLeft" || k = "NumpadRight") && !GetKeyState(k, "P")
      return
    k := StrLen(k) > 1 ? "{" k "}" : k ~= "\w" ? k : "{" vksc "}"
    Log(k, 1)
  }
}

LogKey_Control(key) {
  global LogArr
  k := InStr(key, "Win") ? key : SubStr(key, 2)
  Log("{" k " Down}", 1)
  Critical("Off")
  ErrorLevel := !KeyWait(key)
  Critical()
  Log("{" k " Up}", 1)
}

LogKey_Mouse(key) {
  global LogArr, RelativeX, RelativeY
  k := SubStr(key, 1, 1)

  ;screen
  CoordMode("Mouse", "Screen")
  MouseGetPos(&X, &Y, &id)
  Log((MouseMode == "window" || MouseMode == "relative" ? ";" : "") "MouseClick(`"" k "`", " X ", " Y ",,, `"D`") `;screen")

  ;window
  CoordMode("Mouse", "Window")
  MouseGetPos(&WindowX, &WindowY, &id)
  Log((MouseMode != "window" ? ";" : "") "MouseClick(`"" k "`", " WindowX ", " WindowY ",,, `"D`") `;window")

  ;relative
  CoordMode("Mouse", "Screen")
  MouseGetPos(&tempRelativeX, &tempRelativeY, &id)
  Log((MouseMode != "relative" ? ";" : "") "MouseClick(`"" k "`", " (tempRelativeX - RelativeX) ", " (tempRelativeY - RelativeY) ",,, `"D`", `"R`") `;relative")
  RelativeX := tempRelativeX
  RelativeY := tempRelativeY

  ;get dif
  CoordMode("Mouse", "Screen")
  MouseGetPos(&X1, &Y1)
  t1 := A_TickCount
  Critical("Off")
  ErrorLevel := !KeyWait(key)
  Critical()
  t2 := A_TickCount
  if (t2 - t1 <= 200)
    X2 := X1, Y2 := Y1
  else
    MouseGetPos(&X2, &Y2)

  ;log screen
  i := LogArr.Length - 2, r := LogArr[i]
  if (InStr(r, ",,, `"D`")") && Abs(X2 - X1) + Abs(Y2 - Y1) < 5)
    LogArr[i] := SubStr(r, 1, -16) ") `;screen", Log()
  else
    Log((MouseMode == "window" || MouseMode == "relative" ? ";" : "") "MouseClick(`"" k "`", " (X + X2 - X1) ", " (Y + Y2 - Y1) ",,, `"U`") `;screen")

  ;log window
  i := LogArr.Length - 1, r := LogArr[i]
  if (InStr(r, ",,, `"D`")") && Abs(X2 - X1) + Abs(Y2 - Y1) < 5)
    LogArr[i] := SubStr(r, 1, -16) ") `;window", Log()
  else
    Log((MouseMode != "window" ? ";" : "") "MouseClick(`"" k "`", " (WindowX + X2 - X1) ", " (WindowY + Y2 - Y1) ",,, `"U`") `;window")

  ;log relative
  i := LogArr.Length, r := LogArr[i]
  if (InStr(r, ",,, `"D`", `"R`")") && Abs(X2 - X1) + Abs(Y2 - Y1) < 5)
    LogArr[i] := SubStr(r, 1, -23) ",,,, `"R`") `;relative", Log()
  else
    Log((MouseMode != "relative" ? ";" : "") "MouseClick(`"" k "`", " (X2 - X1) ", " (Y2 - Y1) ",,, `"U`", `"R`") `;relative")
}

LogWindow() {
  global oldid, LogArr, MouseMode
  static oldtitle
  id := WinExist("A")
  title := WinGetTitle()
  class := WinGetClass()
  if (title = "" && class = "")
    return
  if (id = oldid && title = oldtitle)
    return
  oldid := id, oldtitle := title
  title := SubStr(title, 1, 50)
  title .= class ? " ahk_class " class : ""
  title := RegExReplace(Trim(title), "[``%;]", "``$0")
  CommentString := ""
  if (MouseMode != "window")
    CommentString := ";"
  s := CommentString "tt := `"" title "`"`n" CommentString "WinWait(tt)" . "`n" CommentString "if (!WinActive(tt))`n" CommentString "  WinActivate(tt)"
  i := LogArr.Length
  r := i = 0 ? "" : LogArr[i]
  if (InStr(r, "tt = ") = 1)
    LogArr[i] := s, Log()
  else
    Log(s)
}

Log(str := "", Keyboard := false) {
  global LogArr, RecordSleep
  static LastTime := 0
  t := A_TickCount
  Delay := (LastTime ? t - LastTime : 0)
  LastTime := t
  if (str = "")
    return
  i := LogArr.Length
  r := i = 0 ? "" : LogArr[i]
  if (Keyboard && InStr(r, "Send") && Delay < 1000) {
    LogArr[i] := SubStr(r, 1, -1) . str "`""
    return
  }

  if (Delay > 200) 
    LogArr.Push((RecordSleep == "false" ? ";" : "") "Sleep(" (Delay // 2) ")")
  LogArr.Push(Keyboard ? "Send `"{Blind}" str "`"" : str)
}