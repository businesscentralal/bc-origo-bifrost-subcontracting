namespace Origo.Bifrost.Subcontracting.Test;

using Origo.Bifrost;

/// <summary>
/// Runs worksheet carry-out through the dispatcher so a platform error can be observed.
/// </summary>
codeunit 97315 "Sub Wksh Carry Run ori"
{
    var
        RequestText: Text;
        ResponseText: Text;

    /// <summary>Sets the JSON request to send.</summary>
    procedure SetRequest(NewRequestText: Text)
    begin
        RequestText := NewRequestText;
    end;

    /// <summary>Returns the response text of the last run.</summary>
    procedure GetResponse(): Text
    begin
        exit(ResponseText);
    end;

    trigger OnRun()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText(RequestText);
        // false matches queue dispatch: the handler isolates the report with Codeunit.Run and answers a platform error as a refusal.
        Dispatcher.Execute(Enum::"Message Type ori"::"Subcontracting.Worksheet.CarryOut", Enum::"Message Version ori"::"1.0", '', 'test', 'text/json', RequestContent, ResponseContent, ResponseContentType, false);
        ResponseContent.GetSubText(ResponseText, 1, 8192);
    end;
}
