; Script Inno Setup tao bo cai dat Astra Telos cho Windows.
#define AppName "Astra Telos"
#define AppVersion "1.0.0"
#define AppExe "astra_telos.exe"

[Setup]
AppId={{A1B2C3D4-ASTRA-TELOS-0001}}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={pf}\Astra Telos
DefaultGroupName=Astra Telos
OutputDir=Output
OutputBaseFilename=astra-telos-windows-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Astra Telos
SetupIconFile=app\windows\runner\resources\app_icon.ico

[Languages]
Name: "vietnamese"; MessagesFile: "compiler:Languages\Vietnamese.isl"

[Tasks]
Name: "desktopicon"; Description: "Tao bieu tuong ngoai man hinh"; Flags: unchecked

[Files]
Source: "app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Astra Telos"; Filename: "{app}\{#AppExe}"
Name: "{commondesktop}\Astra Telos"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Mo Astra Telos"; Flags: nowait postinstall skipifsilent
