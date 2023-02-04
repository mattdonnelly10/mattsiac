# Input bindings are passed in via param block.
param($Timer)

$person1 = [pscustomobject]@{
    "Name" = 'John Smith'
    "Number" = 1
}
$response = ConvertTo-Csv -InputObject $person1 -NoTypeInformation
Push-OutputBinding -Name outputBlob -Value $response