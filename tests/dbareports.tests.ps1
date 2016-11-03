$Path = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = (get-item $Path ).parent.FullName
$ModuleName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"
$ManifestPath   = "$ModulePath\$ModuleName.psd1"

# test the module manifest - exports the right functions, processes the right formats, and is generally correct

Describe "Manifest" {

    $Manifest = $null
<#
    It "has a valid manifest" {

        {

            $Script:Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop -WarningAction SilentlyContinue

        } | Should Not Throw

    }
#> ## Until the issue with requiring full paths for required assemblies is resolved need to keep this commented out RMS 01112016

$Script:Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction SilentlyContinue
    It "has a valid name" {

        $Script:Manifest.Name | Should Be $ModuleName

    }



	It "has a valid root module" {

        $Script:Manifest.RootModule | Should Be "$ModuleName.psm1"

    }



	It "has a valid Description" {

        $Script:Manifest.Description | Should Be 'Dopest dba dashboards ever'

    }

	It "has a valid AUthor" {
		$Script:Manifest.Author | SHould Be 'SQL Collaborative - Initial Author Rob Sewell'
	}

	It "has a valid Company Namne" {
		$Script:Manifest.CompanyName | Should Be 'SQL Collaborative'
	}
    It "has a valid guid" {

        $Script:Manifest.Guid | Should Be '654a8346-35f1-4592-a1b5-0ee472fab074'

    }
	It "has valid PowerShell version" {
		$Script:Manifest.PowerShellVersion | Should Be '3.0'
	}

	It "has valid (invalid!!) required assemblies" {
		$Script:Manifest.RequiredAssemblies | Should Be 'Microsoft.SqlServer.Smo','Microsoft.SqlServer.SmoExtended'
	}

	It "has a valid copyright" {

		$Script:Manifest.CopyRight | Should Be '2016 Rob Sewell'

	}



	It 'exports all public functions' {

		$FunctionFiles = Get-ChildItem "$ModulePath\functions" -Filter *.ps1 -Exclude 'dynamicparams.ps1','sharedfunctions.ps1','Template.ps1'| Select -ExpandProperty BaseName

		$FunctionNames = $FunctionFiles

		$ExFunctions = $Script:Manifest.ExportedFunctions.Values.Name
		$ExFunctions
		foreach ($FunctionName in $FunctionNames)

		{

			$ExFunctions -contains $FunctionName | Should Be $true

		}

	}

}
