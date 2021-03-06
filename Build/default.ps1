properties {
    $BaseDirectory = Resolve-Path ..     
    $BuildDirectory = "$BaseDirectory\Build"
    $SrcDirectory = "$BaseDirectory\Source"
    $Nuget = "$BaseDirectory\Tools\NuGet.exe"
	$SlnFile = "$SrcDirectory\Chill.sln"
	$pluginSource = "$BaseDirectory\Source\Plugins"
	$7zip = "$BaseDirectory\Tools\7z.exe"
	$PackageDirectory = "$BaseDirectory\Package"
	$MsBuildLoggerPath = ""
	$Branch = ""
	$MsTestPath = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\MSTest.exe"
	$RunTests = $false
	$GitVersionExe = "$BuildDirectory\GitVersion.CommandLine.1.3.3\tools\GitVersion.exe"
}

task default -depends Clean, RestoreNuget, GetVersionNumber, ApplyAssemblyVersioning, ApplyPackageVersioning, Compile, RunTests, BuildZip, BuildPackage, PublishToMyget

task Clean {	
		
		Get-ChildItem $PackageDirectory -Filter *.nupkg -Recurse | ForEach { Remove-Item $_.FullName }
		Get-ChildItem $PackageDirectory -Filter *.zip -Recurse | ForEach { Remove-Item $_.FullName }
}

task GetVersionNumber{

        Write-Output "Running GitVersion on folder $BaseDirectory";
        
        exec {."$GitVersionExe" "$BaseDirectory" }
        
        $json = . "$GitVersionExe" "$BaseDirectory" 
        
        if ($LASTEXITCODE -eq 0) {
            $version = (ConvertFrom-Json ($json -join "`n"));

            
            $script:AssemblyVersion = $version.ClassicVersion;
            $script:InformationalVersion = $version.InformationalVersion;
            $script:NuGetVersion = $version.NugetVersionV2
			
			Write-Output "using AssemblyVersion: $AssemblyVersion, NugetVersion: $NuGetVersion"
        }
        else {
            Write-Output $json -join "`n";
        }
}

task ApplyAssemblyVersioning {
 	
	Get-ChildItem -Path $SrcDirectory -Filter "AssemblyInfo.cs" -Recurse -Force |
	foreach-object {  

		Set-ItemProperty -Path $_.FullName -Name IsReadOnly -Value $false
		Write-Output " updating assemblyInfo for $_.FullName to: $script:AssemblyVersion "
		
        $content = Get-Content $_.FullName
        
        if ($script:AssemblyVersion) {
    		Write-Output "Updating " $_.FullName "with version" $script:AssemblyVersion
    	    $content = $content -replace 'AssemblyVersion\("(.+)"\)', ('AssemblyVersion("' + $script:AssemblyVersion + '")')
            $content = $content -replace 'AssemblyFileVersion\("(.+)"\)', ('AssemblyFileVersion("' +$script:AssemblyVersion + '")')
        }
		
        if ($script:InfoVersion) {
    		Write-Output "Updating " $_.FullName "with information version" $script:InformationalVersion
            $content = $content -replace 'AssemblyInformationalVersion\("(.+)"\)', ('AssemblyInformationalVersion("' + $script:InformationalVersion + '")')
        }
        
	    Set-Content -Path $_.FullName $content
	}    
}

task ApplyPackageVersioning {

Get-ChildItem -Path $BaseDirectory -Filter ".nuspec" -Recurse -Force |
	foreach-object {  
		$fullName = $_.FullName
		Write-Output "Applying versioning to: $fullName. $script:NuGetVersion" 
	    Set-ItemProperty -Path $fullName -Name IsReadOnly -Value $false
		
	    $content = Get-Content $fullName
	    $content = $content -replace '<version>.*</version>', ('<version>' + "$script:NuGetVersion" + '</version>')
	    Set-Content -Path $fullName $content
	}
}
task RestoreNuget{
	& $Nuget restore $SlnFile
	& $Nuget install GitVersion.CommandLine -version "1.3.3"
}

task Compile {
   
	    exec { msbuild /v:m /p:Platform="Any CPU" $SlnFile /p:Configuration=Release /t:Rebuild}
   
}

task RunTests -precondition { return $RunTests -eq $true } {
	
}

task BuildZip {

}

task BuildPackage {
  & $Nuget pack "$PackageDirectory\Chill\.nuspec" -o "$PackageDirectory\Chill" 
  New-Item -ItemType Directory -Force -Path "$PackageDirectory\Chill.Autofac"
  & $Nuget pack "$pluginSource\Chill.Autofac\.nuspec" -o "$PackageDirectory\Chill.Autofac" 
  
  New-Item -ItemType Directory -Force -Path "$PackageDirectory\Chill.AutofacNSubstitute"
  & $Nuget pack "$pluginSource\Chill.AutofacNSubstitute\.nuspec" -o "$PackageDirectory\Chill.AutofacNSubstitute" 

  New-Item -ItemType Directory -Force -Path "$PackageDirectory\Chill.AutofacFakeItEasy"
  & $Nuget pack "$pluginSource\Chill.AutofacFakeItEasy\.nuspec" -o "$PackageDirectory\Chill.AutofacFakeItEasy" 

  New-Item -ItemType Directory -Force -Path "$PackageDirectory\Chill.Unity"
  & $Nuget pack "$pluginSource\Chill.Unity\.nuspec" -o "$PackageDirectory\Chill.Unity" 
  
    New-Item -ItemType Directory -Force -Path "$PackageDirectory\Chill.UnityNSubstitute"
  & $Nuget pack "$pluginSource\Chill.UnityNSubstitute\.nuspec" -o "$PackageDirectory\Chill.UnityNSubstitute" 
}

task PublishToMyget -precondition { return ($Branch -eq "master" -or $Branch -eq "<default>" -or $Branch -eq "develop") -and ($ApiKey -ne "") } {
}


