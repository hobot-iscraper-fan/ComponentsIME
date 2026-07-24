#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

SendMode "Input"
SetWorkingDir A_ScriptDir

;=====================================================
; 設定參數
;=====================================================
global ProductName := "專利元件符號輸入工具"
global ProductVersion := "2.0.0"
global ComponentsFile := A_ScriptDir . "\components.txt"
global BackupDir := A_ScriptDir . "\backup"
global SendOutputEnabled := true
global currentWindow := 0
global previousWindow := 0
global hHook := 0
global winEventCallback := 0

global AdUrl := "https://drive.google.com/uc?export=download&id=18tzu2sKusE6e86F4P37mS37nnB1BL1zr"

global AdDefaultText := "Hobot擦窗機，最好的選擇"
global AdMaxChars := 120

global mainGui := ""
global candidatesList := ""
global adControl := ""

InitializeWindowHook()
BuildMainGui()
LoadComponentHotstringsAndList()

sleep 1800

; 啟動後立即下載一次廣告 HTML；之後每30分鐘更新一次。
UpdateAdContent()
SetTimer () => UpdateAdContent(), 1800000

return


;=====================================================
; 視窗切換偵測
;=====================================================
InitializeWindowHook() {
    global hHook, winEventCallback, ProductName

    winEventCallback := CallbackCreate(WinEventProc, "Fast", 7)
    hHook := DllCall("SetWinEventHook"
        , "UInt", 0x0003  ; EVENT_SYSTEM_FOREGROUND
        , "UInt", 0x0003
        , "Ptr", 0
        , "Ptr", winEventCallback
        , "UInt", 0
        , "UInt", 0
        , "UInt", 0
        , "Ptr")

    if (!hHook)
        MsgBox "無法啟用視窗切換偵測。列表仍可使用，但點選後可能無法自動回到上一個視窗。", ProductName, "Icon!"

    OnExit UnhookWindowEvent
}

WinEventProc(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
    global currentWindow, previousWindow

    previousWindow := currentWindow
    currentWindow := hwnd
}

UnhookWindowEvent(*) {
    global hHook, winEventCallback

    if (hHook)
        DllCall("UnhookWinEvent", "Ptr", hHook)
    if (winEventCallback)
        CallbackFree winEventCallback
}


;=====================================================
; GUI
;=====================================================
BuildMainGui() {
    global mainGui, candidatesList, adControl, ProductName, AdDefaultText

    mainGui := Gui("+Resize", ProductName)
    mainGui.SetFont("s12")

    fileMenu := Menu()
    fileMenu.Add "打開檔案", (*) => OpenComponent()
    fileMenu.Add "元符產生器", (*) => OpenPrefnum()
    fileMenu.Add "重載(&R)", (*) => Reload()

    funcMenu := Menu()
    funcMenu.Add "刷新列表", (*) => RefreshList(true)
    funcMenu.Add "編輯元件配對", (*) => EditComponent()
    funcMenu.Add "添加元件配對", (*) => AddComponent()
    funcMenu.Add "刪除元件配對", (*) => DeleteComponent()
    funcMenu.Add "輸出開關", (*) => ToggleOutput()
    funcMenu.Add "退出", (*) => ExitApp()

    helpMenu := Menu()
    helpMenu.Add "關於", (*) => ShowAbout()
    helpMenu.Add "贊助", (*) => Showad()

    mainMenu := MenuBar()
    mainMenu.Add "文件(&F)", fileMenu
    mainMenu.Add "刷新(&L)", (*) => RefreshList(true)
    mainMenu.Add "操作(&T)", funcMenu
    mainMenu.Add "幫助(&H)", helpMenu
    mainMenu.Add "贊助(&A)", (*) => Showad()
    mainGui.MenuBar := mainMenu

    mainGui.SetFont("s10 cBlue")
    adControl := mainGui.AddText("x10 y10 w280 r3", AdDefaultText)
    mainGui.SetFont("s12 cDefault")
    candidatesList := mainGui.AddListBox("x10 y90 w250 h600")
    candidatesList.OnEvent "Change", CandidatesChanged

    mainGui.OnEvent "Size", GuiSize
    mainGui.OnEvent "Close", (*) => ExitApp()

    guiWidth := 300
    guiHeight := 700
    xPos := A_ScreenWidth - guiWidth - 200
    yPos := 0
    mainGui.Show "x" xPos " y" yPos " w" guiWidth " h" guiHeight
}

