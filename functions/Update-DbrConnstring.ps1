Function Update-DbrConnstring
{
<#
.SYNOPSIS 


.DESCRIPTION


.PARAMETER 


.PARAMETER 


.PARAMETER 
	

.PARAMETER 

	
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
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[object]$SqlCredential,
		[string]$InstallDatabase,
		[string]$Something,
		[switch]$SomethingElse
	)
	
	
	DynamicParam { if ($sqlserver) { return Get-ParamSqlDatabases -SqlServer $sqlserver -SqlCredential $SqlCredential } }
	
	BEGIN
	{
	
	if ($SqlServer.length -eq 0)
		{
			Get-Config
			$SqlServer = $script:SqlServer
			$InstallDatabase = $script:InstallDatabase
			$SqlCredential = $script:SqlCredential
		}
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		
		$Databases = $psboundparameters.Databases
	}
	
	PROCESS
	{
		$sql = "select * from sys.master_files"
		$datatable = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}