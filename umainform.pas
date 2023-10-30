unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type
  TMainForm = class(TForm)
    CsvButton: TButton;
    OpenCsv: TOpenDialog;
    OpenWeaponsEquipIni: TOpenDialog;
    SaveWeaponsEquipIni: TSaveDialog;
    WeaponsEquipButton: TButton;
    ApplyButton: TButton;
    Log: TMemo;
    procedure ApplyButtonClick(Sender: TObject);
    procedure CsvButtonClick(Sender: TObject);
    procedure WeaponsEquipButtonClick(Sender: TObject);
  private

  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

function FindGunLineIndexByName(const Strings: TStrings; Name: String): Int64;
var
  LineIndex: Int64;
  Line: String;
  GunBlockIndex: Int64;
begin
  Name := Name.Trim.ToLower;
  Result := -1;
  GunBlockIndex := -1;
  for LineIndex := 0 to Strings.Count - 1 do
  begin
    Line := Strings.Strings[LineIndex].Trim;
    if Line = '[Gun]' then
      GunBlockIndex := LineIndex;
    if GunBlockIndex < 0 then
      Continue;
    if Line.StartsWith('ids_name')
      and (LineIndex + 2 < Strings.Count)
      and Strings.Strings[LineIndex + 1].StartsWith(';res str')
      and Strings.Strings[LineIndex + 2].ToLower.StartsWith('; ' + Name + ' (')
    then
      Exit(GunBlockIndex);
  end;
end;

function FindBlockLineIndexByNickname(const Strings: TStrings; Nickname: String): Int64;
var
  LineIndex: Int64;
  Line: String;
  BlockIndex: Int64;
begin
  Nickname := Nickname.ToLower;
  Result := -1;
  BlockIndex := -1;
  for LineIndex := 0 to Strings.Count - 1 do
  begin
    Line := Strings.Strings[LineIndex].Trim.ToLower;
    if Line.StartsWith('[') then
      BlockIndex := LineIndex;
    if BlockIndex < 0 then
      Continue;
    if Line.StartsWith('nickname') and Line.EndsWith(Nickname) then
      Exit(BlockIndex);
  end;
end;

function FindKeyLineIndexForBlock(const Strings: TStrings; const GunBlockLineIndex: Int64; Key: String): Int64;
var
  LineIndex: Int64;
  Line: String;
begin
  Key := Key.ToLower;
  Result := -1;
  for LineIndex := GunBlockLineIndex to Strings.Count - 1 do
  begin
    Line := Strings.Strings[LineIndex].Trim;
    if Line.StartsWith('[') then
      Exit(-1);
    if Line.ToLower.StartsWith(Key) then
      Exit(LineIndex);
  end;
end;

function TrimTrailingZeros(const str: String): String;
begin
  if str.Contains('.') then
    Result := str.TrimRight('0').TrimRight('.')
  else
    Result := str;
end;

procedure ProcessDefinitionLine(const Line: String; const Weapons: TStrings; const LineNumber: Int32);
var
  Parts: TStringArray;
  BlockIndex: Int64;
  KeyIndex: Int64;
  KeyValue: TStringArray;
  ProjectileBlockIndex: Int64;       
  ExplosionBlockIndex: Int64;
  MotorBlockIndex: Int64;
