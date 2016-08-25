<#
.SYNOPSIS 
 Script to scrape the PowerShell log files and enter into DBA Database for Reporting

.DESCRIPTION
This script will scrape the log files int eh log folder and add errors and warnings to the dbareports database for easy reporting

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
	
	$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
	$source = $sourceserver.DomainInstanceName
	
}

PROCESS
{
	$sql = "TRUNCATE TABLE [info].[LogFileErrorMessages]"
	$null = $sourceserver[$InstallDatabase].ExecuteNonQuery($sql)
	
	$regex = 'ERROR:|WARNING:'
	$results = Get-ChildItem $LogFileFolder | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } | Select-String -Pattern $regex | Select-Object FileName, LineNumber, Line
	if (!$results) { break }
	foreach ($result in $results)
	{
		$filename = $result.FileName
		$linenumber = $result.LineNumber
		$errormsg = $result.Line
		$matches = $result.Line.Split(' ')[2]
		$sql = "INSERT INTO [Info].[LogFileErrorMessages]
           ([FileName] ,[ErrorMsg], [Line] ,[Matches]) VALUES
           ('$filename','$errormsg' ,$linenumber,'$matches')"
		
		$null = $sourceserver[$InstallDatabase].ExecuteNonQuery($sql)
	}
}

END
{
	$sourceserver.ConnectionContext.Disconnect()
}
