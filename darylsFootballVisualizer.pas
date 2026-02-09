unit darylsFootballVisualizer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs,
  cxControls, cxGraphics, cxLookAndFeelPainters, cxLookAndFeels,
  dxSkinsCore, cxContainer, cxEdit, dxNavBar, cxClasses,
  dxLayoutLookAndFeels, dxLayoutContainer, dxLayoutControl,
  dxSkinsForm, dxSkinsFluentDesignForm, dxCore, System.ImageList, Vcl.ImgList,
  cxImageList, dxNavBarCollns, dxNavBarBase, System.JSON, System.Generics.Collections,
  System.Generics.Defaults,
  cxImage, cxLabel, cxTextEdit, cxButtons, dxBevel, Vcl.ExtCtrls,
  dxGDIPlusClasses, dxLayoutControlAdapters, dxLayoutcxEditAdapters,
  cxGroupBox, cxMemo, cxListBox, dxScrollbarAnnotations, dxPanel, Vcl.StdCtrls;

type
  TTeamData = class
    ID: Integer;
    Name: string;
    Code: string;
    Country: string;
    Founded: Integer;
    IsNational: Boolean;
    LogoURL: string;
    Keywords: string;
    KeywordsSemantic: string;
    VenueName: string;
    VenueAddress: string;
    VenueCity: string;
    VenueCapacity: Integer;
    VenueSurface: string;
    VenueImageURL: string;
  end;

  TLeagueData = class
    ID: Integer;
    Name: string;
    LeagueType: string;
    LogoURL: string;
    Keywords: string;
    KeywordsSemantic: string;
    CountryName: string;
    CountryCode: string;
    CountryFlag: string;
  end;

  TCountryInfo = class
    Name: string;
    Code: string;
    FlagPath: string;
    ImageIndex: Integer;
    NationalTeam: TTeamData;
    PredominantColor: TColor;
  end;

  TForm1 = class(TdxFluentDesignForm)
    dxNavBar1: TdxNavBar;
    dxLayoutControl1Group_Root: TdxLayoutGroup;
    dxLayoutControl1: TdxLayoutControl;
    dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
    dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
    dxSkinController1: TdxSkinController;
    dxNavBar1Group1: TdxNavBarGroup;
    cxImageList1: TcxImageList;
    justamemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FMetadataPath: string;
    FCountries: TObjectList<TCountryInfo>;
    FAllTeams: TObjectList<TTeamData>;
    FAllLeagues: TObjectList<TLeagueData>;
    FCurrentCountry: TCountryInfo;
    
    // Layout groups
    FCountryInfoGroup: TdxLayoutGroup;
    FLeaguesGroup: TdxLayoutGroup;
    FTeamsGroup: TdxLayoutGroup;
    
    // Country info components
    FCountryBanner: TdxPanel;
    FCountryFlagImage: TcxImage;
    FCountryNameLabel: TcxLabel;
    FCountryFoundedLabel: TcxLabel;
    FKeywordsGroup: TcxGroupBox;
    FKeywordsMemo: TcxMemo;
    FSemanticKeywordsGroup: TcxGroupBox;
    FSemanticKeywordsMemo: TcxMemo;
    
    // Leagues components
    FLeagueSearchEdit: TcxTextEdit;
    FLeagueListBox: TcxListBox;
    FLeagueDetailPanel: TdxPanel;
    FLeagueLogoImage: TcxImage;
    FLeagueNameLabel: TcxLabel;
    FLeagueTypeLabel: TcxLabel;
    FLeagueKeywordsMemo: TcxMemo;
    
    // Teams components
    FTeamSearchEdit: TcxTextEdit;
    FTeamListBox: TcxListBox;
    FTeamDetailPanel: TdxPanel;
    FTeamBanner: TdxPanel;
    FTeamLogoImage: TcxImage;
    FTeamNameLabel: TcxLabel;
    FTeamFoundedLabel: TcxLabel;
    FTeamKeywordsGroup: TcxGroupBox;
    FTeamKeywordsMemo: TcxMemo;
    FTeamSemanticKeywordsGroup: TcxGroupBox;
    FTeamSemanticKeywordsMemo: TcxMemo;
    
    procedure LoadMetadata;
    procedure LoadTeamsFromFile(const AFileName: string);
    procedure LoadLeaguesFromFile(const AFileName: string);
    procedure LoadCountryFlags;
    procedure CreateNavBarCountries;
    procedure CreateCountryInfoLayout;
    procedure CreateLeaguesLayout;
    procedure CreateTeamsLayout;
    procedure DisplayCountryInfo(ACountry: TCountryInfo);
    procedure DisplayLeague(ALeague: TLeagueData);
    procedure DisplayTeam(ATeam: TTeamData);
    procedure OnNavBarItemClick(Sender: TObject);
    procedure OnLeagueListBoxClick(Sender: TObject);
    procedure OnTeamListBoxClick(Sender: TObject);
    procedure OnLeagueSearchChange(Sender: TObject);
    procedure OnTeamSearchChange(Sender: TObject);
    function ExtractPredominantColor(const AImagePath: string): TColor;
    function ResolveMetadataPath: string;
    function CountryCodeToFlagEmoji(const ACountryCode, ACountryName: string): string;
    function NormalizeCountryCode(const ACode, ACountryName: string): string;
    procedure PopulateLeaguesList;
    procedure PopulateTeamsList;
    procedure FilterLeagues(const ASearchText: string);
    procedure FilterTeams(const ASearchText: string);
    function GetAlphaBlendedColor(AColor: TColor; ATransparency: Byte): TColor;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  System.IOUtils, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, System.Types,
  System.Math, System.UITypes;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FMetadataPath := ResolveMetadataPath;
  FCountries := TObjectList<TCountryInfo>.Create(True);
  FAllTeams := TObjectList<TTeamData>.Create(True);
  FAllLeagues := TObjectList<TLeagueData>.Create(True);
  
  Caption := 'Football Visualizer';
  
  // Create UI layouts FIRST (before loading data)
  CreateCountryInfoLayout;
  CreateLeaguesLayout;
  CreateTeamsLayout;
  
  // Load all metadata
  LoadMetadata;
  LoadCountryFlags;
  
  // Create navigation bar with countries AFTER loading data
  CreateNavBarCountries;
  
  // Show message if no data loaded
  if FCountries.Count = 0 then
    ShowMessage('No countries found. Please check metadata folder and JSON files.');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FAllLeagues.Free;
  FAllTeams.Free;
  FCountries.Free;
