$ErrorActionPreference = 'Stop'
$startup = Join-Path $PSScriptRoot 'SubcontractingAlpacaStartup/AdditionalSetup.ps1'
function Assert($Condition, [string] $Message) { if (!$Condition) { throw $Message } }
function Run-Scenario([string] $Name, [scriptblock] $Configure, [bool] $ShouldThrow, [int] $ExpectedWrites) {
    $global:SubcontractingStartupTest_published = @([pscustomobject]@{ Id=[guid]'1f32a50d-0057-4b95-b5df-cc04d7e89470'; Name='Subcontracting'; Publisher='Microsoft'; Version='28.5.54151.55751'; Scope='Global' })
    $global:SubcontractingStartupTest_installed = @()
    $global:SubcontractingStartupTest_writes = [Collections.Generic.List[string]]::new()
    $global:SubcontractingStartupTest_syncFails = $false; $global:SubcontractingStartupTest_installFails = $false; $global:SubcontractingStartupTest_noReadback = $false
    $ServerInstance = 'CI-Test'
    . $Configure
    $threw = $false
    try { & $startup } catch { $threw = $true; if (!$ShouldThrow) { Write-Host $_.Exception.Message } }
    Assert ($threw -eq $ShouldThrow) "$Name unexpected throw=$threw"
    Assert ($global:SubcontractingStartupTest_writes.Count -eq $ExpectedWrites) "$Name unexpected write count=$($global:SubcontractingStartupTest_writes.Count)"
    if ($ExpectedWrites -eq 2) { Assert (($global:SubcontractingStartupTest_writes -join ',') -eq 'Sync,Install') "$Name wrong write order" }
    Write-Host "PASS: $Name"
}
# Mock only platform cmdlets. Execute the complete startup script and verify real call parameters/order.
function Get-NAVAppInfo {
    [CmdletBinding()] param($ServerInstance,$Id,$Tenant,$Name,$Publisher,$Version,[switch]$TenantSpecificProperties)
    Assert ($ServerInstance -eq 'CI-Test') 'Unexpected server instance'
    if (!$TenantSpecificProperties) { Assert ($Id -eq [guid]'1f32a50d-0057-4b95-b5df-cc04d7e89470') 'Wrong app ID'; return $global:SubcontractingStartupTest_published }
    Assert ($Tenant -eq 'default') 'Unexpected tenant'
    return $global:SubcontractingStartupTest_installed
}
function Sync-NAVApp {
    [CmdletBinding()] param($ServerInstance,$Tenant,$Name,$Publisher,$Version,$Mode)
    Assert ($ServerInstance -eq 'CI-Test' -and $Tenant -eq 'default' -and $Name -eq 'Subcontracting' -and $Publisher -eq 'Microsoft' -and $Version -eq '28.5.54151.55751' -and $Mode -eq 'Add') 'Unexpected sync parameters'
    $global:SubcontractingStartupTest_writes.Add('Sync')
    if ($global:SubcontractingStartupTest_syncFails) { throw 'Sync refused' }
}
function Install-NAVApp {
    [CmdletBinding()] param($ServerInstance,$Tenant,$Name,$Publisher,$Version)
    Assert ($ServerInstance -eq 'CI-Test' -and $Tenant -eq 'default' -and $Name -eq 'Subcontracting' -and $Publisher -eq 'Microsoft' -and $Version -eq '28.5.54151.55751') 'Unexpected install parameters'
    $global:SubcontractingStartupTest_writes.Add('Install')
    if ($global:SubcontractingStartupTest_installFails) { throw 'Install refused' }
    if (!$global:SubcontractingStartupTest_noReadback) { $global:SubcontractingStartupTest_installed = @([pscustomobject]@{Id=[guid]'1f32a50d-0057-4b95-b5df-cc04d7e89470';Version=$Version;IsInstalled=$true}) }
}
Run-Scenario 'Published but uninstalled: sync, install, verify' {} $false 2
Run-Scenario 'Restart: same installed version performs no writes' { $global:SubcontractingStartupTest_installed=@([pscustomobject]@{Id=$global:SubcontractingStartupTest_published[0].Id;Version='28.5.54151.55751';IsInstalled=$true}) } $false 0
Run-Scenario 'Missing instance refuses before reads/writes' { $ServerInstance = '' } $true 0
Run-Scenario 'Wrong app ID refuses' { $global:SubcontractingStartupTest_published[0].Id=[guid]::Empty } $true 0
Run-Scenario 'Wrong app name refuses' { $global:SubcontractingStartupTest_published[0].Name='Other' } $true 0
Run-Scenario 'Missing package refuses' { $global:SubcontractingStartupTest_published=@() } $true 0
Run-Scenario 'Ambiguous package versions refuse' { $global:SubcontractingStartupTest_published += $global:SubcontractingStartupTest_published[0] } $true 0
Run-Scenario 'Wrong publisher refuses' { $global:SubcontractingStartupTest_published[0].Publisher='Other' } $true 0
Run-Scenario 'Tenant-published package refuses' { $global:SubcontractingStartupTest_published[0].Scope='Tenant' } $true 0
Run-Scenario 'Old package refuses' { $global:SubcontractingStartupTest_published[0].Version='28.4.0.0' } $true 0
Run-Scenario 'Installed different version refuses upgrade' { $global:SubcontractingStartupTest_installed=@([pscustomobject]@{Version='28.5.0.0';IsInstalled=$true}) } $true 0
Run-Scenario 'Sync error stops before install' { $global:SubcontractingStartupTest_syncFails=$true } $true 1
Run-Scenario 'Install error propagates' { $global:SubcontractingStartupTest_installFails=$true } $true 2
Run-Scenario 'Missing installed readback refuses' { $global:SubcontractingStartupTest_noReadback=$true } $true 2
Write-Host 'Startup script regression scenarios: 14 executed, 14 passed, 0 failed, 0 skipped. Platform cmdlets mocked; not live BC proof.'
Get-Variable -Scope Global -Name 'SubcontractingStartupTest_*' | Remove-Variable -Scope Global
