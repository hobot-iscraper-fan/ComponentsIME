#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
#Persistent

SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;=====================================================
; 設定參數
;=====================================================
currentWindow := ""
previousWindow := ""
SendOutputEnabled := true


;=====================================================
; 使用WinEvent Hook來檢測窗口切換    
;=====================================================

; 設置WinEvent Hook
hHook := DllCall("SetWinEventHook"
    , "UInt", 0x0003  ; EVENT_SYSTEM_FOREGROUND
    , "UInt", 0x0003
    , "UInt", 0
    , "UInt", RegisterCallback("WinEventProc")
    , "UInt", 0
    , "UInt", 0
    , "UInt", 0)

WinEventProc(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
    global currentWindow, previousWindow
    previousWindow := currentWindow
    currentWindow := hwnd
}

OnExit("Unhook")

Unhook() {
    global hHook
    DllCall("UnhookWinEvent", "UInt", hHook)
}


;=====================================================
; 創建視窗
;=====================================================

; 設置字體大小
Gui, Font, s12  ; 設置字體大小為12

; 創建主選單
Menu, FileMenu, Add, 打開檔案, OpenComponent
Menu, FileMenu, Add, 元符產生器, OpenPrefnum
Menu, FileMenu, Add, 重載(&R), rreload
Menu, MainMenu, Add, 文件(&F), :FileMenu

Menu, MainMenu, Add, 刷新(&L), RefreshList

Menu, FuncMenu, Add, 刷新列表, RefreshList
Menu, FuncMenu, Add, 編輯元件配對, EditComponent
Menu, FuncMenu, Add, 添加元件配對, AddComponent
Menu, FuncMenu, Add, 刪除元件配對, DeleteComponent
Menu, FuncMenu, Add, 輸出開關, TurnOffOutput
Menu, FuncMenu, Add, 退出, GuiClose
Menu, MainMenu, Add, 操作(&T), :FuncMenu

Menu, HelpMenu, Add, 關於, ShowAbout
Menu, MainMenu, Add, 幫助(&H), :HelpMenu
; 將主選單附加到 GUI
Gui, Menu, MainMenu

; GUI 設置
Gui, Add, ListBox, w250 h1000 vCandidates gCandidatesChanged

Gui, +Resize  ; 使視窗可調整大小

; 將窗口顯示在右側
GuiWidth := 300  ; 設置視窗的寬度
GuiHeight := 700  ; 設置視窗的高度
xPos := A_ScreenWidth - GuiWidth - 200 ; 計算視窗的x位置
yPos := 0  ; 設置視窗的y位置

Gui, Show, x%xPos% y%yPos%  ; 使視窗可調整大小並靠在桌面的最右側

; 讀取文件並設置熱字串
FileRead, FileContent, components.txt

Loop, Parse, FileContent, `n, `r
{
    if (A_LoopField = "")
        continue

    ; 使用正則表達式分割, 藉以支援(:|：)
    parts := RegExMatch(A_LoopField, "^(.*?)(:|：)(.*)$", match)
    if (!match)
        continue
    number := Trim(match1)
    component := Trim(match3)

    ; 設置熱字串，添加檢查結束字符的邏輯
    Hotstring(":*:" . number . "/", "{Raw}" . component . number)
    ;Hotstring(":to:`" number, component . number)

    ; 添加到列表控件
    GuiControl, , Candidates, %number% ： %component%
}

; 顯示提示訊息
;MsgBox, , 【熱字串】, % "輸入元件符號並按 / 鍵來插入對應的元件名稱。", 1
return

; 調整視窗大小事件
GuiSize:
    if (ErrorLevel = 1)
        return
    NewWidth := A_GuiWidth - 20
    NewHeight := A_GuiHeight - 20
    GuiControl, Move, Candidates, x10 y10 w%NewWidth% h%NewHeight%
return


;=====================================================
; 設計視窗功能
;=====================================================

OpenPrefnum:

    ; Run the batch file
	Run, "D:\WPy64Pure\winprefnum\Run_winprefnum.PurePy.bat"
	
Return


OpenComponent:
    Run, components.txt  ; 
return


; 重新加載腳本 
rreload:
    Reload  ; Ctrl+Alt+Shift+R 重新加載腳本
return


