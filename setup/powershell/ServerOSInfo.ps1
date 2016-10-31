<#
 Hopefully this fixes this bit                    # This currently doesn't work so well with clusters. Will have to slightly reorg database?
                     # I dont know if the above is still true. Plz evaluate. I think it is.

Other useful things
$system.Manufacturer
$system.Model
Lots of stuff in OS
Yes this should alll be added

#>
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
	# this will come much later
	[string]$InstallDatabase = "--installdb--",
	[string]$LogFileFolder = "--logdir--"
)

BEGIN
{
	# Create Log File 
	$Date = Get-Date -Format yyyyMMdd_HHmmss
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_ServerOSInfo_' + $Date + '.txt'
	try
	{
		New-item -Path $LogFilePath -itemtype File -ErrorAction Stop 
		Write-Log -path $LogFilePath -message "ServerOSInfo Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}
	
	# Specify table name that we'll be inserting into
	$table = "info.ServerInfo"
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
		$sql = "SELECT ServerName, ServerID FROM $table"
		$table = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
		Write-Log -path $LogFilePath -message "Got the list of servers from the dbareports database" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Can't get server list from $InstallDatabase on $($sourceserver.name). - $_" -level Error
	}
	
	foreach ($server in $sqlservers)
	{
		$sqlservername = $server.ServerName
		$InstanceName = $server.InstanceName
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
		$update = $true
		
		$row = $table | Where-Object { $_.Servername -eq $SqlserverName }
		$key = $row.ServerID
		
		if ($key.count -eq 0)
		{
			$update = $false
		}
		
		if ($datatable.Rows.ServerName -contains $sqlservername)
		{
			$update = $true
		}
		
		try
		{
			$ipaddr = Resolve-SqlIpAddress $sqlservername
		}
		catch
		{
			$ipaddr = Resolve-IpAddress $sqlservername
		}
		
		if ($ipaddr -eq $null)
		{
			Write-Log -path $LogFilePath -message "Could not resolve IP address for $ServerName. Moving on." -level info
			Write-Log -path $LogFilePath -message "Tried Resolve-SqlIpAddress $ServerName and Resolve-IpAddress $servername"
			continue
		}
		
		try
		{
			Write-Log -path $LogFilePath -message "Getting System WMI from $ipaddr" -level info
			$system = Get-WmiObject Win32_ComputerSystem -ComputerName $ipaddr -ErrorAction Stop 
			Write-Log -path $LogFilePath -message "Getting OS WMI from $ipaddr" -level info
			$os = Get-WmiObject Win32_OperatingSystem -ComputerName $ipaddr -ErrorAction Stop
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Failed to get WMI from  $ipaddr - $_" -level Warn
			continue
		}
		
		$ram = '{0:n0}' -f ($system.TotalPhysicalMemory/1gb)
		
		# to see results as they come in, skip $null=
		try
		{
			$Null = $datatable.Rows.Add(
			$key,
			$DateChecked,
			$SQLServerName,
			$system.DNSHostName,
			$system.Domain,
			$os.Caption,
			$system.NumberOfLogicalProcessors,
			$ipaddr,
			$ram,
			$Update)
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Failed to add Job to datatable - $_" -level Error
			Write-Log -path $LogFilePath -message "Data = $key,
			$DateChecked,
			$SQLServerName,
			$system.DNSHostName,
			$system.Domain,
			$os.Caption,
			$system.NumberOfLogicalProcessors,
			$ipaddr,
			$ram,
			$Update" -level Warn
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
		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of Server OS Info into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "ServerOS Finished"
	$sourceserver.ConnectionContext.Disconnect()
}
