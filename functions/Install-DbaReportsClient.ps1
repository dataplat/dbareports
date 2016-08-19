Function Install-DbaReportsClient
{
<#
.SYNOPSIS 


.DESCRIPTION
Installs the following on the local client:
	
	Config file at Documents\WindowsPowerShell\Modules\dbareports\dbareports-config.json
	
	The config file is pretty simple. This is for Windows (Trusted) Auth
	
	{
    "Username":  null,
    "SqlServer":  "sql2016",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  null
	}
	
	And the following for SQL Login
	{
    "Username":  "sqladmin",
    "SqlServer":  "sqlserver",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  "01000000d08c9ddf0115d1118c7a00c04fc297eb010000etcetc"
	}
	
	Or alternative Windows credentials 
	{
    "Username":  "ad\\dataadmin",
    "SqlServer":  "sqlcluster",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  "01000000d08c9ddf0115d1118c7a00c04fc297eb010000etcetc"
	}

	Note that only the account that created the config file can decrypt the SecurePassword.
	
.PARAMETER 


.PARAMETER 


.PARAMETER 
	

.PARAMETER 

	
.PARAMETER 

	
.PARAMETER 
	

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Verb-SqlNoun

.EXAMPLE
Verb-SqlNoun
Copies all policies and conditions from sqlserver2014a to sqlcluster, using Windows credentials. 


.EXAMPLE   
Verb-SqlNoun -WhatIf
Shows what would happen if the command were executed.
	
.EXAMPLE   
Verb-SqlNoun -Policy 'xp_cmdshell must be disabled'
Does this 
#>
	[CmdletBinding()]
	#SupportsShouldProcess = $true not yet
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential,
		[Alias("Database")]
		[string]$InstallDatabase = "dbareports"
	)
	
	DynamicParam { if ($SqlServer) { return (Get-ParamSqlProxyAccount -SqlServer $SqlServer -SqlCredential $SqlCredential) } }
	
	BEGIN
	{
		
		$parentPath = Split-Path -Parent $PSScriptRoot
		$ProxyAccount = $psboundparameters.ProxyAccount
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		$sqlaccount = $sourceserver.ServiceAccount
		
		if ($sourceserver.VersionMajor -lt 11)
		{
			Write-Exception $_
			throw "The dbareports database can only be installed on SQL Server 2012 and above. Invalid server."
		}
	}
	
	PROCESS
	{
		$dbexists = $sourceserver.Databases[$InstallDatabase]
		if ($dbexists -eq $null)
		{
			throw "Database $InstallDatabase not found"
		}
		
		$securepassword = $SqlCredential.Password
		
		if ($securepassword -ne $null)
		{
			$securepassword = $securepassword | ConvertFrom-SecureString
		}
		
		$json = @{
			SqlServer = $SqlServer
			InstallDatabase = $InstallDatabase
			Username = $SqlCredential.username
			SecurePassword = $securepassword
		}
		
		$config = Get-ConfigFileName
		
		$json | ConvertTo-Json | Set-Content -Path $config -Force
		
		Write-Output "Writing config to $config"
	}
	
	END
	{
		Write-Output "`nThanks for installing dbareports! You may now run Add-DbrServerToInventory to add a new server to your inventory."
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}