<#
# ROB IS THIS SUPPOSED TO KEEP HISTORICAL INFORMATION? IF SO $UPDATE WILL ALWAYS BE FALSE

.SYNOPSIS 
    Adds data to the DBA database for agent job results in a server list 

.DESCRIPTION 
    Connects to a server list and iterates though reading the agent job results and adds data to the DBA Database - This is run as an agent job on LD5v-SQL11n-I06

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
	# Specify table name that we'll be inserting into
	$table = "info.AgentJobServer"
	$schema = $table.Split(".")[0]
	$tablename = $table.Split(".")[1]
	
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	
	# Start Transcript
	$Date = Get-Date -Format ddMMyyyy_HHmmss
	$transcript = "$LogFileFolder\$table" + " _" + "$Date.txt"
	Start-Transcript -Path $transcript -Append
	
	# Connect to dbareports server
	$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
	
	# Get columns automatically from the table on the SQL Server
	# and creates the necessary $script:datatable with it
	Initialize-DataTable
}

PROCESS
{
	$sqlservers = Get-Instances
	
	# Get list of all servers already in the database
	try
	{
		$sql = "SELECT AgentJobServerID, InstanceID FROM $table"
		$table = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
	}
	catch
	{
		Write-Exception $_
		throw "Can't get server list from $InstallDatabase on $($sourceserver.name)."
	}
	
	foreach ($sqlserver in $sqlservers)
	{
		$sqlservername = $sqlserver.ServerName
		$InstanceName = $sqlserver.InstanceName
		$InstanceId = $sqlserver.InstanceId
		$update = $true
		
		$record = $table | Where-Object { $_.InstanceId -eq $InstanceID }
		$key = $record.AgentJobServerID
		
		if ($key.count -eq 0)
		{
			$update = $false
		}
		$sqlservername = $sqlserver.ServerName
		$InstanceName = $sqlserver.InstanceName
		$InstanceId = $sqlserver.InstanceId
		if ($InstanceName -eq 'MSSQLServer')
		{
			$Connection = $sqlservername
		}
		else
		{
			$Connection = "$sqlservername\$InstanceName"
		}
		
		# Connect to dbareports server
		$server = Connect-SqlServer -SqlServer $Connection
		
		Write-Output "Processing $InstanceName"
		
		$jobs = $server.JobServer.jobs
		$JobCount = $jobs.Count
		$successCount = ($jobs | Where-Object { $_.LastRunOutcome -eq 'Succeeded' -and $_.IsEnabled -eq $true }).Count
		$failedCount = ($jobs | Where-Object { $_.LastRunOutcome -eq 'Failed' -and $_.IsEnabled -eq $true }).Count
		$UnknownCount = ($jobs | Where-Object { $_.LastRunOutcome -eq 'Unknown' -and $_.IsEnabled -eq $true }).Count
		$JobsDisabled = ($jobs | Where-Object { $_.IsEnabled -eq $false }).Count
		
		$null = $datatable.rows.Add(
			$key,
			$(Get-Date),
			$InstanceId,
			$JobCount,
			$successCount,
			$failedCount,
			$JobsDisabled,
			$UnknownCount,
			$Update
		)
	}
	
	$rowcount = $datatable.Rows.Count
	
	if ($rowcount -eq 0)
	{
		Write-Output "No rows returned. No update required."
		continue
	}
	
	Write-Output "Attempting Import of $rowcount row(s)"
	try
	{
		Write-Tvp
	}
	catch
	{
		Write-Exception $_
		Write-Output "Bulk insert failed. Recording exception and quitting."
	}
}

END
{
	Write-Output "Finished"
	$sourceserver.ConnectionContext.Disconnect()
	Stop-Transcript
}
