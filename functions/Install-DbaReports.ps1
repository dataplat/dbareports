Function Install-DbaReports
{
<#
.SYNOPSIS 
Installs both the server and client components for dbareports. To install only the client component, use Install-DbaReportsClient.

.DESCRIPTION
Installs the following on the specified SQL server:
	
	Database with all required tables, stored procedures, extended properties etc.
	Adds the executing account (SQL Agent account if no proxy specified) as dbo to the database
	Proxy/Credential (if required)
	Agent Category ("dbareports collection jobs")
	Agent Jobs
	Job Schedules
	Copies PowerShell files to SQL Server or shared network directory

- If the specified database does not exist, you will be prompted to confirm that the script should create it.
- If no Proxy Account is specified, you will be prompted to create one automatically or accept that the Agent ServiceAccount has access
- If no InstallDirectory is specified, the SQL Server's backup directory will be used by default
- If no LogFileDirectory is specified, InstallDirectory\logs will be used 

Installs the following on the local client:
	
	Config file at Documents\WindowsPowerShell\Modules\dbareports\dbareports-config.json
	
	The config file is pretty simple. This is for Windows (Trusted) Authentication
	
	{
    "Username":  null,
    "SqlServer":  "sql2016",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  null
	}
	
	And the following for SQL Login
	{
    "Username":  "sqladmin",
    "SqlServer":  "sql2016",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  "01000000d08c9ddf0115d1118c7a00c04fc297eb010000etcetc"
	}

	Or alternative Windows credentials 
	{
    "Username":  "ad\\dataadmin",
    "SqlServer":  "sqlcluster",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  "01000000d08c9ddf0115d1118c7a00c04fc297eb010000etcetc"
	}
	
Note that only the account that created the config file can decrypt the SecurePassword
	
.PARAMETER SqlServer
The SQL Server Instance that will hold the dbareports database and the agent jobs

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.

.PARAMETER InstallDatabase
The name of the database that will hold all of the information that the agent jobs gather. Defaults to dbareports

.PARAMETER InstallPath
The folder that will hold the PowerShell scripts that the Agent Jobs call and the logfiles for the agent jobs. The Agent account or Proxy must have access to this folder.
	
If no InstallPath is specified, the SQL Server's default backup directory is used. 

.PARAMETER LogFileFolder
The folder where the logs from the Agent Jobs will be written. Defaults to the "logs" folder in the Installpath directory.

.PARAMETER LogFileRetention
The number of days to keep the Log Files defaults to 30 days

.PARAMETER JobPrefix
The Prefix that gets added to the Agent Jobs defaults to dbareports

.PARAMETER JobCategory 
The category for the Agent Jobs. Defaults to "dbareports collection jobs"
	
.PARAMETER TimeSpan
By deafult, the jobs are scheduled to execute daily unless NoJobSchedule is specified. The default time is 04:15. To change the time, pass different timespan.

$customtimespan = New-TimeSpan -hours 22 -minutes 15

This would set the schedule the jobs for 10:15 PM.
	
.PARAMETER ReportsFolder
The folder where the report samples will be stored on the client (?)

.PARAMETER NoDatabaseObjects
A switch which will not update or create the database and its related objects

.PARAMETER NoJobs
A switch which will not install the Agent Jobs

.PARAMETER NoPsFileCopy
A switch which will not copy the PowerShell scripts

.PARAMETER NoJobSchedule
A switch which will not schedule the Agent Jobs

.PARAMETER NoConfig
A switch which will not create the json config file on the local machine. 

.PARAMETER Force
A switch to force the installation of dbareports. This will drop and recreate everything and all of your data will be lost. "Use the force wisely DBA"

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Install-DbaReports

.EXAMPLE
Install-DBAreports -SqlServer sql2016


.EXAMPLE
Install-DBAreports -SqlServer sql2016 -InstallPath \\fileshare\share\sql


.EXAMPLE
Install-DBAreports -SqlServer sql2016 -InstallPath \\fileshare\share\sql


#>
	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential,
		[Alias("Database")]
		[string]$InstallDatabase = "dbareports",
		[string]$InstallPath,
		[string]$JobPrefix = "dbareports",
		[string]$LogFileFolder,
		[int]$LogFileRetention = 30,
		[string]$ReportsFolder,
		[switch]$NoDatabaseObjects,
		[switch]$NoJobs,
		[switch]$NoPsFileCopy,
		[switch]$NoJobSchedule,
		[switch]$NoConfig,
		[string]$JobCategory = "dbareports collection jobs",
		[timespan]$TimeSpan = $(New-TimeSpan -hours 4 -minutes 15),
		[switch]$Force
	)
	
	DynamicParam { if ($SqlServer) { return (Get-ParamSqlProxyAccount -SqlServer $SqlServer -SqlCredential $SqlCredential) } }
	
	BEGIN
	{
		Function Add-DatabaseObjects
		{
			# Schema Setup
			Write-Output "Creating schemas"
			try
			{
				$schemanames = $sourceserver.Databases[$InstallDatabase].Schemas.Name
				$schemas = Get-ChildItem -Path "$parentPath\setup\database\Security\Schemas\*.sql"
				
				foreach ($filename in $schemas.Name)
				{
					$schemaname = $filename.Replace(".sql", "") # .TrimEnd doesn't work.
					
					if ($schemanames -contains $schemaname)
					{
						Write-Warning "Schema $schemaname already exists. Skipping."
						Continue
					}
					
					Write-Output "Creating schema $schemaname"
					$file = Get-ChildItem -Path "$parentPath\setup\database\Security\Schemas\$filename"
					$sql = Get-Content -Path $file -Raw
					$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
				}
			}
			catch
			{
				Write-Warning "Schema could not be created."
			}
			
			# Extended Properties Setup
			Write-Output "Creating extended properties"
			try
			{
				$propertynames = $sourceserver.Databases[$InstallDatabase].ExtendedProperties.Name
				$properties = Get-ChildItem -Path "$parentPath\setup\database\Extended Properties\*.sql"
				
				foreach ($filename in $properties.Name)
				{
					$name = $filename.Replace(".sql", "") # .TrimEnd doesn't work.
					
					if ($propertynames -contains $name)
					{
						Write-Warning "Extended Property $name already exists. Skipping."
						Continue
					}
					
					Write-Output "Creating Extended Property $name"
					$file = Get-ChildItem -Path "$parentPath\setup\database\Extended Properties\$filename"
					$sql = Get-Content -Path $file -Raw
					$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
				}
			}
			catch
			{
				Write-Warning "Extended Properties could not be created."
			}
			
			
			# Table setup with PKs first
			Write-Output "Creating tables"
			$tablenames = $sourceserver.Databases[$InstallDatabase].Tables.Name
			try
			{
				$first = 'info.serverinfo.sql', 'dbo.InstanceList.sql', 'info.Databases.sql', 'dbo.Clients.sql'
				
				foreach ($filename in $first)
				{
					$table = $filename.Replace(".sql", "") # .TrimEnd didn't work :()
					$schema = $table.Split(".")[0]
					$tablename = $table.Split(".")[1]
					
					if ($tablenames -contains $tablename)
					{
						Write-Warning "$table already exists. Skipping."
						continue
					}
					
					Write-Output "Creating table $tablename"
					$file = Get-ChildItem -Path "$parentPath\setup\database\Tables\$filename"
					$sql = Get-Content -Path $file -Raw
					$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
				}
			}
			catch
			{
				Write-Exception $_
				throw "Couldn't create tables $table"
			}
			
			# The rest of the Tables
			try
			{
				$therest = Get-ChildItem -Path "$parentPath\setup\database\Tables\*.sql" | Where-Object { $_.Name -notin $first }
				
				foreach ($filename in $therest.name)
				{
					$table = $filename.Replace(".sql", "") # .TrimEnd didn't work :()
					$schema = $table.Split(".")[0]
					$tablename = $table.Split(".")[1]
					
					if ($tablenames -contains $tablename)
					{
						Write-Warning "$table already exists. Skipping."
						continue
					}
					
					Write-Output "Creating table $tablename"
					
					$file = Get-ChildItem -Path "$parentPath\setup\database\Tables\$filename"
					$sql = Get-Content -Path $file -Raw
					$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
				}
				
			}
			catch
			{
				Write-Exception $_
				throw "Couldn't create the rest of the tables"
			}
			
			# Stored procedure Setup
			Write-Output "Creating initial stored procedures"
			
			try
			{
				$procnames = $sourceserver.Databases[$InstallDatabase].StoredProcedures.Name
				$procs = Get-ChildItem -Path "$parentPath\setup\database\StoredProcedures\*.sql"
				
				foreach ($filename in $procs.Name)
				{
					$procname = $filename.Split(".")[1]
					
					if ($procnames -contains $procname)
					{
						Write-Warning "Procedure $procname already exists. Skipping."
						Continue
					}
					
					Write-Output "Creating procedure $procname"
					$file = Get-ChildItem -Path "$parentPath\setup\database\StoredProcedures\$filename"
					$sql = Get-Content -Path $file -Raw
					$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
				}
			}
			catch
			{
				Write-Exception $_
				Write-Warning "Stored procedures could not be created."
			}
		}
		
		Function Add-BulkInsertSprocs
		{
			$notriggers = 'info.LogFileErrorMessages.sql', 'dbo.NotEntered.sql'
			$tables = Get-ChildItem -Path "$parentPath\setup\database\Tables\*.sql" | Where-Object { $notriggers -notcontains $_.Name }
			
			# Gotta hard refresh
			$sourceserver.Databases[$InstallDatabase].Tables.Refresh()
			$alltables = $sourceserver.Databases[$InstallDatabase].Tables
			
			$tvpnames = $sourceserver.Databases[$InstallDatabase].UserDefinedTableTypes.Name
			
			foreach ($table in $tables.BaseName)
			{
				$schema = $table.Split(".")[0]
				$tablename = $table.Split(".")[1]
				
				$tvptable = $alltables | Where-Object { $_.Schema -eq $schema -and $_.Name -eq $tablename }
				
				if ($tvptable -eq $null)
				{
					Write-Warning "Can't find $schema.$tablename. Moving on."
					Continue
				}
				
				$tvpname = "tvp_$tablename"
				
				if ($tvpnames -contains $tvpname)
				{
					Write-Warning "TVP $schema.tvp_$tablename already exists. Skipping TVP and Stored Procedure."
					Continue
				}
				
				# Use the table definition to create a type
				$script = $tvptable.Script()
				$script = $script.Replace("IDENTITY(1,1) NOT NULL", "")
				$script = $script.Replace("IDENTITY(1,1) NOT NULL", "")
				$script = $script.Replace(") ON [PRIMARY]", "")
				$script = $script.Replace("TEXTIMAGE_ON [PRIMARY]", "")
				$split = ($script -Split "CREATE TABLE \[$schema\]\.\[$tablename\]\(")
				$script = $split[$split.getupperbound(0)]
				
				$sql = "CREATE TYPE $schema.tvp_$tablename AS TABLE ($script, [U] bit)"
				
				try
				{
					Write-Verbose $sql
					Write-Output "Creating user defined table type $schema.tvp_$tablename"
					$results = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql)
				}
				catch
				{
					Write-Exception $_
					Write-Warning "Can't create TVP type for $table in the $InstallDatabase database on $($sourceserver.name)."
					Continue
				}
				
				$sql = "SELECT COLUMN_NAME as columnNames FROM INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = '$schema' AND TABLE_NAME = '$tablename'"
				
				try
				{
					$results = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql)
				}
				catch
				{
					Write-Exception $_
					throw "Can't get column list from $table in the $InstallDatabase database on $($sourceserver.name)."
				}
				
				$pkcolumn = Get-IdentityColumn $table
				if ($pkcolumn -eq $null)
				{
					Write-Warning "No IDENTITY column found on $tablename. Skipping."
					Continue
				}
				
				$onebyone = @()
				
				foreach ($column in $results.Tables.ColumnNames)
				{
					if ($column -ne $pkcolumn)
					{
						$onebyone += "[a].[$column] = [b].[$column]"
					}
				}
				
				$onebyone = $onebyone -join ","
				$allcolumns = ($results.Tables.ColumnNames | Where-Object { $_ -ne $pkcolumn }) -join "],["
				$allcolumns = "[$allcolumns]"
				
				$procname = "$schema.usp_$tablename"
				$sql = "CREATE PROCEDURE $procname
								@TVP $schema.tvp_$tablename READONLY
								AS
								BEGIN
									INSERT INTO $schema.$tablename ($allcolumns)
									SELECT $allcolumns FROM @TVP WHERE [U] = 0
								
									UPDATE a SET
									$onebyone
									FROM @tvp b JOIN $schema.$tablename a on a.$pkcolumn = b.$pkcolumn
									WHERE [U] = 1
								END"
				try
				{
					Write-Output "Creating procedure $procname"
					$results = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
				}
				catch
				{
					Write-Exception $_
					throw "Can't create stored procedure for $table in the $InstallDatabase database on $($sourceserver.name)."
				}
			}
		}
		
		Function Add-Jobs
		{
			if ($jobprefix -ne "dbareports")
			{
				$jobprefix = "$jobprefix - dbareports"
			}
			
			if ($ProxyAccount -eq $null) { $ProxyAccount = "None" }
			
			if ($InstallPath.StartsWith("\\"))
			{
				$JobFilePath = "Microsoft.PowerShell.Core\FileSystem::$InstallPath"
				$JobCommand = "powershell.exe -ExecutionPolicy Bypass"
			}
			else
			{
				#$JobFilePath = [regex]::Escape($InstallPath)
				$JobFilePath = $InstallPath
				$JobCommand = "powershell.exe -ExecutionPolicy Bypass . "
			}
			
			$diskusage = @{
				JobName = "$jobprefix - Disk Usage"
				Description = "This job will run a PowerShell script to gather the disk usage from the servers in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder."
				Command = "$JobCommand '$JobFilePath\DiskSpace.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$AgentJobDetail = @{
				JobName = "$jobprefix - Agent Job Results"
				Description = "This job will return all the agent job information about the servers in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder."
				Command = "$JobCommand '$JobFilePath\AgentJobDetail.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$AgentJobServer = @{
				JobName = "$jobprefix - Agent Job Server"
				Description = "This job will return all the agent job information about the servers in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder."
				Command = "$JobCommand '$JobFilePath\AgentJobServer.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$dbinfo = @{
				JobName = "$jobprefix - Database Information"
				Description = "This job will return all the database information from the Servers in the dbo.InstanceList table in the $InstallDatabase database.It will log to $LogFileFolder."
				Command = "$JobCommand '$JobFilePath\Databases.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$winserver = @{
				JobName = "$jobprefix - Windows Server Information"
				Description = "This job will return information about the servers listed in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder."
				Command = "$JobCommand '$JobFilePath\ServerOSInfo.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$sqlserverinfo = @{
				JobName = "$jobprefix - SQL Server Information"
				Description = "This job will return information about the SQL Servers listed in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder\$InstallDatabaseSQLInfoUpdate_"
				Command = "$JobCommand '$JobFilePath\SQLInfo.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$suspectpages = @{
				JobName = "$jobprefix - Suspect Pages"
				Description = "This job will run a PowerShell script to gather the suspect pages from the msdb database from the servers listed in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder\$InstallDatabaseSuspectPagesUpdate_"
				Command = "$JobCommand '$JobFilePath\SuspectPages.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$logcleanup = @{
				JobName = "$jobprefix - Log File Cleanup"
				Description = "This job will run a PowerShell script to gather the suspect pages from the msdb database from the servers listed in the dbo.InstanceList table in the $InstallDatabase database. It will log to $LogFileFolder\$InstallDatabaseSuspectPagesUpdate_"
				Command = "$JobCommand '$JobFilePath\cleanlogs.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$testaccess = @{
				JobName = "$jobprefix - Test Access to Servers and Log Directory"
				Description = "This job will run a PowerShell script to test accses to servers listed in the dbo.InstanceList table in the $InstallDatabase database. It will also test write access to $LogFileFolder."
				Command = "$JobCommand '$JobFilePath\TestAccess.ps1'"
				Subsystem = 'PowerShell'
			}
			
			$historicaldbsize = @{
				JobName = "$jobprefix - Historical Database Size"
				Description = "This job will archives database size information from the Servers in the dbo.InstanceList table in the $InstallDatabase database.It will log to $LogFileFolder."
				Subsystem = "TransactSql"
				Command = "INSERT INTO [Info].[HistoricalDBSize]
						SELECT [DatabaseID]
						      ,[DB].[InstanceID]
						      ,[DB].[Name]
						      ,[DateChecked]
						      ,[SizeMB]
						      ,[SpaceAvailableKB]
							FROM [$InstallDatabase].[Info].[Databases] DB JOIN [$InstallDatabase].[dbo].[InstanceList] IL ON IL.[InstanceID] = [DB].[InstanceID]
							WHERE [Environment] = 'Production'
							AND [DB].[Inactive] = 0
							AND [Status] NOT LIKE 'Offline%'"
			}
			
			$setdbinactive = @{
				LogFileFolder = $LogFileFolder
				Category = $JobCategory
				OwnerLoginName = $OwnerLoginName
				JobName = "$jobprefix - Check for and Label Inactive Databases"
				Description = "Sets the inactive field of database in info.Databases to 1 (true) when dbareports has been unable to contact/update from it for 3 days."
				Subsystem = "TransactSql"
				Command = "UPDATE [Info].[Databases] SET [Inactive] = 1 WHERE [DatabaseID] in (SELECT [DatabaseID]
                              FROM [$InstallDatabase].[Info].[Databases]
                              JOIN [dbo].InstanceList ON [$InstallDatabase].[Info].[Databases].[InstanceID] = [dbo].[InstanceList].[InstanceID]
                              WHERE [DateChecked] < dateadd(DAY,-3,getdate())
                              AND [InstanceList].[Inactive] = 0
                              AND [InstanceList].[Inactive] = 0)"
			}
			
			$jobnames = $sourceserver.JobServer.Jobs.Name
			
			$hasharray = @()
			$hasharray += $diskusage
			$hasharray += $AgentJobDetail
			$hasharray += $AgentJobServer
			$hasharray += $dbinfo
			$hasharray += $winserver
			$hasharray += $sqlserverinfo
			$hasharray += $suspectpages
			$hasharray += $logcleanup
			$hasharray += $historicaldbsize
			$hasharray += $setdbinactive
			$hasharray += $testaccess
			
			foreach ($hash in $hasharray)
			{
				$jobname = $hash.JobName
				
				if ($jobnames -contains $jobname)
				{
					Write-Warning "$jobname already exists. Skipping."
					Continue
				}
				
				Write-Output "Creating job $jobname"
				
				$temphash = @{
					LogFileFolder = $LogFileFolder
					Category = $JobCategory
					OwnerLoginName = $OwnerLoginName
					ProxyAccount = $ProxyAccount
					JobName = $jobname
					SubSystem = $Hash.SubSystem
					Description = $hash.Description
					Command = $hash.Command
				}
				
				if ($jobname -eq $historicaldbsize.JobName -or $jobname -eq $setdbinactive.JobName)
				{
					# T-SQL can't support a proxy account
					$temphash.Remove('ProxyAccount')
				}
				
				Add-DbrAgentJob @temphash
			}
		}
		
		Function Copy-PsFiles
		{
			if ($InstallPath.StartsWith("\\") -eq $true)
			{
				# Make the directories
				$null = New-Item -ItemType Directory $InstallPath -Force
				$null = New-Item -ItemType Directory "$InstallPath\logs" -Force
				
				# Copy the files
				$sourcedir = "$parentPath\setup\powershell"
				Write-Output "Copying everything from $sourcedir to $InstallPath"
				Copy-Item "$sourcedir\*.ps1" $InstallPath -Force
			}
			else
			{
				# It's local to the SQL Server.
				
				# Is the installer being run on the SQL Server itself?
				if ($Source -ne $env:COMPUTERNAME)
				{
					# Nope, copy files over UNC
					$InstallPath = Join-AdminUnc $Source $InstallPath
				}
				
				try
				{
					# Make the directories
					$null = New-Item -ItemType Directory $InstallPath -Force -ErrorAction Ignore
					$null = New-Item -ItemType Directory "$InstallPath\logs" -Force -ErrorAction Ignore
					
					# Somtimes it takes twice. I don't know why.
					$null = New-Item -ItemType Directory $InstallPath -Force -ErrorAction Ignore
					$null = New-Item -ItemType Directory "$InstallPath\logs" -Force -ErrorAction Ignore
					
					# copy the files to the admin UNC share
					Copy-Item "$parentPath\setup\powershell\*.ps1" $InstallPath -Force
				}
				catch
				{
					Write-Exception $_
					throw "Can't create files on $InstallPath. Check to ensure you have permissions to do so or run the installer locally."
				}
			}
			
			# Do the replaces
			Write-Output "Customizing files for this installation"
			$files = Get-ChildItem "$InstallPath\*.ps1"
			
			if ($LogFileFolder.StartsWith("\\"))
			{
				$JobLogPath = "Microsoft.PowerShell.Core\FileSystem::$LogFileFolder"
			}
			else
			{
				$JobLogPath = $LogFileFolder
			}
			
			foreach ($file in $files)
			{
				Write-Output "Updating $file"
				$customized = (Get-Content -Raw $file).Replace("--installserver--", $source)
				$customized = $customized.Replace("--installdb--", $InstallDatabase)
				$customized = $customized.Replace("--logdir--", $JobLogPath)
				$customized = $customized.Replace("--logretention--", $LogFileRetention)
				$customized | Set-Content $file
			}
		}
		
		Function Add-DatabaseAccess
		{
			$execaccount = $sourceserver.JobServer.ServiceAccount
			
			if ($ProxyAccount -ne $null -and $ProxyAccount -ne "None")
			{
				$proxydetails = $sourceserver.JobServer.ProxyAccounts[$ProxyAccount]
				$execaccount = $proxydetails.CredentialIdentity
			}
			
			$db = $sourceserver.Databases[$InstallDatabase]
			if ($execaccount -ne $null -and $db.Users[$execaccount] -eq $null)
			{
				Write-Output "Adding $execaccount to $InstallDatabase as db_owner"
				try
				{
					$dbuser = New-Object Microsoft.SqlServer.Management.Smo.User -ArgumentList $db, $execaccount
					$dbuser.Login = $execaccount
					$dbuser.Create()
					
					$dbo = $db.Roles['db_owner']
					$dbo.AddMember($execaccount)
					$dbo.Alter()
				}
				catch
				{
					Write-Exception $_
					Write-Warning "Cannot add $execaccount to $InstallDatabase as db_owner."
				}
			}
		}
		
		Function Add-JobSchedule
		{
			$schedulename = "daily dbareports update"
			$now = Get-Date -format "MM/dd/yyyy"
			$sourceserver.JobServer.Jobs.Refresh()
			$dbrjobs = $sourceserver.JobServer.Jobs | Where-Object { $_.Category -eq $JobCategory }
			$fiveminutes = New-TimeSpan -hours 0 -minutes 5
			
			foreach ($job in $dbrjobs)
			{
				$jobname = $job.name.Replace("dbareports - ", "")
				Write-Output "Scheduling $jobname for $timespan"
				
				$schedulename = "Daily dbareports update - $jobname"
				$schedule = New-Object Microsoft.SqlServer.Management.SMO.Agent.JobSchedule($job, $schedulename)
				$schedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily
				$schedule.FrequencyInterval = 1
				$schedule.ActiveStartTimeofDay = $timespan
				$schedule.ActiveStartDate = $now
				$schedule.Create()
				$job.AddSharedSchedule($schedule.id)
				$job.Alter()
				$timespan = $timespan.Add($fiveminutes)
			}
		}
		
		Function Get-IdentityColumn
		{
			$schema = $table.Split(".")[0]
			$tablename = $table.Split(".")[1]
			
			$sql = "SELECT name FROM $InstallDatabase.sys.columns Where [object_id] = OBJECT_ID('$schema.$tablename') AND is_identity = 1"
			
			try
			{
				$identity = $sourceserver.ConnectionContext.ExecuteScalar($sql)
			}
			catch
			{
				Write-Exception $_
				throw "Can't get column list from $table in the $InstallDatabase database on $($sourceserver.name)."
			}
			
			return $identity
		}
		
		Function Test-Access
		{
			$paths = $LogFileFolder, $InstallPath
			
			foreach ($path in $paths)
			{
				$folderperms = Test-SqlPath -SqlServer $sqlserver -Path $path
				
				if ($sqlaccount -eq $agentaccount)
				{
					if ($folderperms -eq $false)
					{
						throw "SQL Server Agent Account ($agentaccount) cannot access $path"
					}
				}
			}
		}
		
		Function Add-InstallInfo
		{
			try
			{
				# sp_addextendedproperty
				$sql = "EXEC sp_updateextendedproperty N'dbareports installpath', N'$InstallPath', NULL, NULL, NULL, NULL, NULL, NULL;
			    			EXEC sp_updateextendedproperty N'dbareports logfilefolder', N'$LogFileFolder', NULL, NULL, NULL, NULL, NULL, NULL"
				$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
			}
			catch
			{
				Write-Exception $_
				Write-Warning "Could not update extended properties in the $InstallDatabase database."
			}
		}
		
		Function Add-Migration
		{
			
			$Migrations = Get-ChildItem -Path "$parentPath\setup\database\UpgradeScripts\*.sql"
			$CurrentDBVersion = $sourceserver.Databases[$InstallDatabase].ExtendedProperties['dbareports version'].Value
			Write-Output "Current database version of $InstallDatabase is $CurrentDBVersion"
			Write-Output "Upgrading database to $DBVersion"
			foreach ($Migration in $Migrations)
			{
				$Scriptversion = $Migration.Name.Split(' ')[1]
				while ($Scriptversion -le $DBVersion)
				{
					try
					{
						$file = $Migration.FullName
						$sql = Get-Content -Path $file -Raw
						$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
						Write-Output "Upgrade file $File executed"
					}
					catch
					{
						Write-Warning "$File failed to execute"
						break
					}
				}
			}
			Write-Output "Upgraded database to $DBVersion"
			Write-Output "Setting Extended Property"
			try
			{
				$sql = "EXEC sp_updateextendedproperty N'dbareports version', N'$DBVersion', NULL, NULL, NULL, NULL, NULL, NULL"
				$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
			}
			catch
			{
				Write-Warning "Failed to update extended property"
			}
			
		}
		
		$DBVersion = '0.0.4' # Updates extended property and runs migration scripts for that version
		$parentPath = Split-Path -Parent $PSScriptRoot
		$ProxyAccount = $psboundparameters.ProxyAccount
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		$sqlaccount = $sourceserver.ServiceAccount
		
		if ($sourceserver.VersionMajor -lt 10)
		{
			throw "The dbareports database must be installed on SQL Server 2008 and above."
		}
	}
	
	PROCESS
	{
		if ($TimeSpan.Hours -gt 24)
		{
			throw "This is a daily schedule so the hours cannot exceed 24"
		}
		
		# ensure agent is running
		$agent = $sourceserver.EnumProcesses() | Where-Object { $_.Program -like '*Agent*' }
		$agentaccount = $sourceserver.JobServer.ServiceAccount
		
		if ($agent.count -eq 0)
		{
			throw "SQL Server Agent does not appear to be running."
		}
		
		# boom!
		if ($Force -eq $true)
		{
			if ($sourceserver.Databases[$InstallDatabase].Count -ne 0)
			{
				Write-Output "Force specified. Removing everything."
				Uninstall-DbaReports -Force -ErrorAction SilentlyContinue
			}
		}
		
		# Set installpath if not set
		if ($InstallPath.Length -eq 0)
		{
			$InstallPath = $sourceserver.BackupDirectory
			Write-Output "No install path specified, using SQL instance's backup directory $installpath"
			# WE CAN EITHER AUTO SET IT TO BACKUPS OR PROMPT THEM WITH SHOW-SQLSERVERFILESYSTEM?
		}
		
		if ($InstallPath -notlike '*dbareports*')
		{
			# Set full path
			$InstallPath = "$InstallPath\dbareports"
		}
		
		# Set logging folder if not set
		if ($LogFileFolder.Length -eq 0)
		{
			$LogFileFolder = "$InstallPath\logs"
			Write-Output "No log file path specified, using $LogFileFolder"
		}
		
		# check if database exists
		$sql = "select count(*) as dbcount from master.dbo.sysdatabases where name = '$InstallDatabase'"
		[bool]$dbexists = $sourceserver.ConnectionContext.ExecuteScalar($sql)
		
		if ($dbexists -eq $false)
		{
			if ($Force -eq $false)
			{
				# Prompt to create and then create. 
				$title = "The install database, $InstallDatabase, does not exist. Create?"
				$message = "Would you like us to create a database named $InstallDatabase on $sqlserver (Y/N)"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will continue"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will exit"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$result = $host.ui.PromptForChoice($title, $message, $options, 0)
				
				if ($result -eq 1) { return "FINE!" }
			}
			try
			{
				$sql = "create database [$InstallDatabase]"
				$dbexists = $sourceserver.ConnectionContext.ExecuteNonQuery($sql)
				$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
				$jobserver = $sourceserver.jobserver
			}
			catch
			{
				Write-Exception $_
				throw "Couldn't create database, sorry. BYE."
			}
		}
		else ## If I am right, if the db exists and db version less than version in here run the migration scripts from the current db version to version in this script
		{
			Write-Output "Checking for Migration Scripts"
			Add-Migration
		}
		If ($NoConfig -eq $false)
		{
			$securepassword = $SqlCredential.Password
			
			if ($securepassword -ne $null)
			{
				$securepassword = $securepassword | ConvertFrom-SecureString
			}
			
			$json = @{
				SqlServer = $SqlServer
				InstallDatabase = $InstallDatabase
				Username = $SqlCredential.username
				SecurePassword = $securepassword
			}
			
			$config = Get-ConfigFileName
			Write-Output "Writing config to $config"
			$json | ConvertTo-Json | Set-Content -Path $config -Force
		}
		
		if ($ProxyAccount.length -eq 0 -and $NoJobs -eq $false)
		{
			$dbrproxy = $sourceserver.JobServer.ProxyAccounts | Where-Object { $_.Name -like "*dbareports*" }
			
			if ($dbrproxy -eq $null -and $Force -eq $false)
			{
				$netbiosname = $sourceserver.ComputerNamePhysicalNetBIOS
				
				if ($agentaccount -like 'NT *' -or $agentaccount -like "$netbiosname\*")
				{
					Write-Warning "The Agent account, $agentaccount, is a local account. It is *highly unlikely* that it will have permissions to log into other SQL Servers."
				}
				
				# Prompt to create and then create. 
				$title = "You haven't specified a proxy account. The SQL Server Agent service account, $agentaccount, must have access to all servers or you can use a proxy account."
				$message = " Would you like to create a proxy now? (Y/N)"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will use the proxy account"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will not use the proxy account"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$result = $host.ui.PromptForChoice($title, $message, $options, 0)
				
				if ($result -eq 1) { Write-Output "K!" }
				if ($result -eq 0)
				{
					Add-DbrCredential
					
					$dbrproxy = $sourceserver.JobServer.ProxyAccounts | Where-Object { $_.Name -eq "PowerShell Proxy Account for dbareports" }
					
					if ($dbrproxy -ne $null)
					{
						$ProxyAccount = $dbrproxy.Name
					}
					else
					{
						throw "Proxy account not found. Can't continue."
					}
				}
			}
			elseif ($dbrproxy -ne $null)
			{
				$proxyname = $dbrproxy.Name
				
				# Prompt to create and then create. 
				$title = "We found the proxy account '$proxyname' but it was not specified."
				$message = "Would you like to use it for the install? (Y/N)"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Will use the proxy account"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Will not use the proxy account"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$result = $host.ui.PromptForChoice($title, $message, $options, 0)
				
				if ($result -eq 1) { Write-Output "FINE!" }
				if ($result -eq 0) { $ProxyAccount = $proxyname }
			}
		}
		
		If ($NoPsFileCopy -eq $false)
		{
			Write-Output "Copying PS files"
			Copy-PsFiles
			
			# Get SQL Server to test the access to each path
			Test-Access
		}
		
		If ($NoDatabaseObjects -eq $false)
		{
			Write-Output "Creating SQL Objects"
			Add-DatabaseObjects
			Write-Output "Creating Stored Procedures and User Defined Table Types"
			Add-BulkInsertSprocs
			Write-Output "Adding dbareports installation extended info"
			Add-InstallInfo
		}
		
		If ($NoJobs -eq $false -and $NoDatabaseObjects -eq $false)
		{
			Add-DatabaseAccess
		}
		
		If ($NoJobs -eq $false)
		{
			Write-Output "Creating Jobs"
			Add-Jobs
		}
		
		If ($NoJobSchedule -eq $false)
		{
			Write-Output "Adding Schedules starting at $TimeSpan"
			Add-JobSchedule
		}
		
		Write-Output "`nThanks for installing dbareports! Here are the results of Get-DbrConfig:"
		Get-DbrConfig
		Write-Output "You may now run Add-DbrServerToInventory to add a new server to your inventory."
		
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}