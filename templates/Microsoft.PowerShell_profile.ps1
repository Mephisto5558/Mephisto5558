$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
[console]::InputEncoding = [System.Text.Encoding]::UTF8
[console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Global:Reset-IP {
  ipconfig /release
  ipconfig /release6
  ipconfig /renew
}

function Global:Reload-Shell {
  . $GLOBAL:profile
}

$env:SFW_SILENT = "true"
function Global:Invoke-SafeNPM {
  sfw npq-hero @args
}

function Global:tempdiff {
  git diff --cached >diff.diff
  code diff.diff --wait
  del diff.diff
}

Set-Alias -Name npm -Value Invoke-SafeNPM -Force -Option AllScope -Scope Global