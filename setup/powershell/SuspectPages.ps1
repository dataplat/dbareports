<#
.SYNOPSIS 


.DESCRIPTION


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
	$table = "info.SuspectPages"
	
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
	$servers = Get-Instances
	
	foreach ($server in $servers)
	{
		$sqlservername = $server.ServerName
		$InstanceName = $server.InstanceName
		$InstanceId = $server.InstanceId
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
		
		Write-Output "Processing $Connection"
		
		$sql = "Select
				DB_NAME(database_id) as DBName, 
				File_Name(file_id) as FileName, 
				page_id, 
				CASE event_type 
				WHEN 1 THEN '823 or 824 or Torn Page'
				WHEN 2 THEN 'Bad Checksum'
				WHEN 3 THEN 'Torn Page'
				WHEN 4 THEN 'Restored'
				WHEN 5 THEN 'Repaired (DBCC)'
				WHEN 7 THEN 'Deallocated (DBCC)'
				END as EventType, 
				error_count, 
				last_update_date,
				$InstanceId as InstanceID
				from dbo.suspect_pages"
		
		try
		{
			$suspectpages = $server.Databases['msdb'].ExecuteWithResults($sql).Tables[0]
		}
		catch
		{
			Write-Exception $_
			throw "Can't get suspect pages from msdb on $servername."
		}
		
		foreach ($row in $suspectpages)
		{
			$null = $datatable.Rows.Add($row)
		}
		
		$server.ConnectionContext.Disconnect()
	}
	
	$rowcount = $datatable.Rows.Count
	
	if ($rowcount -eq 0)
	{
		Write-Output "Looking good on all servers."
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
