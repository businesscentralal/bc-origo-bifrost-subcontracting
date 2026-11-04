namespace Origo.Bifrost.Subcontracting;

/// <summary>
/// Full access to the Subcontracting scaffold; the base set is the single source of object grants.
/// </summary>
permissionset 10036891 "BIFROST SC Full ori"
{
    Caption = 'Bifrost Subcontracting Full', MaxLength = 30, Comment = 'is-IS=Bifröst undirverktakar fullt';
    Assignable = true;
    Access = Public;

    IncludedPermissionSets = "BIFROST Subc ori";
}
