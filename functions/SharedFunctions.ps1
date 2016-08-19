# These are shared, mostly internal functions.

Function Update-dbareports
{
<# 
.SYNOPSIS 
Exported function. Updates dbareports. Deletes current copy and replaces it with freshest copy.

.EXAMPLE
Update-dbareports
#>	
	
	Invoke-Expression (Invoke-WebRequest -UseBasicParsing http://git.io/vn1hQ).Content
}

<#
				
		All functions below are internal to the module and cannot be executed via command line.
				
#>

Function Connect-SqlServer
{
<# 
.SYNOPSIS 
Internal function that creates SMO server object. Input can be text or SMO.Server.
#>	
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$SqlServer,
		[System.Management.Automation.PSCredential]$SqlCredential,
		[switch]$ParameterConnection,
		[switch]$RegularUser
	)
	
	
	if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server])
	{
		
		if ($ParameterConnection)
		{
			$paramserver = New-Object Microsoft.SqlServer.Management.Smo.Server
			$paramserver.ConnectionContext.ConnectTimeout = 2
			$paramserver.ConnectionContext.ApplicationName = "dbareports PowerShell module - dbareports.io"
			$paramserver.ConnectionContext.ConnectionString = $SqlServer.ConnectionContext.ConnectionString
			
			if ($SqlCredential.username -ne $null)
			{
				$username = ($SqlCredential.username).TrimStart("\")
				
				if ($username -like "*\*")
				{
					$username = $username.Split("\")[1]
					$authtype = "Windows Authentication with Credential"
					$server.ConnectionContext.LoginSecure = $true
					$server.ConnectionContext.ConnectAsUser = $true
					$server.ConnectionContext.ConnectAsUserName = $username
					$server.ConnectionContext.ConnectAsUserPassword = ($SqlCredential).GetNetworkCredential().Password
				}
				else
				{
					$authtype = "SQL Authentication"
					$server.ConnectionContext.LoginSecure = $false
					$server.ConnectionContext.set_Login($username)
					$server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
				}
			}
			
			$paramserver.ConnectionContext.Connect()
			return $paramserver
		}
		
		if ($SqlServer.ConnectionContext.IsOpen -eq $false)
		{
			$SqlServer.ConnectionContext.Connect()
		}
		return $SqlServer
	}
	
	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $SqlServer
	$server.ConnectionContext.ApplicationName = "dbareports PowerShell module - dbareports.io"
	
	try
	{
		if ($SqlCredential.username -ne $null)
		{
			$username = ($SqlCredential.username).TrimStart("\")
			
			if ($username -like "*\*")
			{
				$username = $username.Split("\")[1]
				$authtype = "Windows Authentication with Credential"
				$server.ConnectionContext.LoginSecure = $true
				$server.ConnectionContext.ConnectAsUser = $true
				$server.ConnectionContext.ConnectAsUserName = $username
				$server.ConnectionContext.ConnectAsUserPassword = ($SqlCredential).GetNetworkCredential().Password
			}
			else
			{
				$authtype = "SQL Authentication"
				$server.ConnectionContext.LoginSecure = $false
				$server.ConnectionContext.set_Login($username)
				$server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
			}
		}
	}
	catch { }
	
	try
	{
		if ($ParameterConnection)
		{
			$server.ConnectionContext.ConnectTimeout = 2
		}
		else
		{
			$server.ConnectionContext.ConnectTimeout = 3
		}
		
		$server.ConnectionContext.Connect()
	}
	catch
	{
		$message = $_.Exception.InnerException.InnerException
		$message = $message.ToString()
		$message = ($message -Split '-->')[0]
		$message = ($message -Split 'at System.Data.SqlClient')[0]
		$message = ($message -Split 'at System.Data.ProviderBase')[0]
		throw "Can't connect to $sqlserver`: $message "
	}
	
	if ($RegularUser -eq $false)
	{
		if ($server.ConnectionContext.FixedServerRoles -notmatch "SysAdmin")
		{
			throw "Not a sysadmin on $SqlServer. Quitting."
		}
	}
	
	if ($ParameterConnection -eq $false)
	{
		if ($server.VersionMajor -eq 8)
		{
			# 2000
			$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Version')
			$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'CreateDate', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'Name', 'Sid', 'WindowsLoginAccessType')
		}
		
		
		elseif ($server.VersionMajor -eq 9 -or $server.VersionMajor -eq 10)
		{
			# 2005 and 2008
			$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
			$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
		}
		
		else
		{
			# 2012 and above
			$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'ActiveConnections', 'AvailabilityDatabaseSynchronizationState', 'AvailabilityGroupName', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'ContainmentType', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
			$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordHashAlgorithm', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
		}
	}
	
	return $server
}

Function Test-SqlPath
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[System.Management.Automation.PSCredential]$SqlCredential
	)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$sql = "EXEC master.dbo.xp_fileexist '$path'"
	$fileexist = $server.ConnectionContext.ExecuteWithResults($sql)
	
	if ($fileexist.tables.rows['File Exists'] -eq $true -or $fileexist.tables.rows['File is a Directory'] -eq $true)
	{
		return $true
	}
	else
	{
		return $false
	}
}

