namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Registers the subcontracting transfer-order message on Foundation's message type enum.
/// </summary>
enumextension 10036895 "Sub Transf Msg ori" extends "Message Type ori"
{
    /// <summary>Creates transfer orders that move components to the subcontractor for one purchase order.</summary>
    value(10036896; "Subcontracting.TransferOrder.Create")
    {
        Caption = 'Subcontracting.TransferOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Transf Impl ori", "Msg Discovery ori" = "Sub Transf Impl ori", "Msg Contract ori" = "Sub Transf Impl ori";
    }
}
