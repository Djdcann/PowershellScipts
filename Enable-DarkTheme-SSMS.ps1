$filePath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\ssms.pkgundef"
(Get-Content $filePath) -replace "^(\[\`$RootKey\`$\\Themes\\{1ded0138-47ce-435e-84ef-9ec1f439b749}\])$", "//`$1" | Out-File $filePath