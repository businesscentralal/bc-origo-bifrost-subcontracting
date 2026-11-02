namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Registers subcontracting messages on Bifrost Foundation's message type enum.
/// </summary>
enumextension 10036885 "Sub Msg Type ori" extends "Message Type ori"
{
    /// <summary>Creates subcontract purchase orders for a released production routing operation.</summary>
    value(10036886; "Manufacturing.Subcontracting.CreatePurchaseOrders")
    {
        Caption = 'Manufacturing.Subcontracting.CreatePurchaseOrders', Locked = true;
        Implementation = "Msg Interface ori" = "Sub PO Create Impl ori", "Msg Discovery ori" = "Sub PO Create Impl ori", "Msg Contract ori" = "Sub PO Create Impl ori";
    }
}