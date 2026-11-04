namespace Origo.Bifrost.Subcontracting.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Smoke tests of the installed scaffold through Foundation's real application registration event.
/// </summary>
codeunit 97302 "Sub Scaffold Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_InstalledApp_RegisteredWithModuleName()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        // Story #1, AC01 | Time: independent of Today/WorkDate | Risk: temporary metadata only.
        // [GIVEN] The product extension is installed alongside Foundation.
        GetProductModuleInfo(AppInfo);
        // [WHEN] Foundation raises its application registration event.
        AppRegistry.GetApps(TempApps);
        // [THEN] The installed product supplies its actual module name and no invented setup page.
        Assert.IsTrue(TempApps.Get(AppInfo.Id()), 'The installed Subcontracting app must answer OnRegisterApps.');
        Assert.AreEqual(AppInfo.Name(), TempApps."App Name", 'Discovery must use the installed module name.');
        Assert.AreEqual(0, TempApps."Setup Page Id", 'The scaffold has no setup page.');
    end;

    [Test]
    procedure Scenario_AC01_RepeatedDiscovery_RegistersExactlyOnce()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        // Story #1, AC01 | Time: independent of Today/WorkDate | Risk: temporary metadata only.
        // [GIVEN] Foundation has built its application registry once.
        GetProductModuleInfo(AppInfo);
        AppRegistry.GetApps(TempApps);
        // [WHEN] Another discovery request rebuilds the same temporary buffer.
        AppRegistry.GetApps(TempApps);
        // [THEN] The scaffold occurs once and Foundation remains discoverable.
        TempApps.SetRange("App Id", AppInfo.Id());
        Assert.AreEqual(1, TempApps.Count(), 'Repeated discovery must not duplicate the app.');
        TempApps.Reset();
        Assert.IsTrue(TempApps.Get(AppRegistry.GetFoundationAppId()), 'Feature registration must preserve Foundation.');
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    procedure Scenario_AC02_LicenseAdmin_DiscoveryNeedsNoFeatureRole()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        AppInfo: ModuleInfo;
    begin
        // Story #1, AC02/AC05 | Time: independent of Today/WorkDate | Risk: restricted-role metadata reads.
        // [GIVEN] A licence administrator has no Subcontracting permission set.
        GetProductModuleInfo(AppInfo);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        // [WHEN] Foundation discovers installed apps under that role.
        AppRegistry.GetApps(TempApps);
        // [THEN] Inherent execution keeps the feature subscriber reachable without granting data writes.
        Assert.IsTrue(TempApps.Get(AppInfo.Id()), 'Licence-admin discovery must not fail on the subscriber.');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    procedure Scenario_AC02_FoundationFull_DiscoveryIncludesApp()
    begin
        // Story #1, AC02 | Time: independent of Today/WorkDate | Risk: metadata only.
        AssertRoleDiscovery('BIFROST Full ori');
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    procedure Scenario_AC02_FoundationRead_DiscoveryIncludesApp()
    begin
        // Story #1, AC02 | Time: independent of Today/WorkDate | Risk: metadata only.
        AssertRoleDiscovery('BIFROST Read ori');
    end;

    local procedure AssertRoleDiscovery(RoleId: Code[20])
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        AppInfo: ModuleInfo;
    begin
        // [GIVEN] A caller has the selected Foundation role and no separately assigned feature role.
        GetProductModuleInfo(AppInfo);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet(RoleId);
        // [WHEN] Foundation discovers installed feature apps.
        AppRegistry.GetApps(TempApps);
        // [THEN] The role and extension remain usable for scaffold metadata discovery.
        Assert.IsTrue(TempApps.Get(AppInfo.Id()), 'The Foundation role must discover Subcontracting.');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    local procedure GetProductModuleInfo(var AppInfo: ModuleInfo)
    var
        ProductAppId: Guid;
    begin
        Evaluate(ProductAppId, 'a1a7e927-8beb-4ab5-b2c3-68d0f339e43b');
        NavApp.GetModuleInfo(ProductAppId, AppInfo);
    end;
}
