[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
#if HasPublisherUrl
AppPublisherURL={#AppPublisherUrl}
AppSupportURL={#AppPublisherUrl}
AppUpdatesURL={#AppPublisherUrl}
#endif
AppComments={#AppDescription}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableWelcomePage=no

UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
Uninstallable=yes

OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes

SetupArchitecture={#SetupArchitecture}
PrivilegesRequired={#PrivilegesRequired}
#if AllowScopeChoice
PrivilegesRequiredOverridesAllowed=dialog
#endif

#if HasIcon
SetupIconFile={#AppIcon}
#endif

WizardStyle=modern light excludelightcontrols hidebevels
WizardImageFile=
WizardSmallImageFile=

CloseApplications=yes
RestartApplications=no
SetupLogging=yes

VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Installer di {#AppName}
VersionInfoProductName={#AppName}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoTextVersion={#AppVersion}

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

#if DesktopShortcut
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
#endif

[Icons]
#if StartMenuShortcut
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}\{#AppExeDir}"
#endif
#if DesktopShortcut
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}\{#AppExeDir}"; Tasks: desktopicon
#endif

#if LaunchAfterInstall
[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; WorkingDir: "{app}\{#AppExeDir}"; Flags: nowait postinstall skipifsilent
#endif

[Code]
const
  DiasproCanvas = $0033131E;
  DiasproCard = $00471C2B;
  DiasproPlum = $00673F7A;
  DiasproLavender = $00C6859D;
  DiasproSand = $009ED1E8;
  DiasproBlue = $00DCC4A5;
  DiasproWhite = $00FFFFFF;

var
  NextAccent: TPanel;
  WelcomeAccent: TPanel;

procedure StyleText;
begin
  WizardForm.WelcomeLabel1.Font.Color := DiasproSand;
  WizardForm.WelcomeLabel1.Font.Size := 18;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];

  WizardForm.WelcomeLabel2.Font.Color := DiasproWhite;
  WizardForm.WelcomeLabel2.Font.Size := 10;

  WizardForm.PageNameLabel.Font.Color := DiasproSand;
  WizardForm.PageNameLabel.Font.Style := [fsBold];
  WizardForm.PageDescriptionLabel.Font.Color := DiasproBlue;

  WizardForm.FinishedHeadingLabel.Font.Color := DiasproSand;
  WizardForm.FinishedHeadingLabel.Font.Style := [fsBold];
  WizardForm.FinishedLabel.Font.Color := DiasproWhite;

  { Explicit contrast for every built-in page on the purple surfaces. }
  WizardForm.SelectDirLabel.Font.Color := DiasproWhite;
  WizardForm.SelectDirBrowseLabel.Font.Color := DiasproWhite;
  WizardForm.DiskSpaceLabel.Font.Color := DiasproBlue;
  WizardForm.SelectStartMenuFolderLabel.Font.Color := DiasproWhite;
  WizardForm.SelectStartMenuFolderBrowseLabel.Font.Color := DiasproWhite;
  WizardForm.SelectComponentsLabel.Font.Color := DiasproWhite;
  WizardForm.ComponentsDiskSpaceLabel.Font.Color := DiasproBlue;
  WizardForm.SelectTasksLabel.Font.Color := DiasproWhite;
  WizardForm.ReadyLabel.Font.Color := DiasproWhite;
  WizardForm.PreparingLabel.Font.Color := DiasproWhite;
  WizardForm.StatusLabel.Font.Color := DiasproWhite;
  WizardForm.FilenameLabel.Font.Color := DiasproBlue;
  WizardForm.InfoBeforeClickLabel.Font.Color := DiasproWhite;
  WizardForm.InfoAfterClickLabel.Font.Color := DiasproWhite;
  WizardForm.LicenseLabel1.Font.Color := DiasproWhite;
  WizardForm.PasswordEditLabel.Font.Color := DiasproWhite;
  WizardForm.UserInfoNameLabel.Font.Color := DiasproWhite;
  WizardForm.UserInfoOrgLabel.Font.Color := DiasproWhite;
  WizardForm.UserInfoSerialLabel.Font.Color := DiasproWhite;
  WizardForm.BeveledLabel.Font.Color := DiasproBlue;

  WizardForm.NoIconsCheck.Font.Color := DiasproWhite;
  WizardForm.YesRadio.Font.Color := DiasproWhite;
  WizardForm.NoRadio.Font.Color := DiasproWhite;
  WizardForm.PreparingYesRadio.Font.Color := DiasproWhite;
  WizardForm.PreparingNoRadio.Font.Color := DiasproWhite;
  WizardForm.LicenseAcceptedRadio.Font.Color := DiasproWhite;
  WizardForm.LicenseNotAcceptedRadio.Font.Color := DiasproWhite;
end;

procedure StyleSurfaces;
begin
  WizardForm.Color := DiasproCanvas;


  WizardForm.WelcomePage.Color := DiasproCard;
  WizardForm.InnerPage.Color := DiasproCard;
  WizardForm.FinishedPage.Color := DiasproCard;
  WizardForm.MainPanel.Color := DiasproCanvas;

  { Lists and read-only text panes need both background and text set. }
  WizardForm.ReadyMemo.Color := DiasproCard;
  WizardForm.ReadyMemo.Font.Color := DiasproWhite;
  WizardForm.ComponentsList.Color := DiasproCard;
  WizardForm.ComponentsList.Font.Color := DiasproWhite;
  WizardForm.TasksList.Color := DiasproCard;
  WizardForm.TasksList.Font.Color := DiasproWhite;
  WizardForm.RunList.Color := DiasproCard;
  WizardForm.RunList.Font.Color := DiasproWhite;
  WizardForm.LicenseMemo.Color := DiasproCard;
  WizardForm.LicenseMemo.Font.Color := DiasproWhite;
  WizardForm.InfoBeforeMemo.Color := DiasproCard;
  WizardForm.InfoBeforeMemo.Font.Color := DiasproWhite;
  WizardForm.InfoAfterMemo.Color := DiasproCard;
  WizardForm.InfoAfterMemo.Font.Color := DiasproWhite;

  WelcomeAccent := TPanel.Create(WizardForm);
  WelcomeAccent.Parent := WizardForm.WelcomePage;
  WelcomeAccent.ParentBackground := False;
  WelcomeAccent.BevelOuter := bvNone;
  WelcomeAccent.Color := DiasproPlum;
  WelcomeAccent.SetBounds(
    0,
    0,
    ScaleX(7),
    WizardForm.WelcomePage.ClientHeight
  );
  WelcomeAccent.Anchors := [akLeft, akTop, akBottom];
  WelcomeAccent.BringToFront;
end;

procedure StyleWelcomeLayout;
begin
  WizardForm.WelcomeLabel1.SetBounds(
    ScaleX(38),
    ScaleY(42),
    WizardForm.WelcomePage.ClientWidth - ScaleX(76),
    ScaleY(46)
  );

  WizardForm.WelcomeLabel2.SetBounds(
    ScaleX(38),
    ScaleY(106),
    WizardForm.WelcomePage.ClientWidth - ScaleX(76),
    WizardForm.WelcomePage.ClientHeight - ScaleY(138)
  );

  WizardForm.WelcomeLabel1.BringToFront;
  WizardForm.WelcomeLabel2.BringToFront;
end;

procedure StylePrimaryAction;
begin
  WizardForm.NextButton.Font.Style := [fsBold];

  NextAccent := TPanel.Create(WizardForm);
  NextAccent.Parent := WizardForm;
  NextAccent.ParentBackground := False;
  NextAccent.BevelOuter := bvNone;
  NextAccent.Color := DiasproPlum;
  NextAccent.SetBounds(
    WizardForm.NextButton.Left - ScaleX(2),
    WizardForm.NextButton.Top - ScaleY(2),
    WizardForm.NextButton.Width + ScaleX(4),
    WizardForm.NextButton.Height + ScaleY(4)
  );
  NextAccent.Anchors := [akRight, akBottom];
  NextAccent.BringToFront;
  WizardForm.NextButton.BringToFront;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpWelcome then
    WizardForm.NextButton.Caption := 'Inizia  ›'
  else if CurPageID = wpFinished then
    WizardForm.NextButton.Caption := 'Fine'
  else if CurPageID = wpReady then
    WizardForm.NextButton.Caption := 'Installa'
  else
    WizardForm.NextButton.Caption := 'Continua  ›';
end;

procedure InitializeWizard;
begin
  WizardForm.Caption := '{#AppName} — setup';
  WizardForm.Color := DiasproCanvas;

  WizardForm.WelcomeLabel1.Caption := 'Installa {#AppName}';
  WizardForm.WelcomeLabel2.Caption :=
    'Configuriamo {#AppName} sul tuo PC.' + #13#10 + #13#10 +
    '{#AppDescription}' + #13#10 + #13#10 +
    'Diaspro · versione {#AppVersion}';

  StyleSurfaces;
  StyleText;
  StyleWelcomeLayout;
  StylePrimaryAction;
end;
