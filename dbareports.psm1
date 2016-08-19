# All supporting functions have been moved to Functions\SharedFunctions.ps1
# If you're looking through the code, you pretty much have to work with two files
# at any one time. The function you're working on, and SharedFunctions.ps1
foreach ($function in (Get-ChildItem "$PSScriptRoot\functions\*.ps1")) { . $function }

# Not supporting the provider path at this time
# if (((Resolve-Path .\).Path).StartsWith("SQLSERVER:\")) { throw "Please change to another drive and reload the module." }

# In case someone wants to update their client info
Set-Alias -Name Update-DbaReportsClient -Value Install-DbaReportsClient

# Strictmode coming when I've got time.
# Set-StrictMode -Version Latest

<#
# In order to keep backwards compatability, these are loaded here instead of in the manifest.
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Sdk.Sfc")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlEnum")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.RegisteredServers")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.XEvent")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Dmf")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.RegisteredServers")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo")
#>