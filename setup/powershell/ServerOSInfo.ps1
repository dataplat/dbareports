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
	# Specify table name that we'll be inserting into
	$table = "info.ServerInfo"
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
	$DateChecked = Get-Date
	$servers = Get-Instances
	
	# Get list of all servers already in the database
	try
	{
		$sql = "SELECT ServerName, ServerID FROM $table"
		$table = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
	}
	catch
	{
		Write-Exception $_
		throw "Can't get server list from $InstallDatabase on $($sourceserver.name)."
	}
	
	foreach ($server in $servers)
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
		
		# Connect to dbareports server
		$server = Connect-SqlServer -SqlServer $Connection
		
		Write-Output "Processing $Connection"
		
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
			Write-Output "Could not resovle IP address for $sqlServerName. Moving on."
			continue
		}
		
		try
		{
			$system = Get-WmiObject Win32_ComputerSystem -ComputerName $ipaddr
			$os = Get-WmiObject Win32_OperatingSystem -ComputerName $ipaddr
		}
		catch
		{
			Write-Exception $_
			Write-Output "Could not connect to WMI on $SqlserverName. Recording exception and moving on."
			continue
		}
		
		$ram = '{0:n0}' -f ($system.TotalPhysicalMemory/1gb)
		
		# to see results as they come in, skip $null=
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
			$Update
		)
		Write-Output "Added row for $sqlServerName"
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