GuiSize(guiObj, minMax, width, height) {
    global candidatesList, adControl

    if (minMax = -1)
        return

    newWidth := Max(width - 20, 120)
    adHeight := 100
    listHeight := Max(height - adHeight - 30, 80)
    candidatesList.Move 10, 10, newWidth, listHeight
    adControl.Move 10, height - adHeight + 5, newWidth, adHeight
}


;=====================================================
; 廣告背景更新功能
;=====================================================
UpdateAdContent() {
    global AdUrl, AdDefaultText, AdMaxChars

    adFile := A_ScriptDir . "\ComponentsIME-ad.html"
    try {
        if (FileExist(adFile))
            FileDelete adFile

        Download AdUrl, adFile
        adHtml := Trim(FileRead(adFile, "UTF-8"))
        adText := ExtractH1Text(adHtml)
        if (adText = "") {
            SetAdText(AdDefaultText . "`n(找不到 h1 廣告標題)")
            return
        }

        if (StrLen(adText) > AdMaxChars)
            adText := SubStr(adText, 1, AdMaxChars) . "..."

        SetAdText(adText)
    } catch {
        SetAdText(AdDefaultText . "`n(Hobot擦窗機)")
    }
}

ExtractH1Text(html) {
    h1List := []
    pos := 1

    while (pos := RegExMatch(html, "is)<h1\b[^>]*>(.*?)</h1>", &match, pos)) {
        title := DecodeHtmlEntities(StripHtml(match[1]))
        title := Trim(RegExReplace(title, "\s+", " "))
        if (title != "")
            h1List.Push(title)
            ;h1List.Push("`n")
        pos += StrLen(match[0])
    }

    return h1List.Length ? JoinLines(h1List) : ""
}

StripHtml(html) {
    return RegExReplace(html, "is)<[^>]+>", "")
}

DecodeHtmlEntities(text) {
    text := StrReplace(text, "&nbsp;", " ")
    text := StrReplace(text, "&amp;", "&")
    text := StrReplace(text, "&lt;", "<")
    text := StrReplace(text, "&gt;", ">")
    text := StrReplace(text, "&quot;", '"')
    text := StrReplace(text, "&#39;", "'")
    return text
}

JoinLines(items) {
    result := ""
    for item in items {
        if (result != "")
            result .= "`n"
        result .= item
    }
    return result
}

SetAdText(text) {
    global adControl

    try adControl.Value := text
    try adControl.Text := text
    try adControl.Redraw()
}


;=====================================================
; 主功能
;=====================================================
OpenPrefnum() {
    Run '"D:\WPy64Pure\winprefnum\Run_winprefnum.PurePy.bat"'
}

OpenComponent() {
    global ComponentsFile
    Run ComponentsFile
}

CandidatesChanged(ctrl, *) {
    selectedItem := ctrl.Text
    if (selectedItem = "")
        return

    if (!ParseComponentLine(selectedItem, &compNumber, &compName)) {
        MsgBox "無效的 Candidates 格式。", , "Icon!"
        return
    }

    SendToPreviousWindow(compName . compNumber)
}

SendToPreviousWindow(textToSend) {
    global previousWindow, SendOutputEnabled

    if (!previousWindow) {
        MsgBox "沒有前一個窗口可供激活。", "視窗", "T1"
        return
    }

    if (!WinExist("ahk_id " previousWindow)) {
        MsgBox "前一個窗口已不存在或無法激活。", "視窗", "T1"
        return
    }

    WinActivate "ahk_id " previousWindow
    Sleep 300

    if (SendOutputEnabled) {
        SendText textToSend
    } else {
        MsgBox "發送功能已被禁用。", "發送狀態", "T1"
    }
}

ToggleOutput() {
    global SendOutputEnabled

    SendOutputEnabled := !SendOutputEnabled
    if (SendOutputEnabled)
        MsgBox "發送功能已啟用。", "發送狀態"
    else
        MsgBox "發送功能已禁用。", "發送狀態"
}

ShowAbout() {
    global ProductName, ProductVersion

    MsgBox ProductName . "`n版本 " . ProductVersion
        . "`n`n輸入元件編號並按 / 鍵，可快速插入專利元件名稱與符號。"
        . "`n從主選單或按 Ctrl+N 添加新元件配對。", "關於"
}

Showad() {
    global ProductName
    adFile := A_ScriptDir . "\ComponentsIME-ad.html"
    if (FileExist(adFile))
        Run adFile
    else
        MsgBox "廣告檔案不存在：" . adFile, ProductName, "Icon!"
}

