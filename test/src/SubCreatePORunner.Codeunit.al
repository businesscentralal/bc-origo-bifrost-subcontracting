namespace Origo.Bifrost.Subcontracting.Test;

using Origo.Bifrost;

/// <summary>
/// Runs the message through the dispatcher in its own call so a permission error can be observed.
/// </summary>
codeunit 97301 "Sub Create PO Runner ori"
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
        Dispatcher.Execute(Enum::"Message Type ori"::"Subcontracting.PurchaseOrder.Create", Enum::"Message Version ori"::"1.0", '', 'test', 'text/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1, 8192);
    end;
}
