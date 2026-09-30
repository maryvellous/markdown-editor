!include "LogicLib.nsh"

!macro NSIS_HOOK_POSTINSTALL
  ; Aggiunge “Nuovo → Documento Markdown” per l'utente corrente.
  ; Con l'associazione .md installata, Explorer crea il file e lo passa all'app.
  ClearErrors
  ReadRegStr $0 HKCU "Software\Classes\.md\ShellNew" "NullFile"
  ${If} ${Errors}
    WriteRegStr HKCU "Software\Classes\.md\ShellNew" "NullFile" ""
    WriteRegDWORD HKCU "Software\Diaspro\Markdown" "CreatedMdShellNew" 1
  ${EndIf}

  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  ReadRegDWord $0 HKCU "Software\Diaspro\Markdown" "CreatedMdShellNew"
  ${If} $0 == 1
    DeleteRegValue HKCU "Software\Classes\.md\ShellNew" "NullFile"
    DeleteRegKey /ifempty HKCU "Software\Classes\.md\ShellNew"
    DeleteRegKey /ifempty HKCU "Software\Diaspro\Markdown"
    DeleteRegKey /ifempty HKCU "Software\Diaspro"
  ${EndIf}

  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
!macroend