Function Test-SqlConnection
{
<# 
.SYNOPSIS 
Exported function. Tests a the connection to a single instance and shows the output.

.EXAMPLE
Test-SqlConnection sql01

Sample output:

Local PowerShell Enviornment

Windows    : 10.0.10240.0
PowerShell : 5.0.10240.16384
CLR        : 4.0.30319.42000
SMO        : 13.0.0.0
DomainUser : True
RunAsAdmin : False

SQL Server Connection Information

ServerName         : sql01
BaseName           : sql01
InstanceName       : (Default)
AuthType           : Windows Authentication (Trusted)
ConnectingAsUser   : ad\dba
ConnectSuccess     : True
SqlServerVersion   : 12.0.2370
AddlConnectInfo    : N/A
RemoteServer       : True
IPAddress          : 10.0.1.4
NetBIOSname        : SQLSERVER2014A
RemotingAccessible : True
Pingable           : True
DefaultSQLPortOpen : True
RemotingPortOpen   : True
#>	
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	
	$username = $SqlCredential.username
	if ($username -ne $null)
	{
		$username = $username.TrimStart("\")
		if ($username -like "*\*") { throw "Only SQL Logins can be specified when using the Credential parameter. To connect as to SQL Server a different Windows user, you must start PowerShell as that user." }
	}
	
	# Get local enviornment
	Write-Output "Getting local enivornment information"
	$localinfo = @{ } | Select-Object Windows, PowerShell, CLR, SMO, DomainUser, RunAsAdmin
	$localinfo.Windows = [environment]::OSVersion.Version.ToString()
	$localinfo.PowerShell = $PSVersionTable.PSversion.ToString()
	$localinfo.CLR = $PSVersionTable.CLRVersion.ToString()
	$smo = (([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Fullname -like "Microsoft.SqlServer.SMO,*" }).FullName -Split ", ")[1]
	$localinfo.SMO = $smo.TrimStart("Version=")
	$localinfo.DomainUser = $env:computername -ne $env:USERDOMAIN
	$localinfo.RunAsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
	
	# SQL Server
	if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) { $SqlServer = $SqlServer.Name.ToString() }
	
	$serverinfo = @{ } | Select-Object ServerName, BaseName, InstanceName, AuthType, ConnectingAsUser, ConnectSuccess, SqlServerVersion, AddlConnectInfo, RemoteServer, IPAddress, NetBIOSname, RemotingAccessible, Pingable, DefaultSQLPortOpen, RemotingPortOpen
	
	$serverinfo.ServerName = $sqlserver
	
	Write-Output "Determining SQL Server base address"
	$baseaddress = $sqlserver.Split("\")[0]
	try { $instance = $sqlserver.Split("\")[1] }
	catch { $instance = "(Default)" }
	if ($instance -eq $null) { $instance = "(Default)" }
	
	if ($baseaddress -eq "." -or $baseaddress -eq $env:COMPUTERNAME)
	{
		$ipaddr = "."
		$hostname = $env:COMPUTERNAME
		$baseaddress = $env:COMPUTERNAME
	}
	
	$serverinfo.BaseName = $baseaddress
	$remote = $baseaddress -ne $env:COMPUTERNAME
	$serverinfo.InstanceName = $instance
	$serverinfo.RemoteServer = $remote
	
	Write-Output "Resolving IP address"
	try
	{
		$hostentry = [System.Net.Dns]::GetHostEntry($baseaddress)
		$ipaddr = ($hostentry.AddressList | Where-Object { $_ -notlike '169.*' } | Select-Object -First 1).IPAddressToString
	}
	catch { $ipaddr = "Unable to resolve" }
	
	$serverinfo.IPAddress = $ipaddr
	
	Write-Output "Resolving NetBIOS name"
	try
	{
		$hostname = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName $ipaddr -ErrorAction SilentlyContinue).PSComputerName
		if ($hostname -eq $null) { $hostname = (nbtstat -A $ipaddr | Where-Object { $_ -match '\<00\>  UNIQUE' } | ForEach-Object { $_.SubString(4, 14) }).Trim() }
	}
	catch { $hostname = "Unknown" }
	
	$serverinfo.NetBIOSname = $hostname
	
	
	if ($remote -eq $true)
	{
		# Test for WinRM #Test-WinRM neh
		Write-Output "Checking remote acccess"
		winrm id -r:$hostname 2>$null | Out-Null
		if ($LastExitCode -eq 0) { $remoting = $true }
		else { $remoting = $false }
		
		$serverinfo.RemotingAccessible = $remoting
		
		Write-Output "Testing raw socket connection to PowerShell remoting port"
		$tcp = New-Object System.Net.Sockets.TcpClient
		try
		{
			$tcp.Connect($baseaddress, 135)
			$tcp.Close()
			$tcp.Dispose()
			$remotingport = $true
		}
		catch { $remotingport = $false }
		
		$serverinfo.RemotingPortOpen = $remotingport
	}
	
	# Test Connection first using Test-Connection which requires ICMP access then failback to tcp if pings are blocked
	Write-Output "Testing ping to $baseaddress"
	$testconnect = Test-Connection -ComputerName $baseaddress -Count 1 -Quiet
	
	$serverinfo.Pingable = $testconnect
	
	# SQL Server connection
	
	if ($instance -eq "(Default)")
	{
		Write-Output "Testing raw socket connection to default SQL port"
		$tcp = New-Object System.Net.Sockets.TcpClient
		try
		{
			$tcp.Connect($baseaddress, 1433)
			$tcp.Close()
			$tcp.Dispose()
			$sqlport = $true
		}
		catch { $sqlport = $false }
		$serverinfo.DefaultSQLPortOpen = $sqlport
	}
	else { $serverinfo.DefaultSQLPortOpen = "N/A" }
	
	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $SqlServer
	
	try
	{
		if ($SqlCredential -ne $null)
		{
			$authtype = "SQL Authentication"
			$username = ($SqlCredential.username).TrimStart("\")
			$server.ConnectionContext.LoginSecure = $false
			$server.ConnectionContext.set_Login($username)
			$server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
		}
		else
		{
			$authtype = "Windows Authentication (Trusted)"
			$username = "$env:USERDOMAIN\$env:username"
		}
	}
	catch
	{
		$authtype = "Windows Authentication (Trusted)"
		$username = "$env:USERDOMAIN\$env:username"
	}
	
	$serverinfo.ConnectingAsUser = $username
	$serverinfo.AuthType = $authtype
	
	
	Write-Output "Attempting to connect to $SqlServer as $username "
	try
	{
		$server.ConnectionContext.ConnectTimeout = 10
		$server.ConnectionContext.Connect()
		$connectSuccess = $true
		$version = $server.Version.ToString()
		$addlinfo = "N/A"
		$server.ConnectionContext.Disconnect()
	}
	catch
	{
		$connectSuccess = $false
		$version = "N/A"
		$addlinfo = $_.Exception
	}
	
	$serverinfo.ConnectSuccess = $connectSuccess
	$serverinfo.SqlServerVersion = $version
	$serverinfo.AddlConnectInfo = $addlinfo
	
	Write-Output "`nLocal PowerShell Enviornment"
	$localinfo | Select-Object Windows, PowerShell, CLR, SMO, DomainUser, RunAsAdmin
	
	Write-Output "SQL Server Connection Information`n"
	$serverinfo | Select-Object ServerName, BaseName, InstanceName, AuthType, ConnectingAsUser, ConnectSuccess, SqlServerVersion, AddlConnectInfo, RemoteServer, IPAddress, NetBIOSname, RemotingAccessible, Pingable, DefaultSQLPortOpen, RemotingPortOpen
	
}

Function Connect-AsServer
{
<# 
.SYNOPSIS 
Internal function that creates SMO server object. Input can be text or SMO.Server.
#>	
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$AsServer,
		[switch]$ParameterConnection
	)
	
	if ($AsServer.GetType() -eq [Microsoft.AnalysisServices.Server])
	{
		
		if ($ParameterConnection)
		{
			$paramserver = New-Object Microsoft.AnalysisServices.Server
			$paramserver.Connect("Data Source=$($AsServer.Name);Connect Timeout=2")
			return $paramserver
		}
		
		if ($AsServer.Connected -eq $false) { $AsServer.Connect("Data Source=$($AsServer.Name);Connect Timeout=3") }
		return $AsServer
	}
	
	$server = New-Object Microsoft.AnalysisServices.Server
	
	try
	{
		if ($ParameterConnection)
		{
			$server.Connect("Data Source=$AsServer;Connect Timeout=2")
		}
		else { $server.Connect("Data Source=$AsServer;Connect Timeout=3") }
	}
	catch
	{
		$message = $_.Exception.InnerException
		$message = $message.ToString()
		$message = ($message -Split '-->')[0]
		$message = ($message -Split 'at System.Data.SqlClient')[0]
		$message = ($message -Split 'at System.Data.ProviderBase')[0]
		throw "Can't connect to $asserver`: $message "
	}
	
	return $server
}

Function Invoke-SmoCheck
{
<# 
.SYNOPSIS 
Checks for PowerShell SMO version vs SQL Server's SMO version.

#>	
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$SqlServer
	)
	
	if ($script:smocheck -ne $true)
	{
		$script:smocheck = $true
		$smo = (([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Fullname -like "Microsoft.SqlServer.SMO,*" }).FullName -Split ", ")[1]
		$smo = ([version]$smo.TrimStart("Version=")).Major
		$serverversion = $SqlServer.version.major
		
		if ($serverversion - $smo -gt 1)
		{
			Write-Warning "Your version of SMO is $smo, which is significantly older than $($sqlserver.name)'s version $($SqlServer.version.major)."
			Write-Warning "This may present an issue when migrating certain portions of SQL Server."
			Write-Warning "If you encounter issues, consider upgrading SMO."
		}
	}
}

Function Get-SqlDefaultPaths
{
<#
.SYNOPSIS
Internal function. Returns the default data and log paths for SQL Server. Needed because SMO's server.defaultpath is sometimes null.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$filetype,
		[object]$SqlCredential
	)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	
	switch ($filetype) { "mdf" { $filetype = "data" } "ldf" { $filetype = "log" } }
	
	if ($filetype -eq "log")
	{
		# First attempt
		$filepath = $server.DefaultLog
		# Second attempt
		if ($filepath.Length -eq 0) { $filepath = $server.Information.MasterDbLogPath }
		# Third attempt
		if ($filepath.Length -eq 0)
		{
			$sql = "select SERVERPROPERTY('InstanceDefaultLogPath') as physical_name"
			$filepath = $server.ConnectionContext.ExecuteScalar($sql)
		}
	}
	else
	{
		# First attempt
		$filepath = $server.DefaultFile
		# Second attempt
		if ($filepath.Length -eq 0) { $filepath = $server.Information.MasterDbPath }
		# Third attempt
		if ($filepath.Length -eq 0)
		{
			$sql = "select SERVERPROPERTY('InstanceDefaultDataPath') as physical_name"
			$filepath = $server.ConnectionContext.ExecuteScalar($sql)
		}
	}
	
	if ($filepath.Length -eq 0) { throw "Cannot determine the required directory path" }
	$filepath = $filepath.TrimEnd("\")
	return $filepath
}

Function Get-SqlSaLogin
{
<#
.SYNOPSIS
Internal function. Gets the name of the sa login in case someone changed it.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$sa = $server.Logins | Where-Object { $_.id -eq 1 }
	
	return $sa.name
	
}

Function Join-AdminUnc
{
<#
.SYNOPSIS
Internal function. Parses a path to make it an admin UNC.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$servername,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$filepath
		
	)
	
	if (!$filepath) { return }
	if ($filepath.StartsWith("\\")) { return $filepath }
	
	$servername = $servername.Split("\")[0]
	
	if ($filepath.length -gt 0 -and $filepath -ne [System.DbNull]::Value)
	{
		$newpath = Join-Path "\\$servername\" $filepath.replace(':', '$')
		return $newpath
	}
	else { return }
}

Function Test-SqlSa
{
<#
.SYNOPSIS
Internal function. Ensures sysadmin account access on SQL Server.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	
	try
	{
		
		if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server])
		{
			return ($SqlServer.ConnectionContext.FixedServerRoles -match "SysAdmin")
		}
		
		$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
		return ($server.ConnectionContext.FixedServerRoles -match "SysAdmin")
	}
	catch { return $false }
}

