function Test-CltAduaOfficeAddress {
    <#
    .SYNOPSIS
    Checks that every enabled Active Directory user has a complete office address.

    .DESCRIPTION
    By default streetAddress, l (city), st (state or province), postalCode and co (country) must all be set. The Active Directory version of MP.CLT.UA.1008 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1006.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1006',
        Title        = 'All Active Directory users have a complete office address.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Medium',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Presence', 'Address'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Address attributes that must all be set: streetAddress, l (city), st (state), postalCode, co or c (country), physicalDeliveryOfficeName (office).
        [ValidateSet('streetAddress', 'l', 'st', 'postalCode', 'co', 'c', 'physicalDeliveryOfficeName')]
        [string[]] $Fields = ('streetAddress', 'l', 'st', 'postalCode', 'co'),

        # More users (sAMAccountName, user principal name, DN or objectGUID) to leave out of this test, on top of the pack-wide exclusions.
        [string[]] $ExcludedUsers,

        # More groups (DN, objectGUID or sAMAccountName) whose members, including nested members, are left out of this test.
        [string[]] $ExcludedGroups,

        # Also check disabled accounts, such as leavers.
        [bool] $IncludeDisabled = $false,

        # Most rows to list in the result; 0 lists them all.
        [ValidateRange(0, 100000)]
        [int] $MaxRows = 100
    )

    $population = Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled
    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    $users = $set.Users
    if ($users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "There are no $population to check after exclusions."
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $users) {
        $missing = @($Fields | Where-Object { Test-CltAduaIsBlank $user.$_ })
        if ($missing.Count) {
            $rows.Add([pscustomobject]@{
                    'User'           = Get-CltAduaUserLabel -User $user
                    'Missing fields' = $missing -join ', '
                    'OU'             = Get-CltAduaParentContainer -DistinguishedName $user.distinguishedName
                })
        }
    }

    $checked = $Fields -join ', '
    if ($rows.Count -eq 0) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. All $($users.Count) $population have a complete office address ($checked)."
        return $true
    }

    $table = Format-CltAduaTable -Rows $rows.ToArray() -Columns 'User', 'Missing fields', 'OU' -MaxRows $MaxRows
    Add-CltAduaResult -Note $set.Note -Result "$($rows.Count) of $($users.Count) $population are missing part of their office address (checked: $checked).`n`n$table"
    return $false
}
