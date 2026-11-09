namespace Origo.Bifrost.Subcontracting;

/// <summary>
/// Permission gate for worksheet carry-out. The table stores nothing.
/// Only permission set BIFROST Subc ori grants write, which BC's WritePermission kernel can see.
/// </summary>
table 10036885 "Subc. Carry Gate ori"
{
    Caption = 'Subcontracting Carry-out Gate', Comment = 'is-IS=Hlið framkvæmdar undirverktaka';
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
