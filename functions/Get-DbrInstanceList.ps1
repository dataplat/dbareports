Function Get-DbrInstanceList
{
<#
.SYNOPSIS 
Returns datatable of contents of InstanceList table

.DESCRIPTION
Returns datatable of contents of InstanceList table

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/Get-DbrInstanceList

.EXAMPLE
Get-DbrInstanceList
Returns datatable of contents of InstanceList table

#>
	
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
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential

	}
	
	PROCESS
	{
		$sql = "select * from dbo.InstanceList"
		$datatable = $sourceserver.Databases[$InstallDatabase].ExecuteWithResults($sql).Tables
		return $datatable
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
	}
}