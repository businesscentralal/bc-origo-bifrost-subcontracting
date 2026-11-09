namespace Origo.Bifrost.Subcontracting;

/// <summary>
/// Permission gate for subcontracting purchase-order creation.
/// No records are stored. Execute checks WritePermission so a caller without BIFROST Subc ori is refused.
/// </summary>
table 10036891 "Subc Gate ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'BIFROST Subc ori', Comment = 'is-IS=Bifröst - undirverktakar';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
