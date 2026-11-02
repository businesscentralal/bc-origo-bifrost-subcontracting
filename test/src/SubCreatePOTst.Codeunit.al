namespace Origo.Bifrost.Subcontracting.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests subcontract purchase-order message validation through the Foundation dispatcher.
/// </summary>
codeunit 97300 "Sub Create PO Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when the production order number is missing.</summary>
    [Test]
    procedure CreatePurchaseOrders_MissingProductionOrder_ReturnsError()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        MessageType: Enum "Message Type ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText('{}');
        MessageType := MessageType::"Manufacturing.Subcontracting.CreatePurchaseOrders";

        Dispatcher.Execute(
            MessageType,
            Enum::"Message Version ori"::"1.0",
            '',
            'test',
            'text/json',
            RequestContent,
            ResponseContent,
            ResponseContentType);

        ResponseContent.GetSubText(ResponseText, 1, 2048);
        ResponseJson.ReadFrom(ResponseText);
        Assert.IsTrue(ResponseJson.Get('status', ResponseToken), 'The response should include a status.');
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing production order number should return an error.');
    end;
}