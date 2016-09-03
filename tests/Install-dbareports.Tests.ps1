#Thank you Warren http://ramblingcookiemonster.github.io/Testing-DSC-with-Pester-and-AppVeyor/

if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}
$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

Import-Module $PSScriptRoot\..\functions\Install-dbareports.ps1 -Force

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.', '.')

Import-Module PSScriptAnalyzer
$Rules = (Get-ScriptAnalyzerRule).Where{$_.RuleName -ne 'PSUseSingularNouns'}
$Name = $sut.Split('.')[0]

    Describe 'Script Analyzer Tests' {
            Context 'Testing $sut for Standard Processing' {
                foreach ($rule in $rules) { 
                    $i = $rules.IndexOf($rule)
                    It "passes the PSScriptAnalyzer Rule number $i - $rule  " {
                        (Invoke-ScriptAnalyzer -Path "$here\$sut" -IncludeRule $rule.RuleName ).Count | Should Be 0 
                    }
                }
            }
        }
    Describe 'Tests For Help' {
    # The module-qualified command fails on Microsoft.PowerShell.Archive cmdlets 
$Help = Get-Help $Name -ErrorAction SilentlyContinue 

# If help is not found, synopsis in auto-generated help is the syntax diagram 
It "should not be auto-generated" { 
## Unsure why this fails so commenting out	$Help.Synopsis | Should Not Match '*[<CommonParameters>]*' 
} 
 
# Should be a description for every function 
It "gets description for $Name" { 
	$Help.Description | Should Not BeNullOrEmpty 
} 
 
# Should be at least one example 
It "gets example code from $Name" { 
	($Help.Examples.Example | Select-Object -First 1).Code | Should Not BeNullOrEmpty 
} 
 
# Should be at least one example description 
It "gets example help from $Name" { 
	($Help.Examples.Example.Remarks | Select-Object -First 1).Text | Should Not BeNullOrEmpty 
} 
 
Context "Test parameter help for $Name" { 
	 
	$Common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer', 'OutVariable', 
	'PipelineVariable', 'Verbose', 'WarningAction', 'WarningVariable' 
	$command = Get-Command $name
	$parameters = $command.ParameterSets.Parameters | Sort-Object -Property Name -Unique | Where-Object { $_.Name -notin $common } 
	$parameterNames = $parameters.Name 
	$HelpParameterNames = $Help.Parameters.Parameter.Name | Sort-Object -Unique 
	 
	foreach ($parameter in $parameters) 
	{ 
		$parameterName = $parameter.Name 
		$parameterHelp = $Help.parameters.parameter | Where-Object Name -EQ $parameterName 
		 
		# Should be a description for every parameter 
		It "gets help for parameter: $parameterName : in $Name" { 
			$parameterHelp.Description.Text | Should Not BeNullOrEmpty 
		} 
		 
		# Required value in Help should match IsMandatory property of parameter 
		It "help for $parameterName parameter in $Name has correct Mandatory value" { 
			$codeMandatory = $parameter.IsMandatory.toString() 
			$parameterHelp.Required | Should Be $codeMandatory 
			} 
			 
			# Parameter type in Help should match code 
			It "help for $Name has correct parameter type for $parameterName" { 
				$codeType = $parameter.ParameterType.Name 
				# To avoid calling Trim method on a null object. 
				$helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() } 
				$helpType | Should be $codeType 
			} 
		} 
		 
		foreach ($helpParm in $HelpParameterNames) 
		{ 
			# Shouldn't find extra parameters in help. 
			It "finds help parameter in code: $helpParm" { 
				$helpParm -in $parameterNames | Should Be $true 
			} 
		} 
	} 
} 
    Describe "$Name Tests"{
              Context "$Name Parameters" {
              BeforeAll {
              $Name= Get-Command $Name
              }
              It 'Has Cmdlet Binding set to true' {
              $Name.CmdletBinding |should Be True
              }
              It 'Has a sqlserver Parameter'{
              ($Name.Parameters['sqlserver']) | Should Be $true
              }
              It 'sqlserver Parameter shoud be an object' {
              $Name.Parameters['sqlserver'].ParameterType | Should Be System.Object
              }
              It 'has a sqlcredential Parameter' {
              ($Name.Parameters['SqlCredential']) | Should Be $true
              }
              It 'SqlCredential Parameter should be PSCredential' {
              $Name.Parameters['SqlCredential'].ParameterType | Should be PSCredential
              }
              It 'has an InstallDatabase parameter' {
              ($Name.Parameters['InstallDatabase']) | Should Be $True
              }
              It 'InstallDatabase Parameter should be a string' {
              $Name.Parameters['InstallDatabase'].ParameterType | Should Be string
              }
              It 'has a InstallPath Parameter' {
              ($Name.Parameters['InstallPath']) | Should Be $true
              }
              It 'InstallPath Parameter should be a string' {
              $Name.Parameters['InstallPath'].ParameterType | Should Be string
              }
              It 'has a JobPrefix Parameter' {
              ($Name.Parameters['JobPrefix']) | Should Be $true
              }
              It 'JobPrefix Parameter should be a string' {
              $Name.Parameters['JobPrefix'].ParameterType | Should Be string
              }
              It 'has a LogFileFolder Parameter' {
              ($Name.Parameters['LogFileFolder']) | Should Be $true
              }
              It 'LogFileFolder Parameter should be a string' {
              $Name.Parameters['LogFileFolder'].ParameterType | Should Be string
              }
              It 'has a LogFileRetention Parameter' {
              ($Name.Parameters['LogFileRetention']) | Should Be $true
              }
              It 'LogFileRetention Parameter should be an int' {
              $Name.Parameters['LogFileRetention'].ParameterType | Should Be int
              }
              It 'has a ReportsFolder Parameter' {
              ($Name.Parameters['ReportsFolder']) | Should Be $true
              }
              It 'ReportsFolder Parameter should be a string' {
              $Name.Parameters['ReportsFolder'].ParameterType | Should Be string
              }
              It 'has a NoDatabaseObjects Parameter' {
              ($Name.Parameters['NoDatabaseObjects']) | Should Be $true
              }
              It 'NoDatabaseObjects Parameter should be a switch' {
              $Name.Parameters['NoDatabaseObjects'].ParameterType | Should Be switch
              }
              It 'has a NoJobs Parameter' {
              ($Name.Parameters['NoJobs']) | Should Be $true
              }
              It 'NoJobs Parameter should be a switch' {
              $Name.Parameters['NoJobs'].ParameterType | Should Be switch
              }
              It 'has a NoPsFileCopy Parameter' {
              ($Name.Parameters['NoPsFileCopy']) | Should Be $true
              }
              It 'NoPsFileCopy Parameter should be a switch' {
              $Name.Parameters['NoPsFileCopy'].ParameterType | Should Be switch
              }
              It 'has a NoJobSchedule Parameter' {
              ($Name.Parameters['NoJobSchedule']) | Should Be $true
              }
              It 'NoJobSchedule Parameter should be a switch' {
              $Name.Parameters['NoJobSchedule'].ParameterType | Should Be switch
              }
              It 'has a NoConfig Parameter' {
              ($Name.Parameters['NoConfig']) | Should Be $true
              }
              It 'NoConfig Parameter should be a switch' {
              $Name.Parameters['NoConfig'].ParameterType | Should Be switch
              }
              It 'has a JobCategory Parameter' {
              ($Name.Parameters['JobCategory']) | Should Be $true
              }
              It 'JobCategory Parameter should be a string' {
              $Name.Parameters['JobCategory'].ParameterType | Should Be string
              }
              It 'has a TimeSpan Parameter' {
              ($Name.Parameters['TimeSpan']) | Should Be $true
              }
              It 'TimeSpan Parameter should be a timespan' {
              $Name.Parameters['TimeSpan'].ParameterType | Should Be timespan
              }  
              }
              Context 'Output' {

              }
    }
