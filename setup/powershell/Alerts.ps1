<#
.SYNOPSIS  
This Script will check all of the instances in the InstanceList and gather the Alerts Information to the info.Alerts table

.DESCRIPTION 
This Script will check all of the instances in the InstanceList and gather the Alerts Information to the info.Alerts table

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
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_Alerts_' + $Date + '.txt'
	try
	{
		New-item -Path $LogFilePath -itemtype File -ErrorAction Stop 
		Write-Log -path $LogFilePath -message "Alerts Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}
		
	# Specify table name that we'll be inserting into
	$table = "info.Alertss"
	$schema,$tablename = $table.Split(".")
	
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

	# Get list of all Alerts already in the database
	try
	{
		Write-Log -path $LogFilePath -message "Getting a list of alerts from the dbareports database" -level info
		$sql = "SELECT AlertsID, Name, InstanceID FROM $table"
		$ExistingAlerts = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
		Write-Log -path $LogFilePath -message "Got the list of alerts from the dbareports database" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Can't get alerts list from $InstallDatabase on $($sourceserver.name). - $_" -level Error
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
		
		foreach($Alert in $srv.JobServer.Alerts)

 		{

    		$LastOccurrenceDate = $Alert.LastOccurrenceDate
			if ($LastOccurrenceDate -eq '01/01/0001 00:00:00') 
			{ 
				$LastOccurrenceDate = $null 
			} 

    		$LastResponseDate =  $Alert.LastResponseDate
			if ($LastResponseDate -eq '01/01/0001 00:00:00') 
			{ 
				$LastResponseDate = $null 
			} 

    		if($Alert.WmiEventQuery)
			{
				$WmiEventQuery = $Alert.WmiEventQuery.Replace("'","''")
			}

			# Check for existing alerts
			$record = $ExistingAlerts| Where-Object { $_.Name -eq $Alert.name -and $_.InstanceId -eq $InstanceID }
			$key = $record.AlertsID
			$update = $true
			
			if ($key.count -eq 0)
			{
				$update = $false
			}

			try
			{
				$null = $datatable.rows.Add(
				$key,
				$Date,
				$InstanceID,
				$($Alert.Name),
				$($Alert.Category),
 				$($Alert.DatabaseID),
 				$($Alert.DelayBetweenResponses),
 				$($Alert.EventDescriptionKeyword),
 				$($Alert.EventSource),
 				$($Alert.HasNotification),
 				$($Alert.IncludeEventDescription),
 				$($Alert.IsEnabled),
 				$($Alert.AgentJobDetailID),
 				$($Alert.LastOccurrenceDate),
 				$($Alert.LastResponseDate),
 				$($Alert.MessageID),
 				$($Alert.NotificationMessage),
 				$($Alert.OccurrenceCount),
 				$($Alert.PerformanceCondition),
 				$($Alert.Severity),
 				$($Alert.WmiEventNamespace),
 				$($Alert.WmiEventQuery),
				$Update
				)
			}
			catch
			{
				Write-Log -Message "Failed to add Alert Information to the datatable - $_" -Level Error
				Write-Log -Message "Data is $key,
				$Date,
				$InstanceID,
				$($Alert.Name),
				$($Alert.Category),
 				$($Alert.DatabaseID),
 				$($Alert.DelayBetweenResponses),
 				$($Alert.EventDescriptionKeyword),
 				$($Alert.EventSource),
 				$($Alert.HasNotification),
 				$($Alert.IncludeEventDescription),
 				$($Alert.IsEnabled),
 				$($Alert.AgentJobDetailID),
 				$($Alert.LastOccurrenceDate),
 				$($Alert.LastResponseDate),
 				$($Alert.MessageID),
 				$($Alert.NotificationMessage),
 				$($Alert.OccurrenceCount),
 				$($Alert.PerformanceCondition),
 				$($Alert.Severity),
 				$($Alert.WmiEventNamespace),
 				$($Alert.WmiEventQuery),
				$Update"
				continue
			}
	    } #End foreach ALerts
    }#End foreach Servers
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
		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of Alerts into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "Alerts Finished"
	$sourceserver.ConnectionContext.Disconnect()
}