Function Resolve-NetBiosName
{
 <#
.SYNOPSIS
Internal function. Takes a best guess at the NetBIOS name of a server. 		
 #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$servernetbios = $server.ComputerNamePhysicalNetBIOS
	
	if ($servernetbios -eq $null)
	{
		$servernetbios = ($server.name).Split("\")[0]
		$servernetbios = $servernetbios.Split(",")[0]
	}
	
	return $($servernetbios.ToLower())
}

Function Resolve-SqlIpAddress
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$servernetbios = $server.ComputerNamePhysicalNetBIOS
	$ipaddr = (Test-Connection $servernetbios -count 1).Ipv4Address
	return $ipaddr
}

Function Resolve-IpAddress
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$ComputerName
	)
	
	$ipaddr = (Test-Connection $ComputerName -count 1).Ipv4Address
	return $ipaddr
}


Function Test-SqlAgent
{
<#
.SYNOPSIS
Internal function. Checks to see if SQL Server Agent is running on a server.  
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	
	if ($SqlServer.GetType() -ne [Microsoft.SqlServer.Management.Smo.Server])
	{
		$SqlServer = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	}
	
	if ($SqlServer.JobServer -eq $null) { return $false }
	try { $null = $SqlServer.JobServer.script(); return $true }
	catch { return $false }
}

