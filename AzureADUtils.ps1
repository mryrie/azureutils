Connect-AzureAD

$AADUsers = Get-AzureADUser -All $true | Select DisplayName, UserPrincipalName, Roles, MemberOf
$AADDirectoryRoles = Get-AzureADDirectoryRole
$AADGroups = Get-AzureADGroup

$htAADDirectoryRoles = $null
$htAADGroups = $null

foreach ($AADDirectoryRole in $AADDirectoryRoles){
    $htAADDirectoryRoles += @{ $AADDirectoryRole.DisplayName = ((Get-AzureADDirectoryRoleMember -ObjectId $AADDirectoryRole.ObjectId).UserPrincipalName) }
}

foreach ($AADGroup in $AADGroups){
    $htAADGroups += @{ $AADGroup.DisplayName = ((Get-AzureADGroupMember -ObjectId $AADGroup.ObjectId).UserPrincipalName) }
}

#Get the roles that the users hold
foreach ($AADUser in $AADUsers) {

    $AADUser.Roles = $null

    foreach ($roleName in $htAADDirectoryRoles.Keys){
        $htAADDirectoryRole = $htAADDirectoryRoles[$roleName]
        if ($htAADDirectoryRole -ne $null){
            if ($htAADDirectoryRole.Contains($AADUser.UserPrincipalName)) {
                $AADUser.Roles += "$roleName,"
            }    
        }
    }

    if ($AADUser.Roles -ne $null) {
        $AADUser.Roles = $AADUser.Roles.TrimEnd(",")
    }

    $AADUser.MemberOf = $null

    foreach ($AADGroupName in $htAADGroups.Keys){
        $htAADGroup = $htAADGroups[$AADGroupName]
        if ($htAADGroup -ne $null){
            if ($htAADGroup.Contains($AADUser.UserPrincipalName)) {
                $AADUser.MemberOf += "$AADGroupName,"
            }
        }
    }

    if ($AADUser.MemberOf -ne $null) {
        $AADUser.MemberOf = $AADUser.MemberOf.TrimEnd(",")
    }
}

$AADUsers | Export-Csv -Path D:\temp\AADUsers.csv -NoTypeInformation