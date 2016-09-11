# This needs to be here becuse it's not part of a module.

$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")

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
		[object]$SqlCredential,
		[switch]$ParameterConnection,
		[switch]$RegularUser
	)
	
	
	$username = $SqlCredential.username
	if ($username -ne $null)
	{
		$username = $username.TrimStart("\")
		if ($username -like "*\*") { throw "Only SQL Logins can be specified when using the Credential parameter. To connect as to SQL Server a different Windows user, you must start PowerShell as that user." }
	}
	
	if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server])
	{
		
		if ($ParameterConnection)
		{
			$paramserver = New-Object Microsoft.SqlServer.Management.Smo.Server
			$paramserver.ConnectionContext.ConnectTimeout = 2
			$paramserver.ConnectionContext.ApplicationName = "dbareports PowerShell module - dbareports.io"
			$paramserver.ConnectionContext.ConnectionString = $SqlServer.ConnectionContext.ConnectionString
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
			$server.ConnectionContext.LoginSecure = $false
			$server.ConnectionContext.set_Login($username)
			$server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
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
			throw "Not a sysadmin on $source. Quitting."
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
		[object]$ComputerName,
		[object]$SqlCredential
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
	
	# add event log stuff?
	# Write-EventLog -LogName Application -Source 'SQLAUTOSCRIPT' -EventId 1 -EntryType Error -Message $Msg
	
	$errorlog = "$LogFileFolder\dbareports-exceptions.txt"
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

function Get-Instances
{
	$sql = "SELECT DISTINCT ServerName, InstanceName, InstanceId, ServerId FROM [dbo].[InstanceList] Where Inactive = 0 AND NotContactable = 0"
	try
	{
		$server = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables[0]
	}
	catch
	{
		Write-Exception $_
		throw "Can't get InstanceList in the $InstallDatabase database on $($sourceserver.name)."
	}
	
	return $server
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
		if ($result.data_type -eq 'datetime' -or $result.data_type -eq 'datetime2')
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

Function Write-BulkInsert
{
	# Build the sqlbulkcopy connection, and set the timeout to infinite
	$connectionstring = "Data Source=$sqlserver;Integrated Security=true;Initial Catalog=$installdatabase;"
	$options = 'TableLock', 'FireTriggers'
	$bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($connectionstring, $options)
	$bulkcopy.DestinationTableName = $table
	$bulkcopy.bulkcopyTimeout = 0
	$bulkcopy.WriteToServer($datatable)
	$datatable.Clear()
	$bulkcopy.Close()
	$bulkcopy.Dispose()
	$datatable.Dispose()
}

Function Write-Tvp
{
	$cmd = $sourceserver.ConnectionContext.SqlConnectionObject.CreateCommand()
	$cmd.CommandType = "StoredProcedure"
	$cmd.CommandText = "$schema.usp_$tablename"
	$null = $cmd.Parameters.Add("@TVP", [System.Data.SqlDbType]::Structured)
	$cmd.Parameters["@TVP"].Value = $datatable
	$cmd.ExecuteNonQuery()
}

