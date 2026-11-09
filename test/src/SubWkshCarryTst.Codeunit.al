namespace Origo.Bifrost.Subcontracting.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.Subcontracting;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Subcontracting.Worksheet.CarryOut through the Foundation dispatcher on self-created data.
/// </summary>
codeunit 97314 "Sub Wksh Carry Tst ori"
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
        TemplateName: Code[10];
        BatchName: Code[10];

    /// <summary>An accepted worksheet line becomes a subcontracting purchase order and leaves the batch.</summary>
    [Test]
    procedure CarryOut_HappyPath_CreatesPurchaseOrder()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        RequisitionLine: Record "Requisition Line";
        PurchaseLine: Record "Purchase Line";
        Response: JsonObject;
        ResponseText: Text;
    begin
        // [GIVEN] A calculated subcontracting worksheet line that the standard report has accepted.
        Initialize();
        CreateAcceptedLine(ProductionOrder, Vendor, 4);
        // [WHEN] The accepted line is carried out.
        ResponseText := RunText(BatchRequest());
        // [THEN] Business Central created a purchase order and removed the worksheet line.
        Assert.IsTrue(Response.ReadFrom(ResponseText), ResponseText);
        Assert.AreEqual('Success', StatusOf(Response), 'The request should succeed: ' + ResponseText);
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        RequisitionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.IsTrue(RequisitionLine.IsEmpty(), 'The carried-out worksheet line should be gone.');
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.IsTrue(PurchaseLine.FindFirst(), 'A subcontracting purchase line should exist.');
        Assert.AreEqual(Vendor."No.", PurchaseLine."Buy-from Vendor No.", 'The purchase line should name the subcontractor.');
    end;

    /// <summary>A missing batch key is refused and the worksheet is unchanged.</summary>
    [Test]
    procedure CarryOut_MissingBatch_Refused()
    var
        RequisitionLine: Record "Requisition Line";
        ResponseText: Text;
        LinesBefore: Integer;
    begin
        // [GIVEN] A subcontracting batch.
        Initialize();
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        LinesBefore := RequisitionLine.Count();
        // [WHEN] The batch key is omitted.
        ResponseText := RunText(StrSubstNo('{"worksheetTemplateName":"%1"}', TemplateName));
        // [THEN] The call is a missing-parameter refusal and the batch is unchanged.
        Assert.IsTrue(ResponseText.Contains('MissingParameter'), 'The refusal should be a MissingParameter code: ' + ResponseText);
        Assert.AreEqual(LinesBefore, RequisitionLine.Count(), 'A missing key must not change the batch.');
    end;

    /// <summary>An unknown key is refused and the worksheet is unchanged.</summary>
    [Test]
    procedure CarryOut_UnknownKey_Refused()
    var
        RequisitionLine: Record "Requisition Line";
        ResponseText: Text;
        LinesBefore: Integer;
    begin
        // [GIVEN] A subcontracting batch.
        Initialize();
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        LinesBefore := RequisitionLine.Count();
        // [WHEN] The request contains a key this type does not accept.
        ResponseText := RunText(StrSubstNo('{"worksheetTemplateName":"%1","journalBatchName":"%2","skip":10}', TemplateName, BatchName));
        // [THEN] The unknown key is refused and the batch is unchanged.
        Assert.IsTrue(ResponseText.Contains('UnknownParameter'), 'The refusal should be an UnknownParameter code: ' + ResponseText);
        Assert.AreEqual(LinesBefore, RequisitionLine.Count(), 'An unknown key must not change the batch.');
    end;

    /// <summary>Business Central's blocked-vendor error is a refusal and leaves the worksheet line.</summary>
    [Test]
    procedure CarryOut_BlockedVendor_BusinessCentralRefusal()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        RequisitionLine: Record "Requisition Line";
        PurchaseLine: Record "Purchase Line";
        Runner: Codeunit "Sub Wksh Carry Run ori";
        LinesBefore: Integer;
    begin
        // [GIVEN] An accepted worksheet line whose subcontractor is blocked.
        Initialize();
        CreateAcceptedLine(ProductionOrder, Vendor, 3);
        Vendor.Blocked := Vendor.Blocked::All;
        Vendor.Modify();
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        RequisitionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        LinesBefore := RequisitionLine.Count();
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Runner.SetRequest(BatchRequest());
        Commit();
        // [WHEN] The standard report is asked to carry out that line on the committing dispatch path.
        Assert.IsTrue(Runner.Run(), 'A Business Central error must come back as a refusal.');
        Assert.IsTrue(Runner.GetResponse().Contains('"status":"Error"'), 'Expected an error response: ' + Runner.GetResponse());
        Assert.IsTrue(Runner.GetResponse().Contains('BusinessCentralError'), 'The refusal code should be BusinessCentralError: ' + Runner.GetResponse());
        // [THEN] The refusal leaves the worksheet line and creates no purchase order.
        Assert.AreEqual(LinesBefore, RequisitionLine.Count(), 'A Business Central refusal must not remove the worksheet line.');
        Assert.IsTrue(PurchaseLine.IsEmpty(), 'A Business Central refusal must not leave a purchase order.');
        // The refusal is committed so the runner can see it. Clear it so the next test's calculate report can validate vendors.
        Vendor.Blocked := Vendor.Blocked::" ";
        Vendor.Modify();
        RequisitionLine.DeleteAll();
    end;

    /// <summary>A user without the Bifrost permission set is refused.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure CarryOut_LowerPermissions_NoBifrostSet_Refused()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        RequisitionLine: Record "Requisition Line";
        Runner: Codeunit "Sub Wksh Carry Run ori";
        LinesBefore: Integer;
        Ran: Boolean;
    begin
        // [GIVEN] Business permissions without the Subcontracting permission set.
        // Restrictive mode drops the tenant SUPER user. Outside scope is only for fixture setup.
        Initialize();
        CreateAcceptedLine(ProductionOrder, Vendor, 2);
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        RequisitionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        LinesBefore := RequisitionLine.Count();
        Runner.SetRequest(BatchRequest());
        // Permission changes are refused while the fixture write transaction is open.
        Commit();
        LibraryLowerPermissions.StartLoggingNAVPermissions();
        LibraryLowerPermissions.SetO365BusFull();
        LibraryLowerPermissions.AddO365BusinessPremium();
        LibraryLowerPermissions.AddPermissionSet('Subcontract. - Edit');
        Assert.IsTrue(LibraryLowerPermissions.HasChangedPermissions(), 'The permission mock must replace SUPER before the refusal check.');
        // [WHEN] The user carries out the worksheet.
        Ran := Runner.Run();
        LibraryLowerPermissions.SetOutsideO365Scope();
        LibraryLowerPermissions.StopLoggingNAVPermissions();
        // [THEN] The dispatcher answers PermissionDenied and the worksheet line stays.
        Assert.IsTrue(Ran, 'A missing Bifrost permission must be a refusal, not a platform error.');
        Assert.IsTrue(Runner.GetResponse().Contains('PermissionDenied'), Runner.GetResponse());
        Assert.IsFalse(Runner.GetResponse().Contains('"status":"Success"'), Runner.GetResponse());
        Assert.AreEqual(LinesBefore, RequisitionLine.Count(), 'A permission refusal must not change the batch.');
    end;

    local procedure BatchRequest(): Text
    begin
        exit(StrSubstNo('{"worksheetTemplateName":"%1","journalBatchName":"%2"}', TemplateName, BatchName));
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
        TemplateName := 'SUBCOUT';
        ReqWkshTemplate.Init();
        ReqWkshTemplate.Name := TemplateName;
        ReqWkshTemplate.Type := ReqWkshTemplate.Type::Subcontracting;
        ReqWkshTemplate."Page ID" := Page::"Subc. Subcontracting Worksheet";
        if not ReqWkshTemplate.Insert() then
            ReqWkshTemplate.Modify();
        if not RequisitionWkshName.Get(TemplateName, TemplateName) then
            LibraryPlanning.CreateRequisitionWkshName(RequisitionWkshName, ReqWkshTemplate.Name);
        BatchName := RequisitionWkshName.Name;
        ManufacturingSetup.Get();
        ManufacturingSetup."Subcontracting Template Name" := ReqWkshTemplate.Name;
        ManufacturingSetup."Subcontracting Batch Name" := RequisitionWkshName.Name;
        ManufacturingSetup.Modify();
        Initialized := true;
    end;

    local procedure CreateAcceptedLine(var ProductionOrder: Record "Production Order"; var Vendor: Record Vendor; Quantity: Decimal)
    var
        Item: Record Item;
        WorkCenter: Record "Work Center";
        RoutingHeader: Record "Routing Header";
        RequisitionLine: Record "Requisition Line";
        CalculateSubcontracts: Report "Subc. Calculate Subcontracts";
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
        RequisitionLine.Init();
        RequisitionLine."Worksheet Template Name" := TemplateName;
        RequisitionLine."Journal Batch Name" := BatchName;
        CalculateSubcontracts.SetWkShLine(RequisitionLine);
        CalculateSubcontracts.UseRequestPage(false);
        CalculateSubcontracts.Run();
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        RequisitionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        RequisitionLine.FindFirst();
        RequisitionLine.Validate("Accept Action Message", true);
        RequisitionLine.Modify(true);
    end;

    local procedure RunText(RequestText: Text) ResponseText: Text
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(Enum::"Message Type ori"::"Subcontracting.Worksheet.CarryOut", Enum::"Message Version ori"::"1.0", '', 'test', 'text/json', RequestContent, ResponseContent, ResponseContentType, false);
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
