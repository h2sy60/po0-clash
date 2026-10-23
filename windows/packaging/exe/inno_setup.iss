[Setup]
AppId={{67A8CFA2-EC79-4DD3-AB44-75CDD5C3B591}
AppVersion={#AppVersion}
AppName=po0-clash
AppPublisher=yuuuki-creation
AppPublisherURL=https://github.com/yuuuki-creation/po0-clash
AppSupportURL=https://github.com/yuuuki-creation/po0-clash/issues
AppUpdatesURL=https://github.com/yuuuki-creation/po0-clash/releases
DefaultDirName={autopf}\po0-clash
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma
SolidCompression=yes
SetupIconFile={#ProjectDir}\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed={#TargetArch}
ArchitecturesInstallIn64BitMode={#TargetArch}
#ifdef SignBuild
SignTool=po0
SignedUninstaller=yes
#endif

[Code]
procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['po0-clash.exe', 'Po0ClashCore.exe', 'Po0ClashHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure UnregisterHelperService;
var
  HelperPath: String;
  ResultCode: Integer;
begin
  HelperPath := ExpandConstant('{app}\\Po0ClashHelperService.exe');
  if FileExists(HelperPath) then
  begin
    Exec(HelperPath, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  UnregisterHelperService;
  KillProcesses;
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  UnregisterHelperService;
  KillProcesses;
  Result := True;
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chineseSimplified"; MessagesFile: "{#ProjectDir}\windows\packaging\exe\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\po0-clash"; Filename: "{app}\po0-clash.exe"
Name: "{autodesktop}\po0-clash"; Filename: "{app}\po0-clash.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\po0-clash.exe"; Description: "{cm:LaunchProgram,po0-clash}"; Flags: runascurrentuser nowait postinstall skipifsilent
