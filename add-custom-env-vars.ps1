param (
  [string]$key="",
  [string]$value="",
  [string]$level="machine"
)

function AddNewEnvVariable($key, $value, $level="machine")
{
  if($key -ne "")
  {
        if($level -eq "all")
        {
          try
          {
              $level = "machine"
              
              [Environment]::SetEnvironmentVariable($key, $value, $level)
              
              Write-host "Successfully added a new env var of '$key = $value' at $level level."
              
              $level = "user"
              
              [Environment]::SetEnvironmentVariable($key, $value, $level)
              
              Write-host "Successfully added a new env var of '$key = $value' at $level level."
          }
          catch
          {
              Write-host $_.Exception.Message
          }
      }
      else
      {
          if($level -eq "machine" -or $level -eq "user")
          {
              try
              {
                  [Environment]::SetEnvironmentVariable($key, $value, $level)
                  
                    Write-host "Successfully added a new env var of '$key = $value' at $level level."
              }
              catch
              {
                  Write-host $_.Exception.Message
              }
          }
          else
          {
              Write-host "Error! Only 'machine' or 'user' are valid words for the variable 'level'. Please try again."
          }
      }
      # "process" level is for current session update - always required
      try
      {
          $level = "process"
          
          [Environment]::SetEnvironmentVariable($key, $value, $level)
          
          Write-host "Successfully added a new env var of '$key = $value' at $level level."
      }
      catch
      {
          Write-host $_.Exception.Message
      }    
  }
  else
  {
      write-host "ERROR! key must not be empty!"
  }
}

###########################
# Main Program
###########################

$usageInfo = "Usage: " + $MyInvocation.MyCommand.Name + " <new-key> <new-value> [optional: <level>]`nlevel is one of: 'machine', 'user'"

if($level -ne "machine" -and $level -ne "user" -and $level -ne "all")
{
    $level = "machine"
}

if($key -ne "")
{
    AddNewEnvVariable $key $value $level
}
else
{
     write-host "ERROR! key must not be empty!"
     write-host $usageInfo
}