; 列表控件選擇變更事件
CandidatesChanged:
    Gui, Submit, NoHide
    if (Candidates != "") {
        selectedItem := Candidates

        ; 使用 " - " 拆分字符串
        parts := StrSplit(Candidates, "：")
        
        ; 确保 parts 数组有两个元素
        if (parts.MaxIndex() < 2) {
            MsgBox, , , 無效的 Candidates 格式
            return
        }

        stringparts := Trim(parts[2]) .  Trim(parts[1])

        ; Clipboard := ""  ; 清空剪貼簿
        ; Sleep, 50  ; 等待50毫秒
        ; Clipboard := stringparts  ; 將內容設置到剪貼簿
        ; ClipWait, 0.5  ; 等待剪貼簿內容更新

        Gosub, GotoPreviousActiveWindow

    }
return


GotoPreviousActiveWindow:
    if (previousWindow)
    {
        if WinExist("ahk_id " previousWindow)
        {
            WinActivate, ahk_id %previousWindow% ; 激活前一個窗口
            Sleep, 300  ; 增加延遲來確保窗口切換完成
            if (SendOutputEnabled)  ; 檢查是否允許發送
            {
                SendInput, {Raw}%stringparts%       ; 發送內容
            }
            else
            {
                MsgBox, , 【發送狀態】, 發送功能已被禁用。, 1
            }
        }
        else
        {
            MsgBox, , 【視窗】, 前一個窗口已不存在或無法激活。, 1
        }
    }
    else
    {
        MsgBox, , 【視窗】, % "沒有前一個窗口可供激活。", 1
    }
return

; 定義TurnOffOutput功能
TurnOffOutput:
    SendOutputEnabled := !SendOutputEnabled  ; 切換狀態
    if (SendOutputEnabled)
    {
        ;Menu, MainMenu, Modify, 關閉輸出, 開啟輸出
        MsgBox, , 【發送狀態】, 發送功能已啟用。
    }
    else
    {
        ;Menu, MainMenu, Modify, 開啟輸出, 關閉輸出
        MsgBox, , 【發送狀態】, 發送功能已禁用。
    }
return


;=====================================================
; 顯示關於信息
ShowAbout:
    MsgBox, 0, 關於, 中文輸入工具`n版本 1.0`n作者：Assistant `n`n輸入元件符號並按 / 鍵來插入對應的元件名稱。`n從主選單或按 Ctrl+N 添加新元件配對。
return


;=====================================================
;ComponentManagement.ahk
;=====================================================
; 全局變數
global Candidates

;=====================================================
; 添加新元件配對、刪除元件配對、以及編輯元件配對
;=====================================================

; 添加新元件配對
AddComponent:
    Gui, Submit, NoHide
    InputText := Input
    if (InputText = "") {
        MsgBox, , , 請輸入元件配對
        return
    }

    ; 使用 " - " 拆分字符串
    parts := StrSplit(InputText, "：")

    ; 确保 parts 数组有两个元素
    if (parts.MaxIndex() < 2) {
        MsgBox, , , 無效的元件配對格式
        return
    }

    number := Trim(parts.1)
    component := Trim(parts.2)

    ; 設置熱字串，添加檢查結束字符的邏輯
    Hotstring(":*:" . number . "/", "{Text}" . component . number)

    ; 添加到列表控件
    GuiControl, , Candidates, %number% ： %component%

    ; 更新文件
    FileAppend, %number%:%component%n, components.txt, UTF-8
    ; 刷新列表
    Gosub, RefreshListNoMsg

return

; 刪除元件配對
DeleteComponent:
    Gui, Submit, NoHide
    if (Candidates = "")
    {
        MsgBox, , , 請選擇要刪除的元件配對
        return
    }

    ; 解析選中的項目
    parts := StrSplit(Candidates, "：")
    if (parts.MaxIndex() < 2)
    {
        MsgBox, , , 無效的 Candidates 格式
        return
    }

    number := Trim(parts[1])
    component := Trim(parts[2])

    ; 刪除選中的項目
    FileRead, FileContent, components.txt
    FileDelete, components.txt
    Loop, Parse, FileContent, `n, `r
    {
        if InStr(A_LoopField, number "：" component){
            MsgBox, , , 確定要刪除元件配對: %number% ： %component%
            continue  ; 跳過要刪除的行
        }
        FileAppend, %A_LoopField%`n, components.txt, UTF-8
    }

    ; 刷新列表
    Gosub, RefreshListNoMsg
    MsgBox, , , 已刪除元件配對: %number% ： %component%
