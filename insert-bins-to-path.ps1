###################################################################
# User Settings (Optional – Leave blank for interactive mode):
#
# to add multiple values use semi-colons (;) e.g. $newPathOrPathsToAdd = "c:\cygwin\bin;c:\tools\drush"
# ---------------------------------------------
  $newPathOrPathsToAdd = ""
  $level = "machine" # 'user' for user-level path manipulation , 'machine' for system-level path manipulation

###################################################################

function getASubListOfValidPaths($aListOfPathsToWorkOn)
{
    $validPathsArr=@()
    $pathsToTest = $aListOfPathsToWorkOn.split(";")
   
    if($pathsToTest.length -gt 0)
    {
        foreach($path in $pathsToTest)
        {
            $status = test-path $path
            
            if ($status -eq $true)
            {
                $validPathsArr += $path
            }
        }
        
        $validPaths = $validPathsArr -join ";"
        
        return($validPaths)
    }
    else
    {
        return ""
    }
}

function getNumOfItemsInASemicolonDelimitedList($aList)
{
    $items = $aList.split(";")
    
    return($items.length)
}

function AddANewPathToThePathVariable($newPathOrPaths, $level="machine")
{
    if($newPathOrPaths -ne "")
    {
        $numOfPaths = getNumOfItemsInASemicolonDelimitedList($newPathOrPaths)
        
        if($level -ne "all" -and $level -ne "user" -and $level -ne "machine")
        {
          $level = "machine"
        }
        
        if($level -eq "all")
        {
          try
          {
              $level = "machine"
              
              ### Modify a system environment variable ###
              $currentSystemLevelPathVariableValue = [Environment]::GetEnvironmentVariable("PATH", $level)
              
              [Environment]::SetEnvironmentVariable("Path", $currentSystemLevelPathVariableValue + ";" + $newPathOrPaths, $level)
              
              Write-host "Successfully added $numOfPaths new path(s) at $level level."
              
              $level = "user"
              
              ### Modify a system environment variable ###
              $currentSystemLevelPathVariableValue = [Environment]::GetEnvironmentVariable("PATH", $level)
              
              [Environment]::SetEnvironmentVariable("Path", $currentSystemLevelPathVariableValue + ";" + $newPathOrPaths, $level)
              
              Write-host "Successfully added $numOfPaths new path(s) at $level level."
          }
          catch
          {
              Write-host $_.Exception.Message
          }
      }
      else
      {
        try
        {
            ### Modify a user environment variable ###
            $currentUserLevelPathVariableValue = [Environment]::GetEnvironmentVariable("PATH", $level)
            
            [Environment]::SetEnvironmentVariable("Path", $currentUserLevelPathVariableValue + ";" + $newPathOrPaths, $level)
            
            Write-host "Successfully added $numOfPaths new path(s) at $level level."
        }
        catch
        {
            Write-host $_.Exception.Message
        }
      }
    }
    
    # "process" level is for current session update - always required
    try
    {
        $level = "process"
        
        ### Modify a system environment variable ###
        $currentSystemLevelPathVariableValue = [Environment]::GetEnvironmentVariable("PATH", $level)
        
        [Environment]::SetEnvironmentVariable("Path", $currentSystemLevelPathVariableValue + ";" + $newPathOrPaths, $level)
        
        Write-host "Successfully added $numOfPaths new path(s) at $level level."
    }
    catch
    {
        Write-host $_.Exception.Message
    }    
}

###########################
# Main Program
###########################

while($newPathOrPathsToAdd -eq "")
{
    $newPathOrPathsToAdd = Read-Host -Prompt "Please input a valid path to add (you can input either a single path or a list of paths divided by semicolons)"
}

$validPathsList = getASubListOfValidPaths($newPathOrPathsToAdd)

if($validPathsList.length -gt 0)
{
    write-host "Detected"(getNumOfItemsInASemicolonDelimitedList($validPathsList))"valid path(s) out of"(getNumOfItemsInASemicolonDelimitedList($newPathOrPathsToAdd))"path(s)."
    
    write-host `n
    write-host "The path variable value before the change:"
    write-host "--------------------------------------------------"
    [Environment]::GetEnvironmentVariable("PATH", $level)
    
    write-host `n
    write-host "Adding paths ..."
    
    AddANewPathToThePathVariable $validPathsList $level
    
    write-host `n
    write-host "The path variable value after the change:"
    write-host "--------------------------------------------------"
    [Environment]::GetEnvironmentVariable("PATH", $level)
}
else
{
    write-host "ERROR! No valid paths detected. Nothing to do... Aborting..."
}
