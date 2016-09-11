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
	# Specify table name that we'll be inserting into
	$table = "info.Databases"
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
	$sqlservers = Get-Instances
	
	# Get list of all servers already in the database
	try
	{
		$sql = "SELECT Name, DatabaseID, InstanceID, DateAdded, Inactive FROM $table"
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
		
		$reboot = $server.Databases['tempdb'].CreateDate
		$dblastused = $server.ConnectionContext.ExecuteWithResults($querylastused).Tables[0]
		
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
			    $DBCCInfoSQL = "DBCC DBInfo('$DBName') With TableResults;"
                $dbccresults = $server.ConnectionContext.ExecuteWithResults($DBCCInfoSQL).Tables
                $LastDBCCDate = $dbccresults.rows.Where{$_.Field -eq 'dbi_dbccLastKnownGood'}[0].value 
            }
            else
            {
            $LastDBCCDate = $null
            }
			$lastusedinfo = $dblastused | Where-Object { $_.dbname -eq $db.name }
			$lastread = $lastusedinfo.last_read
			$lastwrite = $lastusedinfo.last_write
			
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
				$Update
			)
		}
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

