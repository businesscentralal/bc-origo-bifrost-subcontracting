namespace Origo.Bifrost.Subcontracting.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Subcontracting.PurchaseOrder.Create through the Foundation dispatcher on self-created data.
/// </summary>
codeunit 97300 "Sub Create PO Tst ori"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryPlanning: Codeunit "Library - Planning";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        Initialized: Boolean;

    /// <summary>Creates a purchase order for the subcontracted operation of a released order.</summary>
    [Test]
    procedure Create_HappyPath_CreatesPurchaseOrderForVendor()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        PurchaseLine: Record "Purchase Line";
        Response: JsonObject;
        OrderNos: JsonArray;
        Token: JsonToken;
        ResponseText: Text;
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 7);

        ResponseText := RunText(StrSubstNo('{"productionOrderNo":"%1","operationNo":"%2"}', ProductionOrder."No.", OperationNoOf(ProductionOrder."No.")));

        Assert.IsTrue(Response.ReadFrom(ResponseText), ResponseText);
        Assert.AreEqual('Success', StatusOf(Response), 'The request should succeed: ' + ResponseText);
        Response.Get('purchaseOrderNos', Token);
        OrderNos := Token.AsArray();
        Assert.AreEqual(1, OrderNos.Count(), 'One purchase order should be reported.');
        OrderNos.Get(0, Token);
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange("Document No.", Token.AsValue().AsCode());
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.IsTrue(PurchaseLine.FindFirst(), 'The purchase line should exist.');
        Assert.AreEqual(Vendor."No.", PurchaseLine."Buy-from Vendor No.", 'The order should be for the subcontractor.');
        Assert.AreEqual(7, PurchaseLine.Quantity, 'The order should carry the production quantity.');
    end;

    /// <summary>Refuses a request without operationNo and creates nothing.</summary>
    [Test]
    procedure Create_MissingOperationNo_Refused()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 3);

        ResponseText := RunText(StrSubstNo('{"productionOrderNo":"%1"}', ProductionOrder."No."));

        Assert.IsTrue(ResponseText.Contains('MissingParameter'), 'The refusal should be a MissingParameter code: ' + ResponseText);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.RecordIsEmpty(PurchaseLine);
    end;

    /// <summary>Refuses an unknown production order with RecordNotFound.</summary>
    [Test]
    procedure Create_UnknownOrder_RecordNotFound()
    var
        ResponseText: Text;
    begin
        Initialize();
        ResponseText := RunText('{"productionOrderNo":"NO-SUCH-ORDER","operationNo":"10"}');
        Assert.IsTrue(ResponseText.Contains('RecordNotFound'), 'Expected RecordNotFound: ' + ResponseText);
    end;

    /// <summary>Refuses a too long key as an invalid format.</summary>
    [Test]
    procedure Create_TooLongKey_InvalidFormat()
    var
        ResponseText: Text;
    begin
        Initialize();
        ResponseText := RunText('{"productionOrderNo":"123456789012345678901234567890","operationNo":"10"}');
        Assert.IsTrue(ResponseText.Contains('InvalidParameterFormat'), 'Expected InvalidParameterFormat: ' + ResponseText);
    end;

    /// <summary>Refuses a work center without subcontractor.</summary>
    [Test]
    procedure Create_NoSubcontractor_PreconditionFailed()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        WorkCenter: Record "Work Center";
        RoutingLine: Record "Prod. Order Routing Line";
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 3);
        RoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        RoutingLine.FindFirst();
        WorkCenter.Get(RoutingLine."Work Center No.");
        WorkCenter."Subcontractor No." := '';
        WorkCenter.Modify();

        ResponseText := RunText(StrSubstNo('{"productionOrderNo":"%1","operationNo":"%2"}', ProductionOrder."No.", OperationNoOf(ProductionOrder."No.")));

        Assert.IsTrue(ResponseText.Contains('PreconditionFailed'), 'Expected PreconditionFailed: ' + ResponseText);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.RecordIsEmpty(PurchaseLine);
    end;

    /// <summary>A repeated call with nothing left to purchase is refused, not reported as success.</summary>
    [Test]
    procedure Create_RepeatedCall_PreconditionFailedAndNoDuplicate()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        PurchaseLine: Record "Purchase Line";
        Request: Text;
        ResponseText: Text;
        LinesAfterFirst: Integer;
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 4);
        Request := StrSubstNo('{"productionOrderNo":"%1","operationNo":"%2"}', ProductionOrder."No.", OperationNoOf(ProductionOrder."No."));
        ResponseText := RunText(Request);
        Assert.IsTrue(ResponseText.Contains('"status":"Success"'), 'The first call should succeed: ' + ResponseText);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        LinesAfterFirst := PurchaseLine.Count();

        ResponseText := RunText(Request);

        Assert.IsTrue(ResponseText.Contains('PreconditionFailed'), 'Expected PreconditionFailed: ' + ResponseText);
        Assert.AreEqual(LinesAfterFirst, PurchaseLine.Count(), 'No duplicate purchase line may be created.');
    end;

    /// <summary>Business Central's own refusal (blocked item) is raised by the standard creator and leaves no purchase data.</summary>
    [Test]
    procedure Create_BlockedItem_BusinessCentralRefusal()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        Runner: Codeunit "Sub Create PO Runner ori";
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 2);
        Item.Get(ProductionOrder."Source No.");
        Item.Blocked := true;
        Item.Modify();
        Runner.SetRequest(StrSubstNo('{"productionOrderNo":"%1","operationNo":"%2"}', ProductionOrder."No.", OperationNoOf(ProductionOrder."No.")));
        Commit();

        if Runner.Run() then
            Assert.IsTrue(Runner.GetResponse().Contains('"status":"Error"'), 'Expected an error response: ' + Runner.GetResponse())
        else
            Assert.ExpectedError('Blocked');
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.RecordIsEmpty(PurchaseLine);
    end;

    /// <summary>A user with the Bifrost Full set and ordinary business permissions can create the order.</summary>
    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    procedure Create_LowerPermissions_FullSet_Succeeds()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        ResponseText: Text;
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 5);
        LibraryLowerPermissions.SetO365BusFull();
        LibraryLowerPermissions.AddO365BusinessPremium();
        LibraryLowerPermissions.AddPermissionSet('Subcontract. - Edit');
        LibraryLowerPermissions.AddPermissionSet('BIFROST Full ori');

        ResponseText := RunText(StrSubstNo('{"productionOrderNo":"%1","operationNo":"%2"}', ProductionOrder."No.", OperationNoOf(ProductionOrder."No.")));
        Assert.IsTrue(ResponseText.Contains('"status":"Success"'), 'The Full set should be enough: ' + ResponseText);
    end;

    /// <summary>A user without the Bifrost permission set is refused.</summary>
    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    procedure Create_LowerPermissions_NoBifrostSet_Refused()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        PurchaseLine: Record "Purchase Line";
        Runner: Codeunit "Sub Create PO Runner ori";
        Ran: Boolean;
    begin
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 5);
        Runner.SetRequest(StrSubstNo('{"productionOrderNo":"%1","operationNo":"%2"}', ProductionOrder."No.", OperationNoOf(ProductionOrder."No.")));
        LibraryLowerPermissions.SetO365BusFull();
        LibraryLowerPermissions.AddO365BusinessPremium();
        LibraryLowerPermissions.AddPermissionSet('Subcontract. - Edit');
        Ran := Runner.Run();
        LibraryLowerPermissions.SetOutsideO365Scope();
        Assert.IsTrue(Ran, 'The refusal should be a response, not an unhandled error.');
        Assert.IsTrue(Runner.GetResponse().Contains('PermissionDenied'), 'Without the Bifrost set the call must be PermissionDenied: ' + Runner.GetResponse());
        Assert.IsFalse(Runner.GetResponse().Contains('"status":"Success"'), 'Without the Bifrost set the call must not succeed: ' + Runner.GetResponse());
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.RecordIsEmpty(PurchaseLine);
    end;

    local procedure OperationNoOf(ProductionOrderNo: Code[20]): Code[10]
    var
        RoutingLine: Record "Prod. Order Routing Line";
    begin
        RoutingLine.SetRange("Prod. Order No.", ProductionOrderNo);
        RoutingLine.FindFirst();
        exit(RoutingLine."Operation No.");
    end;

    local procedure Initialize()
    var
        ManufacturingSetup: Record "Manufacturing Setup";
        ReqWkshTemplate: Record "Req. Wksh. Template";
        RequisitionWkshName: Record "Requisition Wksh. Name";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        if Initialized then
            exit;
        ReqWkshTemplate.Init();
        ReqWkshTemplate.Name := 'SUBTST';
        ReqWkshTemplate.Type := ReqWkshTemplate.Type::Subcontracting;
        ReqWkshTemplate."Page ID" := Page::"Req. Worksheet";
        if not ReqWkshTemplate.Insert() then
            ReqWkshTemplate.Modify();
        if not RequisitionWkshName.Get('SUBTST', 'SUBTST') then
            LibraryPlanning.CreateRequisitionWkshName(RequisitionWkshName, ReqWkshTemplate.Name);
        ManufacturingSetup.Get();
        ManufacturingSetup."Subcontracting Template Name" := ReqWkshTemplate.Name;
        ManufacturingSetup."Subcontracting Batch Name" := RequisitionWkshName.Name;
        ManufacturingSetup.Modify();
        Initialized := true;
    end;

    local procedure CreateScenario(var ProductionOrder: Record "Production Order"; var Vendor: Record Vendor; Quantity: Decimal)
    var
        Item: Record Item;
        WorkCenter: Record "Work Center";
        RoutingHeader: Record "Routing Header";
    begin
        LibraryPurchase.CreateVendor(Vendor);
        LibraryManufacturing.CreateWorkCenterWithCalendar(WorkCenter);
        WorkCenter."Subcontractor No." := Vendor."No.";
        WorkCenter.Modify();
        LibraryInventory.CreateItem(Item);
        Item.Validate("Replenishment System", Item."Replenishment System"::"Prod. Order");
        Item.Modify();
        LibraryManufacturing.CreateRoutingforWorkCenter(RoutingHeader, Item, WorkCenter."No.");
        LibraryManufacturing.CreateAndRefreshProductionOrder(
            ProductionOrder, Enum::"Production Order Status"::Released, Enum::"Prod. Order Source Type"::Item, Item."No.", Quantity);
    end;

    local procedure RunText(RequestText: Text) ResponseText: Text
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

    local procedure StatusOf(Response: JsonObject): Text
    var
        Token: JsonToken;
    begin
        if Response.Get('status', Token) then
            exit(Token.AsValue().AsText());
    end;
}
