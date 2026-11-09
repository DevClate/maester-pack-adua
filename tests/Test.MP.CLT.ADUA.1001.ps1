function Test-CltAduaManager {
    <#
    .SYNOPSIS
    Checks that every enabled Active Directory user has a manager (manager), except people at the top of the organisation.

    .DESCRIPTION
    Microsoft Entra Connect syncs manager to Microsoft Entra ID, where access reviews, approvals, Lifecycle Workflows and the organisation chart use it. The Active Directory version of MP.CLT.UA.1002 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1001.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1001',
        Title        = 'All Active Directory users have a manager.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Medium',
        UserImpact   = 'Low',
        ImplementationCost = 'Medium',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Presence', 'Governance'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Job titles at the top of the organisation that have no manager, matched exactly but ignoring case.
        [string[]] $ExcludedJobTitles = ('CEO', 'Chief Executive Officer'),

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
    $topTitles = @($ExcludedJobTitles | Where-Object { $_ } | ForEach-Object { $_.Trim() })
    $users = @($set.Users | Where-Object { -not ($_.title -and ($topTitles -contains "$($_.title)".Trim())) })
    return (Invoke-CltAduaPresenceCheck -Users $users -Attribute manager -Label 'a manager' -Population (Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled) -MaxRows $MaxRows -Note $set.Note)
}
