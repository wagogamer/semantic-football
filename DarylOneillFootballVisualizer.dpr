program DarylOneillFootballVisualizer;

uses
  Vcl.Forms,
  darylsFootballVisualizer in 'darylsFootballVisualizer.pas' {Form1: TdxFluentDesignForm},
  DarylOneillFootballVisualizer.dxSettings in 'DarylOneillFootballVisualizer.dxSettings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
