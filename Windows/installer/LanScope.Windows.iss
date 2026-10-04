#define MyAppName "LanScope Windows"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Dezoff-max"
#define MyAppURL "https://github.com/Dezoff-max/lanscope-mac"
#define MyAppExeName "LanScope.Windows.exe"

[Setup]
AppId={{92B3BF95-6E59-46D4-BBB9-DDF1C1D7CA37}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={localappdata}\Programs\LanScope Windows
DefaultGroupName=LanScope Windows
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=LanScope-Windows-Setup-x64
SetupIconFile=..\LanScope.Windows\Resources\LanScope.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
LicenseFile=..\..\LICENSE
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=no
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\LanScope Windows"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall LanScope Windows"; Filename: "{uninstallexe}"
Name: "{autodesktop}\LanScope Windows"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,LanScope Windows}"; Flags: nowait postinstall skipifsilent
