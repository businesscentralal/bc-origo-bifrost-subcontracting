namespace Origo.Bifrost.Subcontracting;

using Origo.Bifrost;

/// <summary>
/// Registers Subcontracting in Foundation's aggregated setup and application discovery.
/// Registration changes only the temporary metadata buffer; it grants no business-data access.
/// </summary>
codeunit 10036887 "Sub Registration ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}
