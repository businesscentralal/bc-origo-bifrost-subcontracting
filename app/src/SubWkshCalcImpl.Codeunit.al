namespace Origo.Bifrost.Subcontracting;

using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Subcontracting;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;

/// <summary>
/// Fills a subcontracting worksheet by running report Subc. Calculate Subcontracts.
/// </summary>
codeunit 10036894 "Sub Wksh Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingKeyErr: Label 'Provide %1.', Comment = '%1 = request key||is-IS=Tilgreindu %1.';
        TooLongErr: Label '%1 is longer than the %2 characters Business Central allows.', Comment = '%1 = request key, %2 = max length||is-IS=%1 er lengra en þeir %2 stafir sem Business Central leyfir.';
        UnknownKeyErr: Label 'Unknown request key %1.', Comment = '%1 = request key||is-IS=Óþekktur beiðnilykill %1.';
        InvalidDateErr: Label '%1 must be a date in yyyy-mm-dd form.', Comment = '%1 = request key||is-IS=%1 verður að vera dagsetning á forminu yyyy-mm-dd.';
        TemplateMissingErr: Label 'Requisition worksheet template %1 was not found.', Comment = '%1 = template name||is-IS=Beiðnisniðmát %1 fannst ekki.';
        BatchMissingErr: Label 'Requisition worksheet batch %1 was not found on template %2.', Comment = '%1 = batch name, %2 = template name||is-IS=Beiðnihópur %1 fannst ekki á sniðmáti %2.';
        NotSubcontractingErr: Label 'Worksheet template %1 is not a subcontracting worksheet.', Comment = '%1 = template name||is-IS=Vinnublaðssniðmát %1 er ekki undirverktakavinnublað.';
        NoPermissionErr: Label 'User %1 does not have permission to change requisition worksheet lines or read production routing lines, so the subcontracting worksheet cannot be calculated.', Comment = '%1 = User ID||is-IS=Notandinn %1 hefur ekki heimild til að breyta beiðnalínum eða lesa leiðarlínur framleiðslu, því er ekki hægt að reikna undirverktakavinnublaðið.';
        NextStepPermissionTxt: Label 'Ask an administrator to assign a permission set that edits requisition lines and reads production routing lines (for example Subcontract. - Edit) in addition to BIFROST Subc ori.', Comment = 'is-IS=Biddu stjórnanda um að úthluta heimildasamstæðu sem breytir beiðnalínum og les leiðarlínur framleiðslu (til dæmis Subcontract. - Edit) til viðbótar við BIFROST Subc ori.';
        PermissionExpectedTxt: Label 'write permission on requisition lines and read permission on production routing lines', Comment = 'is-IS=skrifheimild á beiðnalínur og lesheimild á leiðarlínur framleiðslu';
        AtMostTxt: Label 'At most %1 characters', Comment = '%1 = max length||is-IS=Mest %1 stafir';
        NextStepProvideTxt: Label 'Send the key in data and call again.', Comment = 'is-IS=Sendu lykilinn í data og kallaðu aftur.';
        NextStepTemplateTxt: Label 'Send the name of a subcontracting worksheet template and its batch.', Comment = 'is-IS=Sendu nafn undirverktakasniðmáts og hóps þess.';
        NextStepDateTxt: Label 'Send the date as yyyy-mm-dd.', Comment = 'is-IS=Sendu dagsetninguna sem yyyy-mm-dd.';
        DescriptionLbl: Label 'Fills one subcontracting worksheet batch with proposed requisition lines from released production routing lines at external work centers.', MaxLength = 250, Comment = 'is-IS=Fyllir einn hóp undirverktakavinnublaðs með fyrirhuguðum beiðnalínum úr útgefnum leiðarlínum framleiðslu á ytri vinnustöðvum.';

    /// <summary>Reports that worksheet calculation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the requisition line table this operation fills.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Requisition Line");
    end;

    /// <summary>Describes subcontracting worksheet calculation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for worksheet calculation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'subcontracting, worksheet, calculate subcontracts, requisition line, work center, production order', Comment = 'is-IS=undirverktaka, vinnublað, reikna undirverktaka, beiðnalína, vinnustöð, framleiðslupöntun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Replaces the lines of one subcontracting worksheet batch with proposals from released external routing lines. The batch is cleared first.', Comment = 'is-IS=Skiptir út línum eins hóps á undirverktakavinnublaði fyrir tillögur úr útgefnum ytri leiðarlínum. Hópurinn er tæmdur fyrst.';
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

    /// <summary>Describes the worksheet batch this operation fills.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.worksheetTemplateName', 'worksheet template name', 'Subcontracting requisition worksheet template.'));
        Target.Add(ContractMgt.TargetEntry('data.journalBatchName', 'journal batch name', 'Batch of that template. Existing lines in the batch are removed.'));
        Target.Add(ContractMgt.TargetEntry('data.workCenterNo', 'work center number', 'Optional filter on the work center.'));
        Target.Add(ContractMgt.TargetEntry('data.subcontractorNo', 'subcontractor number', 'Optional filter on the work center subcontractor.'));
        Target.Add(ContractMgt.TargetEntry('data.prodOrderNo', 'production order number', 'Optional filter on the released production order.'));
        Target.Add(ContractMgt.TargetEntry('data.startingDate', 'starting date', 'Optional filter on the routing line starting date (yyyy-mm-dd).'));
        exit(true);
    end;

    /// <summary>Describes the worksheet calculation parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('worksheetTemplateName', 'string', true, 'Subcontracting requisition worksheet template.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, 'Batch whose lines are replaced with the calculation.'));
        Parameters.Add(ContractMgt.Parameter('workCenterNo', 'string', false, 'Optional work center number filter of the standard report.'));
        Parameters.Add(ContractMgt.Parameter('subcontractorNo', 'string', false, 'Optional subcontractor number filter of the standard report.'));
        Parameters.Add(ContractMgt.Parameter('prodOrderNo', 'string', false, 'Optional released production order filter of the standard report.'));
        Parameters.Add(ContractMgt.Parameter('startingDate', 'string', false, 'Optional routing starting date filter, yyyy-mm-dd.'));
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
        ResponseField.Add('name', 'worksheetTemplateName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Worksheet template that was calculated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalBatchName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Batch that was cleared and rebuilt.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'linesCreated');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Requisition lines in the batch after the report. Zero is a successful empty result.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes refusals for worksheet calculation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'worksheetTemplateName or journalBatchName is missing.', 'Send both keys.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request contains a key this type does not accept.', 'Remove the key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key is too long or startingDate is not yyyy-mm-dd.', 'Send valid values.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The worksheet template or batch does not exist.', 'Check the template and batch names.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The template is not a subcontracting worksheet.', 'Choose a subcontracting template.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot write requisition lines or read production routing lines.', 'Ask an administrator for a permission set that edits requisition lines and reads production routing lines, in addition to BIFROST Subc ori.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the calculation, for example a blocked item.', 'Fix the condition Business Central named. The batch is unchanged.'));
        exit(true);
    end;

    /// <summary>Describes the worksheet replacement effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Calls report Subc. Calculate Subcontracts for one subcontracting requisition batch. The report deletes every requisition line in that batch, then inserts proposed lines for released work-center routing lines that still have a quantity to purchase. It writes no other tables directly and contains no Commit().');
        Effect.Add('idempotent', true);
        Effect.Add('idempotentNote', 'A second call with the same filters deletes the batch and rebuilds the same proposals. It does not stack lines. Lines that were already in the batch, including lines this call did not create, are removed on every call.');
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

    /// <summary>Describes worksheet calculation in the subcontracting workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Subcontracting.Worksheet.Calculate');
        WorkflowStep.Add('purpose', 'Propose requisition lines for released subcontract operations.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative worksheet calculation request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('worksheetTemplateName', 'SUBC');
        RequestData.Add('journalBatchName', 'DEFAULT');
        Request.Add('type', 'Subcontracting.Worksheet.Calculate');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('worksheetTemplateName', 'SUBC');
        Response.Add('journalBatchName', 'DEFAULT');
        Response.Add('linesCreated', 1);
        Example.Add('title', 'Calculate subcontracting worksheet lines');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to calculate the subcontracting worksheet.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Fills one subcontracting worksheet batch with proposed requisition lines for released production routing lines at external work centers.';
        exit(true);
    end;

    /// <summary>Documents the effect and idempotency of worksheet calculation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The standard report Subc. Calculate Subcontracts deletes every line in the named batch and inserts new proposals. A repeated call rebuilds those proposals and does not stack lines, so the call is idempotent for the same source data. The report has no Commit(). A Business Central error rolls the batch back. An unknown key changes nothing.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCalculate(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCalculate(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Wksh Calc Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformCalculate(var Argument: Record "Message Argument ori")
    var
        ReqWkshTemplate: Record "Req. Wksh. Template";
        RequisitionWkshName: Record "Requisition Wksh. Name";
        RequisitionLine: Record "Requisition Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        TemplateName: Code[10];
        BatchName: Code[10];
        WorkCenterNo: Code[20];
        SubcontractorNo: Code[20];
        ProdOrderNo: Code[20];
        StartingDate: Date;
        HasWorkCenter: Boolean;
        HasSubcontractor: Boolean;
        HasProdOrder: Boolean;
        HasStartingDate: Boolean;
        ValueText: Text;
        LinesCreated: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ReadCode(RequestJson, 'worksheetTemplateName', Argument, MaxStrLen(TemplateName), true, ValueText) then
            exit;
        TemplateName := CopyStr(ValueText, 1, MaxStrLen(TemplateName));
        if not ReadCode(RequestJson, 'journalBatchName', Argument, MaxStrLen(BatchName), true, ValueText) then
            exit;
        BatchName := CopyStr(ValueText, 1, MaxStrLen(BatchName));
        HasWorkCenter := RequestJson.Contains('workCenterNo');
        if HasWorkCenter then begin
            if not ReadCode(RequestJson, 'workCenterNo', Argument, MaxStrLen(WorkCenterNo), false, ValueText) then
                exit;
            WorkCenterNo := CopyStr(ValueText, 1, MaxStrLen(WorkCenterNo));
            HasWorkCenter := WorkCenterNo <> '';
        end;
        HasSubcontractor := RequestJson.Contains('subcontractorNo');
        if HasSubcontractor then begin
            if not ReadCode(RequestJson, 'subcontractorNo', Argument, MaxStrLen(SubcontractorNo), false, ValueText) then
                exit;
            SubcontractorNo := CopyStr(ValueText, 1, MaxStrLen(SubcontractorNo));
            HasSubcontractor := SubcontractorNo <> '';
        end;
        HasProdOrder := RequestJson.Contains('prodOrderNo');
        if HasProdOrder then begin
            if not ReadCode(RequestJson, 'prodOrderNo', Argument, MaxStrLen(ProdOrderNo), false, ValueText) then
                exit;
            ProdOrderNo := CopyStr(ValueText, 1, MaxStrLen(ProdOrderNo));
            HasProdOrder := ProdOrderNo <> '';
        end;
        HasStartingDate := RequestJson.Contains('startingDate');
        if HasStartingDate then
            if not ReadDate(RequestJson, 'startingDate', Argument, StartingDate) then
                exit;

        ReqWkshTemplate.SetLoadFields(Name, Type);
        if not ReqWkshTemplate.Get(TemplateName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(TemplateMissingErr, TemplateName), 'worksheetTemplateName', TemplateName, 'A requisition worksheet template', NextStepTemplateTxt);
            exit;
        end;
        if ReqWkshTemplate.Type <> Enum::"Req. Worksheet Template Type"::Subcontracting then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotSubcontractingErr, TemplateName), 'worksheetTemplateName', TemplateName, 'A subcontracting worksheet template', NextStepTemplateTxt);
            exit;
        end;
        RequisitionWkshName.SetLoadFields(Name, "Worksheet Template Name");
        if not RequisitionWkshName.Get(TemplateName, BatchName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(BatchMissingErr, BatchName, TemplateName), 'journalBatchName', BatchName, 'A batch of the worksheet template', NextStepTemplateTxt);
            exit;
        end;

        if not (RequisitionLine.WritePermission() and ProdOrderRoutingLine.ReadPermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(NoPermissionErr, UserId()), '', '', PermissionExpectedTxt, NextStepPermissionTxt);
            exit;
        end;

        RunReport(TemplateName, BatchName, HasWorkCenter, WorkCenterNo, HasSubcontractor, SubcontractorNo, HasProdOrder, ProdOrderNo, HasStartingDate, StartingDate);

        RequisitionLine.SetRange("Worksheet Template Name", TemplateName);
        RequisitionLine.SetRange("Journal Batch Name", BatchName);
        LinesCreated := RequisitionLine.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('worksheetTemplateName', TemplateName);
        ResponseJson.Add('journalBatchName', BatchName);
        ResponseJson.Add('linesCreated', LinesCreated);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RunReport(TemplateName: Code[10]; BatchName: Code[10]; HasWorkCenter: Boolean; WorkCenterNo: Code[20]; HasSubcontractor: Boolean; SubcontractorNo: Code[20]; HasProdOrder: Boolean; ProdOrderNo: Code[20]; HasStartingDate: Boolean; StartingDate: Date)
    var
        ReqLine: Record "Requisition Line";
        WorkCenter: Record "Work Center";
        RoutingLine: Record "Prod. Order Routing Line";
        CalculateSubcontracts: Report "Subc. Calculate Subcontracts";
    begin
        ReqLine.Init();
        ReqLine."Worksheet Template Name" := TemplateName;
        ReqLine."Journal Batch Name" := BatchName;
        CalculateSubcontracts.SetWkShLine(ReqLine);
        CalculateSubcontracts.UseRequestPage(false);
        if HasWorkCenter or HasSubcontractor then begin
            WorkCenter.SetCurrentKey("No.");
            if HasWorkCenter then
                WorkCenter.SetRange("No.", WorkCenterNo);
            if HasSubcontractor then
                WorkCenter.SetRange("Subcontractor No.", SubcontractorNo);
            CalculateSubcontracts.SetTableView(WorkCenter);
        end;
        if HasProdOrder or HasStartingDate then begin
            RoutingLine.SetCurrentKey(Type, "No.");
            RoutingLine.SetRange(Status, RoutingLine.Status::Released);
            RoutingLine.SetRange(Type, RoutingLine.Type::"Work Center");
            RoutingLine.SetFilter("Routing Status", '<%1', RoutingLine."Routing Status"::Finished);
            if HasProdOrder then
                RoutingLine.SetRange("Prod. Order No.", ProdOrderNo);
            if HasStartingDate then
                RoutingLine.SetRange("Starting Date", StartingDate);
            CalculateSubcontracts.SetTableView(RoutingLine);
        end;
        CalculateSubcontracts.Run();
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Keys: List of [Text];
        KeyName: Text;
    begin
        Keys := RequestJson.Keys();
        foreach KeyName in Keys do
            if not IsKnownKey(KeyName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownKeyErr, KeyName), KeyName, '', 'One of the documented keys', NextStepProvideTxt);
                exit(false);
            end;
        exit(true);
    end;

    local procedure IsKnownKey(KeyName: Text): Boolean
    begin
        exit((KeyName = 'worksheetTemplateName') or (KeyName = 'journalBatchName') or (KeyName = 'workCenterNo') or
          (KeyName = 'subcontractorNo') or (KeyName = 'prodOrderNo') or (KeyName = 'startingDate'));
    end;

    local procedure ReadCode(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; MaxLength: Integer; Required: Boolean; var Result: Text): Boolean
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

    local procedure ReadDate(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Result: Date): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            if Evaluate(Result, Token.AsValue().AsText(), 9) then
                exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidDateErr, KeyName), KeyName, '', 'yyyy-mm-dd', NextStepDateTxt);
        exit(false);
    end;
}