begin
  Parts := Line.Split(',');
  BlockIndex := FindGunLineIndexByName(Weapons, Parts[2]);
  if BlockIndex < 0 then
  begin
    KeyValue := Line.Split(',');
    MainForm.Log.Append('Could not find "' + KeyValue[2] + '" for ' + LineNumber.ToString);
    Exit;
  end;     

  // Projectile
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'projectile_archetype');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "projectile_archetype" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  ProjectileBlockIndex := FindBlockLineIndexByNickname(Weapons, KeyValue[1].Trim);
  if ProjectileBlockIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "' + KeyValue[1].Trim + '" for ' + LineNumber.ToString);
    Exit;
  end;

  // Motor
  MotorBlockIndex := -1;
  KeyIndex := FindKeyLineIndexForBlock(Weapons, ProjectileBlockIndex + 1, 'motor');
  if KeyIndex >= 0 then
  begin
    KeyValue := Weapons.Strings[KeyIndex].Split('=');
    MotorBlockIndex := FindBlockLineIndexByNickname(Weapons, KeyValue[1].Trim);
    if MotorBlockIndex < 0 then
    begin
      MainForm.Log.Append('Could not find "' + KeyValue[1].Trim + '" for ' + LineNumber.ToString);
      Exit;
    end;
  end;

  // Explosion
  ExplosionBlockIndex := -1;
  if MotorBlockIndex >= 0 then
  begin
    KeyIndex := FindKeyLineIndexForBlock(Weapons, ProjectileBlockIndex + 1, 'explosion_arch');
    if KeyIndex < 0 then
    begin
      MainForm.Log.Append('Could not find "explosion_arch" for ' + LineNumber.ToString);
      Exit;
    end;
    KeyValue := Weapons.Strings[KeyIndex].Split('=');
    ExplosionBlockIndex := FindBlockLineIndexByNickname(Weapons, KeyValue[1].Trim);
    if ExplosionBlockIndex < 0 then
    begin
      MainForm.Log.Append('Could not find "' + KeyValue[1].Trim + '" for ' + LineNumber.ToString);
      Exit;
    end;
  end;

  // Class
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'hp_gun_type');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "hp_gun_type" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  case Parts[3].ToLower of
    'light-', 'light', 'light+': KeyValue[1] := 'hp_gun_special_1';
    'medium-', 'medium', 'medium+': KeyValue[1] := 'hp_gun_special_2';
    'heavy-', 'heavy', 'heavy+': KeyValue[1] := 'hp_gun_special_3';
    'special', 'special+': KeyValue[1] := 'hp_torpedo_special_1';
    else
      MainForm.Log.Append('Could not find "' + Parts[3] + '" for ' + LineNumber.ToString);
      Exit;
  end;
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];

  // Mass
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'mass');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "mass" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  case Parts[3].ToLower of          
    'light-': KeyValue[1] := '1';
    'light': KeyValue[1] := '2';
    'light+': KeyValue[1] := '3';      
    'medium-':  KeyValue[1] := '3';
    'medium':  KeyValue[1] := '4';
    'medium+': KeyValue[1] := '5';     
    'heavy-': KeyValue[1] := '5';
    'heavy': KeyValue[1] := '6';
    'heavy+': KeyValue[1] := '7';
    'special': KeyValue[1] := '10';
    'special+': KeyValue[1] := '10';
    else
      MainForm.Log.Append('Could not find "' + Parts[3] + '" for ' + LineNumber.ToString);
      Exit;
  end;
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];

  // Power
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'power_usage');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "power_usage" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  KeyValue[1] := Parts[5];
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];

  // Lifetime
  KeyIndex := FindKeyLineIndexForBlock(Weapons, ProjectileBlockIndex + 1, 'lifetime');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "lifetime" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  KeyValue[1] := (StrToFloat(Parts[6]) / StrToFloat(Parts[7])).ToString(TFloatFormat.ffFixed, 0, 6);
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + TrimTrailingZeros(KeyValue[1]);

  // Speed
  if MotorBlockIndex < 0 then
  begin
    KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'muzzle_velocity');
    if KeyIndex < 0 then
    begin
      MainForm.Log.Append('Could not find "muzzle_velocity" for ' + LineNumber.ToString);
      Exit;
    end;
    KeyValue := Weapons.Strings[KeyIndex].Split('=');
    KeyValue[1] := specialize IfThen<String>(MotorBlockIndex >= 0, '30', Parts[7]);
    Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];
  end;

  // Hull Damage
  KeyIndex := FindKeyLineIndexForBlock(Weapons, specialize IfThen<Int64>(ExplosionBlockIndex >= 0, ExplosionBlockIndex, ProjectileBlockIndex) + 1, 'hull_damage');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "hull_damage" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  KeyValue[1] := Parts[8];
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];

  // Energy Damage
  KeyIndex := FindKeyLineIndexForBlock(Weapons, specialize IfThen<Int64>(ExplosionBlockIndex >= 0, ExplosionBlockIndex, ProjectileBlockIndex) + 1, 'energy_damage');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "energy_damage" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  KeyValue[1] := Parts[9];
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];

  // Dispersion Angle
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'dispersion_angle');
  if (KeyIndex < 0) and (Parts[15] <> '0') then
  begin
    MainForm.Log.Append('Could not find "dispersion_angle" for ' + LineNumber.ToString);
  end;
  if KeyIndex >= 0 then
  begin
    KeyValue := Weapons.Strings[KeyIndex].Split('=');
    KeyValue[1] := Parts[15];
    Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];
  end;

  // Refire Rate
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'refire_delay');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "refire_delay" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  KeyValue[1] := (1 / StrToFloat(Parts[18])).ToString(TFloatFormat.ffFixed, 0, 6);
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + TrimTrailingZeros(KeyValue[1]);

  // Toughness
  KeyIndex := FindKeyLineIndexForBlock(Weapons, BlockIndex + 1, 'toughness');
  if KeyIndex < 0 then
  begin
    MainForm.Log.Append('Could not find "toughness" for ' + LineNumber.ToString);
    Exit;
  end;
  KeyValue := Weapons.Strings[KeyIndex].Split('=');
  KeyValue[1] := (StrToFloat(Parts[20]) / 200).ToString(TFloatFormat.ffFixed, 0, 6);
  Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + TrimTrailingZeros(KeyValue[1]);

  // Damage Type
  KeyIndex := FindKeyLineIndexForBlock(Weapons, ProjectileBlockIndex + 1, 'weapon_type');
  if (KeyIndex < 0) and (Parts[21].ToLower <> 'missile') and (Parts[21].ToLower <> 'rocket') then
  begin
    MainForm.Log.Append('Could not find "weapon_type" for ' + LineNumber.ToString);
  end;
  if KeyIndex >= 0 then
  begin
    if MotorBlockIndex < 0 then
    begin
      KeyValue := Weapons.Strings[KeyIndex].Split('=');
      case Parts[21].ToLower of
        'laser': KeyValue[1] := 'W_Laser';
        'plasma': KeyValue[1] := 'W_Plasma';
        'tachyon': KeyValue[1] := 'W_Tachyon';
        'neutron': KeyValue[1] := 'W_Neutron';
        'particle': KeyValue[1] := 'W_Particle';
        'photon': KeyValue[1] := 'W_Photon';
        'pulse': KeyValue[1] := 'W_Pulse';
        'nomad': KeyValue[1] := 'W_Nomad';
        'none': KeyValue[1] := 'W_NoClass';
      else
        MainForm.Log.Append('Could not assign "weapon_type" "' + Parts[21] + '" for ' + LineNumber.ToString);
      end;
      Weapons.Strings[KeyIndex] := KeyValue[0] + '= ' + KeyValue[1];
    end
    else
    begin
      MainForm.Log.Append('Cannot apply a "weapon_type" for a missile ' + LineNumber.ToString);
    end;
  end;
