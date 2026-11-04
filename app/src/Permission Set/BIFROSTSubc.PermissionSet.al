namespace Origo.Bifrost.Subcontracting;

/// <summary>
/// Grants execute permission on the Bifrost Subcontracting message and registry codeunits.
/// </summary>
permissionset 10036888 "BIFROST Subc ori"
{
    Caption = 'Bifrost Subcontracting', MaxLength = 30, Comment = 'is-IS=Bifröst - undirverktakar';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "Sub PO Create Impl ori" = X,
        codeunit "Sub Registration ori" = X;
}
