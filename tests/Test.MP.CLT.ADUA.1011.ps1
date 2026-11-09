function Test-CltAduaUniqueEmployeeId {
    <#
    .SYNOPSIS
    Checks that no two Active Directory users share an employee ID (employeeID).

    .DESCRIPTION
    Disabled accounts are included by default, because an old account of a rehired person often still holds the ID. The Active Directory version of MP.CLT.UA.1010 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1011.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1011',
        Title        = 'Every Active Directory employee ID belongs to only one user.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Medium',
        UserImpact   = 'Low',
        ImplementationCost = 'Medium',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Format', 'Governance'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Treat IDs that differ only in leading zeros (00123 and 123) as the same ID.
        [bool] $IgnoreLeadingZeros = $false,

        # More users (sAMAccountName, user principal name, DN or objectGUID) to leave out of this test, on top of the pack-wide exclusions.
        [string[]] $ExcludedUsers,

        # More groups (DN, objectGUID or sAMAccountName) whose members, including nested members, are left out of this test.
        [string[]] $ExcludedGroups,

        # Also check disabled accounts, such as leavers.
        [bool] $IncludeDisabled = $true,

        # Most rows to list in the result; 0 lists them all.
        [ValidateRange(0, 100000)]
        [int] $MaxRows = 100
    )

    $population = Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled
    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    $users = @($set.Users | Where-Object { -not (Test-CltAduaIsBlank $_.employeeID) })
    if ($users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "None of the $population has an employee ID, so there is nothing to compare."
    }

    $byId = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($user in $users) {
        $key = "$($user.employeeID)".Trim()
        if ($IgnoreLeadingZeros) {
            $key = $key.TrimStart('0')
            if (-not $key) { $key = '0' }
        }
        if (-not $byId.ContainsKey($key)) { $byId[$key] = [System.Collections.Generic.List[object]]::new() }
        $byId[$key].Add($user)
    }

    # One row per account: the report shows raw HTML such as <br> as text, and a Markdown table cell cannot hold a line break.
    $shared = @($byId.GetEnumerator() | Where-Object { $_.Value.Count -ge 2 } | Sort-Object Key)
    $rows = foreach ($entry in $shared) {
        foreach ($user in ($entry.Value | Sort-Object { "$($_.sAMAccountName)" })) {
            [pscustomobject]@{
                'Employee ID' = "``$($entry.Key)``"
                'Stored as'   = "``$($user.employeeID)``"
                'User'        = Get-CltAduaUserLabel -User $user
                'Account'     = if ($user.Enabled) { 'Enabled' } else { 'Disabled' }
                'OU'          = Get-CltAduaParentContainer -DistinguishedName $user.distinguishedName
            }
        }
    }
    $rows = @($rows)

    if ($shared.Count -eq 0) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. The $($users.Count) $population with an employee ID all have different IDs."
        return $true
    }

    # 'Stored as' only differs from the shared ID when leading zeros are ignored.
    $columns = if ($IgnoreLeadingZeros) { 'Employee ID', 'Stored as', 'User', 'Account', 'OU' } else { 'Employee ID', 'User', 'Account', 'OU' }
    $table = Format-CltAduaTable -Rows $rows -Columns $columns -MaxRows $MaxRows
    Add-CltAduaResult -Note $set.Note -Result ("$($shared.Count) employee ID(s) are shared by $($rows.Count) accounts. Each ID should identify one person. " +
        "Accounts with the same ID are listed together.`n`n$table")
    return $false
}
