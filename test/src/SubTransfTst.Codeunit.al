namespace Origo.Bifrost.Subcontracting.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Subcontracting;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Subcontracting;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Subcontracting.TransferOrder.Create through the Foundation dispatcher on self-created data.
/// </summary>
codeunit 97312 "Sub Transf Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>The standard report creates a transfer order for a subcontracting purchase order.</summary>
    [Test]
    [HandlerFunctions('TransferOrderPageHandler')]
    procedure Create_HappyPath_CreatesTransferOrder()
    var
        PurchaseHeader: Record "Purchase Header";
        TransferLine: Record "Transfer Line";
        Response: JsonObject;
        ResponseText: Text;
    begin
        // [GIVEN] A subcontracting purchase order with a component to transfer.
        CreateSubcontractingOrder(PurchaseHeader);
        // [WHEN] The transfer order is created for that purchase order.
        ResponseText := RunText(OrderRequest(PurchaseHeader."No."));
        // [THEN] The standard report leaves a transfer line for the purchase order.
        Assert.IsTrue(Response.ReadFrom(ResponseText), ResponseText);
        Assert.AreEqual('Success', StatusOf(Response), 'The request should succeed: ' + ResponseText);
        TransferLine.SetRange("Subc. Purch. Order No.", PurchaseHeader."No.");
        Assert.IsFalse(TransferLine.IsEmpty(), 'A transfer line should exist for the purchase order.');
    end;

    /// <summary>A missing purchase-order key is refused and creates no transfer order.</summary>
    [Test]
    procedure Create_MissingPurchaseOrder_Refused()
    var
        TransferHeader: Record "Transfer Header";
        ResponseText: Text;
        HeadersBefore: Integer;
    begin
        // [GIVEN] No purchase order number.
        HeadersBefore := TransferHeader.Count();
        // [WHEN] The required key is omitted.
        ResponseText := RunText('{}');
        // [THEN] The call is a missing-parameter refusal and no transfer header is added.
        Assert.IsTrue(ResponseText.Contains('MissingParameter'), 'The refusal should be a MissingParameter code: ' + ResponseText);
        Assert.AreEqual(HeadersBefore, TransferHeader.Count(), 'A missing key must not create a transfer order.');
    end;

    /// <summary>An unknown key is refused and creates no transfer order.</summary>
    [Test]
    procedure Create_UnknownKey_Refused()
    var
        TransferHeader: Record "Transfer Header";
        ResponseText: Text;
        HeadersBefore: Integer;
    begin
        // [GIVEN] A request that also sends a key this type does not accept.
        HeadersBefore := TransferHeader.Count();
        // [WHEN] The unknown key is sent.
        ResponseText := RunText('{"purchaseOrderNo":"106001","skip":1}');
        // [THEN] The unknown key is refused and no transfer header is added.
        Assert.IsTrue(ResponseText.Contains('UnknownParameter'), 'The refusal should be an UnknownParameter code: ' + ResponseText);
        Assert.AreEqual(HeadersBefore, TransferHeader.Count(), 'An unknown key must not create a transfer order.');
    end;

    /// <summary>Business Central's non-subcontracting error is a refusal and leaves no transfer order.</summary>
    [Test]
    procedure Create_PlainPurchaseOrder_BusinessCentralRefusal()
    var
        PurchaseHeader: Record "Purchase Header";
        TransferLine: Record "Transfer Line";
        Runner: Codeunit "Sub Transf Run ori";
    begin
        // [GIVEN] A purchase order that is not subcontracting work.
        CreatePlainPurchaseOrder(PurchaseHeader);
        Runner.SetRequest(OrderRequest(PurchaseHeader."No."));
        Commit();
        // [WHEN] The standard report is asked to create a transfer order for it.
        Assert.IsTrue(Runner.Run(), 'A Business Central error must come back as a refusal.');
        Assert.IsTrue(Runner.GetResponse().Contains('"status":"Error"'), 'Expected an error response: ' + Runner.GetResponse());
        Assert.IsTrue(Runner.GetResponse().Contains('BusinessCentralError'), 'The refusal code should be BusinessCentralError: ' + Runner.GetResponse());
        // [THEN] The refusal leaves no transfer line for that purchase order.
        TransferLine.SetRange("Subc. Purch. Order No.", PurchaseHeader."No.");
        Assert.IsTrue(TransferLine.IsEmpty(), 'A Business Central refusal must not leave a transfer order.');
    end;

    /// <summary>A caller who may not execute the message is refused before the report runs.</summary>
    [Test]
    procedure Create_LowerPermissions_NoBifrostSet_Refused()
    var
        TransferHeader: Record "Transfer Header";
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Transf Impl ori";
        Response: JsonObject;
        ResponseText: Text;
        HeadersBefore: Integer;
    begin
        // [GIVEN] No purchase order. This container user is SUPER, and the test host does not drop that assignment,
        // so a lowered permission set still runs the report. The guard below is the production check.
        HeadersBefore := TransferHeader.Count();
        Assert.IsTrue(Impl.CallerMayExecute(), 'The signed-in user must be allowed to execute. The container user is SUPER.');
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(false);
        // [WHEN] The same guard is asked to run for a caller who may not execute.
        Impl.CreateForCaller(TempArgument, false);
        ResponseText := TempArgument.GetResponseText();
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'The refusal should be JSON: ' + ResponseText);
        // [THEN] The refusal is PermissionDenied and no transfer header is added.
        Assert.IsTrue(ResponseText.Contains('PermissionDenied'), 'The refusal should be PermissionDenied: ' + ResponseText);
        Assert.AreEqual(HeadersBefore, TransferHeader.Count(), 'A permission refusal must not create a transfer order.');
    end;

    /// <summary>Closes the transfer order the report shows after it commits.</summary>
    [PageHandler]
    procedure TransferOrderPageHandler(var TransferOrder: TestPage "Transfer Order")
    begin
        TransferOrder.Close();
    end;

    local procedure OrderRequest(PurchaseOrderNo: Code[20]): Text
    begin
        exit(StrSubstNo('{"purchaseOrderNo":"%1"}', PurchaseOrderNo));
    end;

    local procedure CreatePlainPurchaseOrder(var PurchaseHeader: Record "Purchase Header")
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchaseLine: Record "Purchase Line";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        LibraryPurchase.CreateVendor(Vendor);
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 1);
    end;

    local procedure CreateSubcontractingOrder(var PurchaseHeader: Record "Purchase Header")
    var
        Component: Record Item;
        FromLocation: Record Location;
        Item: Record Item;
        ProdOrderComponent: Record "Prod. Order Component";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionOrder: Record "Production Order";
        PurchaseLine: Record "Purchase Line";
        RoutingHeader: Record "Routing Header";
        ToLocation: Record Location;
        Vendor: Record Vendor;
        WorkCenter: Record "Work Center";
    begin
        LibraryLowerPermissions.SetOutsideO365Scope();
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(FromLocation);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(ToLocation);
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Validate("Subc. Location Code", ToLocation.Code);
        Vendor.Modify(true);
        LibraryManufacturing.CreateWorkCenterWithCalendar(WorkCenter);
        WorkCenter."Subcontractor No." := Vendor."No.";
        WorkCenter.Modify(true);
        LibraryInventory.CreateItem(Component);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Replenishment System", Item."Replenishment System"::"Prod. Order");
        Item.Modify(true);
        LibraryManufacturing.CreateProductionBOM(ProductionBOMHeader, Item, Component, 1, '');
        LibraryManufacturing.CreateRoutingforWorkCenter(RoutingHeader, Item, WorkCenter."No.");
        LibraryManufacturing.CreateAndRefreshProductionOrder(
            ProductionOrder, Enum::"Production Order Status"::Released, Enum::"Prod. Order Source Type"::Item, Item."No.", 4);
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.FindFirst();
        ProdOrderComponent.SetRange(Status, ProductionOrder.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderComponent.FindSet();
        repeat
            ProdOrderComponent.Validate("Location Code", FromLocation.Code);
            ProdOrderComponent.Validate("Component Supply Method", ProdOrderComponent."Component Supply Method"::"Transfer to Vendor");
            ProdOrderComponent.Modify(true);
        until ProdOrderComponent.Next() = 0;
        ProdOrderRoutingLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderRoutingLine.FindFirst();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 4);
        PurchaseLine.Validate("Prod. Order No.", ProductionOrder."No.");
        PurchaseLine.Validate("Prod. Order Line No.", ProdOrderLine."Line No.");
        PurchaseLine.Validate("Routing No.", ProdOrderRoutingLine."Routing No.");
        PurchaseLine.Validate("Routing Reference No.", ProdOrderRoutingLine."Routing Reference No.");
        PurchaseLine.Validate("Operation No.", ProdOrderRoutingLine."Operation No.");
        PurchaseLine.Validate("Work Center No.", WorkCenter."No.");
        PurchaseLine.Validate("Subc. Purchase Line Type", PurchaseLine."Subc. Purchase Line Type"::LastOperation);
        PurchaseLine.Modify(true);
    end;

    local procedure RunText(RequestText: Text) ResponseText: Text
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(Enum::"Message Type ori"::"Subcontracting.TransferOrder.Create", Enum::"Message Version ori"::"1.0", '', 'test', 'text/json', RequestContent, ResponseContent, ResponseContentType, false);
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
