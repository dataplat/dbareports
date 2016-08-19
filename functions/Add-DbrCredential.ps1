Function Add-DbrCredential
{
<#
.SYNOPSIS 
Adds a credential and proxy for SQL Agent Jobs to the dbareports server

.DESCRIPTION
This will create a credential and a proxy on the dbareports server using the install configuration and add the PowerShell and CmdExec subsystems

.PARAMETER JobCredential
The Username and password for the credential in a PSCredential object. Will be prompted if it does not exist


.PARAMETER CredentialName 
The name of the credential Defaults to 'DBAreports',

.PARAMETER ProxyName
The name of the proxy. Defaults to 'PowerShell Proxy Account for dbareports'


.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Verb-SqlNoun

.EXAMPLE
Add-DbrCredential -CredentialName TheBeard -ProxyName Rob

This will create a credential called TheBeard and a Proxy named Rob for that credential and add the PowerShell and CmdExec subsystems
#>
	[CmdletBinding()]
	Param (
		[object]$JobCredential,
		[string]$CredentialName = 'DBAreports',
		[string]$ProxyName = 'PowerShell Proxy Account for dbareports'
	)
	
	PROCESS
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
		$source = $sourceserver.DomainInstanceName
		$jobserver = $sourceserver.JobServer
		
		if ($JobCredential -eq $null)
		{
			$msg = "Enter the credential username and password for a Windows account that has permissions on all servers."
			$JobCredential = $Host.UI.PromptForCredential("Credential username and password", $msg, "$env:userdomain\$env:username", $null)
		}
		
		if ($JobCredential -eq $null) { return }
		
		$username = $JobCredential.UserName
		$password = $JobCredential.Password
		
		if ($username -notmatch '\\')
		{
			throw "Username must be a Windows domain account that can authenticate to other servers. Cannot add $username. Quitting."
		}
		
		$login = $sourceserver.Logins[$username]
		
		if ($login -eq $null)
		{
			try
			{
				$title = "$username does not exist on $sqlserver."
				$message = "Adding now as non-privileged login. Continue? (Y/N)"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will continue"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will exit"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$result = $host.ui.PromptForChoice($title, $message, $options, 0)
				
				if ($result -eq 1)
				{
					return "FINE!"
				}
				
				$login = New-Object Microsoft.SqlServer.Management.Smo.Login($sourceserver, $username)
				$login.LoginType = "WindowsUser"
				If ($Pscmdlet.ShouldProcess($source, "Adding login $username to Server"))
				{
					$login.Create()
				}
				
				Write-Output "Created login for $username"
			}
			catch
			{
				Write-Exception $_
				throw "Cannot create login for $username. Quitting."
			}
		}
		
		$sqlcredential = $sourceserver.Credentials[$CredentialName]
		
		if ($SqlCredential -eq $null)
		{
			try
			{
				$sqlcredential = New-Object Microsoft.SqlServer.Management.SMO.Credential($source, $CredentialName)
				$SqlCredential.Identity = $username
				
				If ($Pscmdlet.ShouldProcess($source, "Adding Credential $username to Server"))
				{
					$sqlcredential.Create()
				}
				
				Write-Output "Created credential for $username as $CredentialName"
			}
			catch
			{
				Write-Exception $_
				throw "Cannot create credential for $username. Quitting."
			}
		}
		else
		{
			Write-Output "Credential '$CredentialName' already exists."
		}
		
		$proxyaccount = $sourceserver.JobServer.ProxyAccounts[$ProxyName]
		
		if ($proxyaccount -ne $null)
		{
			if (!$login.IsMember("sysadmin") -and $proxyaccount.CredentialIdentity -ne $username)
			{
				try
				{
					$proxy.AddLogin($username)
					$proxy.Alter()
					
					Write-Output "Added username $username to '$ProxyName' logins"
				}
				catch
				{
					Write-Exception $_
					throw "Cannot add login to proxy account."
				}
			}
		}
		
		if ($sourceserver.JobServer.ProxyAccounts[$ProxyName] -ne $null)
		{
			Write-Output "Proxy account already exists! Nothing left to do."
			return
		}
		
		try
		{
			$proxy = New-Object Microsoft.SqlServer.Management.Smo.Agent.ProxyAccount($jobserver, $ProxyName)
			$proxy.credentialName = $CredentialName
			$proxy.Description = "This account is used to execute PowerShell scripts locally and was created by dbareports."
			$proxy.isEnabled = $true
			$proxy.Create()
			$proxy.AddLogin($username)
			
			Write-Output "Created Proxy Account for credential as '$ProxyName'"
		}
		catch
		{
			Write-Exception $_
			throw "Cannot create proxy for credential '$CredentialName'. Quitting."
		}
		
		# Add both subsystems just in case
		$pssubsystem = [Microsoft.SqlServer.Management.Smo.Agent.AgentSubSystem]::PowerShell
		$cmdsubsystem = [Microsoft.SqlServer.Management.Smo.Agent.AgentSubSystem]::CmdExec
		try
		{
			$proxy.AddSubSystem($pssubsystem)
			$proxy.AddSubSystem($cmdsubsystem)
			
			Write-Output "Added PowerShell and CmdExec subsystems to '$ProxyName'"
		}
		catch
		{
			Write-Exception $_
			throw "Cannot add PowerShell and CmdExec subsystems to proxy account. Quitting."
		}
		
		$sourceserver.ConnectionContext.Disconnect()
	}
}