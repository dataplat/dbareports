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
	
	# Create Log File 
	$Date = Get-Date -Format yyyyMMdd_HHmmss
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_Databases_' + $Date + '.txt'
	try
	{
		New-item -Path $LogFilePath -itemtype File -ErrorAction Stop 
		Write-Log -path $LogFilePath -message "Databases Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}
		
	# Specify table name that we'll be inserting into
	$table = "info.Databases"
	$schema = $table.Split(".")[0]
	$tablename = $table.Split(".")[1]
	
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	
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
	
	# Set SQL Query
	$querylastused = "WITH agg AS
				(
				  SELECT 
				       max(last_user_seek) last_user_seek,
				       max(last_user_scan) last_user_scan,
				       max(last_user_lookup) last_user_lookup,
				       max(last_user_update) last_user_update,
				       sd.name dbname
				   FROM
				       sys.dm_db_index_usage_stats, master..sysdatabases sd
				   WHERE
				     database_id = sd.dbid AND database_id > 4
					  group by sd.name 
				)
				SELECT 
				   dbname,
				   last_read = MAX(last_read),
				   last_write = MAX(last_write)
				FROM
				(
				   SELECT dbname, last_user_seek, NULL FROM agg
				   UNION ALL
				   SELECT dbname, last_user_scan, NULL FROM agg
				   UNION ALL
				   SELECT dbname, last_user_lookup, NULL FROM agg
				   UNION ALL
				   SELECT dbname, NULL, last_user_update FROM agg
				) AS x (dbname, last_read, last_write)
				GROUP BY
				   dbname
				ORDER BY 1;"
}

PROCESS
{
	$DateChecked = Get-Date
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
		$sql = "SELECT Name, DatabaseID, InstanceID, DateAdded, Inactive FROM $table"
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
		
		$reboot = $server.Databases['tempdb'].CreateDate

		try
		{
			$dblastused = $server.ConnectionContext.ExecuteWithResults($querylastused).Tables[0]
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Failed to gather Last Used Information - $_" -level Warn
			continue
		}

		foreach ($db in $server.databases)
		{
			$record = $table | Where-Object { $_.Name -eq $db.name -and $_.InstanceId -eq $InstanceID }
			$key = $record.DatabaseID
			$DateAdded = $record.DateAdded
			$Inactive = $record.Inactive
			$update = $true
			
			if ($key.count -eq 0)
			{
				$update = $false
				$DateAdded = $DateChecked
				$Inactive = 0
			}
            $DBName = $db.Name
            if($DB.status -ne 'Normal')
            {
			    try
				{
					$DBCCInfoSQL = "DBCC DBInfo('$DBName') With TableResults;"
                	$dbccresults = $server.ConnectionContext.ExecuteWithResults($DBCCInfoSQL).Tables[0]
                	$LastDBCCDate = ($dbccresults | Where-Object {$_.Field -eq 'dbi_dbccLastKnownGood'} | Sort-Object Value -Descending | Select-Object Value -First 1).Value
				}
				catch
				{
					Write-Log -path $LogFilePath -message "Failed to gather DBCC Information - $_" -level Warn
				}
            }
            else
            {
            $LastDBCCDate = $null
            }
			$lastusedinfo = $dblastused | Where-Object { $_.dbname -eq $db.name }
			$lastread = $lastusedinfo.last_read
			$lastwrite = $lastusedinfo.last_write
			try
			{
				$null = $datatable.rows.Add(
				$key,
				$InstanceID,
				$db.Name,
				$DateAdded,
				$DateChecked,
				$db.AutoClose,
				$db.AutoCreateStatisticsEnabled,
				$db.AutoShrink,
				$db.AutoUpdateStatisticsEnabled,
				$db.AvailabilityDatabaseSynchronizationState,
				$db.AvailabilityGroupName,
				$db.CaseSensitive,
				$db.Collation,
				$db.CompatibilityLevel,
				$db.CreateDate,
				$db.DataSpaceUsage,
				$db.EncryptionEnabled,
				$db.IndexSpaceUsage,
				$db.IsAccessible,
				$db.IsFullTextEnabled,
				$db.IsMirroringEnabled,
				$db.IsParameterizationForced,
				$db.IsReadCommittedSnapshotOn,
				$db.IsSystemObject,
				$db.IsUpdateable,
				$db.LastBackupDate,
				$db.LastDifferentialBackupDate,
				$db.LastLogBackupDate,
				$db.Owner,
				$db.PageVerify,
				$db.ReadOnly,
				$db.RecoveryModel,
				$db.ReplicationOptions,
				$db.Size,
				$db.SnapshotIsolationState,
				$db.SpaceAvailable,
				$db.Status,
				$db.TargetRecoveryTime,
				$InActive,
				$lastread,
				$lastwrite,
				$reboot,
                $LastDBCCDate,
				$Update)
			}
			catch
			{
				Write-Log -path $LogFilePath -message "Failed to add database info for $DBName to datatable - $_" -level Error
				Write-Log -path $LogFilePath -message "Data = $key,
				$InstanceID,
				$db.Name,
				$DateAdded,
				$DateChecked,
				$db.AutoClose,
				$db.AutoCreateStatisticsEnabled,
				$db.AutoShrink,
				$db.AutoUpdateStatisticsEnabled,
				$db.AvailabilityDatabaseSynchronizationState,
				$db.AvailabilityGroupName,
				$db.CaseSensitive,
				$db.Collation,
				$db.CompatibilityLevel,
				$db.CreateDate,
				$db.DataSpaceUsage,
				$db.EncryptionEnabled,
				$db.IndexSpaceUsage,
				$db.IsAccessible,
				$db.IsFullTextEnabled,
				$db.IsMirroringEnabled,
				$db.IsParameterizationForced,
				$db.IsReadCommittedSnapshotOn,
				$db.IsSystemObject,
				$db.IsUpdateable,
				$db.LastBackupDate,
				$db.LastDifferentialBackupDate,
				$db.LastLogBackupDate,
				$db.Owner,
				$db.PageVerify,
				$db.ReadOnly,
				$db.RecoveryModel,
				$db.ReplicationOptions,
				$db.Size,
				$db.SnapshotIsolationState,
				$db.SpaceAvailable,
				$db.Status,
				$db.TargetRecoveryTime,
				$InActive,
				$lastread,
				$lastwrite,
				$reboot,
                $LastDBCCDate,
				$Update" -level Error
			}
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
		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of Databases into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "Databases Finished"
	$sourceserver.ConnectionContext.Disconnect()
}
