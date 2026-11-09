namespace Origo.Bifrost.Subcontracting;

using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Subcontracting;
using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>
/// Creates transfer orders for one subcontracting purchase order by running report Subc. Create Transf. Order.
/// </summary>
codeunit 10036896 "Sub Transf Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingKeyErr: Label 'Provide %1.', Comment = '%1 = request key||is-IS=Tilgreindu %1.';
        TooLongErr: Label '%1 is longer than the %2 characters Business Central allows.', Comment = '%1 = request key, %2 = max length||is-IS=%1 er lengra en þeir %2 stafir sem Business Central leyfir.';
        UnknownKeyErr: Label 'Unknown request key %1.', Comment = '%1 = request key||is-IS=Óþekktur beiðnilykill %1.';
        OrderMissingErr: Label 'Purchase order %1 was not found.', Comment = '%1 = purchase order number||is-IS=Innkaupapöntun %1 fannst ekki.';
        AtMostTxt: Label 'At most %1 characters', Comment = '%1 = max length||is-IS=Mest %1 stafir';
        NextStepProvideTxt: Label 'Send the key in data and call again.', Comment = 'is-IS=Sendu lykilinn í data og kallaðu aftur.';
        NextStepOrderTxt: Label 'Send the number of an existing purchase order.', Comment = 'is-IS=Sendu númer innkaupapöntunar sem er til.';
        ExpectedOrderTxt: Label 'A purchase order', Comment = 'is-IS=Innkaupapöntun';
        ExpectedTextTxt: Label 'A non-empty string', Comment = 'is-IS=Strengur sem er ekki tómur';
        DescriptionLbl: Label 'Creates transfer orders that move production components to the subcontractor location for one subcontracting purchase order.', MaxLength = 250, Comment = 'is-IS=Býr til flutningspantanir sem flytja framleiðsluíhluti á staðsetningu undirverktaka fyrir eina innkaupapöntun undirverktaka.';

    /// <summary>Reports that transfer-order creation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the transfer header table this operation creates.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Transfer Header");
    end;

    /// <summary>Describes subcontracting transfer-order creation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for transfer-order creation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'subcontracting, transfer order, purchase order, component, subcontractor, work in process', Comment = 'is-IS=undirverktaka, flutningspöntun, innkaupapöntun, íhlutur, undirverktaki, vara í vinnslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates transfer orders that send components, and work in process when the routing asks for it, from the component location to the subcontractor location for one subcontracting purchase order.', Comment = 'is-IS=Býr til flutningspantanir sem senda íhluti, og vöru í vinnslu þegar leiðin biður um það, af staðsetningu íhlutar á staðsetningu undirverktaka fyrir eina innkaupapöntun undirverktaka.';
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

    /// <summary>Describes the purchase order this operation reads.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.purchaseOrderNo', 'purchase order number', 'Subcontracting purchase order whose components are transferred.'));
        exit(true);
    end;

    /// <summary>Describes the transfer-order request parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('purchaseOrderNo', 'string', true, 'Number of the subcontracting purchase order. The report uses this number as its purchase header filter.'));
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
        ResponseField.Add('description', 'Success when the standard report finished.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'purchaseOrderNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Purchase order that was processed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'transferOrderCount');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Open transfer orders linked to the purchase order after the report.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'linesCreated');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Transfer lines linked to the purchase order after the report.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'transferOrderNos');
        ResponseField.Add('type', 'array');
        ResponseField.Add('description', 'Numbers of those transfer orders.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes refusals for transfer-order creation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'purchaseOrderNo is missing.', 'Send the key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request contains a key this type does not accept.', 'Remove the key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'purchaseOrderNo is longer than 20 characters.', 'Send a purchase order number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The purchase order does not exist.', 'Check the purchase order number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the report, for example the order is not subcontracting work or nothing remains to transfer.', 'Fix the condition Business Central named. A refusal before the report commits leaves no transfer document.'));
        exit(true);
    end;

    /// <summary>Describes the transfer-order effect and the report Commit.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Calls report Subc. Create Transf. Order for one purchase order. The report inserts transfer orders for components with supply method Transfer to Vendor, and for work in process when the routing asks for it. It writes no transfer fields except by that report. After the lines exist, the report calls Commit() and then asks page management to show the transfer orders. A session without a user interface does not open that page. This message adds no Commit of its own.');
        Effect.Add('idempotent', false);
        Effect.Add('idempotentNote', 'A second call when nothing remains to transfer is the standard Nothing to create error and adds no document. While quantity remains, another call can add lines to the open transfer order for the same purchase order, vendor and locations. A successful call has already committed.');
        Effect.Add('permissionSet', 'BIFROST Subc ori');
        exit(true);
    end;

    /// <summary>Declares no additional metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares no related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes transfer-order creation in the subcontracting workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Subcontracting.TransferOrder.Create');
        WorkflowStep.Add('purpose', 'Move production components to the subcontractor location for one subcontracting purchase order.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative transfer-order request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        OrderNos: JsonArray;
        Example: JsonObject;
    begin
        RequestData.Add('purchaseOrderNo', '106001');
        Request.Add('type', 'Subcontracting.TransferOrder.Create');
        Request.Add('data', RequestData);
        OrderNos.Add('1001');
        Response.Add('status', 'Success');
        Response.Add('purchaseOrderNo', '106001');
        Response.Add('transferOrderCount', 1);
        Response.Add('linesCreated', 2);
        Response.Add('transferOrderNos', OrderNos);
        Example.Add('title', 'Create a subcontracting transfer order');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to create the subcontracting transfer order.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates transfer orders that move production components to the subcontractor location for one subcontracting purchase order.';
        exit(true);
    end;

    /// <summary>Documents the effect and idempotency of transfer-order creation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The standard report Subc. Create Transf. Order is the same object as the purchase order action Create Transf. Ord. to Subcontractor. On this application the report commits after it inserts the transfer lines, then asks page management to show them. A call without a user interface does not open the page. This message does not write transfer fields itself and does not add another Commit(). The call is not idempotent: a repeat when demand is already covered is a Business Central refusal, and a repeat while quantity remains can add lines to the open transfer order. An unknown key changes nothing.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCreate(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCreate(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Transf Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformCreate(var Argument: Record "Message Argument ori")
    var
        PurchaseHeader: Record "Purchase Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PurchaseOrderNo: Code[20];
        ValueText: Text;
        LinesCreated: Integer;
        TransferOrderCount: Integer;
        TransferOrderNos: JsonArray;
    begin
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ReadCode(RequestJson, 'purchaseOrderNo', Argument, MaxStrLen(PurchaseOrderNo), ValueText) then
            exit;
        PurchaseOrderNo := CopyStr(ValueText, 1, MaxStrLen(PurchaseOrderNo));

        PurchaseHeader.SetLoadFields("Document Type", "No.");
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseOrderNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(OrderMissingErr, PurchaseOrderNo), 'purchaseOrderNo', PurchaseOrderNo, ExpectedOrderTxt, NextStepOrderTxt);
            exit;
        end;

        RunReport(PurchaseHeader);
        CollectTransferOrders(PurchaseOrderNo, LinesCreated, TransferOrderCount, TransferOrderNos);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('purchaseOrderNo', PurchaseOrderNo);
        ResponseJson.Add('transferOrderCount', TransferOrderCount);
        ResponseJson.Add('linesCreated', LinesCreated);
        ResponseJson.Add('transferOrderNos', TransferOrderNos);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RunReport(PurchaseHeader: Record "Purchase Header")
    begin
        PurchaseHeader.SetRecFilter();
        Report.Run(Report::"Subc. Create Transf. Order", false, false, PurchaseHeader);
    end;

    local procedure CollectTransferOrders(PurchaseOrderNo: Code[20]; var LinesCreated: Integer; var TransferOrderCount: Integer; var TransferOrderNos: JsonArray)
    var
        TransferLine: Record "Transfer Line";
        Seen: List of [Code[20]];
        DocumentNo: Text;
    begin
        LinesCreated := 0;
        TransferOrderCount := 0;
        TransferLine.SetLoadFields("Document No.");
        TransferLine.SetRange("Subc. Purch. Order No.", PurchaseOrderNo);
        if TransferLine.FindSet() then
            repeat
                LinesCreated += 1;
                if not Seen.Contains(TransferLine."Document No.") then begin
                    Seen.Add(TransferLine."Document No.");
                    DocumentNo := TransferLine."Document No.";
                    TransferOrderNos.Add(DocumentNo);
                    TransferOrderCount += 1;
                end;
            until TransferLine.Next() = 0;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Keys: List of [Text];
        KeyName: Text;
    begin
        Keys := RequestJson.Keys();
        foreach KeyName in Keys do
            if KeyName <> 'purchaseOrderNo' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownKeyErr, KeyName), KeyName, '', 'purchaseOrderNo', NextStepProvideTxt);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadCode(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; MaxLength: Integer; var Result: Text): Boolean
    var
        Token: JsonToken;
        Value: Text;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingKeyErr, KeyName), KeyName, '', ExpectedTextTxt, NextStepProvideTxt);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Value = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingKeyErr, KeyName), KeyName, '', ExpectedTextTxt, NextStepProvideTxt);
            exit(false);
        end;
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, KeyName, MaxLength), KeyName, CopyStr(Value, 1, 80), StrSubstNo(AtMostTxt, MaxLength), NextStepProvideTxt);
            exit(false);
        end;
        Result := Value;
        exit(true);
    end;
}
