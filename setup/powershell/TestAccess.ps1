<#
.SYNOPSIS  
This Script will check all of the instances in the InstanceList and gather the Database name and size to the Info.Databases table

.DESCRIPTION 
This Script will check all of the instances in the InstanceList and gather the Database name and size to the Info.Databases table

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#>
[CmdletBinding()]
Param (
	[Alias("ServerInstance", "SqlInstance")]
	[object]$SqlServer = "--installserver--",
	[object]$SqlCredential,
	[string]$InstallDatabase = "--installdb--",
	[string]$LogFileFolder = "--logdir--"
)

BEGIN
{
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	
	$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
}

PROCESS
{
	$test = "$LogFileFolder\test.txt"
	try
	{
		Write-Output "Writing to $test."
		Set-Content -Path $test -value $test
		Write-Output "Success! Removing $test."
		Remove-Item -Path $test -Force
	}
	catch
	{
		Write-Exception $_
		throw "Cannot write to log directory $LogFileFolder"
	}
	
	$sqlservers = Get-Instances
	$fails = @()
	
	foreach ($sqlserver in $sqlservers)
	{
		$sqlservername = $sqlserver.ServerName
		$InstanceName = $sqlserver.InstanceName
		
		if ($InstanceName -eq 'MSSQLServer')
		{
			$Connection = $sqlservername
		}
		else
		{
			$Connection = "$sqlservername\$InstanceName"
		}
		
		# Connect to dbareports server
		try
		{
			Write-Output "Connecting to $Connection"
			$server = Connect-SqlServer -SqlServer $Connection
		}
		catch
		{
			Write-Exception $_
			$fails += $Connection
		}
	}
	
	if ($fails.count -gt 0)
	{
		$fails = $fails -join ", "
		$log = "$LogFileFolder\FailedConnections.txt"
		Set-Content -Path $log -Value $fails
		
		throw "Cannot connect to $fails"
	}
}

END
{
	$sourceserver.ConnectionContext.Disconnect()
}
