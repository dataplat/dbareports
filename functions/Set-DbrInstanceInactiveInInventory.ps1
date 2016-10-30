Function Set-DbrInstanceInactiveInInventory
{
<#
.SYNOPSIS 
For Instances that have been decommisioned but you still want to report on

.DESCRIPTION
Marks the specified instance as inactive. This means that new data will not be gathered about that instance however existing data will not be removed and you will still be able generate reports using that data. 

.PARAMETER SQLServerName

.PARAMETER SQLInstanceName

.NOTES 
dbareports PowerShell module (https://dbareports.io, SQLDBAWithABeard.com)
Copyright (C) 2016 Rob Sewell

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbareports.io/functions/Set-DbrInstanceInactiveInInventory
#>
	[CmdletBinding()]
	Param (
		[string]$SQLServerName,
		[string]$SQLInstanceName
	)
	
	DynamicParam { return Get-ParamSqlServerInventory }
	
	BEGIN
	{
		Get-Config
		$SqlServer = $script:SqlServer
		$InstallDatabase = $script:InstallDatabase
		$SqlCredential = $script:SqlCredential
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		
		# Get columns automatically from the table on the SQL Server
		# and creates the necessary $script:datatable with it
		$table = "dbo.InstanceList"
		$schema = $table.Split(".")[0]
		$tablename = $table.Split(".")[1]
		
	}
	
	PROCESS
	{
		
		
		$sql = "UPDATE $table SET InActive = 1 where ServerName = '$SQLServerName' AND InstanceName = '$SQLInstanceName'"
		
		try
		{
			Write-Output "Setting $SQLServerName\$SQLInstanceName to Inactive in the dbareports database $InstallDatabase on $sqlserver"
			$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
		}
		catch
		{
			Write-Output "Unable to set $SQLServerName\$SQLInstanceName to Inactive in the dbareports database $InstallDatabase on $sqlserver using SQL: $sql"
			Write-Exception $_
			Continue
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}