function Test-CltAduaStraySpace {
    <#
    .SYNOPSIS
    Checks that name, job and location attributes of enabled Active Directory users have no leading, trailing, repeated or invisible spaces.

    .DESCRIPTION
    Values that look the same but differ by a space break dynamic groups, approved-value checks and sorting once synced to Microsoft Entra ID. The Active Directory version of MP.CLT.UA.1012 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1013.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1013',
        Title        = 'Active Directory name, job and location attributes have no stray spaces.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Low',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Format'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Text attributes to check; extensionAttribute1-15 and msDS-cloudExtensionAttribute1-20 can be added.
        [ValidateSet('displayName', 'givenName', 'sn', 'title', 'department', 'company', 'physicalDeliveryOfficeName',
            'streetAddress', 'l', 'st', 'postalCode', 'co', 'employeeID', 'employeeNumber', 'employeeType',
            'extensionAttribute1', 'extensionAttribute2', 'extensionAttribute3', 'extensionAttribute4', 'extensionAttribute5',
            'extensionAttribute6', 'extensionAttribute7', 'extensionAttribute8', 'extensionAttribute9', 'extensionAttribute10',
            'extensionAttribute11', 'extensionAttribute12', 'extensionAttribute13', 'extensionAttribute14', 'extensionAttribute15',
            'msDS-cloudExtensionAttribute1', 'msDS-cloudExtensionAttribute2', 'msDS-cloudExtensionAttribute3', 'msDS-cloudExtensionAttribute4', 'msDS-cloudExtensionAttribute5',
            'msDS-cloudExtensionAttribute6', 'msDS-cloudExtensionAttribute7', 'msDS-cloudExtensionAttribute8', 'msDS-cloudExtensionAttribute9', 'msDS-cloudExtensionAttribute10',
            'msDS-cloudExtensionAttribute11', 'msDS-cloudExtensionAttribute12', 'msDS-cloudExtensionAttribute13', 'msDS-cloudExtensionAttribute14', 'msDS-cloudExtensionAttribute15',
            'msDS-cloudExtensionAttribute16', 'msDS-cloudExtensionAttribute17', 'msDS-cloudExtensionAttribute18', 'msDS-cloudExtensionAttribute19', 'msDS-cloudExtensionAttribute20')]
        [string[]] $Attributes = ('displayName', 'givenName', 'sn', 'title', 'department', 'company', 'physicalDeliveryOfficeName', 'l', 'st', 'co'),

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

    $invisible = "[$([char]0x00A0)$([char]0x2007)$([char]0x202F)$([char]0x200B)$([char]0x200C)$([char]0x200D)$([char]0xFEFF)]"
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $users) {
        foreach ($attribute in $Attributes) {
            $value = $user.$attribute
            if ($value -isnot [string] -or $value.Length -eq 0) { continue }

            $problems = @(
                if ($value -match '^\s') { 'leading space' }
                if ($value -match '\s$') { 'trailing space' }
                if ($value -match ' {2,}') { 'repeated spaces' }
                if ($value -match '[\t\r\n]') { 'tab or line break' }
                if ($value -match $invisible) { 'invisible character' }
            )
            if ($problems.Count -eq 0) { continue }

            # Show where the problem is: spaces as a visible mark, other characters by name.
            $shown = $value -replace ' ', ([string][char]0x2423) -replace "`t", '[tab]' -replace '\r?\n', '[line break]' -replace $invisible, '[invisible]'
            $rows.Add([pscustomobject]@{
                    'User'      = "$($user.sAMAccountName)"
                    'Attribute' = $attribute
                    'Problem'   = $problems -join ', '
                    'Value'     = $shown
                })
        }
    }

    if ($rows.Count -eq 0) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. None of the $($users.Count) $population has stray spaces in $($Attributes -join ', ')."
        return $true
    }

    $table = Format-CltAduaTable -Rows $rows.ToArray() -Columns 'User', 'Attribute', 'Problem', 'Value' -MaxRows $MaxRows
    Add-CltAduaResult -Note $set.Note -Result ("$($rows.Count) attribute value(s) on $population have stray or invisible spaces. In the table, " +
        "$([char]0x2423) marks each space.`n`n$table")
    return $false
}
