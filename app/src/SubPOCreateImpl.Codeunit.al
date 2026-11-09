namespace Origo.Bifrost.Subcontracting;

using Microsoft.Foundation.Enums;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.Subcontracting;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>
/// Creates subcontract purchase orders from released production routing operations.
/// </summary>
codeunit 10036886 "Sub PO Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        NotFoundErr: Label 'Released production routing operation %1 was not found on order %2.', Comment = '%1 = operation number, %2 = production order number||is-IS=Útgefin leiðaraðgerð %1 fannst ekki á framleiðslupöntun %2.';
        AtMostTxt: Label 'At most %1 characters', Comment = '%1 = max length||is-IS=Mest %1 stafir';
        MissingKeyErr: Label 'Provide %1.', Comment = '%1 = request key||is-IS=Tilgreindu %1.';
        ProductionOrderNoTok: Label 'productionOrderNo', Locked = true;
        OperationNoTok: Label 'operationNo', Locked = true;
        RoutingNoTok: Label 'routingNo', Locked = true;
        RoutingRefTok: Label 'routingReferenceNo', Locked = true;
        TooLongErr: Label '%1 is longer than the %2 characters Business Central allows.', Comment = '%1 = request key, %2 = max length||is-IS=%1 er lengra en þeir %2 stafir sem Business Central leyfir.';
        InvalidIntegerErr: Label '%1 must be a whole number.', Comment = '%1 = request key||is-IS=%1 verður að vera heiltala.';
        NextStepProvideTxt: Label 'Send the key in data and call again.', Comment = 'is-IS=Sendu lykilinn í data og kallaðu aftur.';
        NextStepIdentifyTxt: Label 'Check the production order and operation identifiers; only released production orders are supported.', Comment = 'is-IS=Athugaðu auðkenni framleiðslupöntunar og aðgerðar; aðeins útgefnar framleiðslupantanir eru studdar.';
        NextStepAmbiguousTxt: Label 'Send routingReferenceNo (and routingNo) to pick one routing line.', Comment = 'is-IS=Sendu routingReferenceNo (og routingNo) til að velja eina leiðarlínu.';
        NextStepSetupTxt: Label 'Fix the setup named in the message in Business Central, then call again.', Comment = 'is-IS=Lagaðu uppsetninguna sem nefnd er í skilaboðunum í Business Central og kallaðu aftur.';
        AmbiguousErr: Label 'More than one released routing line matches operation %1 on order %2.', Comment = '%1 = operation number, %2 = production order number||is-IS=Fleiri en ein útgefin leiðarlína passar við aðgerð %1 á pöntun %2.';
        NotWorkCenterErr: Label 'Routing line %1 on order %2 is not a work center operation; only work center operations can be subcontracted.', Comment = '%1 = operation number, %2 = production order number||is-IS=Leiðarlína %1 á pöntun %2 er ekki vinnustöðvaraðgerð; aðeins vinnustöðvaraðgerðir geta verið undirverktaka.';
        NoSubcontractorErr: Label 'Work center %1 has no Subcontractor No.', Comment = '%1 = work center number||is-IS=Vinnustöð %1 er ekki með undirverktaka.';
        NoSetupErr: Label 'Manufacturing Setup has no subcontracting requisition template and batch.', Comment = 'is-IS=Framleiðsluuppsetning er ekki með undirverktakabeiðnisniðmát og -hóp.';
        NothingToPurchaseErr: Label 'No outstanding quantity remains to be purchased for operation %1 on order %2.', Comment = '%1 = operation number, %2 = production order number||is-IS=Ekkert óafgreitt magn er eftir til innkaupa fyrir aðgerð %1 á pöntun %2.';
        NoOrderCreatedErr: Label 'Business Central created no purchase order for operation %1 on order %2 (subcontracting disabled, quantity already on purchase orders, or component check declined).', Comment = '%1 = operation number, %2 = production order number||is-IS=Business Central stofnaði enga innkaupapöntun fyrir aðgerð %1 á pöntun %2.';
        NoPermissionErr: Label 'Permission denied: missing ''%1'' permission set.', Comment = '%1 = permission set||is-IS=Heimild hafnað: vantar heimildasamstæðuna ''%1''.';
        NoPermissionNextStepLbl: Label 'Ask an administrator to assign the ''%1'' permission set. Nothing was changed.', Comment = '%1 = permission set||is-IS=Biddu kerfisstjóra um að úthluta heimildasamstæðunni ''%1''. Engu var breytt.';
        PermissionSetTok: Label 'BIFROST Subc ori', Locked = true;
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
        Target.Add(ContractMgt.TargetEntry('data.routingNo', 'routing number', 'Optional routing header used by the production order.'));
        Target.Add(ContractMgt.TargetEntry('data.routingReferenceNo', 'routing reference number', 'Optional routing reference number of the production order line.'));
        Target.Add(ContractMgt.TargetEntry('data.operationNo', 'operation number', 'Subcontracted routing operation.'));
        exit(true);
    end;

    /// <summary>Describes the production routing operation parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('productionOrderNo', 'string', true, 'Released production order containing the subcontracted operation.'));
        Parameters.Add(ContractMgt.Parameter('routingReferenceNo', 'integer', false, 'Routing reference number on the production order. Needed only when the operation number is not unique on the order.'));
        Parameters.Add(ContractMgt.Parameter('routingNo', 'string', false, 'Routing number of the production order line. Needed only when the operation number is not unique on the order.'));
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
        ResponseField.Add('description', 'Number of distinct purchase orders created or changed; always at least one on success.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'purchaseOrderNos');
        ResponseField.Add('type', 'array');
        ResponseField.Add('description', 'Numbers of the purchase orders created or changed by this call.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes invalid production routing targets.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not have the BIFROST Subc ori permission set.', 'Ask an administrator to assign BIFROST Subc ori or BIFROST Full ori.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'productionOrderNo or operationNo is missing.', 'Send both keys.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key is too long or routingReferenceNo is not a whole number.', 'Send valid values.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No released routing line matches the identifiers.', 'Check the production order and operation.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Not a work center line, no subcontractor, missing setup, nothing to purchase, or more than one matching line.', 'Fix the named condition or send routingReferenceNo.'));
        exit(true);
    end;

    /// <summary>Describes purchase orders created by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates or changes subcontracting purchase orders (and purchase lines for vendor-supplied components) for one released routing operation, through the standard Subcontracting purchase order creator. The standard creator commits internally, so Omit Commit cannot defer the commit. Business Central confirmations about component locations are answered yes without a user.');
        Effect.Add('idempotent', false);
        Effect.Add('idempotentNote', 'A repeated call creates purchase orders only for quantity not yet on purchase orders; with none left it is refused.');
        Effect.Add('permissionSet', 'BIFROST Subc ori');
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
        WorkflowStep.Add('messageType', 'Subcontracting.PurchaseOrder.Create');
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
        RequestData.Add('operationNo', '020');
        Request.Add('type', 'Subcontracting.PurchaseOrder.Create');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Response.Add('purchaseOrdersCreated', 1);
        Response.Add('purchaseOrderNos', 'X-PO-0001');
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
    var
        Gate: Record "Subc Gate ori";
    begin
        Argument.AssertVersion1();
        if not Gate.WritePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(NoPermissionErr, PermissionSetTok), '', '', PermissionSetTok, StrSubstNo(NoPermissionNextStepLbl, PermissionSetTok));
            exit;
        end;
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
        PurchaseLine: Record "Purchase Line";
        SubcontractPurchaseOrderCreator: Codeunit "Subc. Purchase Order Creator";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        OrderNos: JsonArray;
        SeenNos: List of [Code[20]];
        ProductionOrderNo: Code[20];
        OperationNo: Code[10];
        RoutingNo: Code[20];
        RoutingReferenceNo: Integer;
        HasRoutingNo: Boolean;
        HasRoutingRef: Boolean;
        CreatedCount: Integer;
        ValueText: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        if not ReadCode(Argument, RequestJson, ProductionOrderNoTok, MaxStrLen(ProductionOrderNo), true, ValueText) then
            exit;
        ProductionOrderNo := CopyStr(ValueText, 1, MaxStrLen(ProductionOrderNo));
        if not ReadCode(Argument, RequestJson, OperationNoTok, MaxStrLen(OperationNo), true, ValueText) then
            exit;
        OperationNo := CopyStr(ValueText, 1, MaxStrLen(OperationNo));
        HasRoutingNo := RequestJson.Contains(RoutingNoTok);
        if HasRoutingNo then begin
            if not ReadCode(Argument, RequestJson, RoutingNoTok, MaxStrLen(RoutingNo), false, ValueText) then
                exit;
            RoutingNo := CopyStr(ValueText, 1, MaxStrLen(RoutingNo));
        end;
        HasRoutingRef := RequestJson.Contains(RoutingRefTok);
        if HasRoutingRef then
            if not ReadInteger(Argument, RequestJson, RoutingRefTok, RoutingReferenceNo) then
                exit;

        ProductionOrderRoutingLine.SetRange(Status, Enum::"Production Order Status"::Released);
        ProductionOrderRoutingLine.SetRange("Prod. Order No.", ProductionOrderNo);
        ProductionOrderRoutingLine.SetRange("Operation No.", OperationNo);
        if HasRoutingNo then
            ProductionOrderRoutingLine.SetRange("Routing No.", RoutingNo);
        if HasRoutingRef then
            ProductionOrderRoutingLine.SetRange("Routing Reference No.", RoutingReferenceNo);
        if not ProductionOrderRoutingLine.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, OperationNo, ProductionOrderNo), OperationNoTok, OperationNo, 'A released routing operation', NextStepIdentifyTxt);
            exit;
        end;
        if ProductionOrderRoutingLine.Count() > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(AmbiguousErr, OperationNo, ProductionOrderNo), RoutingRefTok, '', 'One matching routing line', NextStepAmbiguousTxt);
            exit;
        end;

        if not CheckPreconditions(Argument, ProductionOrderRoutingLine) then
            exit;

        // Serialise concurrent callers on the routing line, then re-read the state that the checks used.
        ProductionOrderRoutingLine.LockTable();
        ProductionOrderRoutingLine.Get(ProductionOrderRoutingLine.RecordId());
        if not CheckPreconditions(Argument, ProductionOrderRoutingLine) then
            exit;

        if SubcontractPurchaseOrderCreator.CreateSubcontractingPurchaseOrderFromRoutingLine(ProductionOrderRoutingLine) = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoOrderCreatedErr, OperationNo, ProductionOrderNo), '', '', 'At least one purchase order', NextStepSetupTxt);
            exit;
        end;

        PurchaseLine.SetCurrentKey("Document Type", Type, "Prod. Order No.");
        PurchaseLine.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseLine.SetRange(Type, Enum::"Purchase Line Type"::Item);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrderRoutingLine."Prod. Order No.");
        PurchaseLine.SetRange("Routing No.", ProductionOrderRoutingLine."Routing No.");
        PurchaseLine.SetRange("Routing Reference No.", ProductionOrderRoutingLine."Routing Reference No.");
        PurchaseLine.SetRange("Operation No.", ProductionOrderRoutingLine."Operation No.");
        if PurchaseLine.FindSet() then
            repeat
                if not SeenNos.Contains(PurchaseLine."Document No.") then begin
                    SeenNos.Add(PurchaseLine."Document No.");
                    OrderNos.Add(PurchaseLine."Document No.");
                    CreatedCount += 1;
                end;
            until PurchaseLine.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productionOrderNo', ProductionOrderNo);
        ResponseJson.Add('purchaseOrdersCreated', CreatedCount);
        ResponseJson.Add('purchaseOrderNos', OrderNos);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CheckPreconditions(var Argument: Record "Message Argument ori"; ProductionOrderRoutingLine: Record "Prod. Order Routing Line"): Boolean
    var
        ManufacturingSetup: Record "Manufacturing Setup";
        WorkCenter: Record "Work Center";
        ProdOrderLine: Record "Prod. Order Line";
    begin
        if ProductionOrderRoutingLine.Type <> Enum::"Capacity Type"::"Work Center" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotWorkCenterErr, ProductionOrderRoutingLine."Operation No.", ProductionOrderRoutingLine."Prod. Order No."), OperationNoTok, ProductionOrderRoutingLine."Operation No.", 'A work center operation', NextStepIdentifyTxt);
            exit(false);
        end;

        WorkCenter.SetLoadFields("Subcontractor No.");
        if not WorkCenter.Get(ProductionOrderRoutingLine."Work Center No.") or (WorkCenter."Subcontractor No." = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoSubcontractorErr, ProductionOrderRoutingLine."Work Center No."), OperationNoTok, ProductionOrderRoutingLine."Work Center No.", 'A work center with a subcontractor', NextStepSetupTxt);
            exit(false);
        end;

        if not ManufacturingSetup.Get() or (ManufacturingSetup."Subcontracting Template Name" = '') or (ManufacturingSetup."Subcontracting Batch Name" = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoSetupErr, '', '', 'Subcontracting template and batch', NextStepSetupTxt);
            exit(false);
        end;

        ProdOrderLine.SetRange(Status, ProductionOrderRoutingLine.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrderRoutingLine."Prod. Order No.");
        ProdOrderLine.SetRange("Routing No.", ProductionOrderRoutingLine."Routing No.");
        ProdOrderLine.SetRange("Routing Reference No.", ProductionOrderRoutingLine."Routing Reference No.");
        ProdOrderLine.SetFilter("Remaining Quantity", '<>%1', 0);
        if ProdOrderLine.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NothingToPurchaseErr, ProductionOrderRoutingLine."Operation No.", ProductionOrderRoutingLine."Prod. Order No."), '', '', 'Remaining quantity on the production order line', NextStepIdentifyTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadCode(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer; Required: Boolean; var Result: Text): Boolean
    var
        Token: JsonToken;
        Value: Text;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then begin
            if Required then
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingKeyErr, KeyName), KeyName, '', 'A non-empty string', NextStepProvideTxt);
            exit(not Required);
        end;
        Value := Token.AsValue().AsText();
        if (Value = '') and Required then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingKeyErr, KeyName), KeyName, '', 'A non-empty string', NextStepProvideTxt);
            exit(false);
        end;
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, KeyName, MaxLength), KeyName, CopyStr(Value, 1, 80), StrSubstNo(AtMostTxt, MaxLength), NextStepProvideTxt);
            exit(false);
        end;
        Result := Value;
        exit(true);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Result: Integer): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            if Evaluate(Result, Token.AsValue().AsText(), 9) then
                exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidIntegerErr, KeyName), KeyName, '', 'A whole number', NextStepProvideTxt);
        exit(false);
    end;
}
