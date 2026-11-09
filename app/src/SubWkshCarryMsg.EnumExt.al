namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Registers the subcontracting worksheet carry-out message on Foundation's message type enum.
/// </summary>
enumextension 10036898 "Sub Wksh Carry Msg ori" extends "Message Type ori"
{
    /// <summary>Turns accepted subcontracting worksheet lines into purchase orders.</summary>
    value(10036897; "Subcontracting.Worksheet.CarryOut")
    {
        Caption = 'Subcontracting.Worksheet.CarryOut', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Wksh Carry Impl ori", "Msg Discovery ori" = "Sub Wksh Carry Impl ori", "Msg Contract ori" = "Sub Wksh Carry Impl ori";
    }
}
