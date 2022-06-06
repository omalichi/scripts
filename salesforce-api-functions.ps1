<#

creds file template:
----------------------

client_id=<client_id from ui>
client_secret=<client_secret from ui>
username=<username>
password=<pwd>

#>


$global:proxy="http://192.168.1.1:3128"

$global:salesForceDomainUrl = "https://org-dev-ed.my.salesforce.com"

$global:salesForceTokensURL = $global:salesForceDomainUrl + "/services/oauth2/token"

$global:sObjectsAPI = $global:salesForceDomainUrl + "/services/data/v54.0/sobjects/"
$global:queryAPI = $global:salesForceDomainUrl + "/services/data/v54.0/query?q="

$global:defaultLogFileName = "functions.log"

$global:tempPwdsFileSpec = "tempPwds.txt"

$global:userAlreadyExistsErrorCode = "DUPLICATE_username"
$global:SuccessfulEmptyResult = "`"totalSize`":0"

$global:MINIMAL_PASSWORD_SIZE=8

if($PSScriptRoot -eq "" -or $PSScriptRoot -eq $null)
{
    $PSScriptRoot = "C:\projects\export-users-to-google"
}

#Enable-TlsCipherSuite -Name "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384" -Position 0            

#[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# skip ssl certs checks and force tls 1.2

function setup-ssl()
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
        $certCallback = @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback
        {
            public static void Ignore()
            {
                if(ServicePointManager.ServerCertificateValidationCallback == null)
                {
                    ServicePointManager.ServerCertificateValidationCallback +=
                        delegate
                        (
                            Object obj,
                            X509Certificate certificate,
                            X509Chain chain,
                            SslPolicyErrors errors
                        )
                        {
                            return true;
                        };
                }
            }
        }
"@
        Add-Type $certCallback
    }

    [ServerCertificateValidationCallback]::Ignore()	

}

function write-to-log-file($dataToWrite, $logFileSpec, $append = "yes")
{
    if($dataToWrite -ne $null -and $dataToWrite -ne "")
    {
        if($append -eq "yes")
        {
            $dataToWrite | Out-File -FilePath $logFileSpec -Append
        }
        else
        {
            $dataToWrite | Out-File -FilePath $logFileSpec
        }
    }
}

function connect-to-salesforce-cloud($credsFileSpec, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($credsFileSpec -ne $null)
    {
        $status = Test-Path $credsFileSpec

        if($status -eq $true)
        {
            $accessToken = ""

            $authParams = (Get-Content $credsFileSpec | ConvertFrom-StringData)
        
            if($authParams -ne "")
            {
                $accessToken = (connect-to-salesforce-cloud-2 $authParams[0].client_id $authParams[1].client_secret $authParams[2].username $authParams[3].password $logFileSpec)

                #write-to-log-file $accessToken $logFileSpec "yes"
            }
            else
            {
                write-to-log-file "Error! Invalid creds file! (connect func #1 - empty auth param)" $logFileSpec "yes" 

                return $false            
            }

            if($accessToken -ne $false)
            {
                return $accessToken
            }
            else
            {
                write-to-log-file "Error! Invalid creds! (connect func #1)" $logFileSpec "yes" 

                return $false
            }
        }
        else
        {
            write-to-log-file "Error! Invalid creds file! (connect func #1)" $logFileSpec "yes"

            return $false
        }
    }
    else
    {
        write-to-log-file "Error! Invalid creds file! (connect func #1 - null param)" $logFileSpec "yes"

        return $false        
    }
}

function connect-to-salesforce-cloud-2($client_id, $client_secret, $username, $password, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($client_id -ne "" -and $client_secret -ne "" -and $username -ne "" -and $password -ne "")
    {
        $authParams = @{
            client_id=$client_id
            client_secret=$client_secret
            username=$username
            password=$password
            grant_type="password" # Fixed value
        }       

        try
        {
            $result = Invoke-WebRequest -UseBasicParsing -Proxy $global:proxy -Uri $global:salesForceTokensURL -Method POST -Body $authParams -ContentType "application/x-www-form-urlencoded"

            if($result.StatusCode -eq "200")
            {
                $tokens = ($result.content | ConvertFrom-Json)

                if($tokens.access_token -ne $null -and $tokens.access_token -ne "")
				{
					$accessToken = $tokens.access_token

					return $accessToken
				}
				else
				{
					write-to-log-file "Error! Could not get a valid 'access token' from the given 'refresh token'." $logFileSpec "yes"

					return $false
				}
            }
            else
            {
                if($result.content -ne $null -and $result.content -ne "")
                {
                    write-to-log-file "Error occured while trying to get the tokens!" $logFileSpec "yes"
                    write-to-log-file "The response was:" $logFileSpec "yes"
                    write-to-log-file ($result.content) $logFileSpec "yes"
                }
                else
                {
                    write-to-log-file ("error [connect-to-salesforce-cloud-2]: " + $error[0]) $logFileSpec "yes"
                }

                return $false
            }
        }
        catch
        {
            write-to-log-file ("error [connect-to-salesforce-cloud-2]: " + $error[0]) $logFileSpec "yes"
            
            write-to-log-file "Error! (connect func #2)" $logFileSpec "yes"

            return $false
        }
    }
    else
    {
        write-to-log-file "ERROR! Some arguments are empty. Please fill all arguments and run again." $logFileSpec "yes"

        return $false
    }
}

function run-a-query-based-api-request-on-salesforce-cloud($accessToken, $query, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($query -ne $null -and $query -ne "")
    {
        if($accessToken -ne "")
        {
            $headers = @{
                Authorization = "Bearer " + $accessToken
            }

            try
            {                
                write-to-log-file ("`n`nfunc: run-a-query-based-api-request-on-salesforce-cloud, about to run the cmd: Invoke-WebRequest -UseBasicParsing -Proxy $global:proxy -Headers `@" + (($headers | ConvertTo-Json) -replace ":","=") + " -ContentType `"application/json; charset=UTF-8`" -Uri $global:queryAPI" + ($query -replace "'","``'") + "`n`n") $logFileSpec "yes"
                $result = Invoke-WebRequest -UseBasicParsing -Proxy $global:proxy -Headers $headers -ContentType "application/json; charset=UTF-8" -Uri $global:queryAPI$query

                # salesforce returns status of 201 for success as well
                if($result.StatusCode -eq "200" -or $result.StatusCode -eq "201")
                {
                    return $result
                }
                else
                {
                    if($result.content -ne $null -and $result.content -ne "")
                    {
                        write-to-log-file "Error occured while trying to run the query '$query'!" $logFileSpec "yes"
                        write-to-log-file "The status code was:" $logFileSpec "yes"
                        write-to-log-file ($result.StatusCode) $logFileSpec "yes"                                
                        write-to-log-file "The response was:" $logFileSpec "yes"
                        write-to-log-file ($result.content) $logFileSpec "yes"
                    }
                    else
                    {
                        write-to-log-file ("error [run-a-query-based-api-request-on-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                    }

                    return $false
                }
            }
            catch
            {
                write-to-log-file "error [run-a-query-based-api-request-on-salesforce-cloud]:" $logFileSpec "yes"

                if($Error[0].Exception.Response -eq $null)
                {
                    write-to-log-file "Error[0].Exception.Response is null!" $logFileSpec "yes"
                    write-to-log-file "Error[0] is:" $logFileSpec "yes"
                    write-to-log-file "$Error[0]" $logFileSpec "yes"
                }
                else
                {
                    $respStream = $Error[0].Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($respStream)
                    $respBody = $reader.ReadToEnd() | ConvertFrom-Json                                        
                }

                return $false
            }
        }
        else
        {
            write-to-log-file "Error! Invalid creds (func: run-a-query-based-api-request-on-salesforce-cloud)!" $logFileSpec "yes"

            return $false
        }
    }        
    else
    {
            write-to-log-file "Error! the 'query' param must be not null and not empty (func: run-a-query-based-api-request-on-salesforce-cloud)!" $logFileSpec "yes"

            return $false        
    }
}

