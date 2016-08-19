Function Get-DbrConfig
{
<#
.SYNOPSIS 


.DESCRIPTION


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
	Get-Config
	$SqlServer = $script:SqlServer
	$InstallDatabase = $script:InstallDatabase
	$SqlCredential = $script:SqlCredential
	$configfile = Get-ConfigFileName
	
	if ($SqlServer.length -eq 0)
	{
		throw "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient"
	}
	
	$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
	
	$logintype = "Windows Authentication"
	$username = "$env:USERDOMAIN\$env:USERNAME"
	
	if ($SqlCredential.Username.Length -gt 0)
	{
		$username = $SqlCredential.UserName.TrimStart("\\")
		
		if ($username -notmatch "\\")
		{
			$logintype = "SQL Authentication"
		}
	}
	
	$execaccount = $sourceserver.JobServer.ServiceAccount
	$samplejob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - *" } | Select-Object -First 1
	$proxy = $samplejob.JobSteps[0].ProxyName
	
	if ($proxy.length -ne 0)
	{
		$proxydetails = $sourceserver.JobServer.ProxyAccounts[$proxy]
		$proxycredential = $proxydetails.CredentialIdentity
		$execaccount = "$proxy ($proxycredential)"
	}
	
	$props = Get-ExtendedProperties
	
	$eppath = $props | Where-Object Name -eq 'dbareports installpath'
	$eplogpath = $props | Where-Object Name -eq 'dbareports logfilefolder'
	$epversion = $props | Where-Object Name -eq 'dbareports version'
	
	[PSCustomObject]@{
		SQLServer = $SqlServer
		Username = $username
		LoginType = $logintype
		ConfigFile = $configfile
		DbaReportsVersion = $epversion.value
		InstallDatabase = $InstallDatabase
		AgentAccount = $execaccount
		InstallPath = $eppath.value
		LogPath = $eplogpath.value
	}
}