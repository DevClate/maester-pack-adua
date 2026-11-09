function Test-CltAduaApprovedPostalCode {
    <#
    .SYNOPSIS
    Checks that every postal code (postalCode) set on enabled Active Directory users is an approved value.

    .DESCRIPTION
    Blank values are not checked; the presence tests check those. Without approved values the test reports Investigate and lists the values in use. The Active Directory version of MP.CLT.UA.1024 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1021.ps1 -Parameter @{ CaseSensitive = $false }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1021',
        Title        = 'Active Directory postal codes are on the approved list.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Low',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Validation', 'Address'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Approved values for this test only; when set, the pack-wide CLT.ADUA.AllowedValues are not used.
        [string[]] $AllowedValues,

        # Treat values that differ only in letter case (finance and Finance) as different.
        [bool] $CaseSensitive = $true,

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

    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    return (Invoke-CltAduaAllowedValueCheck -Set $set -Attribute postalCode -Label 'postal code' -Column 'Postal code' -Population (Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled) -AllowedValues $AllowedValues -CaseSensitive $CaseSensitive -MaxRows $MaxRows)
}