end;

procedure TForm1.LoadMetadata;
var
  SearchRec: TSearchRec;
  FileName: string;
  TeamsCount, LeaguesCount: Integer;
begin
  TeamsCount := 0;
  LeaguesCount := 0;
  
  if not DirectoryExists(FMetadataPath) then
  begin
    ShowMessage('Metadata folder not found at: ' + FMetadataPath + #13#10 +
                'Please create this folder and add JSON files.');
    Exit;
  end;
  
  // Load all team files (club + national-team datasets)
  if FindFirst(FMetadataPath + '*.json', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        FileName := FMetadataPath + SearchRec.Name;
        if (Pos('clubes_', LowerCase(SearchRec.Name)) = 1) or
           (Pos('internationals', LowerCase(SearchRec.Name)) > 0) then
        begin
          LoadTeamsFromFile(FileName);
          Inc(TeamsCount);
        end;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
  
  // Load all league files
  if FindFirst(FMetadataPath + 'leagues_*.json', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      FileName := FMetadataPath + SearchRec.Name;
      LoadLeaguesFromFile(FileName);
      Inc(LeaguesCount);
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
  
  Caption := Format('Football Visualizer - Loaded %d teams, %d leagues from %d+%d files', 
    [FAllTeams.Count, FAllLeagues.Count, TeamsCount, LeaguesCount]);
end;

function TForm1.ResolveMetadataPath: string;
const
  FolderName = 'metadata';
var
  CandidateBase: string;
  I: Integer;
begin
  // Try exe folder and a few parent folders (IDE/debug builds normally run from Win32\Debug).
  CandidateBase := ExcludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  for I := 0 to 4 do
  begin
    Result := IncludeTrailingPathDelimiter(CandidateBase) + FolderName + '\';
    if DirectoryExists(Result) then
      Exit;

    CandidateBase := ExtractFileDir(CandidateBase);
  end;

  // Fallback: keep expected path near the executable (error message in LoadMetadata will explain it).
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + FolderName + '\';
end;

procedure TForm1.LoadTeamsFromFile(const AFileName: string);
var
  JSONString: string;
  JSONArray: TJSONArray;
  JSONObj, TeamObj, VenueObj: TJSONObject;
  TeamData: TTeamData;
  I: Integer;
  FileStream: TFileStream;
  StringStream: TStringStream;
begin
  try
    FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      StringStream := TStringStream.Create('', TEncoding.UTF8);
      try
        StringStream.CopyFrom(FileStream, FileStream.Size);
        JSONString := StringStream.DataString;
      finally
        StringStream.Free;
      end;
    finally
      FileStream.Free;
    end;
    
    JSONArray := TJSONObject.ParseJSONValue(JSONString) as TJSONArray;
    if JSONArray = nil then Exit;
    
    try
      for I := 0 to JSONArray.Count - 1 do
      begin
        JSONObj := JSONArray.Items[I] as TJSONObject;
        TeamObj := JSONObj.GetValue('team') as TJSONObject;
        if TeamObj = nil then Continue;
        
        TeamData := TTeamData.Create;
        
        TeamData.ID := TeamObj.GetValue<Integer>('id', 0);
        TeamData.Name := TeamObj.GetValue<string>('name', '');
        TeamData.Code := TeamObj.GetValue<string>('code', '');
        TeamData.Country := TeamObj.GetValue<string>('country', '');
        TeamData.Founded := TeamObj.GetValue<Integer>('founded', 0);
        TeamData.IsNational := TeamObj.GetValue<Boolean>('national', False);
        TeamData.LogoURL := TeamObj.GetValue<string>('logo', '');
        TeamData.Keywords := TeamObj.GetValue<string>('keywords', '');
        TeamData.KeywordsSemantic := TeamObj.GetValue<string>('keywords_semantic', '');
        
        VenueObj := JSONObj.GetValue('venue') as TJSONObject;
        if VenueObj <> nil then
        begin
          TeamData.VenueName := VenueObj.GetValue<string>('name', '');
          TeamData.VenueAddress := VenueObj.GetValue<string>('address', '');
          TeamData.VenueCity := VenueObj.GetValue<string>('city', '');
          TeamData.VenueCapacity := VenueObj.GetValue<Integer>('capacity', 0);
          TeamData.VenueSurface := VenueObj.GetValue<string>('surface', '');
          TeamData.VenueImageURL := VenueObj.GetValue<string>('image', '');
        end;
        
        FAllTeams.Add(TeamData);
      end;
    finally
      JSONArray.Free;
    end;
  except
    on E: Exception do
      ShowMessage('Error loading teams: ' + E.Message);
  end;
end;

procedure TForm1.LoadLeaguesFromFile(const AFileName: string);
var
  JSONString: string;
  JSONArray: TJSONArray;
  JSONObj, LeagueObj, CountryObj: TJSONObject;
  LeagueData: TLeagueData;
  I: Integer;
  FileStream: TFileStream;
  StringStream: TStringStream;
begin
  try
    FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      StringStream := TStringStream.Create('', TEncoding.UTF8);
      try
        StringStream.CopyFrom(FileStream, FileStream.Size);
        JSONString := StringStream.DataString;
      finally
        StringStream.Free;
      end;
    finally
      FileStream.Free;
    end;
    
    JSONArray := TJSONObject.ParseJSONValue(JSONString) as TJSONArray;
    if JSONArray = nil then Exit;
    
    try
      for I := 0 to JSONArray.Count - 1 do
      begin
        JSONObj := JSONArray.Items[I] as TJSONObject;
        LeagueObj := JSONObj.GetValue('league') as TJSONObject;
        if LeagueObj = nil then Continue;
        
        LeagueData := TLeagueData.Create;
        
        LeagueData.ID := LeagueObj.GetValue<Integer>('id', 0);
        LeagueData.Name := LeagueObj.GetValue<string>('name', '');
        LeagueData.LeagueType := LeagueObj.GetValue<string>('type', '');
        LeagueData.LogoURL := LeagueObj.GetValue<string>('logo', '');
        LeagueData.Keywords := LeagueObj.GetValue<string>('keywords', '');
        LeagueData.KeywordsSemantic := LeagueObj.GetValue<string>('keywords_semantic', '');
        
        CountryObj := JSONObj.GetValue('country') as TJSONObject;
        if CountryObj <> nil then
        begin
          LeagueData.CountryName := CountryObj.GetValue<string>('name', '');
          LeagueData.CountryCode := CountryObj.GetValue<string>('code', '');
          LeagueData.CountryFlag := CountryObj.GetValue<string>('flag', '');
        end;
        
        FAllLeagues.Add(LeagueData);
      end;
    finally
      JSONArray.Free;
    end;
  except
    on E: Exception do
      ShowMessage('Error loading leagues: ' + E.Message);
  end;
end;

function TForm1.NormalizeCountryCode(const ACode, ACountryName: string): string;
begin
  Result := UpperCase(ACode.Trim);

  if Length(Result) = 3 then
    Result := Copy(Result, 1, 2);

  if Length(Result) <> 2 then
  begin
    if SameText(ACountryName, 'Argentina') then Result := 'AR'
    else if SameText(ACountryName, 'Bolivia') then Result := 'BO'
    else if SameText(ACountryName, 'Brazil') then Result := 'BR'
    else if SameText(ACountryName, 'Chile') then Result := 'CL'
    else if SameText(ACountryName, 'Colombia') then Result := 'CO'
    else if SameText(ACountryName, 'Ecuador') then Result := 'EC'
    else if SameText(ACountryName, 'Mexico') then Result := 'MX'
    else if SameText(ACountryName, 'Paraguay') then Result := 'PY'
    else if SameText(ACountryName, 'Peru') then Result := 'PE'
    else if SameText(ACountryName, 'Uruguay') then Result := 'UY'
    else if SameText(ACountryName, 'Venezuela') then Result := 'VE'
    else
      Result := '';
  end;
end;

function TForm1.CountryCodeToFlagEmoji(const ACountryCode, ACountryName: string): string;
var
  Code: string;
begin
  Code := NormalizeCountryCode(ACountryCode, ACountryName);

  if Length(Code) = 2 then
    Result := WideChar($D83C) + WideChar($DDE6 + (Ord(Code[1]) - Ord('A'))) +
              WideChar($D83C) + WideChar($DDE6 + (Ord(Code[2]) - Ord('A')))
  else
    Result := '';
end;

procedure TForm1.LoadCountryFlags;
var
  Team: TTeamData;
  League: TLeagueData;
  Country: TCountryInfo;
  Countries: TDictionary<string, TCountryInfo>;
  CountryKey: string;
  FlagsLoaded: Integer;

  procedure TryLoadLocalFlag(ACountry: TCountryInfo);
  var
    FlagPath: string;
    Picture: TPicture;
    ImageIndex: Integer;
  begin
    FlagPath := FMetadataPath + 'crests\' + LowerCase(ACountry.Name) + '.png';

    if (not FileExists(FlagPath)) and (ACountry.Code <> '') then
      FlagPath := FMetadataPath + 'crests\' + LowerCase(ACountry.Code) + '.png';

    if FileExists(FlagPath) then
    begin
      ACountry.FlagPath := FlagPath;

      Picture := TPicture.Create;
      try
        Picture.LoadFromFile(FlagPath);
        ImageIndex := cxImageList1.Add(Picture.Graphic, nil);
        ACountry.ImageIndex := ImageIndex;
        ACountry.PredominantColor := ExtractPredominantColor(FlagPath);
      finally
        Picture.Free;
      end;
    end;
  end;
begin
  Countries := TDictionary<string, TCountryInfo>.Create;
  FlagsLoaded := 0;

  try
    // Create country entries from national teams
    for Team in FAllTeams do
    begin
      if Team.IsNational and (Team.Country <> '') then
      begin
        CountryKey := Team.Country.Trim;
        if not Countries.ContainsKey(CountryKey) then
        begin
          Country := TCountryInfo.Create;
          Country.Name := CountryKey;
          Country.Code := NormalizeCountryCode(Team.Code, Team.Country);
          Country.NationalTeam := Team;
          Country.FlagPath := '';
          Country.ImageIndex := -1;
          Country.PredominantColor := $006B3410; // Default green

          TryLoadLocalFlag(Country);

          Countries.Add(CountryKey, Country);
          FCountries.Add(Country);
        end;
      end;
    end;

    // Ensure countries from leagues json are also available in navbar
    for League in FAllLeagues do
    begin
      if League.CountryName <> '' then
      begin
        CountryKey := League.CountryName.Trim;
        if not Countries.ContainsKey(CountryKey) then
        begin
          Country := TCountryInfo.Create;
          Country.Name := CountryKey;
          Country.Code := NormalizeCountryCode(League.CountryCode, League.CountryName);
          Country.NationalTeam := nil;
          Country.FlagPath := '';
          Country.ImageIndex := -1;
          Country.PredominantColor := $006B3410; // Default green

          TryLoadLocalFlag(Country);

          Countries.Add(CountryKey, Country);
          FCountries.Add(Country);
        end
        else
        begin
          Country := Countries.Items[CountryKey];
          if (Country.Code = '') and (League.CountryCode <> '') then
            Country.Code := NormalizeCountryCode(League.CountryCode, League.CountryName);
        end;
      end;
    end;

    FCountries.Sort(TComparer<TCountryInfo>.Construct(
      function(const Left, Right: TCountryInfo): Integer
      begin
        Result := CompareText(Left.Name, Right.Name);
      end));

    for Country in FCountries do
    begin
      if (Country.ImageIndex >= 0) or (Country.Code <> '') then
        Inc(FlagsLoaded);
    end;

    Caption := Caption + Format(' - %d countries, %d flags loaded',
      [FCountries.Count, FlagsLoaded]);

  finally
    Countries.Free;
  end;
end;

procedure TForm1.CreateNavBarCountries;
var
  Country: TCountryInfo;
  NavItem: TdxNavBarItem;
  FlagEmoji: string;
begin
  // Add countries to navigation bar
  for Country in FCountries do
  begin
    NavItem := TdxNavBarItem.Create(Self);
    FlagEmoji := CountryCodeToFlagEmoji(Country.Code, Country.Name);
    if FlagEmoji <> '' then
      NavItem.Caption := FlagEmoji + ' ' + Country.Name
    else
      NavItem.Caption := Country.Name;

    NavItem.Hint := Country.Name;
    NavItem.SmallImageIndex := Country.ImageIndex;
    NavItem.Tag := Integer(Country);
    NavItem.OnClick := OnNavBarItemClick;

    dxNavBar1Group1.CreateLink(NavItem);
  end;
end;

procedure TForm1.CreateCountryInfoLayout;
var
  LayoutItem: TdxLayoutItem;
begin
  // Create main country info group
  FCountryInfoGroup := dxLayoutControl1Group_Root.CreateGroup;
  FCountryInfoGroup.Caption := 'Country Information';
  FCountryInfoGroup.LayoutDirection := ldVertical;
  FCountryInfoGroup.AlignHorz := ahClient;
  FCountryInfoGroup.AlignVert := avTop;
  FCountryInfoGroup.CaptionOptions.Visible := False;
  FCountryInfoGroup.Index := 0;
  
  // Banner panel
  FCountryBanner := TdxPanel.Create(Self);
  FCountryBanner.Height := 150;
  LayoutItem := FCountryInfoGroup.CreateItemForControl(FCountryBanner);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  // Flag image on banner
  FCountryFlagImage := TcxImage.Create(FCountryBanner);
  FCountryFlagImage.Parent := FCountryBanner;
  FCountryFlagImage.Left := 20;
  FCountryFlagImage.Top := 20;
  FCountryFlagImage.Width := 150;
  FCountryFlagImage.Height := 110;
  FCountryFlagImage.Properties.FitMode := ifmProportionalStretch;
  FCountryFlagImage.Properties.Center := True;
  
  // Country name on banner
  FCountryNameLabel := TcxLabel.Create(FCountryBanner);
  FCountryNameLabel.Parent := FCountryBanner;
  FCountryNameLabel.Left := 190;
  FCountryNameLabel.Top := 30;
  FCountryNameLabel.AutoSize := False;
  FCountryNameLabel.Width := 400;
  FCountryNameLabel.Height := 40;
  FCountryNameLabel.Style.Font.Size := 24;
  FCountryNameLabel.Style.Font.Style := [fsBold];
  FCountryNameLabel.Transparent := True;
  
  // Founded label
  FCountryFoundedLabel := TcxLabel.Create(FCountryBanner);
  FCountryFoundedLabel.Parent := FCountryBanner;
  FCountryFoundedLabel.Left := 190;
  FCountryFoundedLabel.Top := 80;
  FCountryFoundedLabel.AutoSize := False;
  FCountryFoundedLabel.Width := 400;
  FCountryFoundedLabel.Height := 30;
  FCountryFoundedLabel.Style.Font.Size := 11;
  FCountryFoundedLabel.Transparent := True;
  
  // Keywords group
  FKeywordsGroup := TcxGroupBox.Create(Self);
  FKeywordsGroup.Caption := 'Keywords';
  FKeywordsGroup.Height := 150;
  LayoutItem := FCountryInfoGroup.CreateItemForControl(FKeywordsGroup);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  FKeywordsMemo := TcxMemo.Create(FKeywordsGroup);
  FKeywordsMemo.Parent := FKeywordsGroup;
  FKeywordsMemo.Align := alClient;
  FKeywordsMemo.Properties.ReadOnly := True;
  FKeywordsMemo.Properties.ScrollBars := ssVertical;
  FKeywordsMemo.Style.BorderStyle := ebsNone;
  
  // Semantic Keywords group
  FSemanticKeywordsGroup := TcxGroupBox.Create(Self);
  FSemanticKeywordsGroup.Caption := 'Semantic Keywords';
  FSemanticKeywordsGroup.Height := 150;
  LayoutItem := FCountryInfoGroup.CreateItemForControl(FSemanticKeywordsGroup);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  FSemanticKeywordsMemo := TcxMemo.Create(FSemanticKeywordsGroup);
  FSemanticKeywordsMemo.Parent := FSemanticKeywordsGroup;
  FSemanticKeywordsMemo.Align := alClient;
  FSemanticKeywordsMemo.Properties.ReadOnly := True;
  FSemanticKeywordsMemo.Properties.ScrollBars := ssVertical;
  FSemanticKeywordsMemo.Style.BorderStyle := ebsNone;
  
  FCountryInfoGroup.Visible := False;
end;

procedure TForm1.CreateLeaguesLayout;
var
  LayoutItem: TdxLayoutItem;
  LeftGroup, RightGroup: TdxLayoutGroup;
begin
  // Main leagues group
  FLeaguesGroup := dxLayoutControl1Group_Root.CreateGroup;
  FLeaguesGroup.Caption := 'Leagues';
  FLeaguesGroup.LayoutDirection := ldHorizontal;
  FLeaguesGroup.AlignHorz := ahClient;
  FLeaguesGroup.AlignVert := avClient;
  FLeaguesGroup.Index := 1;
  
  // Left side - list
  LeftGroup := FLeaguesGroup.CreateGroup;
  LeftGroup.LayoutDirection := ldVertical;
  LeftGroup.AlignHorz := ahLeft;
  LeftGroup.Width := 300;
  LeftGroup.CaptionOptions.Visible := False;
  
  // Search box
  FLeagueSearchEdit := TcxTextEdit.Create(Self);
  FLeagueSearchEdit.Properties.OnChange := OnLeagueSearchChange;
  LayoutItem := LeftGroup.CreateItemForControl(FLeagueSearchEdit);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.CaptionOptions.Text := 'Search';
  
  // List box
  FLeagueListBox := TcxListBox.Create(Self);
  FLeagueListBox.OnClick := OnLeagueListBoxClick;
  LayoutItem := LeftGroup.CreateItemForControl(FLeagueListBox);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.AlignVert := avClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  // Right side - details
  RightGroup := FLeaguesGroup.CreateGroup;
  RightGroup.LayoutDirection := ldVertical;
  RightGroup.AlignHorz := ahClient;
  RightGroup.CaptionOptions.Visible := False;
  
  FLeagueDetailPanel := TdxPanel.Create(Self);
  LayoutItem := RightGroup.CreateItemForControl(FLeagueDetailPanel);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.AlignVert := avClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  // League logo
  FLeagueLogoImage := TcxImage.Create(FLeagueDetailPanel);
  FLeagueLogoImage.Parent := FLeagueDetailPanel;
  FLeagueLogoImage.Left := 20;
  FLeagueLogoImage.Top := 20;
  FLeagueLogoImage.Width := 100;
  FLeagueLogoImage.Height := 100;
  FLeagueLogoImage.Properties.FitMode := ifmProportionalStretch;
  
  // League name
  FLeagueNameLabel := TcxLabel.Create(FLeagueDetailPanel);
  FLeagueNameLabel.Parent := FLeagueDetailPanel;
  FLeagueNameLabel.Left := 140;
  FLeagueNameLabel.Top := 20;
  FLeagueNameLabel.AutoSize := False;
  FLeagueNameLabel.Width := 400;
  FLeagueNameLabel.Height := 30;
  FLeagueNameLabel.Style.Font.Size := 16;
  FLeagueNameLabel.Style.Font.Style := [fsBold];
  
  // League type
  FLeagueTypeLabel := TcxLabel.Create(FLeagueDetailPanel);
  FLeagueTypeLabel.Parent := FLeagueDetailPanel;
  FLeagueTypeLabel.Left := 140;
  FLeagueTypeLabel.Top := 55;
  FLeagueTypeLabel.AutoSize := False;
  FLeagueTypeLabel.Width := 400;
  FLeagueTypeLabel.Height := 20;
  
  // Keywords memo
  FLeagueKeywordsMemo := TcxMemo.Create(FLeagueDetailPanel);
  FLeagueKeywordsMemo.Parent := FLeagueDetailPanel;
  FLeagueKeywordsMemo.Left := 20;
  FLeagueKeywordsMemo.Top := 140;
  FLeagueKeywordsMemo.Width := 600;
  FLeagueKeywordsMemo.Height := 200;
  FLeagueKeywordsMemo.Properties.ReadOnly := True;
  FLeagueKeywordsMemo.Properties.ScrollBars := ssVertical;
  
  FLeaguesGroup.Visible := False;
end;

procedure TForm1.CreateTeamsLayout;
var
  LayoutItem: TdxLayoutItem;
  LeftGroup, RightGroup: TdxLayoutGroup;
begin
  // Main teams group
  FTeamsGroup := dxLayoutControl1Group_Root.CreateGroup;
  FTeamsGroup.Caption := 'Teams';
  FTeamsGroup.LayoutDirection := ldHorizontal;
  FTeamsGroup.AlignHorz := ahClient;
  FTeamsGroup.AlignVert := avClient;
  FTeamsGroup.Index := 2;
  
  // Left side - list
  LeftGroup := FTeamsGroup.CreateGroup;
  LeftGroup.LayoutDirection := ldVertical;
  LeftGroup.AlignHorz := ahLeft;
  LeftGroup.Width := 300;
  LeftGroup.CaptionOptions.Visible := False;
  
  // Search box
  FTeamSearchEdit := TcxTextEdit.Create(Self);
  FTeamSearchEdit.Properties.OnChange := OnTeamSearchChange;
  LayoutItem := LeftGroup.CreateItemForControl(FTeamSearchEdit);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.CaptionOptions.Text := 'Search';
  
  // List box
  FTeamListBox := TcxListBox.Create(Self);
  FTeamListBox.OnClick := OnTeamListBoxClick;
  LayoutItem := LeftGroup.CreateItemForControl(FTeamListBox);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.AlignVert := avClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  // Right side - details
  RightGroup := FTeamsGroup.CreateGroup;
  RightGroup.LayoutDirection := ldVertical;
  RightGroup.AlignHorz := ahClient;
  RightGroup.CaptionOptions.Visible := False;
  
  FTeamDetailPanel := TdxPanel.Create(Self);
  LayoutItem := RightGroup.CreateItemForControl(FTeamDetailPanel);
  LayoutItem.AlignHorz := ahClient;
  LayoutItem.AlignVert := avClient;
  LayoutItem.CaptionOptions.Visible := False;
  
  // Team banner
  FTeamBanner := TdxPanel.Create(FTeamDetailPanel);
  FTeamBanner.Parent := FTeamDetailPanel;
  FTeamBanner.Left := 0;
  FTeamBanner.Top := 0;
  FTeamBanner.Width := 700;
  FTeamBanner.Height := 150;
  
  // Team logo on banner
  FTeamLogoImage := TcxImage.Create(FTeamBanner);
  FTeamLogoImage.Parent := FTeamBanner;
  FTeamLogoImage.Left := 20;
  FTeamLogoImage.Top := 20;
  FTeamLogoImage.Width := 110;
  FTeamLogoImage.Height := 110;
  FTeamLogoImage.Properties.FitMode := ifmProportionalStretch;
  
  // Team name
  FTeamNameLabel := TcxLabel.Create(FTeamBanner);
  FTeamNameLabel.Parent := FTeamBanner;
  FTeamNameLabel.Left := 150;
  FTeamNameLabel.Top := 30;
  FTeamNameLabel.AutoSize := False;
  FTeamNameLabel.Width := 500;
  FTeamNameLabel.Height := 35;
  FTeamNameLabel.Style.Font.Size := 20;
  FTeamNameLabel.Style.Font.Style := [fsBold];
  FTeamNameLabel.Transparent := True;
  
  // Founded label
  FTeamFoundedLabel := TcxLabel.Create(FTeamBanner);
  FTeamFoundedLabel.Parent := FTeamBanner;
  FTeamFoundedLabel.Left := 150;
  FTeamFoundedLabel.Top := 75;
  FTeamFoundedLabel.AutoSize := False;
  FTeamFoundedLabel.Width := 500;
  FTeamFoundedLabel.Height := 25;
  FTeamFoundedLabel.Transparent := True;
  
  // Keywords group
  FTeamKeywordsGroup := TcxGroupBox.Create(FTeamDetailPanel);
  FTeamKeywordsGroup.Parent := FTeamDetailPanel;
  FTeamKeywordsGroup.Caption := 'Keywords';
  FTeamKeywordsGroup.Left := 0;
  FTeamKeywordsGroup.Top := 160;
  FTeamKeywordsGroup.Width := 700;
  FTeamKeywordsGroup.Height := 120;
  
  FTeamKeywordsMemo := TcxMemo.Create(FTeamKeywordsGroup);
  FTeamKeywordsMemo.Parent := FTeamKeywordsGroup;
  FTeamKeywordsMemo.Align := alClient;
  FTeamKeywordsMemo.Properties.ReadOnly := True;
  FTeamKeywordsMemo.Properties.ScrollBars := ssVertical;
  FTeamKeywordsMemo.Style.BorderStyle := ebsNone;
  
  // Semantic Keywords group
  FTeamSemanticKeywordsGroup := TcxGroupBox.Create(FTeamDetailPanel);
  FTeamSemanticKeywordsGroup.Parent := FTeamDetailPanel;
  FTeamSemanticKeywordsGroup.Caption := 'Semantic Keywords';
  FTeamSemanticKeywordsGroup.Left := 0;
  FTeamSemanticKeywordsGroup.Top := 290;
  FTeamSemanticKeywordsGroup.Width := 700;
  FTeamSemanticKeywordsGroup.Height := 120;
  
  FTeamSemanticKeywordsMemo := TcxMemo.Create(FTeamSemanticKeywordsGroup);
  FTeamSemanticKeywordsMemo.Parent := FTeamSemanticKeywordsGroup;
  FTeamSemanticKeywordsMemo.Align := alClient;
  FTeamSemanticKeywordsMemo.Properties.ReadOnly := True;
  FTeamSemanticKeywordsMemo.Properties.ScrollBars := ssVertical;
  FTeamSemanticKeywordsMemo.Style.BorderStyle := ebsNone;
  
  FTeamsGroup.Visible := False;
end;

procedure TForm1.OnNavBarItemClick(Sender: TObject);
var
  NavItem: TdxNavBarItem;
  Country: TCountryInfo;
begin
  if Sender is TdxNavBarItem then
  begin
    NavItem := TdxNavBarItem(Sender);
    if NavItem.Tag <> 0 then
    begin
      Country := TCountryInfo(NavItem.Tag);
      FCurrentCountry := Country;
      DisplayCountryInfo(Country);
      PopulateLeaguesList;
      PopulateTeamsList;
    end;
  end;
end;

procedure TForm1.DisplayCountryInfo(ACountry: TCountryInfo);
var
  TransparentColor: TColor;
begin
  FCountryInfoGroup.Visible := True;
  FLeaguesGroup.Visible := True;
  FTeamsGroup.Visible := True;
  
  // Set banner background with transparency
  TransparentColor := GetAlphaBlendedColor(ACountry.PredominantColor, 25);
  FCountryBanner.Color := TransparentColor;
  
  // Load flag
  if ACountry.FlagPath <> '' then
    FCountryFlagImage.Picture.LoadFromFile(ACountry.FlagPath);
  
  // Set country info
  FCountryNameLabel.Caption := ACountry.Name;
  if ACountry.NationalTeam <> nil then
  begin
    if ACountry.NationalTeam.Founded > 0 then
      FCountryFoundedLabel.Caption := 'National Team' + #13#10 + 
        'Foundation: ' + IntToStr(ACountry.NationalTeam.Founded)
    else
      FCountryFoundedLabel.Caption := 'National Team';
    
    // Keywords
    FKeywordsMemo.Text := ACountry.NationalTeam.Keywords;
    FSemanticKeywordsMemo.Text := ACountry.NationalTeam.KeywordsSemantic;
  end;
end;

procedure TForm1.DisplayLeague(ALeague: TLeagueData);
begin
  FLeagueNameLabel.Caption := ALeague.Name;
  FLeagueTypeLabel.Caption := 'Type: ' + ALeague.LeagueType;
  FLeagueKeywordsMemo.Lines.Clear;
  FLeagueKeywordsMemo.Lines.Add('Keywords:');
  FLeagueKeywordsMemo.Lines.Add(ALeague.Keywords);
  FLeagueKeywordsMemo.Lines.Add('');
  FLeagueKeywordsMemo.Lines.Add('Semantic Keywords:');
  FLeagueKeywordsMemo.Lines.Add(ALeague.KeywordsSemantic);
end;

procedure TForm1.DisplayTeam(ATeam: TTeamData);
var
  TransparentColor: TColor;
begin
  // For simplicity, using a default color
  TransparentColor := GetAlphaBlendedColor($006B3410, 25);
  FTeamBanner.Color := TransparentColor;
  
  FTeamNameLabel.Caption := ATeam.Name;
  if ATeam.Founded > 0 then
    FTeamFoundedLabel.Caption := 'Foundation: ' + IntToStr(ATeam.Founded)
  else
    FTeamFoundedLabel.Caption := '';
  
  FTeamKeywordsMemo.Text := ATeam.Keywords;
  FTeamSemanticKeywordsMemo.Text := ATeam.KeywordsSemantic;
end;

procedure TForm1.PopulateLeaguesList;
var
  League: TLeagueData;
begin
  FLeagueListBox.Clear;
  
  if FCurrentCountry = nil then Exit;
  
  for League in FAllLeagues do
  begin
    if League.CountryName = FCurrentCountry.Name then
      FLeagueListBox.Items.AddObject(League.Name + ' (' + League.LeagueType + ')', League);
  end;
end;

procedure TForm1.PopulateTeamsList;
var
  Team: TTeamData;
begin
  FTeamListBox.Clear;
  
  if FCurrentCountry = nil then Exit;
  
  for Team in FAllTeams do
  begin
    if (Team.Country = FCurrentCountry.Name) and (not Team.IsNational) then
      FTeamListBox.Items.AddObject(Team.Name, Team);
  end;
  
  FTeamListBox.Sorted := True;
end;

procedure TForm1.OnLeagueListBoxClick(Sender: TObject);
var
  League: TLeagueData;
begin
  if (FLeagueListBox.ItemIndex >= 0) and 
     (FLeagueListBox.Items.Objects[FLeagueListBox.ItemIndex] <> nil) then
  begin
    League := TLeagueData(FLeagueListBox.Items.Objects[FLeagueListBox.ItemIndex]);
    DisplayLeague(League);
  end;
end;

procedure TForm1.OnTeamListBoxClick(Sender: TObject);
var
  Team: TTeamData;
begin
  if (FTeamListBox.ItemIndex >= 0) and 
     (FTeamListBox.Items.Objects[FTeamListBox.ItemIndex] <> nil) then
  begin
    Team := TTeamData(FTeamListBox.Items.Objects[FTeamListBox.ItemIndex]);
    DisplayTeam(Team);
  end;
end;

procedure TForm1.OnLeagueSearchChange(Sender: TObject);
begin
  FilterLeagues(FLeagueSearchEdit.Text);
end;

procedure TForm1.OnTeamSearchChange(Sender: TObject);
begin
  FilterTeams(FTeamSearchEdit.Text);
end;

procedure TForm1.FilterLeagues(const ASearchText: string);
var
  League: TLeagueData;
  SearchUpper: string;
begin
  FLeagueListBox.Clear;
  
  if FCurrentCountry = nil then Exit;
  
  SearchUpper := UpperCase(ASearchText);
  
  for League in FAllLeagues do
  begin
    if League.CountryName = FCurrentCountry.Name then
    begin
      if (ASearchText = '') or 
         (Pos(SearchUpper, UpperCase(League.Name)) > 0) then
        FLeagueListBox.Items.AddObject(League.Name + ' (' + League.LeagueType + ')', League);
    end;
  end;
end;

procedure TForm1.FilterTeams(const ASearchText: string);
var
  Team: TTeamData;
  SearchUpper: string;
begin
  FTeamListBox.Clear;
  
  if FCurrentCountry = nil then Exit;
  
  SearchUpper := UpperCase(ASearchText);
  
  for Team in FAllTeams do
  begin
    if (Team.Country = FCurrentCountry.Name) and (not Team.IsNational) then
    begin
      if (ASearchText = '') or 
         (Pos(SearchUpper, UpperCase(Team.Name)) > 0) then
        FTeamListBox.Items.AddObject(Team.Name, Team);
    end;
  end;
  
  FTeamListBox.Sorted := True;
end;

function TForm1.ExtractPredominantColor(const AImagePath: string): TColor;
var
  Picture: TPicture;
  Bitmap: TBitmap;
  ColorCounts: TDictionary<TColor, Integer>;
  X, Y: Integer;
  PixelColor: TColor;
  MaxCount: Integer;
  PredominantColor: TColor;
  Count: Integer;
begin
  Result := $006B3410; // Default green
  
  if not FileExists(AImagePath) then Exit;
  
  Picture := TPicture.Create;
  Bitmap := TBitmap.Create;
  ColorCounts := TDictionary<TColor, Integer>.Create;
  try
    Picture.LoadFromFile(AImagePath);
    Bitmap.Assign(Picture.Graphic);
    Bitmap.PixelFormat := pf24bit;
    
    // Sample colors (every 4th pixel for performance)
    for Y := 0 to Bitmap.Height - 1 do
    begin
      if Y mod 4 <> 0 then Continue;
      for X := 0 to Bitmap.Width - 1 do
      begin
        if X mod 4 <> 0 then Continue;
        PixelColor := Bitmap.Canvas.Pixels[X, Y];
        
        if ColorCounts.ContainsKey(PixelColor) then
          ColorCounts[PixelColor] := ColorCounts[PixelColor] + 1
        else
          ColorCounts.Add(PixelColor, 1);
      end;
    end;
    
    // Find most common color
    MaxCount := 0;
    PredominantColor := Result;
    for PixelColor in ColorCounts.Keys do
    begin
      Count := ColorCounts[PixelColor];
      if Count > MaxCount then
      begin
        MaxCount := Count;
        PredominantColor := PixelColor;
      end;
    end;
    
    Result := PredominantColor;
  finally
    ColorCounts.Free;
    Bitmap.Free;
    Picture.Free;
  end;
end;

function TForm1.GetAlphaBlendedColor(AColor: TColor; ATransparency: Byte): TColor;
var
  R, G, B: Byte;
  BackR, BackG, BackB: Byte;
  Alpha: Single;
begin
  // Get RGB components
  R := GetRValue(AColor);
  G := GetGValue(AColor);
  B := GetBValue(AColor);
  
  // Background color (dark theme)
  BackR := 30;
  BackG := 30;
  BackB := 30;
  
  // Apply transparency (0-100)
  Alpha := 1.0 - (ATransparency / 100.0);
  
  R := Round(R * Alpha + BackR * (1 - Alpha));
  G := Round(G * Alpha + BackG * (1 - Alpha));
  B := Round(B * Alpha + BackB * (1 - Alpha));
  
  Result := RGB(R, G, B);
end;

end.
