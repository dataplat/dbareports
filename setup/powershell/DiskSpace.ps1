<#
.SYNOPSIS
This Script will check all of the instances in the InstanceList and gather the Windows Info and save to the Info.ServerInfo table

.DESCRIPTION
This Script will check all of the instances in the InstanceList and gather the Windows Info and save to the Info.ServerInfo table

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
	. "$currentdir\Write-Log.ps1"
	# Create Log File
	$Date = Get-Date -Format yyyyMMdd_HHmmss
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_DiskSpace_' + $Date + '.txt'
	try
	{
		Write-Log -path $LogFilePath -message "DiskSpace Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}

	# Connect to dbareports server
	try
	{
		Write-Log -path $LogFilePath -message "Connecting to $sqlserver" -level info
		$sourceserver = dbatools\Connect-DbaInstance -SqlServer $sqlserver -SqlCredential $SqlCredential -ErrorAction Stop
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Failed to connect to $sqlserver - $_" -level Error
	}
}

PROCESS
{
	try
	{
		Write-Log -path $LogFilePath -message "Getting a list of servers from the dbareports database" -level info

		$params = @{
			'ServerInstance' = $SqlServer
			'Database' = $InstallDatabase
			'Query' = "SELECT DISTINCT ServerID, ServerName FROM dbo.instancelist"
		}

		if ($SqlCredential) {
			$params['Credential'] = $SqlCredential
		}
		$sqlservers = Invoke-Sqlcmd2 @params

		Write-Log -path $LogFilePath -message "Got the list of servers from the dbareports database" -level info

	}
	catch
	{
		Write-Log -path $LogFilePath -message " Failed to get instances - $_" -level Error
		break
	}

	try {
		$data = dbatools\Get-DbaDiskSpace -ComputerName $sqlservers.ServerName -EnableException -ErrorAction 'Continue' | Select-Object -Property @(
			@{Name = 'DiskSpaceID'; Expression = { $null }},
			@{Name = 'Date'; Expression = { Get-Date }},
			@{Name = 'ServerID'; Expression = { $server.ServerId }},
			@{Name = 'DiskName'; Expression = { $_.Name }},
			@{Name = 'Label'; Expression = { $_.Label }},
			@{Name = 'Capacity'; Expression = { [decimal]("{0:n2}" -f  $_.SizeInGB) }},
			@{Name = 'FreeSpace'; Expression = { [decimal]("{0:n2}" -f $_.FreeInGB) }},
			@{Name = 'Percentage'; Expression = { [decimal]("{0:n2}" -f $_.PercentFree) }}
		)
	}
	catch {
		Write-Log -Path $LogFilePath -Message $_.Message -Level Error
	}

	$datatable = dbatools\ConvertTo-DbaDataTable -InputObject $data

	$rowcount = $datatable.Rows.Count

	if ($rowcount -eq 0)
	{
		Write-Log -path $LogFilePath -message "No rows returned. No update required." -level info
		continue
	}

	try
	{
		Write-Log -path $LogFilePath -message "Attempting Import of $rowcount row(s)" -level info

		$params = @{
			'SqlInstance' = $SqlServer
			'Database' = $InstallDatabase
			'Schema' = 'info'
			'Table' = 'DiskSpace'
			'InputObject' = $datatable
			'EnableException' = $true
		}

		if ($SqlCredential) {
			$params['SqlCredential'] = $SqlCredential
		}

		dbatools\Write-DbaDataTable @params

		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of DiskSpace into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "DiskSpace Finished"
	$sourceserver.ConnectionContext.Disconnect()
}