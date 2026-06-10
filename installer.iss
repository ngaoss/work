#define MyAppVersion "1.0.7"

[Setup]
AppName=DeepCode Work
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\DeepCodeWork
DefaultGroupName=DeepCode
OutputDir=dist\{#MyAppVersion}
OutputBaseFilename=DeepCodeWork_Setup
Compression=lzma
SolidCompression=yes
SetupIconFile=assets\app_icon.ico
DisableProgramGroupPage=yes
AppMutex=DeepCodeWorkMutex
CloseApplications=yes
RestartApplications=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DeepCode Work"; Filename: "{app}\DeepCodeWork.exe"
Name: "{autodesktop}\DeepCode Work"; Filename: "{app}\DeepCodeWork.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\DeepCodeWork.exe"; Description: "{cm:LaunchProgram,DeepCode Work}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    // Ép buộc tắt ứng dụng nếu đang chạy ngầm
    Exec('taskkill.exe', '/f /im DeepCodeWork.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
