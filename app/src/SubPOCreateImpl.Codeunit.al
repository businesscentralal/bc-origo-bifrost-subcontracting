namespace Origo.Bifrost.Subcontracting;

using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Subcontracting;
using Origo.Bifrost;

/// <summary>
/// Creates subcontract purchase orders from released production routing operations.
/// </summary>
codeunit 10036886 "Sub PO Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ProductionOrderNoRequiredErr: Label 'Provide productionOrderNo.', Comment = 'is-IS=Tilgreindu productionOrderNo.';
        RoutingReferenceNoRequiredErr: Label 'Provide routingReferenceNo.', Comment = 'is-IS=Tilgreindu routingReferenceNo.';
        RoutingNoRequiredErr: Label 'Provide routingNo.', Comment = 'is-IS=Tilgreindu routingNo.';
        OperationNoRequiredErr: Label 'Provide operationNo.', Comment = 'is-IS=Tilgreindu operationNo.';
        ProductionRoutingNotFoundErr: Label 'Released production routing operation %1 was not found on order %2.', Comment = '%1 = operation number, %2 = production order number||is-IS=Leiðaraðgerð %1 fannst ekki á útgefinni framleiðslupöntun %2.';
        DescriptionLbl: Label 'Creates subcontract purchase orders for one released production-order routing operation and its outstanding subcontract quantity.', MaxLength = 250, Comment = 'is-IS=Stofnar undirverktakakauppantanir fyrir eina útgefna leiðaraðgerð framleiðslupöntunar og óafgreitt magn hennar.';

    /// <summary>Reports whether subcontract purchase-order creation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the production-order routing line table used to filter this operation.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Prod. Order Routing Line");
    end;

    /// <summary>Describes subcontract purchase-order creation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for subcontract purchase-order creation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'subcontracting, subcontract purchase order, production routing, work center, vendor operation', Comment = 'is-IS=undirverktaka, undirverktakakaup, framleiðsluleið, vinnustöð, söluaðilaaðgerð';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates purchase orders for the outstanding quantity of one subcontracted routing operation. Check the work center vendor and manufacturing setup first.', Comment = 'is-IS=Stofnar innkaupapantanir fyrir óafgreitt magn einnar undirverktakaleiðaraðgerðar. Athugaðu söluaðila vinnustöðvar og framleiðslugrunn fyrst.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not used.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the production routing operation target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.productionOrderNo', 'production order number', 'Released production order containing the routing operation.'));
        Target.Add(ContractMgt.TargetEntry('data.routingNo', 'routing number', 'Routing header used by the production order.'));
        Target.Add(ContractMgt.TargetEntry('data.operationNo', 'operation number', 'Subcontracted routing operation.'));
        exit(true);
    end;

    /// <summary>Describes the production routing operation parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('productionOrderNo', 'string', true, 'Released production order containing the subcontracted operation.'));
        Parameters.Add(ContractMgt.Parameter('routingReferenceNo', 'integer', true, 'Routing reference number on the production order.'));
        Parameters.Add(ContractMgt.Parameter('routingNo', 'string', true, 'Routing number for the production order operation.'));
        Parameters.Add(ContractMgt.Parameter('operationNo', 'string', true, 'Subcontracted routing operation number.'));
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        ResponseField: JsonObject;
    begin
        ResponseField.Add('name', 'status');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Success when the subcontract purchase-order operation completed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'productionOrderNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The production order processed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'purchaseOrdersCreated');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Number of subcontract purchase orders created; zero means no outstanding subcontract quantity.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes invalid production routing targets.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Production routing operation not found.');
        ErrorInfo.Add('when', 'The production order, routing reference, routing number, and operation number do not identify a released operation.');
        ErrorInfo.Add('fix', 'Check the production order and routing identifiers.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes purchase orders created by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates one or more purchase orders for a subcontracted routing operation.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Subcontracting ori');
        exit(true);
    end;

    /// <summary>Declares no additional subcontracting-specific metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares no related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes subcontract purchase-order creation in the production workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Subcontracting.CreatePurchaseOrders');
        WorkflowStep.Add('purpose', 'Create vendor purchase orders for the remaining quantity on a subcontracted routing operation.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative subcontract purchase-order request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('productionOrderNo', 'X-PROD-0001');
        RequestData.Add('routingReferenceNo', 0);
        RequestData.Add('routingNo', 'X-ROUTE-01');
        RequestData.Add('operationNo', '020');
        Request.Add('type', 'Manufacturing.Subcontracting.CreatePurchaseOrders');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Response.Add('purchaseOrdersCreated', 1);
        Example.Add('title', 'Create subcontract purchase orders');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to create subcontract purchase orders.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates subcontract purchase orders for outstanding production quantities at one released routing operation assigned to a subcontractor work center.';
        exit(true);
    end;

    /// <summary>Documents important behavior of subcontract purchase-order creation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Microsoft manufacturing setup must define the subcontracting requisition worksheet. The work center must name a subcontractor. The standard creator may return zero when no quantity remains to purchase.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCreatePurchaseOrders(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCreatePurchaseOrders(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub PO Create Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformCreatePurchaseOrders(var Argument: Record "Message Argument ori")
    var
        ProductionOrderRoutingLine: Record "Prod. Order Routing Line";
        SubcontractPurchaseOrderCreator: Codeunit "Subc. Purchase Order Creator";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        ProductionOrderNo: Code[20];
        ProductionOrderNoText: Text;
        RoutingReferenceNo: Integer;
        RoutingNo: Code[20];
        OperationNo: Code[10];
        OperationNoText: Text;
        PurchaseOrdersCreated: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('productionOrderNo', RequestToken) then
            Error(ProductionOrderNoRequiredErr);
        ProductionOrderNoText := RequestToken.AsValue().AsText();
        if StrLen(ProductionOrderNoText) > MaxStrLen(ProductionOrderNo) then
            Error(ProductionOrderNoRequiredErr);
        ProductionOrderNo := CopyStr(ProductionOrderNoText, 1, MaxStrLen(ProductionOrderNo));

        if not RequestJson.Get('routingReferenceNo', RequestToken) then
            Error(RoutingReferenceNoRequiredErr);
        if not Evaluate(RoutingReferenceNo, RequestToken.AsValue().AsText(), 9) then
            Error(RoutingReferenceNoRequiredErr);

        if not RequestJson.Get('routingNo', RequestToken) then
            Error(RoutingNoRequiredErr);
        if StrLen(RequestToken.AsValue().AsText()) > MaxStrLen(RoutingNo) then
            Error(RoutingNoRequiredErr);
        RoutingNo := CopyStr(RequestToken.AsValue().AsText(), 1, MaxStrLen(RoutingNo));

        if not RequestJson.Get('operationNo', RequestToken) then
            Error(OperationNoRequiredErr);
        OperationNoText := RequestToken.AsValue().AsText();
        if StrLen(OperationNoText) > MaxStrLen(OperationNo) then
            Error(OperationNoRequiredErr);
        OperationNo := CopyStr(OperationNoText, 1, MaxStrLen(OperationNo));

        if not ProductionOrderRoutingLine.Get(
            Enum::"Production Order Status"::Released,
            ProductionOrderNo,
            RoutingReferenceNo,
            RoutingNo,
            OperationNo)
        then
            Error(ProductionRoutingNotFoundErr, OperationNo, ProductionOrderNo);

        PurchaseOrdersCreated := SubcontractPurchaseOrderCreator.CreateSubcontractingPurchaseOrderFromRoutingLine(ProductionOrderRoutingLine);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productionOrderNo', ProductionOrderNo);
        ResponseJson.Add('purchaseOrdersCreated', PurchaseOrdersCreated);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}