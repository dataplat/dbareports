. Git:\dbareports\functions\SharedFunctions.ps1

### Get-Config Tests

Describe 'Get-Config Tests' {
  BeforeAll {
  # Remove those pesky variables if they exist
  Get-Variable -Name sqlserver -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
  Get-Variable -Name SqlCredential -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
  Get-Variable -Name InstallDatabase -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue

  # Move config json if it exists to keep it safe
    $docs = [Environment]::GetFolderPath("MyDocuments")
	$folder = "$docs\WindowsPowerShell\Modules\dbareports"
	$configfile = "$folder\dbareports-config.json"
	$exists = Test-Path $configfile
	
	if ($exists -eq $true)
	{
		Move-Item $configfile -Destination $docs -Force
	}

  }
    Context "No Config File" {
    It "Should Throw if there is no config file" {
       { Get-Config -ErrorAction Stop} |should Throw
    }
    } # End Context
    Context "With Config File - no credentials" {
    BeforeAll {
        New-Item -Path $folder -Name dbareports-config.json -ItemType File
    $json = @"
    	{
    "Username":  null,
    "SqlServer":  "sql2016",
    "InstallDatabase":  "dbareports",
    "SecurePassword":  null
	}
"@
    Set-Content -Value $json -LiteralPath $configfile
    }
    It "Should return" {
    Get-Config |Should Not Be NullorEmpty
    }
    It "sqlserver variable should exist" {
        Get-Variable sqlserver | Should Not Be NullorEmpty
    }
    It "sqlserver variable should have correct values" {
        (Get-Variable sqlserver).Value |Should Be 'sql2016'
    }
    It "installdatabase variable should exist" {
        Get-variable installdatabase | SHould Not Be NUllorEmpty
    }
    It "install database variable should have correct values" {
        (Get-Variable installdatabase).Value | Should be 'dbareports'
    }
} # End Context
    AfterAll {
    # return config json if it existed
    $docs = [Environment]::GetFolderPath("MyDocuments")
	$folder = "$docs\WindowsPowerShell\Modules\dbareports"
	$configfile = "$docs\dbareports-config.json"
	$exists = Test-Path $configfile
	
	if ($exists -eq $true)
	{
		Move-Item $configfile -Destination $Folder -Force
	}
    }
    Get-Config
}# end describe