namespace Origo.Bifrost.Subcontracting;

/// <summary>
/// Read access to scaffold metadata only. The scaffold has no message types or business tables.
/// </summary>
permissionset 10036892 "BIFROST SC Read ori"
{
    Caption = 'Bifrost Subcontracting Read', MaxLength = 30, Comment = 'is-IS=Bifröst undirverktakar lestur';
    Assignable = true;
    Access = Public;

    Permissions = codeunit "Sub Registration ori" = X;
}
