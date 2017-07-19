<#
.SYNOPSIS  
This Script will check the Log Files in the Log File Folder for errors and warnings and insert them into the LogFileErrorMessages table

.DESCRIPTION 
This Script will check the Log Files in the Log File Folder for errors and warnings and insert them into the LogFileErrorMessages table

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
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	. "$currentdir\Write-Log.ps1"
	# Create Log File 
	$Date = Get-Date -Format yyyyMMdd_HHmmss
	$LogFilePath = $LogFileFolder + '\' + 'dbareports_LogFileErrorMessages_' + $Date + '.txt'
	try
	{
		Write-Log -path $LogFilePath -message "Databases Job started" -level info
	}
	catch
	{
		Write-error "Failed to create Log File at $LogFilePath"
	}
    
    # Specify table name that we'll be inserting into
	$table = "info.LogFileErrorMessages"
	$schema,$tablename  = $table.Split(".")

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
	

	$Date = Get-Date	
}

PROCESS
{
$Regex = 'ERROR:|WARNING:'
$Results = Get-ChildItem "$LogFileFolder\dbareports_*" |Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-1)}|Select-String -Pattern $Regex|select FileName,LineNumber,Line
if (!$Results)
{
    Write-Log -Message "No Results Found - Good Work! The Beard is happy, Your Gathering Scripts are working well"
    break
}
foreach($Result in $Results)
{
$FileName = $Result.FileName
$LineNumber = $Result.LineNumber
$ErrorMsg = $Result.Line 
$Matches = $result.Line.Split(' ')[2]
$update = $false
try
{
	$null = $datatable.rows.Add(
        $Null, # PK
        $Date,
        $FileName,
        $ErrorMsg,
        $LineNumber,
        $Matches,
        $Update
    )
}
catch
{
    Write-Log -path $LogFilePath -message "Failed to add LogFile Error to datatable - $_" -level Error
	Write-Log -path $LogFilePath -message "Data =$Date,
        $FileName,
        $ErrorMsg,
        $LineNumber,
        $Matches,
        $Update"
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
		Write-Log -path $LogFilePath -message "Successfully Imported $rowcount row(s) of Errors and Warnings into the $InstallDatabase on $($sourceserver.name)" -level info
	}
	catch
	{
		Write-Log -path $LogFilePath -message "Bulk insert failed - $_" -level Error
	}
}

END
{
	Write-Log -path $LogFilePath -message "All Errors Finished"
	$sourceserver.ConnectionContext.Disconnect()
}