namespace Origo.Bifrost.Subcontracting.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Subcontracting;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Subcontracting.TransferOrder.Create through the Foundation dispatcher on self-created data.
/// </summary>
codeunit 97312 "Sub Transf Tst ori"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>The standard report creates a transfer order for a subcontracting purchase order.</summary>
    [Test]
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

    /// <summary>A user without the Bifrost permission set is refused.</summary>
    [Test]
    procedure Create_LowerPermissions_NoBifrostSet_Refused()
    var
        PurchaseHeader: Record "Purchase Header";
        TransferLine: Record "Transfer Line";
        Runner: Codeunit "Sub Transf Run ori";
        LinesBefore: Integer;
        Ran: Boolean;
    begin
        // [GIVEN] A subcontracting purchase order and business permissions without the Subcontracting permission set.
        CreateSubcontractingOrder(PurchaseHeader);
        TransferLine.SetRange("Subc. Purch. Order No.", PurchaseHeader."No.");
        LinesBefore := TransferLine.Count();
        Runner.SetRequest(OrderRequest(PurchaseHeader."No."));
        LibraryLowerPermissions.SetO365BusFull();
        LibraryLowerPermissions.AddO365BusinessPremium();
        LibraryLowerPermissions.AddPermissionSet('Subcontract. - Edit');
        // [WHEN] The user creates the transfer order.
        Ran := Runner.Run();
        LibraryLowerPermissions.SetOutsideO365Scope();
        // [THEN] The call does not succeed and the purchase order has no new transfer line.
        if Ran then
            Assert.IsFalse(Runner.GetResponse().Contains('"status":"Success"'), 'Without the Bifrost set the call must not succeed: ' + Runner.GetResponse());
        Assert.AreEqual(LinesBefore, TransferLine.Count(), 'A permission refusal must not create a transfer line.');
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
        LibraryManufacturing.CreateRoutingforWorkCenter(RoutingHeader, Item, WorkCenter."No.");
        LibraryManufacturing.CreateAndRefreshProductionOrder(
            ProductionOrder, Enum::"Production Order Status"::Released, Enum::"Prod. Order Source Type"::Item, Item."No.", 4);
        ProductionOrder.Validate("Location Code", FromLocation.Code);
        ProductionOrder.Modify(true);
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.FindFirst();
        ProdOrderComponent.SetRange(Status, ProductionOrder.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderComponent.FindSet() then
            repeat
                ProdOrderComponent.Validate("Location Code", FromLocation.Code);
                ProdOrderComponent.Validate("Component Supply Method", ProdOrderComponent."Component Supply Method"::"Transfer to Vendor");
                ProdOrderComponent.Modify(true);
            until ProdOrderComponent.Next() = 0
        else begin
            ProdOrderComponent.Init();
            ProdOrderComponent.Status := ProductionOrder.Status;
            ProdOrderComponent."Prod. Order No." := ProductionOrder."No.";
            ProdOrderComponent."Prod. Order Line No." := ProdOrderLine."Line No.";
            ProdOrderComponent."Line No." := 10000;
            ProdOrderComponent.Validate("Item No.", Component."No.");
            ProdOrderComponent.Validate("Quantity per", 1);
            ProdOrderComponent.Validate("Location Code", FromLocation.Code);
            ProdOrderComponent.Validate("Component Supply Method", ProdOrderComponent."Component Supply Method"::"Transfer to Vendor");
            ProdOrderComponent.Insert(true);
        end;
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
