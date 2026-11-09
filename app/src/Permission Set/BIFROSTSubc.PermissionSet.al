namespace Origo.Bifrost.Subcontracting;

/// <summary>
/// Grants execution of the scaffold registry subscriber without granting access to business data.
/// </summary>
permissionset 10036888 "BIFROST Subc ori"
{
    Caption = 'Bifrost Subcontracting', MaxLength = 30, Comment = 'is-IS=Bifröst - undirverktakar';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "Sub Registration ori" = X,
        codeunit "Sub Wksh Carry Impl ori" = X;
}
