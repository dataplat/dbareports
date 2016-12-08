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

.PARAMETER Confirm
Prompts you for confirmation before executing the command.

.PARAMETER WhatIf
This doesnt work as install is too dynamic. Show what would happen if the cmdlet was run.

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/functions/Add-DbrServerToInventory

.EXAMPLE
Add-DbrServerToInventory sql2016
	
Adds the SQL Server instance "sql2016" to the inventory then takes additional steps determined by the content of the config file.

.EXAMPLE
Add-DbrServerToInventory sql2016, sql2014
	
Adds the SQL Server instances sql2016 and sql2014 to the inventory then takes additional steps determined by the content of the config file.
#>
	[CmdletBinding(SupportsShouldProcess = $true)] 
	[OutputType([string])]
	Param (
		[parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[Alias("SqlServer", "ServerInstance")]
		[string[]]$SqlInstance,
		[object]$SqlInstanceCredential,
		[int]$Port,
		[string]$Environment,
		[string]$Location
	)
	
	BEGIN
	{
		try	
    	{
      		$docs = [Environment]::GetFolderPath("MyDocuments")
      		$Date = Get-Date -format yyyyMMddhhmmss

      		If ($PSCmdlet.ShouldProcess("Creating LogFile")) 
      		{ 
        		$LogFile = New-Item "$docs\dbareports_ADD-DBRServerToInventory_$Date.txt" -ItemType File -ErrorAction Stop
      		}
    	}
    	catch
    	{
      		Write-Warning "Failed to create log file please see error below"
      		Write-Error $_
     		Write-Output "You can find the install log here $($Logfile.FullName)- IF it managed to create it!"
      		break

    	}
    	$LogFilePath = $LogFile.FullName
    	Write-Output "Log filepath for install is $LogFilePath"

		try 
		{

				  Get-Config
			
		}
		catch 
		{
			Write-Log -path $LogFilePath -message "Get-Config Failed to run - $_" -Level Error
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
		}
		
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		if ($SqlServer.length -eq 0)
		{
			Write-Log -path $LogFilePath -message "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient" -Level Warn
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
		}
		
		try
		{
			If ($PSCmdlet.ShouldProcess("Connecting to $sqlserver")) 
      		{ 
				  $sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
			}
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Failed to connect to $sqlserver - $_ " -Level Error
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
			break
		}
		
		# Get columns automatically from the table on the SQL Server
		# and creates the necessary $script:datatable with it
		$table = "dbo.InstanceList"
		$schema = $table.Split(".")[0]
		$tablename = $table.Split(".")[1]

		try 
		{
			If ($PSCmdlet.ShouldProcess("Initialise the Datatable")) 
      		{ 
				Initialize-DataTable
                Write-Log -path $LogFilePath -message "Intialised the datatable for $table" -Level Info
                $Column = New-Object system.Data.DataColumn update, ([boolean]) 
                $null = $datatable.Columns.Add($column) 
                Write-Log -path $LogFilePath -message  "Added update of bit" -Level Info
			}
		}
		catch  
		{
			Write-Log -path $LogFilePath -message "Failed to Intialise the datatable for $table - $_ " -Level Error
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
			break			
		}
		
		
		# Go get list of instances
		try
		{
			$sql = "SELECT * FROM [dbo].[InstanceList]"
			$allservers = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Can't get InstanceList in the $InstallDatabase database on $($sourceserver.name). - $_" -Level Error
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
			break	
		}
        
        # Go get a list of SERVERS :-)
		try
		{
			$sql = "SELECT ServerID,ServerName FROM [info].[ServerInfo]"
			$TheServers = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
		}
		catch
		{
			Write-Log -path $LogFilePath -message "Can't get ServerName in the $InstallDatabase database on $($sourceserver.name). - $_" -Level Error
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
			break	
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
                    Write-Log -path $LogFilePath -message "TCP connection failed for $Server trying again without" -Level Warn
                    $smoserver = Connect-SqlServer -SqlServer "$Server" -SqlCredential $SqlInstanceCredential
                }
				 # If localhost or . entered and server being added then $port is not retrieved unless connection made with server name
				 if ($smoserver.ConnectionContext.ServerInstance -eq 'localhost' -or $smoserver.ConnectionContext.ServerInstance -eq '.' )
 				{
    				try
					{
						$smoserver.ConnectionContext.Disconnect()
    					$Connection = "TCP:$($smoserver.ComputerNamePhysicalNetBIOS)"
    					$smoserver  = New-Object Microsoft.SqlServer.Management.Smo.Server $Connection
					}
					catch
					{
						Write-Log -path $LogFilePath -message "TCP connection failed for TCP:$($smoserver.ComputerNamePhysicalNetBIOS)" -Level Error
						Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
						break	
					}
 				}
				$ComputerName = $smoserver.ComputerNamePhysicalNetBIOS
                if ($null -eq $ComputerName)
                {
                    $ComputerName = $smoserver.DomainInstanceName 
                }
				$ServerName = $smoserver.NetName
                if ($null -eq $ServerName)
                {
                    $ServerName = $smoserver.DomainInstanceName 
                }
				$isclustered = $smoserver.IsClustered
				$InstanceName = $smoserver.InstanceName
				$name = $smoserver.Name.Replace("TCP:","")
				$NotContactable = $False

               # Write-Output "ComputerName = $ComputerName" ## For troubleshooting
				
				if ($InstanceName.length -eq 0)
				{
					$InstanceName = "MSSQLSERVER"
				}
			}
			catch
			{
				Write-Log -path $LogFilePath -message "Couldn't contact $Server. Marked as NotContactable." -Level Warn
				$NotContactable = $true
                $Name = $server
			}
			
			$row = $allservers.Rows | Where-Object { $_.InstanceName -eq $InstanceName -and $_.ComputerName -eq $ComputerName }
			$key = $row.InstanceId
									
			if ($null -eq $key)
			{
				$update = $false
			}
			else
			{
				Write-Log -path $LogFilePath -message "$Server already exists in database. Updating information." -Level Warn
				$update = $true
			}
            
            $row = $TheServers.Rows | Where-Object {$_.ServerName -eq $ComputerName }

                        if($row.Count -gt 1)
            {
                Write-Log -Path $LogFilePath -Message "You appear to have duplicate entries for this ComputerName. Please Check Instance List table and resolve" -Level Error
                Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
                break
            }

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
            # Write-output "Exists = $Exists for $Server"		## trouble shooting			
			if ($null -eq $Serverkey)
			{
				if($exists -eq $false)
                {
                    $update = $false
                try
			    	{
                        $sql = "INSERT INTO [info].[ServerInfo] ([ServerName]) VALUES ('$ComputerName')"
                    	If ($PSCmdlet.ShouldProcess("Adding $ComputerName to  $InstallDatabase")) 
        				{
						 $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
						}
                        Write-Output "Added $ComputerName to ServerInfo Table"
                    }
                catch
                    {
                    	Write-Log -path $LogFilePath -message "Server insert FOR $Servername failed - $_" -Level Error
						Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
						break	
                    }
			    }
                else
			    {
			    	Write-Log -path $LogFilePath -message "$ComputerName already exists in datatable. Moving On." -Level Info
                    break
			    }
            }
			else
			{
				Write-Log -path $LogFilePath -message "$ComputerName already exists in database. Updating information." -Level info
			}


            try
				{
                    $sql = "SELECT [ServerId] FROM [info].[ServerInfo] WHERE Servername = '$ComputerName'"
                   # Write-Output $SQL ## For Troubleshooting
                    $serverid = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables.ServerId
                }
            catch
                {
                	Write-Log -path $LogFilePath -message "Failed to Get ServerId from Serverinfo Table - $_" -Level Warn
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
					Write-Log -path $LogFilePath -message "Port could not be determined for $ServerName. Skipping." -Level Warn
					Continue
				}
			}
			
			if ($isclustered -eq $true)
			{
				Write-Log -path $LogFilePath -message "$server is clustered - Grabbing Nodes" -Level Info
				$sql = "Select NodeName  FROM sys.dm_os_cluster_nodes"
				$nodes = $smoserver.ConnectionContext.ExecuteWithResults($sql).Tables.NodeName
				
				foreach ($node in $nodes)
				{
					if ($SqlInstance -notcontains $node -and $computername -ne $node)
					{
						$row = $allservers.Rows | Where-Object { $_.ComputerName -eq $node }

                        if($row.Count -gt 1)
                        {
                            Write-Log -Path $LogFilePath -Message "You appear to have duplicate entries for this ComputerName. Please Check Instance List table and resolve" -Level Error
                            Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
                            break
                        }

						$nodekey = $row.InstanceId
												
						if ($null -eq $nodekey)
						{
							$nodeupdate = $false
						}
						else
						{
							$nodeupdate = $true
						}
						
						Write-Log -path $LogFilePath -message "Added clustered node $node to server collection." -Level Info
						
						# Populate the datatable
						try
						{
							If ($PSCmdlet.ShouldProcess("Adding $Servername\$InstanceName to datatable")) 
      							{ 									
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
						catch
						{
							Write-Log -path $LogFilePath -message "Failed to add $servername\$InstanceName to the datatable - $_" -Level Error
							Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
							continue	
						}
					}
				}
			}
			
			try 
			{
				If ($PSCmdlet.ShouldProcess("Adding $Servername\$InstanceName to datatable")) 
      			{ 	
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
			}
			catch 
			{
				Write-Log -path $LogFilePath -message "Failed to add $servername\$InstanceName to the datatable - $_" -Level Error
                ## $datatable ## For Troubleshooting
				Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
				continue
			}
		}
		
		$rowcount = $datatable.Rows.Count
		
		if ($rowcount -eq 0)
		{
			Write-Log -path $LogFilePath -message "No rows returned. No update required." -Level Info
			continue
		}
		
		
		if ($Update -eq $true)
		{
			Write-Log -path $LogFilePath -message "Updating $rowcount row(s)" -Level Info
		}
		else
		{
			Write-Log -path $LogFilePath -message "Adding $rowcount row(s)" -Level Info
		}
		try
		{
			If ($PSCmdlet.ShouldProcess("Peforming bulk Insert of $rowcount rows")) 
      		{ 
				  Write-Tvp
			}
		}
		catch
		{
				Write-Log -path $LogFilePath -message "Bulk insert failed. Recording exception and quitting.- $_" -Level Error
				Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
				break
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
		Write-Log -path $LogFilePath -message "Checking to see if $execaccount has access to $successful." -Level Info
		
		try
		{
			$agentserverjob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Test Access to Servers and Log Directory" }
			if ($agentserverjob.CurrentRunStatus -eq "Idle")
			{
				If ($PSCmdlet.ShouldProcess("Starting Agent Job $($agentserverjob.name)")) 
        				{
							$agentserverjob.Start()
						}
			}
			do
			{
				Start-Sleep -Milliseconds 200
			}
			until ($agentserverjob.CurrentRunStatus -eq "Idle" -or ++$i -eq 20)
			
			
			if ($agentserverjob.LastRunOutcome -eq "Failed")
			{
				Write-Log -path $LogFilePath -message "$execaccount cannot access one of the instances in InstanceList. Check dat." -Level Warn
			}
			else
			{
				Write-Log -path $LogFilePath -message "Lookin' good! $execaccount successfully logged in to $successful." -Level Info
			}
			
			if ($update -ne $true)
			{
				Write-Log -path $LogFilePath -message "Populating a few other tables with the info for $successful while we're at it." -Level Info
				
				try
				{
					Write-Log -path $LogFilePath -message "Starting Agent Job Server job" -Level Info
					$agentserverjob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Agent Job Server*" }
					$agentserverjob.Start()
					
					Write-Log -path $LogFilePath -message "Starting Windows Server Information job" -Level Info
					$winserverInfoJob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - Windows Server Information*" }
					$winserverInfoJob.Start()
					
					Write-Log -path $LogFilePath -message "Starting SQL Server Information job" -Level Info
					$sqlserverinfojob = $sourceserver.JobServer.Jobs | Where-Object { $_.Name -like "*dbareports - SQL Server Information*" }
					$sqlserverinfojob.Start()
					
					Write-Log -path $LogFilePath -message "Done!" -Level Info
				}
				catch
				{
					Write-Log -path $LogFilePath -message "Well that didn't go as planned. Please ensure that SQL Server Agent is running on $sqlserver - $_" -Level Warn
					Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
				}
			}
		}
		catch
		{
			Write-Log -path $LogFilePath -message "The Agent Job on $sqlserver cannot contact all servers in the InventoryList. Check job history for details. - $_"
			Write-Output "Something went wrong - The Beard is sad :-( . You can find the install log here $($Logfile.FullName)"
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
    	$title = "Want to review the log?"
    	$message = "Would you like to review the log now? (Y/N)"
    	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will continue"
    	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will exit"
    	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    	$result = $host.ui.PromptForChoice($title, $message, $options, 0)
			
    	if ($result -eq 1) 
    	{ 
    	  Write-Output "K!" 
    	}
    	else
    	{
    	  notepad $LogFilePath
    	}
		
	}
}