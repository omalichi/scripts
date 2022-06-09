###################################################################
# User Settings:

  $proxy = "http://192.168.2.2:3128"
  $no_proxy = "localhost, 127.0.0.1, 192.168.0.1, 10.0.0.3, 172.16.1.1"

###################################################################

function ValidateProxy($proxy)
{
    Invoke-WebRequest -UseBasicParsing http://google.com -Proxy $proxy | Out-Null

    if($? -eq $true)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function AddProxy($proxy, $level="system")
{
    if($level -eq "all" -or $level -eq "system")
    {
        try
        {
            [Environment]::SetEnvironmentVariable("http_proxy", $proxy, [System.EnvironmentVariableTarget]::Machine)
            [Environment]::SetEnvironmentVariable("https_proxy", $proxy, [System.EnvironmentVariableTarget]::Machine)
            [Environment]::SetEnvironmentVariable("no_proxy", $no_proxy, [System.EnvironmentVariableTarget]::Machine)
        }
        catch
        {
            Write-host $_.Exception.Message
        }
    }

    if($level -eq "all" -or $level -eq "user")
    {
        try
        {
            [Environment]::SetEnvironmentVariable("http_proxy", $proxy, [System.EnvironmentVariableTarget]::User)
            [Environment]::SetEnvironmentVariable("https_proxy", $proxy, [System.EnvironmentVariableTarget]::User)
            [Environment]::SetEnvironmentVariable("no_proxy", $no_proxy, [System.EnvironmentVariableTarget]::User)
        }
        catch
        {
            Write-host $_.Exception.Message
        }
    }
    
    # "process" level is for current session update - always required
    try
    {
        [Environment]::SetEnvironmentVariable("http_proxy", $proxy, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable("https_proxy", $proxy, [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable("no_proxy", $no_proxy, [System.EnvironmentVariableTarget]::Process)
    }
    catch
    {
        Write-host $_.Exception.Message
    }
}

###########################
# Main Program
###########################

while($proxy -eq "")
{
    $proxy = Read-Host -Prompt "Please input a valid proxy url (scema and port included. E.g http://192.168.174.80:8080))"
}

if(ValidateProxy($proxy))
{
    AddProxy($proxy)
}
else
{
    Write-Host "Error! Invalid proxy value in the proxy parameter! Please make sure you put the correct proxy url and try again."
}