;=====================================================
; 元件管理
;=====================================================
AddComponent() {
    global ProductName, candidatesList

    inputResult := InputBox("請輸入「編號：元件名稱」`n例如：100：Hobot擦窗機", "新增元件配對", "w360 h170")
    if (inputResult.Result = "Cancel")
        return

    inputText := Trim(inputResult.Value)
    if (inputText = "") {
        MsgBox "請輸入元件配對。", ProductName, "Icon!"
        return
    }

    if (!ParseComponentLine(inputText, &compNumber, &compName)) {
        MsgBox "無效的元件配對格式。`n請使用：編號：元件名稱", ProductName, "Icon!"
        return
    }

    if (ComponentExists(compNumber)) {
        MsgBox "此編號已存在：" . compNumber . "`n請先編輯或刪除原項目。", ProductName, "Icon!"
        return
    }

    if (!AppendComponent(compNumber, compName)) {
        MsgBox "無法寫入元件資料檔。`n請確認檔案未被其他程式鎖定。", ProductName, "Iconx"
        return
    }

    RegisterComponentHotstring(compNumber, compName)
    RefreshList(false)
}

DeleteComponent() {
    global ProductName, candidatesList

    selectedItem := candidatesList.Text
    if (selectedItem = "") {
        MsgBox "請選擇要刪除的元件配對。", ProductName, "Icon!"
        return
    }

    if (!ParseComponentLine(selectedItem, &compNumber, &compName)) {
        MsgBox "無效的 Candidates 格式。", ProductName, "Icon!"
        return
    }

    result := MsgBox("確定要刪除元件配對？`n`n" . compNumber . " ： " . compName, "確認刪除", "YesNo Icon?")
    if (result = "No")
        return

    if (!SaveComponentChange("delete", compNumber, compName)) {
        MsgBox "刪除失敗。已保留原始資料檔。", ProductName, "Iconx"
        return
    }

    RefreshList(false)
    MsgBox "已刪除元件配對。`n程式將重新載入以同步熱字串。", ProductName, "T1"
    SetTimer (*) => Reload(), -500
}

EditComponent() {
    global ProductName, candidatesList

    selectedItem := candidatesList.Text
    if (selectedItem = "") {
        MsgBox "請選擇要編輯的元件配對。", ProductName, "Icon!"
        return
    }

    if (!ParseComponentLine(selectedItem, &compNumber, &compName)) {
        MsgBox "無效的 Candidates 格式。", ProductName, "Icon!"
        return
    }

    inputResult := InputBox("修改元件名稱：", "修改元件配對", "w300 h150", compName)
    if (inputResult.Result = "Cancel")
        return

    newComponent := Trim(inputResult.Value)
    if (newComponent = "") {
        MsgBox "元件名稱不可空白。", ProductName, "Icon!"
        return
    }

    if (!SaveComponentChange("edit", compNumber, compName, compNumber, newComponent)) {
        MsgBox "編輯失敗。已保留原始資料檔。", ProductName, "Iconx"
        return
    }

    RefreshList(false)
    MsgBox "已更新元件配對。`n程式將重新載入以同步熱字串。", ProductName, "T1"
    SetTimer (*) => Reload(), -500
}

RefreshList(showMessage := false) {
    global ProductName, candidatesList

    candidatesList.Delete()
    if (!ReadComponents(&fileContent)) {
        MsgBox "無法讀取元件資料檔。", ProductName, "Iconx"
        return
    }

    items := []
    Loop Parse, fileContent, "`n", "`r" {
        if (ParseComponentLine(A_LoopField, &compNumber, &compName))
            items.Push(FormatComponentLine(compNumber, compName))
    }

    if (items.Length)
        candidatesList.Add items

    if (showMessage)
        MsgBox "列表已刷新。", ProductName, "T1"
}

LoadComponentHotstringsAndList() {
    global ProductName

    if (!ReadComponents(&fileContent)) {
        MsgBox "無法讀取元件資料檔。", ProductName, "Iconx"
        fileContent := ""
    }

    items := []
    Loop Parse, fileContent, "`n", "`r" {
        if (!ParseComponentLine(A_LoopField, &compNumber, &compName))
            continue

        RegisterComponentHotstring(compNumber, compName)
        items.Push(FormatComponentLine(compNumber, compName))
    }

    if (items.Length)
        candidatesList.Add items
}

