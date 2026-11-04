namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Includes metadata discovery in Foundation's read role without granting any business-data writes.
/// </summary>
permissionsetextension 10036890 "BIFROST SubcRead ori" extends "BIFROST Read ori"
{
    IncludedPermissionSets = "BIFROST SC Read ori";
}
