; Inno Setup script for Fumic - Magical Media Player 2.6.4.
; Build the Flutter release before compiling this installer:
; flutter build windows --release --build-name=2.6.4 --build-number=0

#define MyAppName "Fumic"
#define MyAppFullName "Fumic - Magical Media Player"
#define MyAppVersion "2.6.4"
#define MyAppPublisher "Saksham Sharma"
#define MyAppExeName "fumic.exe"

; MSIX packaging temporarily changes the release directory. Compile this
; installer before running msix:create, and reject incomplete runtime bundles.
#if !FileExists("..\..\build\windows\x64\runner\Release\msvcp140.dll") || !FileExists("..\..\build\windows\x64\runner\Release\vcruntime140.dll") || !FileExists("..\..\build\windows\x64\runner\Release\vcruntime140_1.dll")
  #error Required Visual C++ runtime DLLs are missing. Rebuild Windows before compiling this installer.
#endif

[Setup]
AppId={{9D778CF7-64C7-47B8-A31B-1220295C5251}
AppName={#MyAppFullName}
AppVerName={#MyAppFullName} {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/UnExplainableFish52/Fumic
AppSupportURL=https://github.com/UnExplainableFish52/Fumic/issues
AppUpdatesURL=https://github.com/UnExplainableFish52/Fumic/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=Fumic-Setup-2.6.4-windows-x64
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayName={#MyAppFullName}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
