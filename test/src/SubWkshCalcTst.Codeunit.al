namespace Origo.Bifrost.Subcontracting.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Subcontracting.Worksheet.Calculate through the Foundation dispatcher on self-created data.
/// </summary>
codeunit 97310 "Sub Wksh Calc Tst ori"
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

    /// <summary>Proposed requisition lines are created for a released subcontracted operation.</summary>
    [Test]
    procedure Calculate_HappyPath_CreatesWorksheetLines()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        RequisitionLine: Record "Requisition Line";
        Response: JsonObject;
        ResponseText: Text;
    begin
        // [GIVEN] A released production order at an external work center and an empty subcontracting batch.
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 7);
        // [WHEN] The worksheet is calculated for that batch.
        ResponseText := RunText(BatchRequest());
        // [THEN] The standard report leaves a requisition line for the production order.
        Assert.IsTrue(Response.ReadFrom(ResponseText), ResponseText);
        Assert.AreEqual('Success', StatusOf(Response), 'The request should succeed: ' + ResponseText);
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        RequisitionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Assert.IsTrue(RequisitionLine.FindFirst(), 'A proposed requisition line should exist.');
        Assert.AreEqual(Vendor."No.", RequisitionLine."Vendor No.", 'The line should name the subcontractor.');
    end;

    /// <summary>A missing batch key is refused and the worksheet is unchanged.</summary>
    [Test]
    procedure Calculate_MissingBatch_Refused()
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
    procedure Calculate_UnknownKey_Refused()
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

    /// <summary>Business Central's blocked-item error is a refusal and leaves the batch unchanged.</summary>
    [Test]
    procedure Calculate_BlockedItem_BusinessCentralRefusal()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        Item: Record Item;
        RequisitionLine: Record "Requisition Line";
        Runner: Codeunit "Sub Wksh Calc Run ori";
        LinesBefore: Integer;
    begin
        // [GIVEN] A released subcontracted order whose item is blocked.
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 2);
        Item.Get(ProductionOrder."Source No.");
        Item.Blocked := true;
        Item.Modify();
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        LinesBefore := RequisitionLine.Count();
        Runner.SetRequest(BatchRequest());
        Commit();
        // [WHEN] The standard report is asked to calculate that order on the committing dispatch path.
        Assert.IsTrue(Runner.Run(), 'A Business Central error must come back as a refusal.');
        Assert.IsTrue(Runner.GetResponse().Contains('"status":"Error"'), 'Expected an error response: ' + Runner.GetResponse());
        Assert.IsTrue(Runner.GetResponse().Contains('BusinessCentralError'), 'The refusal code should be BusinessCentralError: ' + Runner.GetResponse());
        // [THEN] The refusal leaves the batch as it was.
        Assert.AreEqual(LinesBefore, RequisitionLine.Count(), 'A Business Central refusal must not leave partial worksheet lines.');
        // [CLEANUP] The scenario was committed for the committing dispatch path: unblock the item so later tests calculate cleanly.
        Item.Get(ProductionOrder."Source No.");
        Item.Blocked := false;
        Item.Modify();
        Commit();
    end;

    /// <summary>A user who cannot write requisition lines is refused with PermissionDenied.</summary>
    [Test]
    procedure Calculate_NoRequisitionWrite_PermissionDenied()
    var
        ProductionOrder: Record "Production Order";
        Vendor: Record Vendor;
        RequisitionLine: Record "Requisition Line";
        Runner: Codeunit "Sub Wksh Calc Run ori";
        LinesBefore: Integer;
        Ran: Boolean;
    begin
        // [GIVEN] Business permissions without the Subcontracting permission set.
        Initialize();
        CreateScenario(ProductionOrder, Vendor, 5);
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        LinesBefore := RequisitionLine.Count();
        Runner.SetRequest(BatchRequest());
        LibraryLowerPermissions.SetO365BusFull();
        // [WHEN] The user calculates the worksheet.
        Ran := Runner.Run();
        LibraryLowerPermissions.SetOutsideO365Scope();
        // [THEN] The call is refused with PermissionDenied and the batch is unchanged.
        Assert.IsTrue(Ran, 'The permission refusal must come back as a response: ' + GetLastErrorText());
        Assert.IsTrue(Runner.GetResponse().Contains('"status":"Error"'), 'Expected an error response: ' + Runner.GetResponse());
        Assert.IsTrue(Runner.GetResponse().Contains('PermissionDenied'), 'The refusal code should be PermissionDenied: ' + Runner.GetResponse());
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
        TemplateName := 'SUBTST';
        ReqWkshTemplate.Init();
        ReqWkshTemplate.Name := TemplateName;
        ReqWkshTemplate.Type := ReqWkshTemplate.Type::Subcontracting;
        ReqWkshTemplate."Page ID" := Page::"Req. Worksheet";
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
        Dispatcher.Execute(Enum::"Message Type ori"::"Subcontracting.Worksheet.Calculate", Enum::"Message Version ori"::"1.0", '', 'test', 'text/json', RequestContent, ResponseContent, ResponseContentType, false);
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
