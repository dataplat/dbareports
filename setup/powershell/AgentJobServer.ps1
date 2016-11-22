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
		# Create Log File 
	$Date = Get-Date -Format yyyyMMdd_HHmmss
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_AgentJobServer_' + $Date + '.txt'
	try
	{
		New-item -Path $LogFilePath -itemtype File -ErrorAction Stop 
		Write-Log -path $LogFilePath -message "Agent Job Server Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}
	
	# Specify table name that we'll be inserting into
	$table = "info.AgentJobServer"
	$schema = $table.Split(".")[0]
	$tablename = $table.Split(".")[1]
	
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	. "$currentdir\Write-Log.ps1"
	
		# Connect to dbareports server
	try
	{
		Write-Log -path $LogFilePath -message "Connecting to $sqlserver" -level info
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential -ErrorAction Stop 
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Failed to connect to $sqlserver - $_" -level Error
	}

	# Get columns automatically from the table on the SQL Server
	# and creates the necessary $script:datatable with it
	try
	{
		Write-Log -path $LogFilePath -message "Intitialising Datatable" -level info
		Initialize-DataTable -ErrorAction Stop 
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Failed to initialise Data Table - $_" -level Error
	}
}

PROCESS
{
	try
	{
		Write-Log -path $LogFilePath -message "Getting Instances from $sqlserver" -level info
		$sqlservers = Get-Instances
	}
	catch
	{
		Write-Log -path $LogFilePath -message " Failed to get instances - $_" -level Error
		break
	}
	
	# Get list of all servers already in the database
	try
	{
		Write-Log -path $LogFilePath -message "Getting a list of servers from the dbareports database" -level info
		$sql = "SELECT AgentJobServerID, InstanceID FROM $table"
		$table = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
		Write-Log -path $LogFilePath -message "Got the list of servers from the dbareports database" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Can't get server list from $InstallDatabase on $($sourceserver.name). - $_" -level Error
	}
	
	foreach ($sqlserver in $sqlservers)
	{
		$sqlservername = $sqlserver.ServerName
		$InstanceName = $sqlserver.InstanceName
		$InstanceId = $sqlserver.InstanceId
		$update = $true
		
		# Checking for existing record and setting flag
		$record = $table | Where-Object { $_.InstanceId -eq $InstanceID }
		$key = $record.AgentJobServerID
		
		if ($key.count -eq 0)
		{
			$update = $false
		}

		if ($InstanceName -eq 'MSSQLServer')
		{
			$Connection = $sqlservername
		}
		else
		{
			$Connection = "$sqlservername\$InstanceName"
		}
		
		# Connect to Instance
		try
		{
			$server = Connect-SqlServer -SqlServer $Connection
			Write-Log -path $LogFilePath -message "Connecting to $Connection" -level info
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Failed to connect to $Connection - $_" -level Warn
			continue
		}
		
		$jobs = $server.JobServer.jobs
		$JobCount = $jobs.Count
		$successCount = ($jobs | Where-Object { $_.LastRunOutcome -eq 'Succeeded' -and $_.IsEnabled -eq $true }).Count
		$failedCount = ($jobs | Where-Object { $_.LastRunOutcome -eq 'Failed' -and $_.IsEnabled -eq $true }).Count
		$UnknownCount = ($jobs | Where-Object { $_.LastRunOutcome -eq 'Unknown' -and $_.IsEnabled -eq $true }).Count
		$JobsDisabled = ($jobs | Where-Object { $_.IsEnabled -eq $false }).Count
		
		try
		{
			$null = $datatable.rows.Add(
			$key,
			$(Get-Date),
			$InstanceId,
			$JobCount,
			$successCount,
			$failedCount,
			$JobsDisabled,
			$UnknownCount,
			$Update)
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Failed to add Job to datatable - $_" -level Error
			Write-Log -path $LogFilePath -message "Data = $key,
			$(Get-Date),
			$InstanceId,
			$JobCount,
			$successCount,
			$failedCount,
			$JobsDisabled,
			$UnknownCount,
			$Update" -level Error
			continue
		}
	}
	
	$rowcount = $datatable.Rows.Count
	
	if ($rowcount -eq 0)
	{
		Write-Log -path $LogFilePath -message "No rows returned. No update required." -level info
		continue
	}
	
	try
	{
		Write-Log -path $LogFilePath -message "Attempting Import of $rowcount row(s)" -level info
		Write-Tvp -ErrorAction Stop 
		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of Agent Job Server into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "Agent Job Server Finished"
	$sourceserver.ConnectionContext.Disconnect()
}
