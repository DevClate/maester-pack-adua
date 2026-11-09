function Test-CltAduaBusinessPhone {
    <#
    .SYNOPSIS
    Checks that every enabled Active Directory user has a business phone (telephoneNumber).

    .DESCRIPTION
    telephoneNumber is the number shown in the address book and synced to Microsoft Entra ID as businessPhones. The Active Directory version of MP.CLT.UA.1014 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1007.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1007',
        Title        = 'All Active Directory users have a business phone.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Medium',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Presence', 'Phone', 'Optional'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # More users (sAMAccountName, user principal name, DN or objectGUID) to leave out of this test, on top of the pack-wide exclusions.
        [string[]] $ExcludedUsers,

        # More groups (DN, objectGUID or sAMAccountName) whose members, including nested members, are left out of this test.
        [string[]] $ExcludedGroups,

        # Also check disabled accounts, such as leavers.
        [bool] $IncludeDisabled = $false,

        # Most users to list in the result; 0 lists them all.
        [ValidateRange(0, 100000)]
        [int] $MaxRows = 100
    )

    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    return (Invoke-CltAduaPresenceCheck -Users $set.Users -Attribute telephoneNumber -Label 'a business phone' -Population (Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled) -MaxRows $MaxRows -Note $set.Note)
}
