#Requires -Version 5.1
<#
    Post-deploy checks for the New North Ventures BIMI logo URL.

    Usage:
        .\verify.ps1
        .\verify.ps1 -Url "https://bimi.newnorthvc.com/logo.svg"

    Checks the four things mailbox providers silently fail on, plus byte
    integrity against the certified artwork. Also checks the local copy of
    logo.svg if you run it from inside the repo folder, which catches
    line-ending corruption BEFORE it ever gets pushed.
#>
[CmdletBinding()]
param(
    [string]$Url = "https://bimi.newnorthvc.com/logo.svg"
)

$WantSha   = "E75D249117052798183D73A39F3B69D5810AD56A73CF5022010FD1E0009D1806"
$WantBytes = 1676

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:pass = 0
$script:fail = 0
function Ok($m) { Write-Host "  PASS  $m" -ForegroundColor Green; $script:pass++ }
function No($m) { Write-Host "  FAIL  $m" -ForegroundColor Red;   $script:fail++ }

# --------------------------------------------------------------------------
# Pre-flight: the file on disk, before it is pushed anywhere.
# --------------------------------------------------------------------------
$localPath = Join-Path $PSScriptRoot "logo.svg"
if (Test-Path $localPath) {
    Write-Host "Local file: $localPath" -ForegroundColor Cyan
    $lb = (Get-Item $localPath).Length
    $ls = (Get-FileHash -Path $localPath -Algorithm SHA256).Hash
    if ($ls -eq $WantSha) {
        Ok "local logo.svg is the certified artwork ($lb bytes)"
    } else {
        $hint = ""
        if ($lb -eq 1682) {
            $hint = "`n        1682 bytes means CRLF line endings were introduced." +
                    "`n        Fix: git config --global core.autocrlf input, then re-extract the zip."
        }
        No "local logo.svg does NOT match the certified artwork$hint`n        got  $ls`n        want $WantSha"
    }
    Write-Host ""
}

# --------------------------------------------------------------------------
# Live URL
# --------------------------------------------------------------------------
Write-Host "Checking $Url" -ForegroundColor Cyan
Write-Host ""

$resp = $null; $status = $null; $redirected = $false
try {
    $resp = Invoke-WebRequest -Uri $Url -MaximumRedirection 0 -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    $status = [int]$resp.StatusCode
}
catch {
    $r = $_.Exception.Response
    if ($r) {
        $status = [int]$r.StatusCode
        if ($status -ge 300 -and $status -lt 400) { $redirected = $true }
    }
    else {
        Write-Host "  ....  request failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# 1. direct 200
if ($status -eq 200) { Ok "HTTP 200 (direct)" }
else { No ("expected HTTP 200, got " + $(if ($status) { $status } else { "no response" })) }

# 2. no redirect - providers do not follow them
if ($redirected) { No "redirect detected (HTTP $status) - mailbox providers do NOT follow redirects" }
elseif ($status -eq 200) { Ok "no 30x redirect" }
else { No "could not confirm redirect behaviour" }

# 3. exact content type
$ctype = $null
if ($resp -and $resp.Headers -and $resp.Headers['Content-Type']) {
    $ctype = @($resp.Headers['Content-Type'])[0]
}
if ($ctype -and $ctype.ToLower().StartsWith("image/svg+xml")) { Ok "Content-Type: $ctype" }
elseif (-not $ctype) { No "no Content-Type header" }
else { No "Content-Type is '$ctype', must be image/svg+xml" }

# 4. TLS
if ($resp) { Ok "TLS chain validates" } else { No "HTTPS request did not complete" }

# 5. byte integrity and size ceiling
$tmp = Join-Path $env:TEMP ("bimi-" + [guid]::NewGuid().ToString() + ".svg")
try {
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    $gotBytes = (Get-Item $tmp).Length
    $gotSha   = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash

    if ($gotSha -eq $WantSha) { Ok "SHA-256 matches the certified artwork" }
    else { No "SHA-256 MISMATCH - served file is not the certified artwork`n        got  $gotSha`n        want $WantSha" }

    if ($gotBytes -eq $WantBytes) { Ok "size $gotBytes bytes" }
    else { No "size is $gotBytes bytes, expected $WantBytes" }

    if ($gotBytes -lt 32768) { Ok "under the 32 KB ceiling" }
    else { No "exceeds 32 KB" }
}
catch {
    No "could not download the file: $($_.Exception.Message)"
}
finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}

Write-Host ""
if ($script:fail -eq 0) {
    Write-Host "ALL $($script:pass) CHECKS PASSED - safe to put this URL in the BIMI record." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "$($script:fail) CHECK(S) FAILED, $($script:pass) passed - do NOT publish the DNS record yet." -ForegroundColor Red
    exit 1
}
