Function Get-DbrAllInfo
{
<#
.SYNOPSIS 
Gets all of the information in the dbareports database about an instance

.DESCRIPTION
Gets all of the information in the dbareports database about an instance and displays it the screen or into a text file

.PARAMETER SQLInstance
The Server\Instance name to gather information about

.PARAMETER ToScreen
Outputs results to screen. This is default parameter

.PARAMETER FilePath
An optional filepath to have a text file with the information. File will be named \DBAReports_$ServerName" + "_" + $InstanceName + "_" + $Date + ".txt"

.PARAMETER Quiet
An optional parameter that will not display the output to the screen

.PARAMETER Confirm
Will prompt for confirmation

.PARAMETER WhatIf
Writes out the actions that would be taken

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
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
        [parameter(Mandatory = $True)]
        $SQLInstance,
		[parameter(Mandatory = $false)]
		[switch]$ToScreen,
		[parameter(Mandatory = $false)]
		[string]$Filepath,
		[parameter(Mandatory = $false)]
		[switch]$Quiet
	)
	
	DynamicParam
	{
		Get-Config
		if ($script:SqlServer) { return (Get-ParamSqlServerInventory -SqlServer $script:SqlServer -SqlCredential $script:SqlCredential) }
	}
	
	BEGIN
	{
		$ToScreen = $True
		
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		if ($SqlServer.length -eq 0)
		{
			throw "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient"
		}
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		
		$InstanceName = $SQLInstance.Split('\')[1]
		$ServerName = $SQLInstance.Split('\')[0]
        if ($InstanceName -eq $Null)
        {
        $InstanceName = 'MSSQLSERVER'
        }
	}
	
	PROCESS
	{
		$InstanceListsql = "/* Instance List info */
				SELECT IL.*	FROM $installdatabase.dbo.InstanceList IL
				WHERE IL.ServerName = '$servername' AND IL.InstanceName = '$InstanceName'"
		
		$OSSQL = "/*OS Info*/
				SELECT DISTINCT OS.* FROM $installdatabase.dbo.InstanceList IL
				JOIN $installdatabase.info.ServerInfo OS
				ON IL.ServerName = OS.ServerName
				WHERE IL.ServerName = '$servername'"
		
		$SQLInfoSQL = "/*SQL Info */
				SELECT SQL.*	FROM $installdatabase.dbo.InstanceList IL
				JOIN $installdatabase.info.SQLInfo SQL
				ON IL.InstanceID = SQL.InstanceID
				WHERE IL.ServerName = '$servername' AND IL.InstanceName = '$InstanceName'"
		
		$DatabaseSQL = "/*Database Info*/
				SELECT DB.*	FROM $installdatabase.dbo.InstanceList IL
				JOIN $installdatabase.info.Databases DB
				ON IL.InstanceID = DB.InstanceID
				WHERE IL.ServerName = '$servername' AND IL.InstanceName = '$InstanceName'"
		
		$AgentJobsServerSQL = "/*Agent Jobs Server Level*/
				SELECT AJS.*	FROM $installdatabase.dbo.InstanceList IL
				JOIN $installdatabase.info.AgentJobServer AJS
				ON IL.InstanceID = AJS.InstanceID
				WHERE IL.ServerName = '$servername' AND IL.InstanceName = '$InstanceName'"
		
		$AgentJobsDetailSQL = "/*Agent Jobs Detail Level*/
				SELECT AJd.*	FROM $installdatabase.dbo.InstanceList IL
				JOIN $installdatabase.info.AgentJobDetail AJD
				ON IL.InstanceID = AJD.InstanceID
				Where IL.ServerName = '$servername' AND IL.InstanceName = '$InstanceName'"
		
		$InstanceListInfo = $sourceserver.ConnectionContext.ExecuteWithResults($InstanceListsql).Tables
		$OSInfo = $sourceserver.ConnectionContext.ExecuteWithResults($OSSQL).Tables
		$SQLInfo = $sourceserver.ConnectionContext.ExecuteWithResults($SQLInfoSQL).Tables
		$DatabasesInfo = $sourceserver.ConnectionContext.ExecuteWithResults($DatabaseSQL).Tables
		$AgentJobServerInfo = $sourceserver.ConnectionContext.ExecuteWithResults($AgentJobsServerSQL).Tables
		$AgentJobDetailInfo = $sourceserver.ConnectionContext.ExecuteWithResults($AgentJobsDetailSQL).Tables
		
		if ($FilePath)
		{
			If ($Quiet)
			{
				$ToScreen = $false
			}
			try
			{
				$Date = Get-Date -Format dd-MM-yyyy-HH-mm-ss
				$FileName = $FilePath + "\DBAReports_$ServerName" + "_" + $InstanceName + "_" + $Date + ".txt"
				$null = New-Item -Path $FileName -ItemType File
			}
			catch
			{
				Write-Exception "FAILED : To create file $FileName"
				break
			}
			"Information from the dbareports about $ServerName\$InstanceName" | Out-File -FilePath $FileName
			"===============================================================`n" | Out-File -FilePath $FileName -Append
			"General Information`n" | Out-File -FilePath $FileName -Append
			$InstanceListInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Operating System Information from dbareports about $ServerName\$InstanceName `n" | Out-File -FilePath $FileName -Append
			$OSInfo | Out-File -FilePath $FileName -Append
			"SQL Instance Level Information from dbareports about $ServerName\$InstanceName `n" | Out-File -FilePath $FileName -Append
			$SQLInfo | Out-File -FilePath $FileName -Append
			"Database Information from dbareports about $ServerName\$InstanceName `n" | Out-File -FilePath $FileName -Append
			$DatabasesInfo | Out-File -FilePath $FileName -Append
			"Roll up Agent Job Information from dbareports about $ServerName\$InstanceName`n" | Out-File -FilePath $FileName -Append
			$AgentJobServerInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Agent JOb Detail Information from dbareports about $ServerName\$InstanceName `n" | Out-File -FilePath $FileName -Append
			$AgentJobDetailInfo | Out-File -FilePath $FileName -Append
			Write-Output "Information written to $FileName"
		}
		
		if ($ToScreen)
		{
			Write-Output "Information from the dbareports about $ServerName\$InstanceName"
			Write-Output "===============================================================`n"
			Write-output "General Information`n"
			Write-output $InstanceListInfo | Format-Table -AutoSize
			Write-output "Operating System Information from dbareports about $ServerName\$InstanceName `n"
			Write-output $OSInfo
			Write-output "SQL Instance Level Information from dbareports about $ServerName\$InstanceName `n"
			Write-output $SQLInfo
			Write-output "Database Information from dbareports about $ServerName\$InstanceName `n"
			Write-output $DatabasesInfo
			Write-output "Roll up Agent Job Information from dbareports about $ServerName\$InstanceName`n"
			Write-output $AgentJobServerInfo | Format-Table -AutoSize
			Write-output "Agent Job Detail Information from dbareports about $ServerName\$InstanceName `n"
			Write-output $AgentJobDetailInfo
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}