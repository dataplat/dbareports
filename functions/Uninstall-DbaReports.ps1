Function Uninstall-DbaReports
{
<#
.SYNOPSIS 


.DESCRIPTION


.PARAMETER 


.PARAMETER 


.PARAMETER 
	

.PARAMETER 

	
.PARAMETER 

	
.PARAMETER 
	

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Verb-SqlNoun

.EXAMPLE
Verb-SqlNoun
Copies all policies and conditions from sqlserver2014a to sqlcluster, using Windows credentials. 


.EXAMPLE   
Verb-SqlNoun -WhatIf
Shows what would happen if the command were executed.
	
.EXAMPLE   
Verb-SqlNoun -Policy 'xp_cmdshell must be disabled'
Does this 
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
	Param (
		[string]$JobCateogry = "dbareports collection jobs",
		[switch]$NoDatabase,
		[switch]$NoJobs,
		[switch]$NoPsFiles,
		[switch]$Force
	)
	
	DynamicParam { if ($SqlServer) { return (Get-ParamSqlProxyAccount -SqlServer $SqlServer -SqlCredential $SqlCredential) } }
	
	BEGIN
	{
		
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		If ($Force -eq $true) { $ConfirmPreference = 'None' }
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		
		$props = Get-ExtendedProperties
		
		$eppath = $props | Where-Object Name -eq 'dbareports installpath'
		$eplogpath = $props | Where-Object Name -eq 'dbareports logfilefolder'
		
		$InstallPath = $eppath.Value
		$LogFileFolder = $eplogpath.Value
		
		if ($InstallPath -notlike "*dbareports*")
		{
			$InstallPath = "$InstallPath\dbareports"
		}
		
		if ($source -ne $env:COMPUTERNAME)
		{
			# Delete files over UNC
			$InstallPath = Join-AdminUnc $Source $InstallPath
			$LogFileFolder = Join-AdminUnc $Source $LogFileFolder
		}
		
		# check if database exists
		$sql = "select count(*) as dbcount from master.dbo.sysdatabases where name = '$InstallDatabase'"
		[bool]$dbexists = $sourceserver.ConnectionContext.ExecuteScalar($sql)
		
		if ($dbexists -eq $false -and $NoDatabase -eq $false)
		{
			throw "$InstallDatabase does not exist on $sqlserver"
		}
		
		$fileexists = Test-Path $InstallPath
		
		if ($fileexists -eq $false -and $NoPsFiles -eq $false)
		{
			throw "$InstallPath does not exist or access denied"
		}
	}
	
	PROCESS
	{
		if ($NoPsFiles -eq $false)
		{
			If ($Pscmdlet.ShouldProcess($sqlserver, "Deleting $LogFileFolder"))
			{
				Write-Output "Deleting $LogFileFolder"
				Remove-Item $LogFileFolder -Force -Recurse
			}
			
			If ($Pscmdlet.ShouldProcess($sqlserver, "Deleting $InstallPath"))
			{
				Write-Output "Deleting $InstallPath"
				Remove-Item $InstallPath -Force -Recurse
			}
			
			$clientconfig = Get-ConfigFileName
			If ($Pscmdlet.ShouldProcess($sqlserver, "Removing local config file at $clientconfig"))
			{
				Write-Output "Deleting $clientconfig"
				Remove-Item $clientconfig -Force -ErrorAction SilentlyContinue
			}
		}
		
		if ($NoDatabase -eq $false)
		{
			$now = Get-Date
			$lastfull = $sourceserver.Databases[$InstallDatabase].LastBackupDate
			$lastlog = $sourceserver.Databases[$InstallDatabase].LastLogBackupDate
			
			if (($now - $lastfull).Days -gt 0) { $prompt = $true }
			if (($now - $lastlog).Days -gt 0) { $prompt = $true }
			
			if ($prompt -eq $true -and $Force -eq $false)
			{
				If ($Pscmdlet.ShouldProcess("console", "Prompting to confirm drop of database with no recent backups"))
				{
					$title = "A backup of $InstallDatabase has not been performed within the last day."
					$message = "Are you sure you'd like to drop the dbareports database? (Y/N)"
					$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will continue"
					$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will exit"
					$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
					$result = $host.ui.PromptForChoice($title, $message, $options, 0)
					
					if ($result -eq 1)
					{
						Write-Output "Skipping database drop"
					}
				}
			}
			
			If ($Pscmdlet.ShouldProcess($sqlserver, "Dropping database $InstallDatabase"))
			{
				if ($result -ne 1)
				{
					try
					{
						Write-Output "Dropping database $InstallDatabase"
						$sql = "ALTER DATABASE [$InstallDatabase] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE"
						$null = $sourceserver.ConnectionContext.ExecuteNonQuery($sql)
						
						$sql = "DROP DATABASE [$InstallDatabase]"
						$null = $sourceserver.ConnectionContext.ExecuteNonQuery($sql)
					}
					catch
					{
						$null = $sourceserver.KillDatabase($InstallDatabase)
					}
				}
			}
		}
		
		if ($NoJobs -eq $false)
		{
			If ($Pscmdlet.ShouldProcess($sqlserver, "Deleting Agent Jobs and Job Category"))
			{
				$dbrjobs = $sourceserver.JobServer.Jobs | Where-Object { $_.Category -eq $JobCateogry }
				
				foreach ($job in $dbrjobs)
				{
					$jobname = $job.name
					Write-Output "Dropping job $jobname"
					$job.Drop()
				}
				
				$schedules = $sourceserver.JobServer.SharedSchedules | Where-Object { $_.Name -like "*dbareports*" }
				foreach ($schedule in $schedules)
				{
					$schedulename = $schedule.name
					Write-Output "Dropping shared schedule $schedulename"
					$schedule.Drop()
				}
				
				$dbrcategory = $sourceserver.JobServer.JobCategories | Where-Object { $_.Name -eq $JobCateogry }
				Write-Output "Dropping job category $JobCateogry"
				$dbrcategory.drop()
				
			}
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
	}
}