RegisterComponentHotstring(number, component) {
    try Hotstring(":*:" . number . "/", component . number)
}


;=====================================================
; 快捷鍵
;=====================================================
^n::AddComponent()
^q::ExitApp()

<+Up:: {
    global ProductName

    clipboardOld := A_Clipboard
    A_Clipboard := ""
    Send "^c"
    if (!ClipWait(1))
        return

    clipContent := A_Clipboard
    A_Clipboard := clipboardOld

    if RegExMatch(clipContent, "([^\d]+)([0-9a-zA-Z]+)", &match) {
        compName := Trim(match[1])
        compNumber := Trim(match[2])

        if (ComponentExists(compNumber)) {
            MsgBox "此編號已存在：" . compNumber, ProductName, "Icon!"
            return
        }

        if (!AppendComponent(compNumber, compName)) {
            MsgBox "無法寫入元件資料檔。`n請確認檔案未被其他程式鎖定。", ProductName, "Iconx"
            return
        }

        RegisterComponentHotstring(compNumber, compName)
        RefreshList(false)
    } else {
        MsgBox "未找到匹配的內容。", ProductName, "Icon!"
    }
}


;=====================================================
; 元件資料檔工具
;=====================================================
ParseComponentLine(line, &compNumber, &compName) {
    line := Trim(line)
    if (line = "")
        return false

    if RegExMatch(line, "^\s*([^:：]+)\s*[:：]\s*(.+?)\s*$", &match) {
        compNumber := Trim(match[1])
        compName := Trim(match[2])
        return (compNumber != "" && compName != "")
    }
    return false
}

FormatComponentLine(compNumber, compName) {
    return Trim(compNumber) . "：" . Trim(compName)
}

ReadComponents(&content) {
    global ComponentsFile

    if (!FileExist(ComponentsFile)) {
        content := ""
        return true
    }

    try {
        content := FileRead(ComponentsFile, "UTF-8")
        return true
    } catch {
        content := ""
        return false
    }
}

EnsureBackupDir() {
    global BackupDir

    if (!DirExist(BackupDir))
        DirCreate BackupDir
    return DirExist(BackupDir)
}

BackupComponentsFile() {
    global ComponentsFile, BackupDir

    if (!FileExist(ComponentsFile))
        return true
    if (!EnsureBackupDir())
        return false

    stamp := FormatTime(, "yyyyMMdd-HHmmss")
    backupPath := BackupDir . "\components-" . stamp . ".txt"
    try {
        FileCopy ComponentsFile, backupPath, true
        return true
    } catch {
        return false
    }
}

WriteComponentsSafely(newContent) {
    global ComponentsFile

    if (!BackupComponentsFile())
        return false

    tempPath := ComponentsFile . ".tmp"
    try {
        if (FileExist(tempPath))
            FileDelete tempPath
        FileAppend newContent, tempPath, "UTF-8"
        FileMove tempPath, ComponentsFile, true
        return true
    } catch {
        try {
            if (FileExist(tempPath))
                FileDelete tempPath
        }
        return false
    }
}

ComponentExists(targetNumber) {
    if (!ReadComponents(&fileContent))
        return false

    Loop Parse, fileContent, "`n", "`r" {
        if (ParseComponentLine(A_LoopField, &compNumber, &compName) && compNumber = targetNumber)
            return true
    }
    return false
}

AppendComponent(compNumber, compName) {
    if (!ReadComponents(&fileContent))
        return false

    fileContent := RTrim(fileContent, "`r`n")
    if (fileContent != "")
        fileContent .= "`r`n"
    fileContent .= FormatComponentLine(compNumber, compName) . "`r`n"
    return WriteComponentsSafely(fileContent)
}

SaveComponentChange(action, targetNumber, targetComponent, newNumber := "", newComponent := "") {
    if (!ReadComponents(&fileContent))
        return false

    found := false
    newContent := ""
    Loop Parse, fileContent, "`n", "`r" {
        line := A_LoopField
        if (line = "")
            continue

        if (ParseComponentLine(line, &compNumber, &compName)) {
            if (compNumber = targetNumber && compName = targetComponent) {
                found := true
                if (action = "delete")
                    continue
                if (action = "edit")
                    line := FormatComponentLine(newNumber, newComponent)
            } else {
                line := FormatComponentLine(compNumber, compName)
            }
        }
        newContent .= line . "`r`n"
    }

    if (!found)
        return false
    return WriteComponentsSafely(newContent)
}
