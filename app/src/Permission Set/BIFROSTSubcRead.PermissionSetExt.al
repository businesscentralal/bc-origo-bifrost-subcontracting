namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Extends Foundation <c>BIFROST Read ori</c> with the registry codeunit; the app has no read-only message types.
/// </summary>
permissionsetextension 10036890 "BIFROST SubcRead ori" extends "BIFROST Read ori"
{
    Permissions =
        codeunit "Sub Registration ori" = X;
}
