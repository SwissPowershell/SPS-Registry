Set-Location -Path $PSScriptRoot
# $Message = Read-Host -Prompt 'Please enter the commit message or enter for default'
# if ($Message -eq '') {$Message = "V2.0.4 Commit"}
$Message = "V0.0.1 commit"
Git add --all
Git commit -a -am $Message
Git push