<#
.SYNOPSIS 


.DESCRIPTION


.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#>
[CmdletBinding(SupportsShouldProcess = $true)]
Param (
	[Alias("ServerInstance", "SqlInstance")]
	[object]$SqlServer = "--installserver--",
	[string]$LogFileFolder = "--logdir--",
	[int]$LogFileRetention = "---logretention--"
)


BEGIN
{
	# Load up shared functions
	$currentdir = Split-Path -Parent $MyInvocation.MyCommand.Definition
	. "$currentdir\shared.ps1"
	
	# Start Transcript
	$Date = Get-Date -Format ddMMyyyy_HHmmss
	$transcript = "$LogFileFolder\dbareports_LogFile_Cleanup" + " _" + "$Date.txt"
	Start-Transcript -Path $transcript -Append
	
	try
	{
		$filestoremove = Get-ChildItem -Path $LogFileFolder | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($LogFileRetention) }
	}
	catch
	{
		Write-Exception $_
		Write-Output "Failed to get List of Files from $LogFileFolder"
	}
}

PROCESS
{
	If ($Pscmdlet.ShouldProcess($LogFileFolder, "Removing Files older than $LogFileRetention"))
	{
		If ($filestoremove)
		{
			try
			{
				Remove-Item $filestoremove -Force
				$FileNames = $filestoremove.FullName
				Write-Output "Removed $FileNames"
			}
			catch
			{
				Write-Exception $_
				Write-Output "Failed to get List of Files from $LogFileFolder"
			}
		}
		else
		{
			Write-Output "No Files to remove in $LogFileFolder"
		}
	}
}

END
{
	
}
