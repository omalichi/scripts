
$certsBundleFileSpec = "certs-bundle.txt"

cd $PSScriptRoot

if(test-path $certsBundleFileSpec)
{
    $fileData = (get-content $certsBundleFileSpec)

    $dataArr = $fileData -split "\r\n"

    $numOfLines = $fileData.length

    $i=0

    $namePrefix = "ca-cert-"
    $nameCounter = 1
    $nameSuffix = ".cer"

    while($i -lt $numOfLines)
    {
        for($j=$i;$j -le ($i+2); $j++)
        {
            $newFile += $dataArr[$j]
        }

        Set-Content -Value $newFile -Path $namePrefix$nameCounter$nameSuffix

        Import-Certificate -FilePath $namePrefix$nameCounter$nameSuffix -CertStoreLocation Cert:\LocalMachine\Root\
        Import-Certificate -FilePath $namePrefix$nameCounter$nameSuffix -CertStoreLocation Cert:\LocalMachine\AuthRoot\

        $newFile = ""

        $nameCounter += 1

        $i += 3
    }

    Get-ChildItem Cert:\LocalMachine\Root\
    Get-ChildItem Cert:\LocalMachine\AuthRoot\

    Get-ChildItem .
}
else
{
    "Error! file '$certsBundleFileSpec' was not found! Aborting ..."
}