Function Get-SaLoginName
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential
	)
	
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$saname = ($server.logins | Where-Object { $_.id -eq 1 }).Name
	
	return $saname
}

Function Write-Exception
{
<#
.SYNOPSIS
Internal function. Writes exception to disk (my docs\dbareports-exceptions.txt) for later analysis.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$e
	)
	
	$docs = [Environment]::GetFolderPath("mydocuments")
	$errorlog = "$docs\dbareports-exceptions.txt"
	$message = $e.Exception
	$infocation = $e.InvocationInfo
	
	$position = $infocation.PositionMessage
	$scriptname = $infocation.ScriptName
	if ($e.Exception.InnerException -ne $null) { $messsage = $e.Exception.InnerException }
	
	$message = $message.ToString()
	
	Add-Content $errorlog $(Get-Date)
	Add-Content $errorlog $scriptname
	Add-Content $errorlog $position
	Add-Content $errorlog $message
	Write-Warning "See error log $(Resolve-Path $errorlog) for more details."
}

Function New-DbrAgentJobCategory
{
	param ([string]$CategoryName,
		$JobServer)
	if (!$JobServer.JobCategories[$CategoryName])
	{
		try
		{
			Write-Output "Creating Agent Job Category $CategoryName"
			$Category = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobCategory
			$Category.Parent = $JobServer
			$Category.Name = $CategoryName
			$Category.Create()
			Write-Output "Created Agent Job Category $CategoryName"
		}
		catch
		{
			Write-Warning "FAILED : To Create Agent Job Category $CategoryName - Aborting"
			Write-Exception $_
			continue
		}
	}
}