function run-an-object-based-api-request-on-salesforce-cloud($accessToken, $objectName, $method, $extraURLData="", $bodyData="", $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($objectName -ne $null -and $objectName -ne "" -and $method -ne $null -and $method -ne "")
    {
        if($objectName.toLower() -eq "user" -or $objectName.toLower() -eq "PermissionSetAssignment")
        {
            if($method.toLower() -eq "get" -or $method.toLower() -eq "post" -or $method.toLower() -eq "patch" -or $method.toLower() -eq "delete")
            {
                if($accessToken -ne "")
                {
                    $headers = @{
                        Authorization = "Bearer " + $accessToken
                    }
                    
                    try
                    {
                        write-to-log-file ("`n`nfunc: run-an-object-based-api-request-on-salesforce-cloud, about to run the cmd: Invoke-WebRequest -UseBasicParsing -Proxy $global:proxy -Headers `@" + ($headers | ConvertTo-Json) + " -ContentType `"application/json; charset=UTF-8`" -Uri $global:sObjectsAPI$objectName/$extraURLData -Method $method -Body $bodyData`n`n") $logFileSpec "yes"
                        $result = Invoke-WebRequest -UseBasicParsing -Proxy $global:proxy -Headers $headers -ContentType "application/json; charset=UTF-8" -Uri $global:sObjectsAPI$objectName"/"$extraURLData -Method $method -Body $bodyData

                        # salesforce returns status of 201 and 204 (= no content) for success as well
                        if($result.StatusCode -eq "200" -or $result.StatusCode -eq "201" -or $result.StatusCode -eq "204")
                        {
                            return $result
                        }
                        else
                        {
                            if($result.content -ne $null -and $result.content -ne "")
                            {
                                write-to-log-file "Error occured while trying to run the sObject call '$global:sObjectsAPI$objectName`"/`"$extraURLData' with method '$method' and body '$bodyData'!" $logFileSpec "yes"
                                write-to-log-file "The status code was:" $logFileSpec "yes"
                                write-to-log-file ($result.StatusCode) $logFileSpec "yes"                                
                                write-to-log-file "The response was:" $logFileSpec "yes"
                                write-to-log-file ($result.content) $logFileSpec "yes"
                            }
                            else
                            {
                                write-to-log-file ("error [run-an-object-based-api-request-on-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                            }

                            return $false
                        }
                    }
                    catch
                    {
                        write-to-log-file "error [run-an-object-based-api-request-on-salesforce-cloud]:" $logFileSpec "yes"                        

                        if($Error[0].Exception.Response -eq $null)
                        {
                            write-to-log-file "Error[0].Exception.Response is null!" $logFileSpec "yes"
                            write-to-log-file "Error[0] is:" $logFileSpec "yes"
                            write-to-log-file "$Error[0]" $logFileSpec "yes"
                        }
                        else
                        {
                            $respStream = $Error[0].Exception.Response.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($respStream)
                            $respBody = $reader.ReadToEnd() | ConvertFrom-Json                                        
                        }

                        return $false
                    }
                }
                else
                {
                    write-to-log-file "Error! Invalid creds (func: run-an-object-based-api-request-on-salesforce-cloud)!" $logFileSpec "yes"

                    return $false
                }
            }
            else
            {
                write-to-log-file "Error! param 'method' contains an unsupported method type (func: run-an-object-based-api-request-on-salesforce-cloud)!" $logFileSpec "yes"

                return $false
            }
        }
        else
        {
            write-to-log-file "Error! param 'objectName' contains an unsupported object type (func: run-an-object-based-api-request-on-salesforce-cloud)!" $logFileSpec "yes"

            return $false
        }
    }    
    else
    {
            write-to-log-file "Error! the 'objectName' and 'method' params must be not null and not empty (func: run-an-object-based-api-request-on-salesforce-cloud)!" $logFileSpec "yes"

            return $false
    }    
}


function get-first-user-from-salesforce-cloud($accessToken, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($accessToken -ne "")
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        try
        {
            $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+username+FROM+User+Limit+1" $logFileSpec)

            return $result.content
        }
        catch
        {
            write-to-log-file ("error [get-first-user-from-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"

            return $false
        }
    }
    else
    {
        write-to-log-file "Error! Invalid creds (func: get-first-user-from-salesforce-cloud)!" $logFileSpec "yes"

        return $false
    }
}

function create-a-user-in-salesforce-cloud($accessToken, $username, $password, $userDataAsJson, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($accessToken -ne $null -and $accessToken -ne "")
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        try
        {
            # we need this one function to return 2 different statuses so that we could ask about them later
            # so for that we create a 2 fields new object
            # this is a powershell trick for creating an object with custom read/write fields
            $output = "" | Select-Object userCreationStatus,passwordCreationStatus

            $output.userCreationStatus = $false
            $output.passwordCreationStatus = $false

            $result = (run-an-object-based-api-request-on-salesforce-cloud $accessToken "user" "post" "" $userDataAsJson $logFileSpec)

            if($result.StatusCode -eq "200")
            {
                $output.userCreationStatus = $true

                write-to-log-file "User Created successfully." $logFileSpec "yes"
                                
                # try to set a password for the user
                if($password -ne $null -and $password -ne "" -and $password.length -gt $global:MINIMAL_PASSWORD_SIZE)
                {                    
                    try
                    {
                        # we need the user's id to set a password
                        $userID = (get-a-user-id-from-username $accessToken $username $logFileSpec)

                        if($userID -ne $null -and $userID -ne "")
                        {                        
                            $userPwdAsJson = "{`n`"NewPassword`": $password`n}"

                            $result = (run-an-object-based-api-request-on-salesforce-cloud $accessToken "user" "post" ($userID + "/password") $userPwdAsJson $logFileSpec)

                            if($result.StatusCode -eq "200")
                            {
                                write-to-log-file "Password Created successfully." $logFileSpec "yes"
                                
                                $output.passwordCreationStatus = $true
                            }
                            else
                            {
                                write-to-log-file "WARNING: Error occured while trying to create the password." $logFileSpec "yes"

                                $output.passwordCreationStatus = $false
                            }
                        }
                        else
                        {
                            write-to-log-file "Error! Could not get mandatory value of the userID from the cloud for the user '$email' (func: create-a-user-in-salesforce-cloud)!" $logFileSpec "yes"
                            write-to-log-file "WANRING: therefore a password for this user cannot be created." $logFileSpec "yes"
                        }
                    }
                    catch
                    {
                        write-to-log-file "Warning: the given user password is invalid. Will NOT create a password for this user." $logFileSpec "yes"
                    }
                }
                else
                {
                    write-to-log-file "Warning: the given user password is invalid. Will NOT create a password for this user." $logFileSpec "yes"
                }

                return $output
            }
            else
            {
                $respStream = $Error[0].Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($respStream)
                $respBody = $reader.ReadToEnd() | ConvertFrom-Json

                write-to-log-file "Error occured while trying to create the user (func: create-a-user-in-salesforce-cloud)!" $logFileSpec "yes"
                write-to-log-file "The error was:" $logFileSpec "yes"
                write-to-log-file $respBody $logFileSpec "yes"
            }
        }
        catch
        {
            #write-to-log-file $Error[0] $logFileSpec "yes"

            if($Error[0].Exception.Response -eq $null)
            {
                write-to-log-file "Error[0].Exception.Response is null!" $logFileSpec "yes"
                write-to-log-file "Error[0] is:" $logFileSpec "yes"
                write-to-log-file "$Error[0]" $logFileSpec "yes"

                return $false
            }
            else
            {
                $respStream = $Error[0].Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($respStream)
                $respBody = $reader.ReadToEnd() | ConvertFrom-Json
            
                $userStatus = $respBody | select-string $global:userAlreadyExistsErrorCode

                if($userStatus -ne "")
                {
                    # this user already exists - return 409
                    write-to-log-file "User already exists (func: create-a-user-in-salesforce-cloud)!" $logFileSpec "yes"

                    return 409
                }
                else
                {
                    write-to-log-file "Error occured while trying to create the user (func: create-a-user-in-salesforce-cloud)!" $logFileSpec "yes"
                    write-to-log-file "The error was:" $logFileSpec "yes"
                    write-to-log-file $respBody $logFileSpec "yes"
               
                    return $false
                }
            }
        }
    }
    else
    {
        write-to-log-file "Error! Invalid creds (func: create-a-user-in-salesforce-cloud)!" $logFileSpec "yes"

        return $false
    }
}

