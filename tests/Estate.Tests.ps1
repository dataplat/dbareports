# Runs a quick check against the servers returned from the $query
# ONLY CHECKS DEFAULT INSTANCES

$CentralDBAServer = ''
$CentralDatabaseName = 'DBADatabase'
$Query = " SELECT [ServerName] ,[InstanceName] ,[Port] FROM [DBADatabase].[dbo].[InstanceList] Where Inactive = 0  AND NotContactable = 0 "

try
{
	$AlltheServers = Invoke-Sqlcmd -ServerInstance $CentralDBAServer -Database $CentralDatabaseName -Query $query
	$ServerNames = $AlltheServers | Select-Object ServerName, InstanceName, Port
}
catch
{
	Write-Warning " Failed to gather Server and Instance names from the DBA Database"
}

Describe "Checking Estate Connectivity" {
	Context "Ping test" {
		foreach ($ServerName in $ServerNames)
		{
			$InstanceName = $ServerName | Select-Object InstanceName -ExpandProperty InstanceName
			$ServerName = $ServerName | Select-Object ServerName -ExpandProperty ServerName
			It "$Servername Should respond to ping" {
				(Test-Connection -ComputerName $Servername -Count 1 -Quiet -ErrorAction SilentlyContinue) | Should be $True
				
			}
			
		}
	}
}
Describe "Checking Estate SQL Services" {
	foreach ($ServerName in $ServerNames)
	{
		$InstanceName = $ServerName | Select-Object InstanceName -ExpandProperty InstanceName
		$ServerName = $ServerName | Select-Object ServerName -ExpandProperty ServerName
		
		$SQLDBEngine = Get-WmiObject Win32_Service -ComputerName $ServerName -Filter "Name = 'MSSQLSERVER'"
		$SQLAgent = Get-WmiObject Win32_Service -ComputerName $ServerName -Filter "Name = 'SQLSERVERAGENT'"
		It "$ServerName should have MSSQLSERVER Service Running" {
			$SQLDBEngine.State | Should BE "Running"
		}
		It "$ServerName should have SQLSERVERAGENT Service Running"{
			$SQLAgent.State | Should Be "Running"
		}
		If ($ServerName -notin) # dont check start mode of old clusters
		{
			It "$ServerName DBEngine Service should be Auto Start" {
				$SQLDBEngine.StartMode | Should Be "Auto"
			}
			It "$ServerName Agent Service should be Auto Start" {
				$SQLAgent.StartMode | Should Be "Auto"
			}
		}
	}
}

