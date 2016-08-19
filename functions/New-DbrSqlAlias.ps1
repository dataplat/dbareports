Function New-DbrSqlAlias
{
<#
.SYNOPSIS 


.DESCRIPTION


.PARAMETER 


.PARAMETER 
	

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/New-DbrSqlAlias

.EXAMPLE
New-DbrSqlAlias
Copies all policies and conditions from sqlserver2014a to sqlcluster, using Windows credentials. 

.EXAMPLE   
New-DbrSqlAlias -WhatIf
Shows what would happen if the command were executed.
	
.EXAMPLE   
New-DbrSqlAlias -Policy 'xp_cmdshell must be disabled'
Does this 
#>
	[CmdletBinding()]
	Param (
		[switch]$Force
	)
	
	PROCESS
	{
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		$alias = "dbareports"
		
		if ($SqlServer.length -eq 0)
		{
			throw "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient"
		}
		
		If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
		{
			$isadmin = $false
		}
		
		if ($isadmin -eq $false)
		{
			If ($Force -eq $true)
			{
				try
				{
					Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList '-command "New-DbrSqlAlias"' -Wait
					return
				}
				catch
				{
					$nomessage = $true
					throw $_
				}
			}
			else
			{
				# Prompt to create and then create. 
				$title = "This command modifies HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client which requires elevated access."
				$message = "Would you like to open an elevated prompt now and rerun the command?"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will continue"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will exit"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$result = $host.ui.PromptForChoice($title, $message, $options, 1)
				
				if ($result -eq 1)
				{
					$nomessage = $true
					return
				}
				else
				{
					Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList '-command "New-DbrSqlAlias"' -Wait
					return
				}
			}
		}
		
		If ($Force -eq $true)
		{
			$ConfirmPreference = 'None'
		}

		$basekeys = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer", "HKLM:\SOFTWARE\Microsoft\MSSQLServer"
		
		if ($env:PROCESSOR_ARCHITECTURE -like "*64*") { $64bit = $true }
		
		foreach ($basekey in $basekeys)
		{
			if ($64bit -ne $true -and $basekey -like "*WOW64*") { continue }
			
			if ((Test-Path $basekey) -eq $false)
			{
				throw "Base key ($basekey) does not exist. Quitting."
			}
			
			$client = "$basekey\Client"
			
			if ((Test-Path $client) -eq $false)
			{
				Write-Output "Creating $client key"
				$null = New-Item -Path $client -Force
			}
			
			$connect = "$client\ConnectTo"
			
			if ((Test-Path $connect) -eq $false)
			{
				Write-Output "Creating $connect key"
				$null = New-Item -Path $connect -Force
			}
			
			if ($basekey -like "*WOW64*")
			{
				$architecture = "for 32-bit"
			}
			else
			{
				$architecture = "for 64-bit"
			}
			
			Write-Output "Creating/updating alias for $SqlServer for $architecture"
			$null = New-ItemProperty -Path $connect -Name $alias -Value "DBMSSOCN,$sqlserver" -PropertyType String -Force
		}
	}
	
	END
	{
		if ($nomessage -ne $true)
		{
			Write-Output "You should now be able to connect to $SqlServer as $alias"
		}
	}
}