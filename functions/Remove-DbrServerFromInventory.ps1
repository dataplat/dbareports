Function Remove-DbrServerFromInventory
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
	[CmdletBinding()]
	Param ()
	
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
		
		$Instances = $psboundparameters.Instance
		$ServerNames = $psboundparameters.ServerName
		
	}
	
	PROCESS
	{
		
		foreach ($instance in $Instances)
		{
			$sql = "delete from $table where InstanceName = '$instance'"
			
			try
			{
				Write-Output "Removing $instance"
				$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
			}
			catch
			{
				Write-Output "Unable to delete $instance using SQL: $sql"
				Write-Exception $_
				Continue
			}
		}
		
		foreach ($server in $ServerNames)
		{
			$sql = "delete from $table where ServerName = '$server'"
			
			try
			{
				Write-Output "Removing $server"
				$null = $sourceserver.Databases[$InstallDatabase].ExecuteNonQuery($sql)
			}
			catch
			{
				Write-Warning "Unable to delete $server"
				Write-Exception $_
				Continue
			}
		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		
	}
}