end;

procedure ProcessFiles(const CsvFileName: String; const WeaponsIniFileName: String; const OutputWeaponsIniFile: TStrings);
var
  CsvFile: TStrings;       
  WeaponsFile: TStrings;
  Line: String;          
  SplitLine: TStringArray;
  LineNumber: Int32;
begin
  MainForm.Log.Clear;
  MainForm.Log.Append('Processing…');   
  MainForm.Log.Refresh;
  CsvFile := TStringList.Create;     
  WeaponsFile := TStringList.Create;
  try
    try
      CsvFile.LoadFromFile(CsvFileName);
      WeaponsFile.LoadFromFile(WeaponsIniFileName);
      for Line in CsvFile do
      begin
        SplitLine := Line.Split(',');
        if (Length(SplitLine) > 0) and TryStrToInt(SplitLine[0], LineNumber) then
          ProcessDefinitionLine(Line, WeaponsFile, LineNumber);
      end;
      OutputWeaponsIniFile.Assign(WeaponsFile);
    except                            
      MainForm.Log.Append('Error while processing!');
    end;
  finally
    CsvFile.Free;             
    WeaponsFile.Free;
  end;
end;

procedure TMainForm.CsvButtonClick(Sender: TObject);
begin                     
  OpenCsv.Execute;
  ApplyButton.Enabled := (OpenWeaponsEquipIni.FileName.Length > 0) and (OpenCsv.FileName.Length > 0);
end;

procedure TMainForm.WeaponsEquipButtonClick(Sender: TObject);
begin                   
  OpenWeaponsEquipIni.Execute;
  ApplyButton.Enabled := (OpenWeaponsEquipIni.FileName.Length > 0) and (OpenCsv.FileName.Length > 0);
end;

procedure TMainForm.ApplyButtonClick(Sender: TObject);
var
  OutputFile: TStrings;
begin
  OutputFile := TStringList.Create;
  ProcessFiles(OpenCsv.FileName, OpenWeaponsEquipIni.FileName, OutputFile);
  if SaveWeaponsEquipIni.Execute then
  begin
    OutputFile.SaveToFile(SaveWeaponsEquipIni.FileName);
    MainForm.Log.Append(SaveWeaponsEquipIni.FileName + ' saved!');
  end;
  OutputFile.Free;
end;

end.
