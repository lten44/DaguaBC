[Setup]
AppId=DaGuaBasketballClip.DaguaBC
AppName=DaguaBC
AppVersion={#AppVersion}
AppPublisher=DaguaBC
AppPublisherURL=https://github.com/lten44/DaguaBC
DefaultDirName={localappdata}\Programs\DaguaBC
DefaultGroupName=DaguaBC
DisableDirPage=no
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\DaguaBC.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\apps\desktop\windows\runner\resources\app_icon.ico

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PackageSource}\*"; DestDir: "{app}"; Excludes: "__pycache__,*.pyc"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VCRuntime}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\DaguaBC"; Filename: "{app}\DaguaBC.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\DaguaBC"; Filename: "{app}\DaguaBC.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\DaguaBC.exe"; Description: "{cm:LaunchProgram,DaguaBC}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent unchecked