function update-a-user-in-salesforce-cloud($accessToken, $userEmail, $userDataAsJson, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($accessToken -ne $null -and $accessToken -ne "" -and $userEmail -ne $null -and $userEmail -ne "")
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        try
        {
            $result = (run-an-object-based-api-request-on-salesforce-cloud $accessToken "user" "patch" "" $userDataAsJson $logFileSpec)

            if($result.StatusCode -eq "200")
            {
                return $true
            }
            else
            {
                if($result.content -ne $null -and $result.content -ne "")
                {
                    write-to-log-file "Error occured while trying to update the user!" $logFileSpec "yes"
                    write-to-log-file "The response was:" $logFileSpec "yes"
                    write-to-log-file ($result.content) $logFileSpec "yes"
                }
                else
                {
                    write-to-log-file ("error [update-a-user-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                }

                return $false
            }            
        }
        catch
        {
            write-to-log-file ("error [update-a-user-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
            
            return $false
        }
    }
    else
    {
        write-to-log-file "Error! Mandatory values are missing! (func: update-a-user-in-salesforce-cloud)" $logFileSpec "yes"

        return $false
    }
}

# a "group" here is actually a "PermissionSetGroup" object/group in salesforce
function get-a-group-id-from-group-name($accessToken, $groupName, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($groupName -ne $null -and $groupName -ne "")
    {
        if($accessToken -ne "")
        {
            $headers = @{
                Authorization = "Bearer " + $accessToken
            }

            try
            {
                $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+id+FROM+PermissionSetGroup+where+PermissionSetGroup.developerName=`'$groupName`'" $logFileSpec)

                if($result.content -ne $null -and $result.content -ne "")
                {
                    return ($result.content | convertfrom-json).records.id
                }
                else
                {
                    write-to-log-file ("error [get-a-group-id-from-group-name]: " + $error[0]) $logFileSpec "yes"
                }                
            }
            catch
            {
                write-to-log-file ("error [get-a-group-id-from-group-name]: " + $error[0]) $logFileSpec "yes"
            
                return $false
            }

        }       
        else
        {
            write-to-log-file "Error! Invalid creds (func: get-a-group-id-from-group-name)!" $logFileSpec "yes"

            return $false
        }
    }        
    else
    {
            write-to-log-file "Error! the 'groupName' param must be not null and not empty (func: get-a-group-id-from-group-name)!" $logFileSpec "yes"

            return $false        
    }    

}

# the username in salesforce must be an email pattern (the account does not need to exist)
function get-a-user-id-from-username($accessToken, $username, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($username -ne $null -and $username -ne "")
    {
        if($accessToken -ne "")
        {
            $headers = @{
                Authorization = "Bearer " + $accessToken
            }

            try
            {
                $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+id+FROM+User+where+username=`'$username`'" $logFileSpec)

                if($result.content -ne $null -and $result.content -ne "")
                {
                    return ($result.content | convertfrom-json).records.id
                }
                else
                {
                    write-to-log-file ("error [get-a-user-id-from-username]: " + $error[0]) $logFileSpec "yes"
                }                
            }
            catch
            {
                write-to-log-file ("error [get-a-user-id-from-username]: " + $error[0]) $logFileSpec "yes"
            
                return $false
            }

        }       
        else
        {
            write-to-log-file "Error! Invalid creds (func: get-a-user-id-from-username)!" $logFileSpec "yes"

            return $false
        }
    }        
    else
    {
            write-to-log-file "Error! the 'username' param must be not null and not empty (func: get-a-user-id-from-username)!" $logFileSpec "yes"

            return $false
    }    

}

# $groupMembershipsList is a list of groups delimited by commas - the groups MUST be valid names of the same groups on the cloud
# a "group" here is actually a "PermissionSetGroup" object/group in salesforce
# in salesforce cloud, all the data is managed as a big sql DB. this means that we need to use tables ids in order to update the user's group memberships
# there is a special obj called 'PermissionSetAssignment' that manages links between users and groups. this is the object that we need to manage here as well
# the username in salesforce must be an email pattern (the account does not need to exist)
function add-a-user-to-groups-in-salesforce-cloud($accessToken, $username, $groupMembershipsList, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($username -ne $null -and $username -ne "" -and $groupMembershipsList -ne $null -and $groupMembershipsList -ne "")
    {
        # the user's id we need once
        $userID = (get-a-user-id-from-username $accessToken $username $logFileSpec)

        if($userID -ne $null -and $userID -ne "")
        {
            if($accessToken -ne $null -and $accessToken -ne "")
            {
                $headers = @{
                    Authorization = "Bearer " + $accessToken
                }

                try
                {
                    write-to-log-file "groupMembershipsList is:" $logFileSpec "yes"
                    write-to-log-file $groupMembershipsList $logFileSpec "yes"

                    if($groupMembershipsList.trim() -ne "")
                    {
                        $groupsArr = $groupMembershipsList -split ","
                    }

                    foreach($group in $groupsArr)
                    {   
                        $groupID = (get-a-group-id-from-group-name $accessToken $group $logFileSpec)
                        
                        if($groupID -ne $null -and $groupID -ne "")
                        {
                            $body = "{`n`"AssigneeId`": `"$userID`", `"PermissionSetGroupId`": `"$groupID`"`n}"

                            $result = (run-an-object-based-api-request-on-salesforce-cloud $accessToken "PermissionSetAssignment" "post" "" $body $logFileSpec)                            
                                            
                            if($result.StatusCode -ne "200")
                            {
                                #if($result.StatusCode -eq "409")
                                #{
                                #    write-to-log-file "The user is already a member of this group. Ignoring ..." $logFileSpec "yes"                        
                                #}
                                #else
                                #{
                                    if($result.content -ne $null -and $result.content -ne "")
                                    {
                                        write-to-log-file "Error occured while trying to add the user '$username' to the group '$group' (func: add-a-user-to-groups-in-salesforce-cloud)!" $logFileSpec "yes"
                                        write-to-log-file "The response was:" $logFileSpec "yes"
                                        write-to-log-file ($result.content) $logFileSpec "yes"
                                    }
                                    else
                                    {
                                        write-to-log-file ("error [add-a-user-to-groups-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                                    }
                                    
                                    # fatal error
                                    return $false
                                #}
                            }            
                        }
                        else
                        {
                            write-to-log-file "Warning! Could not get mandatory value of the groupID from the cloud for the group '$group'. Does the group exist in the cloud? (func: add-a-user-to-groups-in-salesforce-cloud)!" $logFileSpec "yes"
                        }
                    }

                    return $true
                }
                catch 
                {
                    # when there is an error, the $result param WON'T be populated at all and it will stay NULL
                    # so in that case we need to parse the error itself

                    $err = ($error[0] | ConvertFrom-Json)

                    if($err.error.code -eq "409")
                    {
                        write-to-log-file "The user is already a member of this group. Ignoring ..." $logFileSpec "yes"
                
                        return $true                        
                    }
                    else
                    {
                        write-to-log-file ("error [add-a-user-to-groups-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"

                        return $false
                    }            
                }
            }
            else
            {
                write-to-log-file "Error! Invalid creds (func: add-a-user-to-groups-in-salesforce-cloud)!" $logFileSpec "yes"

                return $false
            }
        }
        else
        {
            write-to-log-file "Error! Could not get mandatory value of the userID from the cloud for the user '$username' (func: add-a-user-to-groups-in-salesforce-cloud)!" $logFileSpec "yes"

            return $false
        }
    }
    else
    {
        write-to-log-file "Error! Mandatory values are missing (func: add-a-user-to-groups-in-salesforce-cloud)!" $logFileSpec "yes"

        return $false
    }
}

# a "group" here is actually a "PermissionSetGroup" object/group in salesforce
# in salesforce cloud, all the data is managed as a big sql DB. this means that we need to use tables ids in order to update the user's group memberships
# there is a special obj called 'PermissionSetAssignment' that manages links between users and groups. this is the object that we need to manage here as well
# the username in salesforce must be an email pattern (the account does not need to exist)
function get-a-assignment-obj-id-from-username-and-group-name($accessToken, $username, $groupName, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($username -ne $null -and $username -ne "" -and $groupName -ne $null -and $groupName -ne "")
    {
        if($accessToken -ne $null -and $accessToken -ne "")
        {
            $headers = @{
                Authorization = "Bearer " + $accessToken
            }

            try
            {
                $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+PermissionSetAssignment.id+from+PermissionSetAssignment+where+assignee.username=`'$username`'+and+PermissionSetGroup.developerName=`'$groupName`'" $logFileSpec)

                if($result.content -ne $null -and $result.content -ne "")
                {
                    if($result.content -contains $global:SuccessfulEmptyResult)
                    {
                        return 0
                    }
                    else
                    {
                        return ($result.content | convertfrom-json).records.id
                    }
                }
                else
                {
                    write-to-log-file ("error [get-a-assignment-obj-id-from-username-and-group-name]: " + $error[0]) $logFileSpec "yes"
                }                
            }
            catch
            {
                write-to-log-file ("error [get-a-assignment-obj-id-from-username-and-group-name]: " + $error[0]) $logFileSpec "yes"
            
                return $false
            }

        }       
        else
        {
            write-to-log-file "Error! Invalid creds (func: get-a-assignment-obj-id-from-username-and-group-name)!" $logFileSpec "yes"

            return $false
        }
    }        
    else
    {
            write-to-log-file "Error! the 'username' and 'groupName' params must be not null and not empty (func: get-a-assignment-obj-id-from-username-and-group-name)!" $logFileSpec "yes"

            return $false
    }    

}

# a "group" here is actually a "PermissionSetGroup" object/group in salesforce
# the username in salesforce must be an email pattern (the account does not need to exist)
function delete-a-user-from-a-group-in-salesforce-cloud($accessToken, $username, $groupName, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($accessToken -ne $null -and $accessToken -ne "" -and $username -ne $null -and $username -ne "" -and $groupName -ne $null -and $groupName -ne "")
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        try
        {
            $assignmentObjID = (get-a-assignment-obj-id-from-username-and-group-name $accessToken $username $groupName $logFileSpec)

            if($assignmentObjID -ne $null -and $assignmentObjID -ne "")
            {
                $result = (run-an-object-based-api-request-on-salesforce-cloud $accessToken "PermissionSetAssignment" "delete" $assignmentObjID "" $logFileSpec)

                # salesforce returns status of 204 (= no content) for successful delete request
                if($result.StatusCode -eq "200" -or $result.StatusCode -eq "204")
                {
                    return $true
                }
                else
                {
                    if($result.content -ne $null -and $result.content -ne "")
                    {
                        write-to-log-file "Error occured while trying to delete the user from the group!" $logFileSpec "yes"
                        write-to-log-file "The response was:" $logFileSpec "yes"
                        write-to-log-file ($result.content) $logFileSpec "yes"
                    }
                    else
                    {
                        write-to-log-file ("error [delete-a-user-from-a-group-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                    }

                    return $false
                }
            }
            else
            {
                if($assignmentObjID -eq 0)
                {
                    write-to-log-file "The is no assignment by that username and group. Nothing to do ..." $logFileSpec "yes"

                    return $true
                }
                else
                {
                    write-to-log-file "Error! Could not get mandatory value of the assignmentObjID from the cloud for the user '$username' and group '$groupName' (func: delete-a-user-from-a-group-in-salesforce-cloud)!" $logFileSpec "yes"

                    return $false
                }                
            }
        }
        catch 
        {
            write-to-log-file ("error [delete-a-user-from-a-group-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"

            return $false
        }
    }
    else
    {
        write-to-log-file "Error! Mandatory values are missing (func: delete-a-user-from-a-group-in-salesforce-cloud)!" $logFileSpec "yes"

        return $false
    }    
}

# the username in salesforce must be an email pattern (the account does not need to exist)
function get-a-user-from-salesforce-cloud($accessToken, $username, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($username -ne $null -and $username -ne "")
    {
        if($accessToken -ne $null -and $accessToken -ne "")
        {
            $headers = @{
                Authorization = "Bearer " + $accessToken
            }

            try
            {
                $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+ID+from+user+where+username=`'$username`'" $logFileSpec)            

                if($result.StatusCode -eq "200")
                {
                    return $result.content
                }
                else
                {
                    write-to-log-file "Error occured while trying to get the user! (response code: " + ($result.StatusCode) + ")" $logFileSpec "yes"
                    write-to-log-file "The response was:" $logFileSpec "yes"
                    write-to-log-file ($result.content) $logFileSpec "yes"

                    return $false
                }
            }
            catch
            {
                if($result.StatusCode -ne $null -and $result.StatusCode -ne "")
                {
                    write-to-log-file "Error occured while trying to get the user! (response code: " + ($result.StatusCode) + ")" $logFileSpec "yes"
                    write-to-log-file "The response was:" $logFileSpec "yes"
                    write-to-log-file ($result.content) $logFileSpec "yes"                
                }
                else
                {
                    write-to-log-file "Error occured while trying to get the user! (general error - request failed)" $logFileSpec "yes"
                    write-to-log-file ("error [get-a-user-from-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                }

                return $false
            }
        }
        else
        {
            write-to-log-file "Error! the 'username' param must be not null and not empty (func: get-a-user-from-salesforce-cloud)!" $logFileSpec "yes"

            return $false            
        }
    }
    else
    {
        write-to-log-file "Error! Invalid creds (func: get-a-user-from-salesforce-cloud)!" $logFileSpec "yes"

        return $false
    }
}

# NOTE: the list is returned WITHOUT the email suffix of the remote groups
# the username in salesforce must be an email pattern (the account does not need to exist)
function get-a-list-of-group-memberships-for-a-user-in-salesforce-cloud($accessToken, $username, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($accessToken -ne $null -and $accessToken -ne "" -and $username -ne $null -and $username -ne "")
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        try
        {
            $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+PermissionSetGroup.developername+from+PermissionSetAssignment+where+assignee.username=`'$username`'+and+PermissionSetGroup.developerName!=null" $logFileSpec)                                    

            if($result.StatusCode -eq "200")
            {
                $resultsAsJson = ($result.Content | ConvertFrom-Json)

                $userGroupMemberships = ($resultsAsJson.records.PermissionSetGroup.DeveloperName -join ",")

                return ($userGroupMemberships)
            }
            else
            {
                if($result.content -ne $null -and $result.content -ne "")
                {
                    write-to-log-file "Error occured while trying to get the user group memberships!" $logFileSpec "yes"
                    write-to-log-file "The response was:" $logFileSpec "yes"
                    write-to-log-file ($result.content) $logFileSpec "yes"
                }
                else
                {
                    write-to-log-file ("error [get-a-list-of-group-memberships-for-a-user-in-salesforce-cloud]:" + $error[0]) $logFileSpec "yes"
                }

                return $false
            }
        }
        catch 
        {
            write-to-log-file ("error [get-a-list-of-group-memberships-for-a-user-in-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"

            return $false
        }
    }
    else
    {
        write-to-log-file "Error! Mandatory values are missing! (func: get-a-list-of-group-memberships-for-a-user-in-salesforce-cloud)" $logFileSpec "yes"

        return $false
    }    
}

# $groupMembershipsList is a list of groups delimited by commas - the groups MUST be valid aliases or emails of the same groups on the cloud
# this function gets a list of groups and compares it to groups on the cloud - groups that need to be removed\added from\to the user will be added\removed
# the username in salesforce must be an email pattern (the account does not need to exist)
function sync-user-group-memberships-from-a-local-user-to-salesforce-cloud($accessToken, $username, $localGroupMembershipsList, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($accessToken -ne $null -and $accessToken -ne "" -and $username -ne $null -and $username -ne "" -and $localGroupMembershipsList -ne $null)
    {
        $headers = @{
            Authorization = "Bearer " + $accessToken
        }

        try
        { 
            $remoteGroupMembershipsList = (get-a-list-of-group-memberships-for-a-user-in-salesforce-cloud $accessToken $username $logFileSpec)

            if($remoteGroupMembershipsList -ne $null)
            {
                $localGroupMembershipsArr = $localGroupMembershipsList -split ","
                $remoteGroupMembershipsArr = $remoteGroupMembershipsList -split ","

                # remove empty items for the arrays
                $localGroupMembershipsArr = $localGroupMembershipsArr.Split('', [System.StringSplitOptions]::RemoveEmptyEntries)
                $remoteGroupMembershipsArr = $remoteGroupMembershipsArr.Split('', [System.StringSplitOptions]::RemoveEmptyEntries)

                write-to-log-file "func 'sync-user-group-memberships-from-a-local-user-to-salesforce-cloud' debug data:" $logFileSpec "yes"
                write-to-log-file "user: $username" $logFileSpec "yes"
                write-to-log-file "localGroupMembershipsList: $localGroupMembershipsList" $logFileSpec "yes"
                write-to-log-file "remoteGroupMembershipsList: $remoteGroupMembershipsList" $logFileSpec "yes"

                # process groups from local to remote and add new groups
                foreach ($group in $localGroupMembershipsArr)
                {
                    if($remoteGroupMembershipsList -notmatch $group -and $group.trim() -ne "")
                    {
                        $result = (add-a-user-to-groups-in-salesforce-cloud $accessToken $username $group $logFileSpec)

                        if($result -ne $true)
                        {
                            write-to-log-file "Error occured while trying to add the user '$username' to the group '$group' (func: sync-user-group-memberships)!" $logFileSpec "yes"

                            return $false
                        }
                    }
                    else
                    {
                        if($group.trim() -ne "")
                        {
                            write-to-log-file "sync-user-group-memberships: the user $username is already a member of the remote group '$group'. No need to add it again." $logFileSpec "yes"
                        }
                    }
                }

                # process groups from remote to local and add remove remote groups that were taken out of the local list
                # this is already "emails" based so no need to convert it as in the code above
                foreach ($group in $remoteGroupMembershipsArr)
                {
                    if($localGroupMembershipsList -notmatch $group -and $group.trim() -ne "")
                    {
                        $result = (delete-a-user-from-a-group-in-salesforce-cloud $accessToken $username $group $logFileSpec)

                        if($result -ne $true)
                        {
                                write-to-log-file "Error occured while trying to delete the user '$username' from the group '$group' (func: sync-user-group-memberships)!" $logFileSpec "yes"

                                return $false
                        }
                    }
                    else
                    {
                        if($group.trim() -ne "")
                        {
                            write-to-log-file "sync-user-group-memberships: the user $username is a member of the local group '$group'. No need to remove its membership from the cloud." $logFileSpec "yes"
                        }
                    }
                }

                return $true
            }
            else
            {
                write-to-log-file "Error occured while trying to get the remote group memberships of the user!" $logFileSpec "yes"
                write-to-log-file ("error [sync-user-group-memberships-from-a-local-user-to-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"
                
                return $false                
            }
        }
        catch
        {
            write-to-log-file ("error [sync-user-group-memberships-from-a-local-user-to-salesforce-cloud]: " + $error[0]) $logFileSpec "yes"

            return $false            
        }
    }
    else
    {
        write-to-log-file "Error! Mandatory values are missing! (func: sync-user-group-memberships-from-a-local-user-to-salesforce-cloud)" $logFileSpec "yes"

        return $false        
    }
}



# in order to create a new user in salesforce cloud, a profileID must be provided. each permission is assigned to a profile and each profile has an id.
# this is the way salesforce connects a permission to a user in its most basic form - groups is another OPTIONAL usage and group use profies as well
function get-a-profile-id-from-profile-name($accessToken, $profileName, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }

    if($profileName -ne $null -and $profileName -ne "")
    {
        if($accessToken -ne "")
        {
            $headers = @{
                Authorization = "Bearer " + $accessToken
            }

            try
            {
                $result = (run-a-query-based-api-request-on-salesforce-cloud $accessToken "SELECT+ID+from+profile+where+name=`'$profileName`'" $logFileSpec)

                if($result.content -ne $null -and $result.content -ne "")
                {
                    return ($result.content | convertfrom-json).records.id
                }
                else
                {
                    write-to-log-file ("error [get-a-profile-id-from-profile-name]: " + $error[0]) $logFileSpec "yes"
                }                
            }
            catch
            {
                write-to-log-file ("error [get-a-profile-id-from-profile-name]: " + $error[0]) $logFileSpec "yes"
            
                return $false
            }

        }       
        else
        {
            write-to-log-file "Error! Invalid creds (func: get-a-profile-id-from-profile-name)!" $logFileSpec "yes"

            return $false
        }
    }        
    else
    {
            write-to-log-file "Error! the 'profileName' param must be not null and not empty (func: get-a-profile-id-from-profile-name)!" $logFileSpec "yes"

            return $false        
    }    

}



function create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud($authToken, $exportType="delta", $singleUserDataObjFromFim, $tempPasswordLength=10, $tempPwdsFileSpec=$global:tempPwdsFileSpec, $cloudName="salesforce", $userCreationDelayTimeInSeconds=3, $logFileSpec)
{
    if($logFileSpec -eq $null -or $logFileSpec -eq "")
    {
        $logFileSpec = $PSScriptRoot + '\' + $global:defaultLogFileName
    }
    
    if($accessToken -ne $null -and $accessToken -ne "" -and $singleUserDataObjFromFim -ne $null -and $singleUserDataObjFromFim -ne "")
    {        
        $fullName = $singleUserDataObjFromFim.FullName


        # in salcesforce, the username must be an email pattern (and the email address does not need to be valid) so we can use the email from the user gotten from fim as the username in salesforce (so this field is used ahead as username as well)
        $email = $singleUserDataObjFromFim.Email

        $department = $singleUserDataObjFromFim.Department        
        $userAccountControl = $singleUserDataObjFromFim.UserAccountControl

        $fullNameArr = $fullName -split " "
        $firstName = $fullNameArr[0]
        $lastName = $fullNameArr[1]

        $groupMemberships = $singleUserDataObjFromFim.MemberOf -replace ";",","

        $randomPassword = -join ((35..38) + (48..57) + (65..90) + (97..122) | Get-Random -Count $tempPasswordLength | % {[char]$_})

        # mandatory in salesforce for user creation, 8 chars max, can be the same in multiple users
        $userAlias = $firstName.substring(0, 4) + $lastName.substring(0, 4)

        # mandatory in salesforce for user creation, a basic permissions obj
        $userBasicProfileID = (get-a-profile-id-from-profile-name $accessToken "standard user" $logFileSpec)

        # mandatory zone/lang/encoding values in salesforce for user creation
        $timeZoneSidKey = "Asia/Jerusalem"
        $localeSidKey = "en_US"
        $languageLocaleKey = "en_US"
        $emailEncodingKey = "UTF-8"


        if($userBasicProfile -ne $null -and $userBasicProfile -ne "")
        {
	        try
	        {
                #$global:accessToken | Out-File -FilePath $logFileSpec -Append

                if ($exportType -eq "Full" -or $exportType -eq "Delta")
	            {
                    # if the email field is empty, we can't continue ...
            
                    if($email -ne "" -and $email -ne $null)
                    {
                        # sync users

                        if($userAccountControl -ne "" -and $userAccountControl -ne $null)
                        {
                            write-to-log-file "username = $email, userAccountControl = $userAccountControl" $logFileSpec "yes"

                            # user disabled = number 2 decimal (2nd bit from lsb)
                            # check if the user is currently disabled locally or not and sync that setting to the cloud
                            # we use a field called 'UserAccountControl' which is made of binary flags
                            # when a use is disabled, a binary value of 2 is lit meaning that we can do a bitwise "and" operation to check its status
                            # if and 2 to current value equals 2 it means that it is lit and that means that the user is disabled.

                            $userStatus = ($userAccountControl -band 2)

                            # is binary result it 2 it means that the user need to be disabled
                            # and "true" means "user is ENABLED" in the cloud because the settings is "isActive".
                            if($userStatus -eq 2)
                            {
                                $userStatus = "false"
                            }
                            else
                            {
                                $userStatus = "true"
                            }

                            # user must change pwd at next logon = number 512 decimal (3rd bit from msb)

                            $userMustChangePassword = ($userAccountControl -band 512)

                            if($userMustChangePassword -eq 512)
                            {
                                $userMustChangePassword = "true"
                            }
                            else
                            {
                                $userMustChangePassword = "false"
                            }
                        }
                        else
                        {
                            # assume "false" when not found - needs to be as text to be send to the cloud as json
                            # and "false" means "user is DISABLED" in the cloud because the settings is "isActive".
                            $userStatus = "true"

                            # assume true to changing pwd when not found
                            $userMustChangePassword = "true"
                        }

                        # NOTE! salesforce cloud DOES NOT have a field called 'changePasswordAtNextLogin'
                        $salesForceUserFieldsToSyncInJson = "{`n`"email`": `"$email`", `"FirstName`": `"$firstName`", `"LastName`": `"$lastName`"`, `"IsActive`": `"$userStatus`"`n}"

                        # check if we need to create a new user on the cloud or just sync an existing one
                        # sync supports only the settings: name, email isUserDisabled
                        $status = (get-a-user-from-salesforce-cloud $accessToken $username $logFileSpec)

                        #"get-a-user-from-salesforce-cloud status: $status`n" | Out-File -FilePath $logFileSpec -Append

                        if($status -ne $false)
                        {
                            # the user already exists - only do a sync
                            write-to-log-file "the user $email already exists - will only do a sync" $logFileSpec "yes"

                            write-to-log-file $salesForceUserFieldsToSyncInJson $logFileSpec "yes"

                            $status = (update-a-user-in-salesforce-cloud $accessToken $username $salesForceUserFieldsToSyncInJson $logFileSpec)

                            if($status)
                            {
                                $syncGroups = $true
                            }
                            else
                            {
                                write-to-log-file "Error occured while trying to sync the user (func: create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud)!" $logFileSpec "yes"

                                write-to-log-file ("error: " + $error[0]) $logFileSpec "yes"
                            }
                        }
                        else
                        {
                            # user does not exist - create a brand new user - but only if we have all the data we need ...

                            if($email -ne "" -and $email -ne $null -and $fullName -ne "" -and $fullName -ne $null)
                            {                                
                                # NOTE! salesforce cloud DOES NOT have a field called 'changePasswordAtNextLogin'
                                $salesForceBasicUserDataInJson = "{`n`"username`": `"$email`, `"email`": `"$email`", `"FirstName`": `"$firstName`", `"LastName`": `"$lastName`"`, `"IsActive`": `"$userStatus`", `"alias`": `"$userAlias`", `"TimeZoneSidKey`": `"$timeZoneSidKey`", `"EmailEncodingKey`": `"$emailEncodingKey`", `"LocaleSidKey`": `"$localeSidKey`", `"LanguageLocaleKey`": `"$languageLocaleKey`", `"ProfileId`": `"$userBasicProfileID`"`n}"

                                write-to-log-file $salesForceBasicUserDataInJson $logFileSpec "yes"

                                $status = (create-a-user-in-salesforce-cloud $accessToken $email $randomPassword $salesForceBasicUserDataInJson $logFileSpec)

                                if($status.userCreationStatus -ne $false)
                                {
                                    if($status -eq 409)
                                    {
                                        # user already exists - run sync instead                                        

                                        write-to-log-file $salesForceUserFieldsToSyncInJson $logFileSpec "yes"

                                        $status = (update-a-user-in-salesforce-cloud $accessToken $username $salesForceUserFieldsToSyncInJson $logFileSpec)

                                        if($status)
                                        {
                                            $syncGroups = $true
                                        }
                                        else
                                        {
                                            write-to-log-file "Error occured while trying to sync the user!" $logFileSpec "yes"

                                            write-to-log-file ("error: " + $error[0]) $logFileSpec "yes"
                                        }
                                    }
                                    else
                                    {
                                        if($status.userCreationStatus -eq $true)
                                        {                                        
                                            write-to-log-file "a new user called $email was created successfully." $logFileSpec "yes"

                                            $newUser = $true
                                            $syncGroups = $true

                                            if($status.passwordCreationStatus -eq $true)
                                            {
                                                # save the temp password to a file
                                                write-to-log-file "username: $email, tempPwd: $randomPassword, cloud: $cloudName" $tempPwdsFileSpec "yes"
                                            }
                                            else
                                            {
                                                 write-to-log-file "WARNING: Error occured while trying to create the password. A password could not be created for user '$email'!" $logFileSpec "yes"
                                            }

                                            # wait a bit for the change to take affect on the cloud
                                            sleep $userCreationDelayTimeInSeconds
                                        }
                                        else
                                        {
                                            $newUser = "error"
                                            $syncGroups = $false
                            
                                            write-to-log-file "Error occured while trying to create the user (func: create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud)!" $logFileSpec "yes"
                                            write-to-log-file ("error: " + $error[0]) $logFileSpec "yes"
                                        }
                                    }
                                }
                                else
                                {
                                    $newUser = "error"
                                    $syncGroups = $false
                            
                                    write-to-log-file "Error occured while trying to create the user (func: create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud)!" $logFileSpec "yes"
                                    write-to-log-file ("error: " + $error[0]) $logFileSpec "yes"
                                }
                            }
                            else
                            {
                                 write-to-log-file "Error occured while trying to get mandatory values for creating the new user (func: create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud)!" $logFileSpec "yes"
                                 write-to-log-file "Values status:" $logFileSpec "yes"
                                 write-to-log-file "Full Name: $fullName" $logFileSpec "yes"
                                 write-to-log-file "Email: $email" $logFileSpec "yes"
                            }
	                    }

                        # sync users groups memberships

                        # make sure that $groupMemberships is not null so that the function call we be valid always
                        if($groupMemberships -eq $null)
                        {
                            $groupMemberships = ""

                            write-to-log-file "Note: $groupMemberships was just found null!" $logFileSpec "yes"
                            write-to-log-file "Other params: fullname = $fullName, email = $email" $logFileSpec "yes"
                        }

                        # syncing groups to users is only relevant if the user exists - if this is a new user we need to verify that it was successfully created before trying to sync its groups

                        if($syncGroups -eq $true)
                        {
                            $status = (sync-user-group-memberships-from-a-local-user-to-salesforce-cloud $accessToken $username $groupMemberships $logFileSpec)
                        }
                        else
                        {
                            if($newUser -eq "error")
                            {
                                write-to-log-file "will NOT try to sync groups for new user '$username' because it was NOT created successfully!" $logFileSpec "yes"
                            }
                            else
                            {
                                write-to-log-file "can't sync groups due to an unexpected error." $logFileSpec "yes"
                            }
                        }

                        if($status -ne $true)
                        {
                                write-to-log-file "Error occured while trying to sync groups between the local list and the cloud!" $logFileSpec "yes"

                                return $false
                        }
                    }
                    else
                    {
                        write-to-log-file "Error! Mandatory value is missing! (email value, main export script)" $logFileSpec "yes"
                        write-to-log-file "Other params: fullname = $fullName" $logFileSpec "yes"
                    }
                } # export type ...
            } # try block
	        catch
	        {
                write-to-log-file "Error occured!" $logFileSpec "yes"
                write-to-log-file "Error:" $logFileSpec "yes"

                write-to-log-file ("error: " + $error[0]) $logFileSpec "yes"
            }
        }
        else
        {
            write-to-log-file "Error! Could not get mandatory value of the assignmentObjID from the cloud for the user '$username' and group '$groupName' (func: create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud)!" $logFileSpec "yes"

            return $false        
        }
    }
    else
    {
        write-to-log-file "Error! Mandatory values are missing! (func: create-or-sync-a-user-from-fim-data-obj-in-salesforce-cloud)" $logFileSpec "yes"

        return $false        
    }   
}