Function Get-DbrDetailedINfo
{
<#
.SYNOPSIS 
Gets all of the information in the dbareports database about the estate

.DESCRIPTION


.PARAMETER ToScreen
Outputs results to screen default parameter


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
	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $false)]
		[switch]$ToScreen,
		[parameter(Mandatory = $false)]
		[string]$Filepath,
		[parameter(Mandatory = $false)]
		[switch]$Quiet
	)
	
	
	DynamicParam { return Get-ParamSqlServerInventory }
	
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
		
		$InstanceName = $psboundparameters.Instance
		$ServerName = $psboundparameters.ServerName
	}
	
	PROCESS
	{
		$NumberofServerSQL = "/* Number of Servers */
                SELECT COUNT(ServerName) as Servers
                ,Environment
                ,Location
                 FROM $installdatabase.dbo.InstanceList il
                 GROUP BY Location, Environment"
		
		$SrvsDBEnvLocSQL = " /*Number of Servers, Number of Databases, Environment and Location */
                     SELECT COUNT(DISTINCT il.ServerName) as 'number of servers'
                    ,COUNT(d.Name) as 'number of databases'
                    ,il.Environment
                    ,il.Location
                     FROM $installdatabase.dbo.InstanceList il
                     JOIN $installdatabase.info.Databases d
                     ON il.InstanceID = d.InstanceID
                     GROUP BY Location,Environment"
		
		$DatabaseSizeSQL = " /*Size, Number of Servers, Number of Databases*/
                         SELECT IL.Environment, COUNT(DISTINCT il.ServerName) AS 'number of servers'
                        ,COUNT(d.Name) AS 'number of databases'
                        ,CAST((SUM(d.SizeMB) / 1024) AS Decimal(7,2)) AS 'Size Gb'
                         FROM $installdatabase.dbo.InstanceList il
                         JOIN $installdatabase.info.Databases d
                         ON il.InstanceID = d.InstanceID
                          GROUP BY Location,Environment"
		
		$SQLVersionSQL = "  SELECT 
                                SI.SQLVersion
                                ,Environment
                                ,COUNT(DISTINCT il.ServerName) AS 'number of servers'
                                FROM $installdatabase.dbo.InstanceList il
                                JOIN $installdatabase.info.SQLInfo SI
                                ON il.ServerName = SI.ServerName 
                                GROUP BY Environment,SI.SQLVersion
                                ORDER BY Environment Desc"
		
		$SQLversionEditionSQL = " SELECT 
                                SI.SQLVersion
                                ,SI.Edition
                                ,SI.ServicePack
                                ,COUNT(DISTINCT il.ServerName) AS 'number of servers'
                                FROM $installdatabase.dbo.InstanceList il
                                JOIN $installdatabase.info.SQLInfo SI
                                ON il.ServerName = SI.ServerName 
                                GROUP BY Environment,SI.SQLVersion,SI.Edition
                                ,SI.ServicePack
                                ORDER BY SQLVersion Desc"
		
		$TotalAgentSQL = " /* Number of Agent Jobs */
                         SELECT COUNT(DISTINCT il.ServerName) as 'number of servers'
                        ,SUM(ajs.NumberOfJobs) as 'Total Agent Jobs'
                        ,il.Environment
                        ,il.Location
                        FROM $installdatabase.dbo.InstanceList il
                        JOIN $installdatabase.info.AgentJobServer AJS
                        ON il.InstanceID = AJS.InstanceID
                        WHERE DATEDIFF( d, AJS.NumberofJobs, GETDATE() ) >300
                        GROUP BY Location,Environment"
		
		$DatabasesWithoutBackupSQL = "  /* Number of databases without a full backup*/
                                     SELECT COUNT(DISTINCT il.ServerName) as 'number of servers'
                                    ,COUNT(d.Name) as 'number of databases'
                                    ,CAST((SUM(d.SizeMB) / 1024) AS Decimal(7,2)) as 'Size Gb'
                                    ,il.Environment
                                    ,il.Location
                                     FROM $installdatabase.dbo.InstanceList il
                                     JOIN $installdatabase.info.Databases d
                                     ON il.InstanceID = d.InstanceID
                                     WHERE d.LastBackupDate = '0001-01-01 00:00:00.0000000'
                                     GROUP BY Location,Environment"
		
		$DbsWithoutLogBackupSQL = " /* Number of Full databases wihtout a transaction log backup */
                                 SELECT COUNT(DISTINCT il.ServerName) as 'number of servers'
                                ,COUNT(d.Name) as 'number of databases'
                                ,CAST((SUM(d.SizeMB) / 1024) AS Decimal(7,2)) as 'Size Gb'
                                ,il.Environment
                                ,il.Location
                                 FROM $installdatabase.dbo.InstanceList il
                                 JOIN $installdatabase.info.Databases d
                                 ON il.InstanceID = d.InstanceID
                                 WHERE d.LastLogBackupDate = '0001-01-01 00:00:00.0000000'
                                 and d.RecoveryModel = 'full'
                                 GROUP BY Location,Environment"
		
		$DBsByRecoveryModelSQL = "/* Databases by Recovery Model */
                                SELECT 
                                il.Environment
                                ,d.RecoveryModel
                                ,COUNT(d.Name) as 'number of databases'
                                 FROM $installdatabase.dbo.InstanceList il
                                 JOIN $installdatabase.info.Databases d
                                 ON il.InstanceID = d.InstanceID
                                 GROUP BY Environment,d.RecoveryModel"
		
		$OSVersionSQL = "SELECT 
                        SOI.OperatingSystem
                        ,IL.Environment
                        ,COUNT(DISTINCT il.ServerName) as 'Number of Servers'
                         FROM $installdatabase.dbo.InstanceList il
                         JOIN $installdatabase.info.ServerOSInfo SOI
                         on IL.ServerName = SOI.ServerName
                         GROUP BY soi.OperatingSystem,Environment
                         ORDER BY soi.OperatingSystem"
		
		$NumberofServersInfo = $sourceserver.ConnectionContext.ExecuteWithResults($NumberofServerSQL).Tables
		$SrvsDBEnvLoc = $sourceserver.ConnectionContext.ExecuteWithResults($SrvsDBEnvLocSQL).Tables
		$DatabaseSizeInfo = $sourceserver.ConnectionContext.ExecuteWithResults($DatabaseSizeSQL).Tables
		$SQLVersionInfo = $sourceserver.ConnectionContext.ExecuteWithResults($SQLVersionSQL).Tables
		$SQLversionEditionInfo = $sourceserver.ConnectionContext.ExecuteWithResults($SQLversionEditionSQL).Tables
		$TotalAgentInfo = $sourceserver.ConnectionContext.ExecuteWithResults($TotalAgentSQL).Tables
		$DatabasesWithoutBackupInfo = $sourceserver.ConnectionContext.ExecuteWithResults($DatabasesWithoutBackupSQL).Tables
		$DbsWithoutLogBackupINfo = $sourceserver.ConnectionContext.ExecuteWithResults($DbsWithoutLogBackupSQL).Tables
		$DBsByRecoveryModelINfo = $sourceserver.ConnectionContext.ExecuteWithResults($DBsByRecoveryModelSQL).Tables
		$OSVersionInfo = $sourceserver.ConnectionContext.ExecuteWithResults($OSVersionSQL).Tables
		
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
			"Information from the dbareports about the estate" | Out-File -FilePath $FileName
			"===============================================================`n" | Out-File -FilePath $FileName -Append
			$NumberofServersInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Number of Servers and Databases by Environment and Location from dbareport  `n" | Out-File -FilePath $FileName -Append
			$SrvsDBEnvLoc | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Total Size Information from dbareport`n " | Out-File -FilePath $FileName -Append
			$DatabaseSizeInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"SQL Version by Environment from dbareports`n" | Out-File -FilePath $FileName -Append
			$SQLVersionInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"SQL Version Edition By Environment from dbareports`n" | Out-File -FilePath $FileName -Append
			$SQLversionEditionInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Total Agent Jobs By Environment from dbareports`n" | Out-File -FilePath $FileName -Append
			$TotalAgentInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Databases without a Backup from dbareports`n" | Out-File -FilePath $FileName -Append
			$DatabasesWithoutBackupInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Databases without a Log Backup from dbareports`n" | Out-File -FilePath $FileName -Append
			$DbsWithoutLogBackupINfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Databases by Recovery Model from dbareports`n" | Out-File -FilePath $FileName -Append
			$DBsByRecoveryModelINfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			"Operating system information from dbareports`n" | Out-File -FilePath $FileName -Append
			$OSVersionInfo | Format-Table -AutoSize | Out-File -FilePath $FileName -Append
			Write-Output "Information written to $FileName"
		}
		
		if ($ToScreen)
		{
			Write-Output "Information from the dbareports about the estate"
			Write-Output "===============================================================`n"
			Write-output $NumberofServersInfo | Format-Table -AutoSize
			Write-output "Number of Servers and Databases by Environment and Location from dbareport  `n"
			Write-output $SrvsDBEnvLoc | Format-Table -AutoSize
			Write-output "Total Size Information from dbareport`n "
			Write-output $DatabaseSizeInfo | Format-Table -AutoSize
			Write-output "SQL Version by Environment from dbareports`n"
			Write-output $SQLVersionInfo | Format-Table -AutoSize
			Write-output "SQL Version Edition By Environment from dbareports`n"
			Write-output $SQLversionEditionInfo | Format-Table -AutoSize
			Write-Output "Total Agent Jobs By Environment from dbareports`n"
			Write-Output $TotalAgentInfo | Format-Table -AutoSize
			Write-Output "Databases without a Backup from dbareports`n"
			Write-Output $DatabasesWithoutBackupInfo | Format-Table -AutoSize
			Write-Output "Databases without a Log Backup from dbareports`n"
			Write-Output $DbsWithoutLogBackupINfo | Format-Table -AutoSize
			Write-Output "Databases by Recovery Model from dbareports`n"
			Write-Output $DBsByRecoveryModelINfo | Format-Table -AutoSize
			Write-Output "Operating System Information from dbareports`n"
			Write-Output $OSVersionInfo | Format-Table -AutoSize
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}

<#

/* OS Operating System*/

SELECT 
SOI.OperatingSystem
,COUNT(DISTINCT il.ServerName) as 'Number of Servers'
 FROM dbo.InstanceList il
 JOIN info.ServerOSInfo SOI
 on IL.ServerName = SOI.ServerName
 GROUP BY soi.OperatingSystem
 ORDER BY soi.OperatingSystem
#>