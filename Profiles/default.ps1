# This profile targets powershell 5.1, alias removal not needed for Powershell 6
Remove-Item alias:curl
Remove-Item alias:wget
Set-PSReadLineKeyHandler -Key CTRL+TAB -Function Complete
