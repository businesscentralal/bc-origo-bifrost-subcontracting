# Run in a child scope so the original Alpaca startup variables remain intact.
& {
    # Append this to the CI owner's existing Alpaca startup bundle's AdditionalSetup.ps1.
    # Run after that bundle's original setup. The image already publishes this app.
    # ServerInstance is supplied by the Business Central image's startup environment.
    $ErrorActionPreference = 'Stop'
    if ([string]::IsNullOrWhiteSpace($ServerInstance)) {
        throw 'Subcontracting startup requires the image ServerInstance variable.'
    }

    $appId = [guid] '1f32a50d-0057-4b95-b5df-cc04d7e89470'
    $tenant = 'default' # The paired CI container uses its default tenant, not a worker's local BC tenant.
    $published = @(Get-NAVAppInfo -ServerInstance $ServerInstance -Id $appId -ErrorAction Stop |
        Where-Object { $_.Id -eq $appId -and $_.Publisher -eq 'Microsoft' -and $_.Name -eq 'Subcontracting' -and $_.Scope -eq 'Global' })
    if ($published.Count -ne 1) {
        throw "Expected exactly one Global Microsoft Subcontracting package in the image; found $($published.Count)."
    }
    $app = $published[0]
    if ([version] $app.Version -lt [version] '28.5.0.0') {
        throw "Microsoft Subcontracting $($app.Version) is below the wrapper's 28.5.0.0 dependency floor."
    }
    $identity = @{
        ServerInstance = $ServerInstance
        Tenant = $tenant
        Name = $app.Name
        Publisher = $app.Publisher
        Version = $app.Version
        ErrorAction = 'Stop'
    }
    $tenantApps = @(Get-NAVAppInfo -ServerInstance $ServerInstance -Tenant $tenant -Id $appId -TenantSpecificProperties -ErrorAction Stop)
    $installed = @($tenantApps | Where-Object IsInstalled)
    if ($installed.Count -gt 0) {
        if ($installed.Count -ne 1 -or [version] $installed[0].Version -ne [version] $app.Version) {
            throw 'A different Subcontracting version is installed; startup does not authorize an upgrade.'
        }
        Write-Host "Microsoft Subcontracting $($app.Version) is already installed on $tenant."
    } else {
        Write-Host "Synchronizing and installing published Microsoft Subcontracting $($app.Version) on $tenant."
        Sync-NAVApp @identity -Mode Add
        Install-NAVApp @identity
    }
    $verified = @(Get-NAVAppInfo @identity -TenantSpecificProperties | Where-Object { $_.Id -eq $appId -and $_.IsInstalled })
    if ($verified.Count -ne 1) {
        throw 'Microsoft Subcontracting installation was not confirmed by tenant readback.'
    }
    Write-Host "Verified Microsoft Subcontracting $($app.Version), tenant $tenant, instance $ServerInstance."
}
