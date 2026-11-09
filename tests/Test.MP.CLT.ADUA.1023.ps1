function Test-CltAduaApprovedLocation {
    <#
    .SYNOPSIS
    Checks that each enabled Active Directory user's address matches one of your approved office locations.

    .DESCRIPTION
    Compares streetAddress, l, st, postalCode, co and company with each location in CLT.ADUA.AllowedValues locations, and lists the closest location and the fields that differ. The Active Directory version of MP.CLT.UA.1026 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1023.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1023',
        Title        = 'Active Directory user addresses match an approved office location.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Medium',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Validation', 'Address'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Attributes that must match an approved location; add telephoneNumber or physicalDeliveryOfficeName to compare them too.
        [ValidateSet('streetAddress', 'l', 'st', 'postalCode', 'co', 'c', 'company', 'telephoneNumber', 'physicalDeliveryOfficeName')]
        [string[]] $Fields = ('streetAddress', 'l', 'st', 'postalCode', 'co', 'company'),

        # Treat values that differ only in letter case (new york and New York) as different.
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

    $population = Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled
    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    $users = @($set.Users | Where-Object { $user = $_; @($Fields | Where-Object { -not (Test-CltAduaIsBlank $user.$_) }).Count -gt 0 })
    if ($users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "None of the $population has any of $($Fields -join ', ') set."
    }

    $comparison = if ($CaseSensitive) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
    $locations = @((Get-CltAduaAllowedValueSet).Locations)
    $checked = $Fields -join ', '

    if ($locations.Count -eq 0) {
        $comparer = if ($CaseSensitive) { [System.StringComparer]::Ordinal } else { [System.StringComparer]::OrdinalIgnoreCase }
        $groups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new($comparer)
        foreach ($user in $users) {
            $address = ($Fields | ForEach-Object { (@($user.$_) | Where-Object { $_ }) -join ' / ' }) -join ' · '
            if (-not $groups.ContainsKey($address)) { $groups[$address] = [System.Collections.Generic.List[object]]::new() }
            $groups[$address].Add($user)
        }
        $rows = @($groups.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | ForEach-Object { ConvertTo-CltAduaValueRow -Entry $_ -Column 'Address' })
        $table = Format-CltAduaTable -Rows $rows -Columns 'Address', 'Users', 'Examples' -MaxRows $MaxRows
        Add-CltAduaResult -Note $set.Note -Investigate -Result ("No approved locations are set, so the $($groups.Count) addresses used by $($users.Count) $population are listed for review ($checked). " +
            "Add your offices to **CLT.ADUA.AllowedValues** → **locations** under GlobalSettings in maester-config.json so this test can enforce them.`n`n$table")
        return $true
    }

    $failed = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $users) {
        $best = $null
        $bestScore = -1
        $bestDiffs = @()
        foreach ($location in $locations) {
            $diffs = [System.Collections.Generic.List[string]]::new()
            $score = 0
            foreach ($field in $Fields) {
                if (-not $location.ContainsKey($field)) { continue }
                $userValues = @(@($user.$field) | Where-Object { -not (Test-CltAduaIsBlank $_) } | ForEach-Object { [string]$_ })
                $match = $false
                foreach ($value in $userValues) {
                    foreach ($approved in $location[$field]) { if ([string]::Equals($value, $approved, $comparison)) { $match = $true } }
                }
                if ($match) { $score++ } else {
                    $shown = if ($userValues.Count) { "``$($userValues -join ' / ')``" } else { '(blank)' }
                    $diffs.Add("$field $shown")
                }
            }
            if ($diffs.Count -eq 0) { $best = $location; $bestDiffs = @(); break }
            if ($score -gt $bestScore) { $best = $location; $bestScore = $score; $bestDiffs = $diffs.ToArray() }
        }
        if ($bestDiffs.Count -eq 0) { continue }
        $name = if ($best.name) { $best.name } else { (@($best['streetAddress']) + @($best['l']) | Where-Object { $_ } | Select-Object -First 2) -join ', ' }
        $failed.Add([pscustomobject]@{
                'User'                      = Get-CltAduaUserLabel -User $user
                'Closest approved location' = $name
                'Differs in'                = $bestDiffs -join '; '
            })
    }

    if ($failed.Count -eq 0) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. All $($users.Count) $population with an address match one of the $($locations.Count) approved locations ($checked)."
        return $true
    }

    $table = Format-CltAduaTable -Rows $failed.ToArray() -Columns 'User', 'Closest approved location', 'Differs in' -MaxRows $MaxRows
    Add-CltAduaResult -Note $set.Note -Result ("$($failed.Count) of $($users.Count) $population have an address that matches none of the $($locations.Count) approved locations (compared: $checked). " +
        "Each row shows the closest location and the fields that differ.`n`n$table")
    return $false
}