function Get-Instances
{
	$sql = "SELECT DISTINCT ServerName, InstanceName, InstanceId,Serverid FROM [dbo].[InstanceList] Where Inactive = 0 AND NotContactable = 0"
	try
	{
		$server = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
	}
	catch
	{
		Write-Exception $_
		throw "Can't get InstanceList in the $InstallDatabase database on $($sourceserver.name)."
	}
	
	return $server
}

function Get-ExtendedProperties
{
	$sql = "SELECT name, value FROM fn_listextendedproperty(default, default, default, default, default, default, default);"
	try
	{
		$property = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
	}
	catch
	{
		Write-Exception $_
		throw "Can't get extended properties from $InstallDatabase on $($sourceserver.name)."
	}
	
	return $property
}
function Initialize-DataTable
{
	# Create datatable for inserts, based off of schema information from existing table
	
	$schema = $table.Split(".")[0]
	$tablename = $table.Split(".")[1]
	
	$sql = "SELECT COLUMN_NAME,DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = '$schema' AND TABLE_NAME = '$tablename'"
	
	try
	{
		$results = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql)
	}
	catch
	{
		Write-Exception $_
		throw "Can't get column list from $table in the $InstallDatabase database on $($sourceserver.name)."
	}
	
	$script:datatable = New-Object System.Data.DataTable $table
	foreach ($result in $results.Tables.rows)
	{
		$ColumnName = $result.column_name
		if ($result.data_type -eq 'datetime')
		{
			$Column = New-Object system.Data.DataColumn $ColumnName, ([datetime])
		}
		else
		{
			$Column = New-Object system.Data.DataColumn $ColumnName, ([string])
		}
		$null = $datatable.Columns.Add($column)
	}
	
	$null = $datatable.Columns.Add("U")
}