return

EditComponent:
    Gui, Submit, NoHide
    if (Candidates = "")
    {
        MsgBox, , , 請選擇要編輯的元件配對
        return
    }

    ; 解析選中的項目
    parts := StrSplit(Candidates, "：")
    if (parts.MaxIndex() < 2)
    {
        MsgBox, , , 無效的 Candidates 格式
        return
    }

    number := Trim(parts[1])
    component := Trim(parts[2])

    ; 讓用戶編輯元件配對
    InputBox, NewComponent, 修改元件配對, 修改元件名稱：, , 300, 150, , , %component%
    if ErrorLevel
        return  ; 用戶取消了操作

    ; 更新文件內容
    FileRead, FileContent, components.txt
    FileDelete, components.txt
    Loop, Parse, FileContent, `n, `r
    {
        if InStr(A_LoopField, number "：" component)
            FileAppend, %number%：%NewComponent%`n, components.txt, UTF-8
        else
            FileAppend, %A_LoopField%`n, components.txt, UTF-8
    }

    Gosub, RefreshListNoMsg
return

; 刷新列表
RefreshListNoMsg:
    GuiControl, , Candidates, |
    FileRead, FileContent, components.txt
    Loop, Parse, FileContent, `n, `r
    {
        if (A_LoopField = "")
            continue
        parts := RegExMatch(A_LoopField, "^(.*?)(:|：)(.*)$", match)
        if (match)
            GuiControl, , Candidates, %match1% ： %match3%
    }
return

; 刷新列表功能
RefreshList:
    Gosub, RefreshListNoMsg
    MsgBox, , , 列表已刷新, 1
return


; 快捷鍵：Ctrl+N 添加新元件配對
^n::
    Gosub, AddComponent
return





;======================================
;======================================
<+Up::  ;  hotkey
    ClipboardOld := Clipboard
    Clipboard := "" ; Must start off blank for detection to work.
    Send ^c
    ClipWait 1
    if ErrorLevel  ; ClipWait timed out.
	return
	
	
    ; Replace CRLF and/or LF with `n for use in a "send-raw" hotstring:
    ; The same is done for any other characters that might otherwise
    ; be a problem in raw mode:
    ClipContent := StrReplace(Clipboard, "``", "````")  ; Do this replacement first to avoid interfering with the others below.
    ClipContent := StrReplace(ClipContent, "`r`n", "``r")  ; Using `r works better than `n in MS Word, etc.
    ClipContent := StrReplace(ClipContent, "`n", "``r")
    ClipContent := StrReplace(ClipContent, "`t", "``t")
    ClipContent := StrReplace(ClipContent, "`;", "```;")
    Clipboard := ClipboardOld  ; Restore previous contents of clipboard.

    ;FoundPos := RegExMatch(ClipContent, "[0-9a-zA-Z]+", match)
    ;Hotstring(":to:`" match, ClipContent)
	; 使用正則表達式抓取漢字與數字
	FoundPos := RegExMatch(ClipContent, "([^\d]+)([0-9a-zA-Z]+)", match)

	if FoundPos {
		; match1 為「主盤」，match2 為「418」
		hotstr := match2 ": " match1
		Hotstring(":*:" . match2 . "/", "{Raw}" . match1 . match2)
        ;Hotstring(":*:" . number . "/", "{Raw}" . component . number)

		; 定義文件路徑為腳本所在目錄的 components.txt
		filePath := A_ScriptDir . "\components.txt"
		FileAppend, `n%hotstr%, %filePath%  ; Put a `n at the beginning in case file lacks a blank line at its end.
		
	} else {
		MsgBox, 未找到匹配的內容。
	}


    if ErrorLevel   ; i.e. it's not blank or zero.
    {   
		MsgBox, 0, 警告, 因寫入太頻繁而無法寫入，等一秒後會自動寫入。, 1
        ;Sleep, 1000  ; 1 second
        FileAppend, `n%hotstr%, %A_ScriptFullPath%  ; Put a `n at the beginning in case file lacks a blank line at its end.
        if ErrorLevel
        MsgBox, 0, 警告, 因寫入太頻繁而無法寫入。,
    }

return






;=====================================================
; 退出腳本
;=====================================================
^q::ExitApp  ; Ctrl+Q 退出腳本

GuiClose:
ExitApp


