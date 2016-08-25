<#
Hopefully fixed please check      # This currently doesn't work so well with clusters. Will have to slightly reorg database?
      # I dont know if the above is still true. Plz evaluate. I think it is.

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
	[string]$InstallDatabase = "--installdb--",
	[string]$LogFileFolder = "--logdir--"
)

BEGIN
{
	# Specify table name that we'll be inserting into
	$table = "info.DiskSpace"
	$schema = $table.Split(".")[0]
	$tablename = $table.Split(".")[1]
	
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	
	# Start Transcript
	$Date = Get-Date -Format ddMMyyyy_HHmmss
	$transcript = "$LogFileFolder\$table" + "_" + "$Date.txt"
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
		$sql = "SELECT a.DiskSpaceID, a.DiskName, b.ServerID, b.ServerName FROM $table a JOIN info.Serverinfo b on a.ServerId = b.ServerId"
		$table = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
	}
	catch
	{
		Write-Exception $_
		throw "Can't get server list from $InstallDatabase on $($sourceserver.name)."
	}
	
	foreach ($server in $servers)
	{
		$ServerName = $server.ServerName
		$ServerId = $server.ServerId
		$date = Get-Date
		
		Write-Output "Processing $ServerName"
		try
		{
			$ipaddr = Resolve-SqlIpAddress $ServerName
		}
		catch
		{
			$ipaddr = Resolve-IpAddress $servername
		}
		
		if ($ipaddr -eq $null)
		{
			Write-Output "Could not resovle IP address for $ServerName. Moving on."
			continue
		}
		
		try
		{
			$query = "Select SystemName, Name, DriveType, FileSystem, FreeSpace, Capacity, Label, BlockSize from Win32_Volume where DriveType = 2 or DriveType = 3"
			$disks = Get-WmiObject -ComputerName $ipaddr -Query $query | Sort-Object -Property Name
		}
		catch
		{
			Write-Exception $_
			Write-Output "Could not connect to WMI on $ServerName. Recording exception and moving on."
			continue
		}
		
		foreach ($disk in $disks)
		{
			$diskname = $disk.name
			if (!$diskname.StartsWith("\\"))
			{
				$update = $true
				$row = $table | Where-Object { $_.DiskName -eq $DiskName -and $_.ServerId -eq $ServerId}
				$key = $row.DiskSpaceID
				
				if ($key.count -eq 0)
				{
					$update = $false
				}
				
				$total = "{0:f2}" -f ($disk.Capacity/1gb)
				$free = "{0:f2}" -f ($disk.Freespace/1gb)
				$percentfree = "{0:n0}" -f (($disk.Freespace / $disk.Capacity) * 100)
				
				# to see results as they come in, skip $null=
				$datatable.Rows.Add(
					$key,
					$Date,
					$ServerId ,
					$diskname,
					$disk.Label,
					$total,
					$free,
					$percentfree,
					$Update)
			}
		}
		Write-Output "Adding $diskname for $ServerName"
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

