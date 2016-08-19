Function Verb-SqlNoun
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
		[switch]$Force
	)
	
	DynamicParam
	{
		Get-Config
		if ($script:SqlServer) { return (Get-ParamSqlDbrJobs -SqlServer $script:SqlServer -SqlCredential $script:SqlCredential) }
	}
	
	BEGIN
	{
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		if ($SqlServer.length -eq 0)
		{
			throw "No config file found. Have you installed dbareports? Please run Install-DbaReports or Install-DbaReportsClient"
		}
		
		If ($Force -eq $true) { $ConfirmPreference = 'None' }
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
	}
	
	PROCESS
	{
		If ($Pscmdlet.ShouldProcess($sqlserver, "Doing this"))
		{
			#Whatever
		}
		
		$sql = "select * from dbo.InstanceList"
		$datatable = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
		return $datatable
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
	}
}