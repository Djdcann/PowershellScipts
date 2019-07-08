# hello
param(
    [string]$d = "$env:USERPROFILE/git",
    [string]$cmd = "git status -s"
)
Set-Location $d
$s = Get-ChildItem -Directory
foreach($z in $s){
    Set-Location $z.FullName
    Write-Output "Checking $Pwd"
    $x = Invoke-Expression $cmd
    if($null -eq $x -or $x -eq ""){
        $true
    }else{
        $false
    }
    $x
}