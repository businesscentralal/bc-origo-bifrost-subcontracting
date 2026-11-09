namespace Origo.Bifrost.Subcontracting;

using Microsoft.Inventory.Requisition;
using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>
/// Turns accepted subcontracting worksheet lines into purchase orders by running report Carry Out Action Msg. - Req.
/// </summary>
codeunit 10036897 "Sub Wksh Carry Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingKeyErr: Label 'Provide %1.', Comment = '%1 = request key||is-IS=Tilgreindu %1.';
        TooLongErr: Label '%1 is longer than the %2 characters Business Central allows.', Comment = '%1 = request key, %2 = max length||is-IS=%1 er lengra en þeir %2 stafir sem Business Central leyfir.';
        UnknownKeyErr: Label 'Unknown request key %1.', Comment = '%1 = request key||is-IS=Óþekktur beiðnilykill %1.';
        NotIntegerErr: Label '%1 must be a whole number.', Comment = '%1 = request key||is-IS=%1 verður að vera heiltala.';
        TemplateMissingErr: Label 'Requisition worksheet template %1 was not found.', Comment = '%1 = template name||is-IS=Beiðnisniðmát %1 fannst ekki.';
        BatchMissingErr: Label 'Requisition worksheet batch %1 was not found on template %2.', Comment = '%1 = batch name, %2 = template name||is-IS=Beiðnihópur %1 fannst ekki á sniðmáti %2.';
        NotSubcontractingErr: Label 'Worksheet template %1 is not a subcontracting worksheet.', Comment = '%1 = template name||is-IS=Vinnublaðssniðmát %1 er ekki undirverktakavinnublað.';
        LineMissingErr: Label 'Worksheet line %1 was not found in batch %2 on template %3.', Comment = '%1 = line number, %2 = batch name, %3 = template name||is-IS=Vinnublaðslína %1 fannst ekki í hópi %2 á sniðmáti %3.';
        NoneAcceptedErr: Label 'Worksheet batch %1 on template %2 has lines, but none are accepted.', Comment = '%1 = batch name, %2 = template name||is-IS=Beiðnihópur %1 á sniðmáti %2 hefur línur, en engin þeirra er samþykkt.';
        AtMostTxt: Label 'At most %1 characters', Comment = '%1 = max length||is-IS=Mest %1 stafir';
        NextStepProvideTxt: Label 'Send the key in data and call again.', Comment = 'is-IS=Sendu lykilinn í data og kallaðu aftur.';
        NextStepTemplateTxt: Label 'Send the name of a subcontracting worksheet template and its batch.', Comment = 'is-IS=Sendu nafn undirverktakasniðmáts og hóps þess.';
        NextStepLineTxt: Label 'Send the worksheet line number as a whole number.', Comment = 'is-IS=Sendu línunúmer vinnublaðsins sem heiltölu.';
        NextStepAcceptTxt: Label 'Accept the worksheet lines, then call again.', Comment = 'is-IS=Samþykktu vinnublaðslínurnar og kallaðu svo aftur.';
        ExpectedTemplateTxt: Label 'A requisition worksheet template.', Comment = 'is-IS=Beiðnisniðmát.';
        ExpectedSubcontractingTemplateTxt: Label 'A subcontracting worksheet template.', Comment = 'is-IS=Undirverktakasniðmát.';
        ExpectedBatchTxt: Label 'A batch of the worksheet template.', Comment = 'is-IS=Hópur vinnublaðssniðmátsins.';
        ExpectedLineTxt: Label 'A line of the worksheet batch.', Comment = 'is-IS=Lína í hópi vinnublaðsins.';
        ExpectedAcceptedTxt: Label 'At least one accepted worksheet line.', Comment = 'is-IS=Að minnsta kosti ein samþykkt vinnublaðslína.';
        ExpectedKnownKeyTxt: Label 'One of the documented keys.', Comment = 'is-IS=Einn af skjalfestu lyklunum.';
        ExpectedNonEmptyTxt: Label 'A non-empty string.', Comment = 'is-IS=Strengur sem er ekki tómur.';
        ExpectedWholeNumberTxt: Label 'A whole number.', Comment = 'is-IS=Heiltala.';
        ExpectedPositiveWholeTxt: Label 'A positive whole number.', Comment = 'is-IS=Jákvæð heiltala.';
        PermissionDeniedErr: Label 'Carry-out denied: missing ''BIFROST Subc ori'' permission set.', Comment = 'is-IS=Framkvæmd hafnað: vantar ''BIFROST Subc ori'' heimildasamstæðu.';
        PermissionDeniedNextStepTxt: Label 'Ask an administrator to assign BIFROST Subc ori. Nothing was changed.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta BIFROST Subc ori. Engu var breytt.';
        ExpectedPermissionTxt: Label 'BIFROST Subc ori', Locked = true;
        DescriptionLbl: Label 'Turns accepted lines of one subcontracting worksheet batch into subcontracting purchase orders.', MaxLength = 250, Comment = 'is-IS=Breytir samþykktum línum eins hóps á undirverktakavinnublaði í innkaupapantanir undirverktaka.';

    /// <summary>Reports that worksheet carry-out is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the purchase line table this operation creates.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Purchase Line");
    end;

    /// <summary>Describes subcontracting worksheet carry-out.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for worksheet carry-out.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'subcontracting, worksheet, carry out action message, purchase order, requisition line, production order', Comment = 'is-IS=undirverktaka, vinnublað, framkvæma aðgerðaskilaboð, innkaupapöntun, beiðnalína, framleiðslupöntun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates subcontracting purchase orders from the accepted lines of one worksheet batch and removes those lines. Lines that are not accepted stay on the worksheet.', Comment = 'is-IS=Býr til innkaupapantanir undirverktaka úr samþykktum línum eins hóps og fjarlægir þær línur. Línur sem ekki eru samþykktar verða eftir á vinnublaðinu.';
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

    /// <summary>Describes the worksheet batch this operation carries out.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.worksheetTemplateName', 'worksheet template name', 'Subcontracting requisition worksheet template.'));
        Target.Add(ContractMgt.TargetEntry('data.journalBatchName', 'journal batch name', 'Batch of that template. Only accepted lines are carried out.'));
        Target.Add(ContractMgt.TargetEntry('data.lineNo', 'line number', 'Optional worksheet line number. When omitted, every accepted line in the batch is carried out.'));
        exit(true);
    end;

    /// <summary>Describes the worksheet carry-out parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('worksheetTemplateName', 'string', true, 'Subcontracting requisition worksheet template.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, 'Batch whose accepted lines become purchase orders.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Optional worksheet line number. The line must already be accepted.'));
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
        ResponseField.Add('description', 'Success when the standard report finished, including a batch that had no lines.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'worksheetTemplateName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Worksheet template that was carried out.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalBatchName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Batch whose accepted lines were carried out.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'linesCarriedOut');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Accepted worksheet lines removed by the report. Zero means the batch had no lines.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'purchaseOrdersCreated');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Purchase orders created for the production orders on those lines.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes refusals for worksheet carry-out.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not have BIFROST Subc ori.', 'Assign BIFROST Subc ori. Nothing is changed.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'worksheetTemplateName or journalBatchName is missing.', 'Send both keys.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request contains a key this type does not accept.', 'Remove the key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key is too long or lineNo is not a whole number.', 'Send valid values.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The worksheet template, batch or line does not exist.', 'Check the template, batch and line number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The template is not a subcontracting worksheet, or the batch has lines that are not accepted.', 'Choose a subcontracting template and accept the lines first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the carry-out, for example a blocked vendor.', 'Fix the condition Business Central named. No purchase order is kept from that failed call.'));
        exit(true);
    end;

    /// <summary>Describes the purchase-order effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Calls report Carry Out Action Msg. - Req. for the accepted lines of one subcontracting requisition batch. The report calls codeunit Req. Wksh.-Make Order. Codeunit Subc. Req. Wksh. Make Ord. in the Microsoft Subcontracting app extends that path and creates the subcontracting purchase order. The report then deletes the carried-out worksheet lines. Codeunit Req. Wksh.-Make Order contains Commit() on this path, in FinalizeOrderHeader. This type does not write purchase lines itself. A call with no worksheet lines does not run the report. Foundation has no purchase message that runs this worksheet action.');
        Effect.Add('idempotent', true);
        Effect.Add('idempotentNote', 'A second call does not create another purchase order. The standard report deletes the lines it carried out. When the batch then has no lines, the call succeeds with zero orders and changes nothing. When lines remain but none are accepted, the call is refused and changes nothing.');
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

    /// <summary>Describes worksheet carry-out in the subcontracting workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Subcontracting.Worksheet.CarryOut');
        WorkflowStep.Add('purpose', 'Create subcontracting purchase orders from accepted worksheet lines.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative worksheet carry-out request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('worksheetTemplateName', 'SUBC');
        RequestData.Add('journalBatchName', 'DEFAULT');
        Request.Add('type', 'Subcontracting.Worksheet.CarryOut');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('worksheetTemplateName', 'SUBC');
        Response.Add('journalBatchName', 'DEFAULT');
        Response.Add('linesCarriedOut', 1);
        Response.Add('purchaseOrdersCreated', 1);
        Example.Add('title', 'Carry out accepted subcontracting worksheet lines');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to carry out the subcontracting worksheet.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates subcontracting purchase orders from the accepted lines of one subcontracting worksheet batch and removes those lines.';
        exit(true);
    end;

    /// <summary>Documents the effect and idempotency of worksheet carry-out.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Effect: report Carry Out Action Msg. - Req. creates subcontracting purchase orders for accepted worksheet lines and deletes those lines. Codeunit Req. Wksh.-Make Order commits inside FinalizeOrderHeader on that path. The Microsoft app extends the same path; this type does not write purchase fields itself. Idempotency: a repeated call does not create another purchase order, because the carried-out lines are gone. An empty batch succeeds with zero orders. Unaccepted lines are refused and left in place. A Business Central error before that commit leaves no purchase order.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCarryOut(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCarryOut(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Wksh Carry Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure HasCarryPermission(): Boolean
    var
        CarryGate: Record "Subc. Carry Gate ori";
    begin
        exit(CarryGate.WritePermission());
    end;

    local procedure PerformCarryOut(var Argument: Record "Message Argument ori")
    var
        ReqWkshTemplate: Record "Req. Wksh. Template";
        RequisitionWkshName: Record "Requisition Wksh. Name";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ProdOrderNos: List of [Code[20]];
        TemplateName: Code[10];
        BatchName: Code[10];
        ValueText: Text;
        LineNo: Integer;
        HasLineNo: Boolean;
        AcceptedBefore: Integer;
        LinesCarriedOut: Integer;
        OrdersBefore: Integer;
        OrdersCreated: Integer;
    begin
        if not HasCarryPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', ExpectedPermissionTxt, PermissionDeniedNextStepTxt);
            exit;
        end;

        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ReadCode(RequestJson, 'worksheetTemplateName', Argument, MaxStrLen(TemplateName), true, ValueText) then
            exit;
        TemplateName := CopyStr(ValueText, 1, MaxStrLen(TemplateName));
        if not ReadCode(RequestJson, 'journalBatchName', Argument, MaxStrLen(BatchName), true, ValueText) then
            exit;
        BatchName := CopyStr(ValueText, 1, MaxStrLen(BatchName));
        HasLineNo := RequestJson.Contains('lineNo');
        if HasLineNo then
            if not ReadInteger(RequestJson, 'lineNo', Argument, LineNo) then
                exit;

        ReqWkshTemplate.SetLoadFields(Name, Type);
        if not ReqWkshTemplate.Get(TemplateName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(TemplateMissingErr, TemplateName), 'worksheetTemplateName', TemplateName, ExpectedTemplateTxt, NextStepTemplateTxt);
            exit;
        end;
        if ReqWkshTemplate.Type <> Enum::"Req. Worksheet Template Type"::Subcontracting then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotSubcontractingErr, TemplateName), 'worksheetTemplateName', TemplateName, ExpectedSubcontractingTemplateTxt, NextStepTemplateTxt);
            exit;
        end;
        RequisitionWkshName.SetLoadFields(Name, "Worksheet Template Name");
        if not RequisitionWkshName.Get(TemplateName, BatchName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(BatchMissingErr, BatchName, TemplateName), 'journalBatchName', BatchName, ExpectedBatchTxt, NextStepTemplateTxt);
            exit;
        end;
        if HasLineNo then
            if not WorksheetLineExists(TemplateName, BatchName, LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineMissingErr, LineNo, BatchName, TemplateName), 'lineNo', Format(LineNo, 0, 9), ExpectedLineTxt, NextStepLineTxt);
                exit;
            end;

        AcceptedBefore := CountAccepted(TemplateName, BatchName, HasLineNo, LineNo);
        if AcceptedBefore = 0 then begin
            if BatchHasLines(TemplateName, BatchName, HasLineNo, LineNo) then
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoneAcceptedErr, BatchName, TemplateName), 'journalBatchName', BatchName, ExpectedAcceptedTxt, NextStepAcceptTxt)
            else
                WriteSuccess(Argument, TemplateName, BatchName, 0, 0);
            exit;
        end;

        CollectProdOrderNos(TemplateName, BatchName, HasLineNo, LineNo, ProdOrderNos);
        OrdersBefore := CountPurchaseOrders(ProdOrderNos);
        RunCarryOut(TemplateName, BatchName, HasLineNo, LineNo);
        LinesCarriedOut := AcceptedBefore - CountAccepted(TemplateName, BatchName, HasLineNo, LineNo);
        OrdersCreated := CountPurchaseOrders(ProdOrderNos) - OrdersBefore;
        if OrdersCreated < 0 then
            OrdersCreated := 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('worksheetTemplateName', TemplateName);
        ResponseJson.Add('journalBatchName', BatchName);
        ResponseJson.Add('linesCarriedOut', LinesCarriedOut);
        ResponseJson.Add('purchaseOrdersCreated', OrdersCreated);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure WriteSuccess(var Argument: Record "Message Argument ori"; TemplateName: Code[10]; BatchName: Code[10]; LinesCarriedOut: Integer; OrdersCreated: Integer)
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('worksheetTemplateName', TemplateName);
        ResponseJson.Add('journalBatchName', BatchName);
        ResponseJson.Add('linesCarriedOut', LinesCarriedOut);
        ResponseJson.Add('purchaseOrdersCreated', OrdersCreated);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RunCarryOut(TemplateName: Code[10]; BatchName: Code[10]; HasLineNo: Boolean; LineNo: Integer)
    var
        ReqLine: Record "Requisition Line";
        CarryOutActionMsgReq: Report "Carry Out Action Msg. - Req.";
    begin
        ReqLine."Worksheet Template Name" := TemplateName;
        ReqLine."Journal Batch Name" := BatchName;
        ReqLine.SetRange("Worksheet Template Name", TemplateName);
        ReqLine.SetRange("Journal Batch Name", BatchName);
        if HasLineNo then begin
            ReqLine."Line No." := LineNo;
            ReqLine.SetRange("Line No.", LineNo);
        end;
        CarryOutActionMsgReq.SetReqWkshLine(ReqLine);
        CarryOutActionMsgReq.SetHideDialog(true);
        CarryOutActionMsgReq.UseRequestPage(false);
        CarryOutActionMsgReq.Run();
    end;

    local procedure WorksheetLineExists(TemplateName: Code[10]; BatchName: Code[10]; LineNo: Integer): Boolean
    var
        RequisitionLine: Record "Requisition Line";
    begin
        RequisitionLine.SetLoadFields("Worksheet Template Name", "Journal Batch Name", "Line No.");
        exit(RequisitionLine.Get(TemplateName, BatchName, LineNo));
    end;

    local procedure CountAccepted(TemplateName: Code[10]; BatchName: Code[10]; HasLineNo: Boolean; LineNo: Integer): Integer
    var
        RequisitionLine: Record "Requisition Line";
    begin
        FilterBatch(RequisitionLine, TemplateName, BatchName, HasLineNo, LineNo);
        RequisitionLine.SetRange("Accept Action Message", true);
        exit(RequisitionLine.Count());
    end;

    local procedure BatchHasLines(TemplateName: Code[10]; BatchName: Code[10]; HasLineNo: Boolean; LineNo: Integer): Boolean
    var
        RequisitionLine: Record "Requisition Line";
    begin
        FilterBatch(RequisitionLine, TemplateName, BatchName, HasLineNo, LineNo);
        exit(not RequisitionLine.IsEmpty());
    end;

    local procedure FilterBatch(var RequisitionLine: Record "Requisition Line"; TemplateName: Code[10]; BatchName: Code[10]; HasLineNo: Boolean; LineNo: Integer)
    begin
        RequisitionLine.Reset();
        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        if HasLineNo then
            RequisitionLine.SetRange("Line No.", LineNo);
    end;

    local procedure CollectProdOrderNos(TemplateName: Code[10]; BatchName: Code[10]; HasLineNo: Boolean; LineNo: Integer; var ProdOrderNos: List of [Code[20]])
    var
        RequisitionLine: Record "Requisition Line";
    begin
        Clear(ProdOrderNos);
        FilterBatch(RequisitionLine, TemplateName, BatchName, HasLineNo, LineNo);
        RequisitionLine.SetRange("Accept Action Message", true);
        RequisitionLine.SetLoadFields("Prod. Order No.");
        if RequisitionLine.FindSet() then
            repeat
                if (RequisitionLine."Prod. Order No." <> '') and (not ProdOrderNos.Contains(RequisitionLine."Prod. Order No.")) then
                    ProdOrderNos.Add(RequisitionLine."Prod. Order No.");
            until RequisitionLine.Next() = 0;
    end;

    local procedure CountPurchaseOrders(ProdOrderNos: List of [Code[20]]): Integer
    var
        PurchaseLine: Record "Purchase Line";
        Seen: List of [Code[20]];
        ProdOrderNo: Code[20];
    begin
        foreach ProdOrderNo in ProdOrderNos do begin
            PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
            PurchaseLine.SetRange("Prod. Order No.", ProdOrderNo);
            PurchaseLine.SetLoadFields("Document No.");
            if PurchaseLine.FindSet() then
                repeat
                    if not Seen.Contains(PurchaseLine."Document No.") then
                        Seen.Add(PurchaseLine."Document No.");
                until PurchaseLine.Next() = 0;
        end;
        exit(Seen.Count());
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Keys: List of [Text];
        KeyName: Text;
    begin
        Keys := RequestJson.Keys();
        foreach KeyName in Keys do
            if not IsKnownKey(KeyName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownKeyErr, KeyName), KeyName, '', ExpectedKnownKeyTxt, NextStepProvideTxt);
                exit(false);
            end;
        exit(true);
    end;

    local procedure IsKnownKey(KeyName: Text): Boolean
    begin
        exit((KeyName = 'worksheetTemplateName') or (KeyName = 'journalBatchName') or (KeyName = 'lineNo'));
    end;

    local procedure ReadCode(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; MaxLength: Integer; Required: Boolean; var Result: Text): Boolean
    var
        Token: JsonToken;
        Value: Text;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then begin
            if Required then
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingKeyErr, KeyName), KeyName, '', ExpectedNonEmptyTxt, NextStepProvideTxt);
            exit(not Required);
        end;
        Value := Token.AsValue().AsText();
        if (Value = '') and Required then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingKeyErr, KeyName), KeyName, '', ExpectedNonEmptyTxt, NextStepProvideTxt);
            exit(false);
        end;
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, KeyName, MaxLength), KeyName, CopyStr(Value, 1, 80), StrSubstNo(AtMostTxt, MaxLength), NextStepProvideTxt);
            exit(false);
        end;
        Result := Value;
        exit(true);
    end;

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Result: Integer): Boolean
    var
        Token: JsonToken;
        Value: Text;
    begin
        if (not RequestJson.Get(KeyName, Token)) or (not Token.IsValue()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotIntegerErr, KeyName), KeyName, '', ExpectedWholeNumberTxt, NextStepLineTxt);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if (Value = '') or (not Evaluate(Result, Value, 9)) or (Result <= 0) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotIntegerErr, KeyName), KeyName, CopyStr(Value, 1, 80), ExpectedPositiveWholeTxt, NextStepLineTxt);
            exit(false);
        end;
        exit(true);
    end;
}
