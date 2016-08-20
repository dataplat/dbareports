[CmdletBinding()]
param (
	[string]$Path
)

$localpath = $(Join-Path -Path (Split-Path -Path $profile) -ChildPath '\Modules\dbareports')

try
{
	if ($Path.length -eq 0)
	{
		
		if ($PSCommandPath.Length -gt 0)
		{
			$path = Split-Path $PSCommandPath
			if ($path -match "github")
			{
				$path = $localpath
			}
		}
		else
		{
			$path = $localpath
		}
	}
}
catch
{
	$path = $localpath
}

if ($path.length -eq 0)
{
	$path = $localpath
}

Write-Output "Installing module to $path"


Remove-Module dbareports -ErrorAction SilentlyContinue
$url = 'https://github.com/sqldbawithabeard/dbareports/archive/master.zip'

$temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
$zipfile = "$temp\dbareports.zip"

if (!(Test-Path -Path $path))
{
	try
	{
		Write-Output "Creating directory: $path"
		New-Item -Path $path -ItemType Directory | Out-Null
	}
	catch
	{
		throw "Can't create $Path. You may need to Run as Administrator"
	}
}
else
{
	try
	{
		Write-Output "Deleting previously installed module"
		Remove-Item -Path "$path\*" -Force -Recurse
	}
	catch
	{
		throw "Can't delete $Path. You may need to Run as Administrator"
	}
}

Write-Output "Downloading archive from github"
try
{
	Invoke-WebRequest $url -OutFile $zipfile
}
catch
{
	#try with default proxy and usersettings
	Write-Output "Probably using a proxy for internet access, trying default proxy settings"
	(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
	Invoke-WebRequest $url -OutFile $zipfile
}

# Unblock if there's a block
Unblock-File $zipfile -ErrorAction SilentlyContinue

Write-Output "Unzipping"

# Keep it backwards compatible
$shell = New-Object -COM Shell.Application
$zipPackage = $shell.NameSpace($zipfile)
$destinationFolder = $shell.NameSpace($temp)
$destinationFolder.CopyHere($zipPackage.Items())

Write-Output "Cleaning up"
Move-Item -Path "$temp\dbareports-master\*" $path
Remove-Item -Path "$temp\dbareports-master"
Remove-Item -Path $zipfile

Write-Output "Done! Please report any bugs to Rob. You can do this via GitHub or better still via the SQL Server Community Slack in the #dbareports channel. Auto invite link https://sqlpas.io/slack"
if ((Get-Command -Module dbareports).count -eq 0) { Import-Module "$path\dbareports.psd1" -Force }
Get-Command -Module dbareports
Write-Output "`n`nIf you experience any function missing errors after update, please restart PowerShell or reload your profile."