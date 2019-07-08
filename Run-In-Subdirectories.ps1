# hello
param(
    [string]$d = "$env:USERPROFILE/git",
    [string]$cmd = "git status -s"
)
$staringLocation = $Pwd
Set-Location $d
$s = Get-ChildItem -Directory
foreach($z in $s){
    Set-Location $z.FullName
    Write-Output "Checking $Pwd"
    $x = Invoke-Expression $cmd
    if($null -eq $x){
        $true
    }else{
        $false
    }
    $x
}
Set-Location $staringLocation