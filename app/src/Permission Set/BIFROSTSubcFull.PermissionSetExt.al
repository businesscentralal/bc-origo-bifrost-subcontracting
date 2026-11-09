namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Extends Foundation <c>BIFROST Full ori</c> so Bifrost roles can call the Subcontracting message types.
/// Data access comes from the caller's own Business Central permissions.
/// </summary>
permissionsetextension 10036889 "BIFROST SubcFull ori" extends "BIFROST Full ori"
{
    Permissions =
        tabledata "Subc Gate ori" = RIMD,
        codeunit "Sub PO Create Impl ori" = X,
        codeunit "Sub Registration ori" = X;
}
