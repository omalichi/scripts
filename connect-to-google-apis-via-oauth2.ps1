
# steps to gain api access to google:

# 1. in google's "api console" web UI (console.developers.google.com) create a new app, create credentials for it, set a "redirect url" for it, and add desired api scopes to it.
#        -> this step will generate 3 data items: 1) a client id, 2) a client secret 3) a list of urls which are the 'scopes' that you will gain access to
# 2. generate a url to google's oauth api using the client_id value and the scopes urls (with SPACES between them) using the respected parameters. e.g. for 2 scopes (user & group mgmt) we will get the url:
# https://accounts.google.com/o/oauth2/auth?client_id=<your-client-id>&scope=https://www.googleapis.com/auth/admin.directory.user https://www.googleapis.com/auth/admin.directory.group&response_type=code&redirect_uri=<your-redirect-uri>&access_type=offline&approval_prompt=force
# a full scopes list is available here: https://developers.google.com/identity/protocols/oauth2/scopes
# 3. open the following url in a web browser and login with your standard google user
# 4. the browser will try to redirect to the url given in step 1 (it does not need to be active) with a value named "code". save this code value. NOTE: the code value is valid for only ONE request! Refresh it if needed by repeating the above process.
# 5. generate a new url to google' token api using the code you just got, client id value, client secret value, redirect uri value, grant type as shown in the code below and access type as shown below.
# 6. the above if successful will grant you an "access token" and a "refresh token". the "access token" is the token you need to run API calls. the "access token" expires whereas the "refresh token" never does! use it to get a new "access token" when the latter expires.
# 7. use the "refresh token" with your client data to get a new "access token" when needed using a different url call (see below in the code). "refresh_token" lasts for several months at a time.

# about this script:

# this script assumes you have a valid code. once you have it, put it below where the 'body' section is.
# fill in the other mandatory fields as well (client_id etc)
# run the script. if everything is OK you should get the refresh token and current access token to text files in the place where you ran the script from
# from this point on, you can use the refresh token to get a new access token to gain api access until it expires (and then you will have to run this script again with a new code to get a new refresh token)
# in the bottom you have a test code sample. adjust it to your own api call needs to test your api access (optional)

# Troubleshooting:

# * if you get an "invalid_grant" error - make sure that you:
#    1. generate a new secret for the client (refresh the 'client_secret' value)
#    2. request a new code (section 4 above) - the 'code' value can be used only once!

#$requestUri = "https://www.googleapis.com/oauth2/v4/token"

$accessTokenFileSpec = $PSScriptRoot + "\accessToken.txt"
$refreshTokenFileSpec = $PSScriptRoot + "\refreshToken.txt"

#$proxy = "1.2.3.4:8080"

# setup a proxy via env var
$env:HTTPS_PROXY="1.2.3.4:8080"

$requestUri = "https://oauth2.googleapis.com/token"

$tokens = ""

$body = @{
  code="<code-gotton-manually-see-details-above>"
  client_id="<your-client-id>"
  client_secret="<your-client-secret>"
  redirect_uri="<your-redirect-uri>"
  grant_type="authorization_code" # Fixed value
  access_type="offline" # fixed value
}

try
{
    $body

    $tokens = Invoke-RestMethod -Uri $requestUri -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" #-Proxy $proxy

    $tokens | select content | ft

    #$tokens | Get-Member

    if($tokens.access_token -ne $null -and $tokens.access_token -ne "")
    {
        # Store accessToken
        Set-Content $accessTokenFileSpec $tokens.access_token
    }

    if($tokens.refresh_token -ne $null -and $tokens.refresh_token -ne "")
    {    
        # Store refreshToken
        Set-Content $refreshTokenFileSpec $tokens.refresh_token
    }
}
catch 
{
    #$_
    $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    $ErrResp = $streamReader.ReadToEnd() | ConvertFrom-Json
    $streamReader.Close()

    $ErrResp | ft

    $error[0]
}

# try to refresh the connection using a refresh token
$status = Test-Path $refreshTokenFileSpec

if($status -eq $true)
{
    $refreshToken = Get-Content $refreshTokenFileSpec

    if($refreshToken.Length -gt 0)
    {
        $refreshTokenParams = @{
                client_id=$body.client_id
                client_secret=$body.client_secret
                refresh_token=$refreshToken
                grant_type="refresh_token" # Fixed value
        }

        $refreshTokenParams

        try
        {
            $tokens = Invoke-RestMethod -Uri $requestUri -Method POST -Body $refreshTokenParams -ContentType "application/x-www-form-urlencoded"

            $tokens | fl
        }
        catch 
        {
            $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $ErrResp = $streamReader.ReadToEnd() | ConvertFrom-Json
            $streamReader.Close()

            $ErrResp | ft
        }

        #$tokens | select *

        if($tokens.access_token -ne $null -and $tokens.access_token -ne "")
        {
            # Store accessToken
            Set-Content $accessTokenFileSpec $tokens.access_token
        }
    }
    else
    {
        Write-Host "Error! Could not get a valid 'refresh token'."
    }
}

# api call example

$status = Test-Path $accessTokenFileSpec

if($status -eq $true)
{
    $accessToken = Get-Content $accessTokenFileSpec

    if($accessToken.Length -gt 0)
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        $api_url_test = "https://admin.googleapis.com/admin/directory/v1/users/"

        try
        {
            $result = Invoke-WebRequest -Uri $api_url_test -Headers $headers #-Proxy $proxy

            echo $result.statusCode
            echo $result.content
        }
        catch 
        {
            $error[0]
        }
    }
}