Function Write-Tvp
{
	$cmd = $sourceserver.ConnectionContext.SqlConnectionObject.CreateCommand()
	$cmd.CommandType = "StoredProcedure"
	$cmd.CommandText = "$schema.usp_$tablename"
	$null = $cmd.Parameters.Add("@TVP", [System.Data.SqlDbType]::Structured)
	$cmd.Parameters["@TVP"].Value = $datatable
	$null = $cmd.ExecuteNonQuery()
}

Function Get-ConfigFileName
{
	$docs = [Environment]::GetFolderPath("MyDocuments")
	$folder = "$docs\WindowsPowerShell\Modules\dbareports"
	$configfile = "$folder\dbareports-config.json"
	$exists = Test-Path $configfile
	
	if ($exists -eq $true)
	{
		return $configfile
	}
	else
	{
		$folderexists = Test-Path $folder
		
		if ($folderexists -eq $false)
		{
			$null = New-Item -ItemType Directory $folder -Force -ErrorAction Ignore
		}
		return $configfile
	}
}

Function Get-Config
{
	$config = Get-Content -Raw -Path (Get-ConfigFileName) -ErrorAction SilentlyContinue | ConvertFrom-Json
	
	if ($config.SqlServer.length -eq 0)
	{
		throw "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient"
	}
	
	if ($config.username.length -gt 0)
	{
		$username = $config.Username
		$password = $config.SecurePassword | ConvertTo-SecureString
		$tempcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
		Set-Variable -Name SqlCredential -Value $tempcred -Scope Script
	}
	
	Set-Variable -Name SqlServer -Value $config.sqlserver -Scope Script
	Set-Variable -Name InstallDatabase -Value $config.InstallDatabase -Scope Script
}