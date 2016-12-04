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
		# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	. "$currentdir\Write-Log.ps1"
	# Create Log File 
	$Date = Get-Date -Format yyyyMMdd_HHmmss
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_SuspectPages_' + $Date + '.txt'
	try
	{
		New-item -Path $LogFilePath -itemtype File -ErrorAction Stop 
		Write-Log -path $LogFilePath -message "SuspectPages Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}

	# Specify table name that we'll be inserting into
	$table = "info.SuspectPages"
	
	
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
			Write-Log -path $LogFilePath "Can't get suspect pages from msdb on $servername." -level Warn
		}
		
		foreach ($row in $suspectpages)
		{
        $DBName = $row.DBName
		$SQL = " SELECT DatabaseID From info.Databases WHERE Name = '$DBName' and InstanceID = '$InstanceId'" 
        $Results = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]	
        $DatabaseID= $Results.DatabaseID
        # remove the null for troubleshooting to see the data
        		try
				{
					$null = $datatable.Rows.Add(
					$DatabaseID,
					$suspectpages.FileName ,
					$suspectpages.page_id,
					$suspectpages.EventType,
					$suspectpages.error_count,
					$suspectpages.last_update_date,
					$suspectpages.InstanceID
                    )
				}
				catch
				{
					Write-Log -path $LogFilePath -message "Failed to add Job to datatable - $_" -level Error
					Write-Log -path $LogFilePath -message "Data = $DatabaseID,
					$suspectpages.FileName ,
					$suspectpages.page_id,
					$suspectpages.EventType,
					$suspectpages.error_count,
					$suspectpages.last_update_date,
					$suspectpages.InstanceID " -level Warn
					continue
				}
		}
		
		$server.ConnectionContext.Disconnect()
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
		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of SuspectPages Info into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "SuspectPages Finished"
	$sourceserver.ConnectionContext.Disconnect()
}
