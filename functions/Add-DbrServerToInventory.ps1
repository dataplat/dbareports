Function Add-DbrServerToInventory
{
<#
.SYNOPSIS 
Adds an instance or an array of instances to the dbareports database using the config file
.DESCRIPTION
This command will add a SQL Instance or an array of instances to the dbareports database using the config file generated at install or via the dbrclient command

.PARAMETER SqlInstance
The instance or array of instances to add
.PARAMETER SqlInstanceCredential
The credential to connect to the dbareports database
.PARAMETER Port
The Port of the Instance to be added (if not specified then this is gathered)
.PARAMETER Environment
The terminology that you and your users use to define the environment the instance is in. Suggested examples are Prod or Production, Test, UAT, QA, PreProd, ProductionSupport,Development, etc
.PARAMETER Location
The terminology that you and your users use to define the location of the instance. It could be the town or city that the data centre is in or the name of the office etc

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Add-DbrServerToInventory

.EXAMPLE
Add-DbrServerToInventory sql2016
	
Adds the SQL Server instance "sql2016" to the inventory then does XYZ

.EXAMPLE
Add-DbrServerToInventory sql2016, sql2014
	
Adds the SQL Server instances sql2016 and sql2014 to the inventory then does XYZ
#>
	[CmdletBinding()]
	Param (
		[parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[string[]]$SqlInstance,
		[object]$SqlInstanceCredential,
		[int]$Port,
		[string]$Environment,
		[string]$Location
	)
	
	BEGIN
	{
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		if ($SqlServer.length -eq 0)
		{
			throw "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient"
		}
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		
		# Get columns automatically from the table on the SQL Server
		# and creates the necessary $script:datatable with it
		$table = "dbo.InstanceList"
		$schema = $table.Split(".")[0]
		$tablename = $table.Split(".")[1]
		Initialize-DataTable
		
		# Go get list of instances
		try
		{
			$sql = "SELECT * FROM [dbo].[InstanceList]"
			$allservers = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
		}
		catch
		{
			Write-Exception $_
			throw "Can't get InstanceList in the $InstallDatabase database on $($sourceserver.name)."
		}
        
        # Go get a list of SERVERS :-)
		try
		{
			$sql = "SELECT ServerID,ServerName FROM [info].[ServerInfo]"
			$TheServers = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
		}
		catch
		{
			Write-Exception $_
			throw "Can't get ServerName in the $InstallDatabase database on $($sourceserver.name)."
		}
	}
	
	PROCESS
	{
		foreach ($server in $SqlInstance)
		{
			try
			{
			    try
                {
                    $smoserver = Connect-SqlServer -SqlServer "TCP:$Server" -SqlCredential $SqlInstanceCredential 
				}
                catch
                {
                    Write-Output "TCP connection failed for $Server trying again without"
                    $smoserver = Connect-SqlServer -SqlServer "$Server" -SqlCredential $SqlInstanceCredential
                }
				$ComputerName = $smoserver.ComputerNamePhysicalNetBIOS
				$ServerName = $smoserver.NetName
				$isclustered = $smoserver.IsClustered
				$InstanceName = $smoserver.InstanceName
				$name = $smoserver.Name.Replace("TCP:","")
				$NotContactable = $False
				
				if ($InstanceName.length -eq 0)
				{
					$InstanceName = "MSSQLSERVER"
				}
			}
			catch
			{
				Write-Warning "Couldn't contact $Server. Marked as NotContactable."
				$NotContactable = $true
                $Name = $server
			}
			
			$row = $allservers.Rows | Where-Object { $_.InstanceName -eq $InstanceName -and $_.ComputerName -eq $ComputerName }
			$key = $row.InstanceId
									
			if ($key -eq $null)
			{
				$update = $false
			}
			else
			{
				Write-Output "$Server already exists in database. Updating information."
				$update = $true
			}
            
            $row = $TheServers.Rows | Where-Object {$_.ServerName -eq $ComputerName }
			$Serverkey = $row.ServerId
            $Exists = $false
            if($datatable.rows.count -gt 0)
            {
            $exists = $datatable.Rows.ComputerName.Contains($ComputerName)
			}
            else
            {
            $exists = $false
            }	
            Write-output "Exists = $Exists for $Server"		## trouble shooting			
			if ($Serverkey -eq $null)
			{
				if($exists -eq $false)
                {
                    $update = $false
                try
			    	{
                        $sql = "INSERT INTO [info].[ServerInfo] ([ServerName]) VALUES ('$ComputerName')"
                        $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
                        Write-Output "Added $ComputerName to ServerInfo Table"
                    }
                catch
                    {
                    	Write-Exception $_
			            return "Server insert failed Quitting"
                    }
			    }
                else
			    {
			    	Write-Output "$ComputerName already exists in datatable. Moving On."
                    break
			    }
            }
			else
			{
				Write-Output "$ComputerName already exists in database. Updating information."
			}


            try
				{
                    $sql = "SELECT [ServerId] FROM [info].[ServerInfo] WHERE Servername = '$ComputerName'"
                    $serverid = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables.ServerId
                }
            catch
                {
                	Write-Exception $_
			        return "Failed to Get ServerId from Serverinfo Table"
                }
			
			
			if ($Port -eq 0 -and $NotContactable -eq $false)
			{
				try
				{
					# WmiComputer is unreliable :( Use T-SQL
					$sql = "SELECT local_tcp_port FROM sys.dm_exec_connections WHERE session_id = @@SPID"
					$Port = $smoserver.ConnectionContext.ExecuteScalar($sql)
				}
				catch
				{
					Write-Warning "Port could not be determined for $ServerName. Skipping."
					Continue
				}
			}
			
			if ($isclustered -eq $true)
			{
				$sql = "Select NodeName  FROM sys.dm_os_cluster_nodes"
				$nodes = $smoserver.ConnectionContext.ExecuteWithResults($sql).Tables.NodeName
				
				foreach ($node in $nodes)
				{
					if ($SqlInstance -notcontains $node -and $computername -ne $node)
					{
						$row = $allservers.Rows | Where-Object { $_.ComputerName -eq $node }
						$nodekey = $row.InstanceId
												
						if ($nodekey -eq $null)
						{
							$nodeupdate = $false
						}
						else
						{
							$nodeupdate = $true
						}
						
						Write-Warning "Added clustered node $node to server collection."
						
						# Populate the datatable
						$datatable.rows.Add(
							$nodekey,
                            $serverid,
							$name,
							$node,
							$servername,
							$InstanceName,
							$isclustered,
							$port,
							0,
							$Environment,
							$Location,
							$NotContactable,
							$nodeupdate
						)
					}
				}
			}
			
			# Populate the datatable
			$datatable.rows.Add(
				$key,
                $serverid,
				$name,
				$computername,
				$servername,
				$InstanceName,
				$isclustered,
				$port,
				0,
				$Environment,
				$Location,
				$NotContactable,
				$Update
			)
		}
		
		$rowcount = $datatable.Rows.Count
		
		if ($rowcount -eq 0)
		{
			Write-Output "No rows returned. No update required."
			continue
		}
		
		
		if ($Update -eq $true)
		{
			Write-Output "Updating $rowcount row(s)"
		}
		else
		{
			Write-Output "Adding $rowcount row(s)"
		}
		try
		{
			Write-Tvp
			
		}
		catch
		{
			Write-Exception $_
			return "Bulk insert failed. Recording exception and quitting."
		}
		
		$execaccount = $sourceserver.JobServer.ServiceAccount
		$testjob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Test*" } | Select-Object -First 1
		$proxy = $testjob.JobSteps[0].ProxyName
		
		if ($proxy.length -gt 0)
		{
			$proxydetails = $sourceserver.JobServer.ProxyAccounts[$proxy]
			$proxycredential = $proxydetails.CredentialIdentity
			$execaccount = "$proxy ($proxycredential)"
		}
		
		$successful = $SqlInstance -join ", "
		Write-Output "Checking to see if $execaccount has access to $successful."
		
		try
		{
			$agentserverjob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Test Access to Servers and Log Directory" }
			if ($agentserverjob.CurrentRunStatus -eq "Idle")
			{
				$agentserverjob.Start()
			}
			do
			{
				Start-Sleep -Milliseconds 200
			}
			until ($agentserverjob.CurrentRunStatus -eq "Idle" -or ++$i -eq 20)
			
			
			if ($agentserverjob.LastRunOutcome -eq "Failed")
			{
				Write-Warning "$execaccount cannot access one of the instances in InstanceList. Check dat."
			}
			else
			{
				Write-Output "Lookin' good! $execaccount successfully logged in to $successful."
			}
			
			if ($update -ne $true)
			{
				Write-Output "Populating a few other tables with the info for $successful while we're at it."
				
				try
				{
					Write-Output "Starting Agent Job Server job"
					$agentserverjob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Agent Job Server*" }
					$agentserverjob.Start()
					
					Write-Output "Starting Windows Server Information job"
					$winserverInfoJob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Windows Server Information*" }
					$winserverInfoJob.Start()
					
					Write-Output "Starting SQL Server Information job"
					$sqlserverinfojob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - SQL Server Information*" }
					$sqlserverinfojob.Start()
					
					Write-Output "Done!"
				}
				catch
				{
					Write-Output "Well that didn't go as planned. Please ensure that SQL Server Agent is running on $sqlserver"
					Write-Exception $_
				}
			}
		}
		catch
		{
			Write-Output "The Agent Job on $sqlserver cannot contact all servers in the InventoryList. Check job history for details."
			Write-Exception $_
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}