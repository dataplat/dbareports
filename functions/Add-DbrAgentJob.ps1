Function Add-DbrAgentJob
{
<#
.SYNOPSIS 
Creates a singel step SQL Agent job using the dba configuration

.DESCRIPTION
This will create a SQL Agent Job. It will use the configuration from the dbareports install and create the job on the the dbareports folder

.PARAMETER JobName
The name of the JOb

.PARAMETER LogFileFolder
The folder to hold the log files for the job. The SQL Agent account needs to be able to access this path. Defaults to the dbareports install log file location

.PARAMETER Description 
This is the description of the job which should accurately describe what it does :-)). There is a default dbareports description	

.PARAMETER Category 
The Job Category. This will be created if it does not exist. Defaults to dbareports collection jobs
	
.PARAMETER Command
The command that the single job step will run

.PARAMETER OwnerLoginName
The account that shall be the Owner of the Agent Job
	
.PARAMETER Subsystem
THe subsystem that the single job step will use. Defaults to PowerShell. Options are 'ActiveScripting', 'AnalysisCommand', 'AnalysisQuery', 'CmdExec', 'Distribution', 'LogReader', 'Merge', 'PowerShell', 'QueueReader', 'Snapshot', 'Ssis', 'TransactSql'
		
.PARAMETER JobCredential
The Job Credential Object

.PARAMETER Force
If a job of the same name exists it will be dropped and created with the script

.PARAMETER Confirm
Prompts for comfirmation for actions

.PARAMETER WhatIf
Writes out the actions that would be taken

.PARAMETER ProxyAccount
A dynamic parameter

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Verb-SqlNoun

.EXAMPLE
Add-DbrAgentJob -JobName 'Agent Job to gather information' -LogFileFolder 'H:\LogFiles' -Description 'THis agent job will gather information and will log to this folder' -Category 'dba collection jobs' -OwnerLoginName 'THEBEARD\Rob' -Command $GatheringScript -Subsystem TransactSql 

This will add a Job called 'Agent Job to gather information' which will log to 'H:\LogFiles' and have a single TSQL Step which will run the TSQL stored in the $GatheringScript variable and the owner will be the THEBEARD\Rob account. It will be created on the dbareports server
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[string]$JobName,
		[string]$LogFileFolder,
		[string]$Description = "This is the dbareports data collector job called $JobName (Which, we hope, should accurately describe what it does :-)). It will use the dbo.instabncelist table and it will output to a log file located at $LogFileFolder More information can be found at dbareports.io",
		[parameter(Mandatory = $false)]
		[string]$Category = "dbareports collection jobs",
		[parameter(Mandatory = $false)]
		[string]$OwnerLoginName,
		[string]$Command,
		[ValidateSet('ActiveScripting', 'AnalysisCommand', 'AnalysisQuery', 'CmdExec', 'Distribution', 'LogReader', 'Merge', 'PowerShell', 'QueueReader', 'Snapshot', 'Ssis', 'TransactSql')]
		[string]$Subsystem = 'PowerShell',
		[parameter(Mandatory = $false)]
		[object]$JobCredential,
        [parameter(Mandatory = $false)]
		[switch]$Force
	)
	
	DynamicParam
	{
		Get-Config
		if ($script:SqlServer) { return (Get-ParamSqlProxyAccount -SqlServer $script:SqlServer -SqlCredential $script:SqlCredential) }
	}
		
	BEGIN
	{
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		$proxyaccount = $psboundparameters.ProxyAccount
		if ($proxyaccount -eq "None") { $proxyaccount = $null }
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		$jobserver = $sourceserver.jobserver
		
		if ($OwnerLoginName.Length -eq 0)
		{
			$OwnerLoginName = ($sourceserver.logins | Where-Object { $_.id -eq 1 }).Name
		}
		
		if ($jobserver.JobCategories[$category] -eq $null)
		{
			New-DbrAgentJobCategory -JobServer $jobserver -CategoryName $Category
		}
	}
	
	PROCESS
	{
		if ($jobserver[$jobname] -ne $null)
		{
			if ($Force -eq $false)
			{
				throw "Job already exists and Force was not speified"
			}
			else
			{
				$jobserver[$jobname].Drop()
				$jobserver.Refresh()
			}
		}
		
		try
		{
			$job = New-Object Microsoft.SqlServer.Management.SMO.Agent.Job($jobServer, $Jobname)
			
			$job.Description = $Description
			$job.OwnerLoginName = $OwnerLoginName
			$job.Category = $Category
			$job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
			$job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
			$job.PageLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
			$job.Create()
			
			$stepname = "Run $Command"
			if ($stepname.Length -gt 125) { $stepname = $stepname.Substring(0, 100) }
			$jobstep = New-Object Microsoft.SqlServer.Management.SMO.Agent.JobStep($job, $stepname)
			$jobstep.OnSuccessAction = [Microsoft.SqlServer.Management.SMO.Agent.StepCompletionAction]::QuitWithSuccess
			$jobstep.OnFailAction = [Microsoft.SqlServer.Management.SMO.Agent.StepCompletionAction]::QuitWithFailure
			$jobstep.ProxyName = $proxyaccount
			$jobstep.Command = $command
			$jobstep.DatabaseName = $InstallDatabase
			$jobstep.SubSystem = $Subsystem
			$jobstep.Create()
		}
		catch
		{
			Write-Exception $_
			throw "The script just couldn't today."
		}
		
		$job.ApplyToTargetServer("(local)")
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}