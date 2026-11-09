namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Registers the subcontracting worksheet message on Foundation's message type enum.
/// </summary>
enumextension 10036893 "Sub Wksh Msg ori" extends "Message Type ori"
{
    /// <summary>Fills the subcontracting worksheet from released external routing lines.</summary>
    value(10036894; "Subcontracting.Worksheet.Calculate")
    {
        Caption = 'Subcontracting.Worksheet.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Wksh Calc Impl ori", "Msg Discovery ori" = "Sub Wksh Calc Impl ori", "Msg Contract ori" = "Sub Wksh Calc Impl ori";
    }
}
