function Test-CltAduaCountrySpelling {
    <#
    .SYNOPSIS
    Checks that enabled Active Directory users use one approved spelling for each country (co by default).

    .DESCRIPTION
    Without approved countries, one spelling passes and several report Investigate with the spellings in use. The Active Directory version of MP.CLT.UA.1013 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1014.ps1 -Parameter @{ ExcludedUsers = 'svc-scanner' }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1014',
        Title        = 'Active Directory country values use an approved spelling.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Low',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Format', 'Address'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The country attribute: co (the country name ADUC shows) or c (the two-letter code).
        [ValidateSet('co', 'c')]
        [string] $Attribute = 'co',

        # The exact country values your organisation uses; blank uses CLT.ADUA.AllowedValues for the attribute, or lists the values found.
        [string[]] $AllowedCountries,

        # Treat values that differ only in letter case (united states and United States) as different spellings.
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
    $users = @($set.Users | Where-Object { -not (Test-CltAduaIsBlank $_.$Attribute) })
    if ($users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "None of the $population has a country ($Attribute) set."
    }

    $comparer = if ($CaseSensitive) { [System.StringComparer]::Ordinal } else { [System.StringComparer]::OrdinalIgnoreCase }
    $groups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new($comparer)
    foreach ($user in $users) {
        $value = "$($user.$Attribute)"
        if (-not $groups.ContainsKey($value)) { $groups[$value] = [System.Collections.Generic.List[object]]::new() }
        $groups[$value].Add($user)
    }

    # Without this test's own list, use the pack-wide approved countries.
    if (-not @($AllowedCountries | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count) {
        $AllowedCountries = @((Get-CltAduaAllowedValueSet).Lists[$Attribute])
    }
    $allowed = [System.Collections.Generic.HashSet[string]]::new($comparer)
    foreach ($country in $AllowedCountries) {
        if (-not [string]::IsNullOrWhiteSpace($country)) { [void]$allowed.Add($country) }
    }

    if ($allowed.Count -eq 0) {
        $rows = @($groups.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | ForEach-Object { ConvertTo-CltAduaValueRow -Entry $_ -Column 'Country value' })
        $table = Format-CltAduaTable -Rows $rows -Columns 'Country value', 'Users', 'Examples' -MaxRows $MaxRows
        if ($groups.Count -eq 1) {
            Add-CltAduaResult -Note $set.Note -Result "Well done. All $($users.Count) $population with a country ($Attribute) use the same value.`n`n$table"
            return $true
        }
        Add-CltAduaResult -Note $set.Note -Investigate -Result ("The $($users.Count) $population with a country ($Attribute) use $($groups.Count) different values. " +
            "Check whether any are different spellings of the same country, then list the spellings you use in **CLT.ADUA.AllowedValues** → **$Attribute** under GlobalSettings in maester-config.json " +
            "(or in this test's **AllowedCountries**) so this test can enforce them.`n`n$table")
        return $true
    }

    $rejected = @($groups.GetEnumerator() | Where-Object { -not $allowed.Contains($_.Key) })
    if ($rejected.Count -eq 0) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. All $($users.Count) $population with a country ($Attribute) use an approved value."
        return $true
    }

    $rows = @($rejected | Sort-Object { $_.Value.Count } -Descending | ForEach-Object { ConvertTo-CltAduaValueRow -Entry $_ -Column 'Country value' })
    $userCount = ($rejected | ForEach-Object { $_.Value.Count } | Measure-Object -Sum).Sum
    $table = Format-CltAduaTable -Rows $rows -Columns 'Country value', 'Users', 'Examples' -MaxRows $MaxRows
    Add-CltAduaResult -Note $set.Note -Result ("$userCount of $($users.Count) $population have a country ($Attribute) that is not an approved value " +
        "($(@($AllowedCountries | Where-Object { $_ }) -join ', ')).`n`n$table")
    return $false
}
