function Test-CltAduaPhoneFormat {
    <#
    .SYNOPSIS
    Checks that phone numbers on enabled Active Directory users are in international E.164 format, such as +14255550100.

    .DESCRIPTION
    Checks telephoneNumber and mobile by default; otherTelephone, otherMobile, homePhone and facsimileTelephoneNumber can be added. The Active Directory version of MP.CLT.UA.1011 in the User Attributes pack (CLT.UA).

    .EXAMPLE
    Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1012.ps1 -Parameter @{ AllowSpaces = $true }
    #>
    [MaesterTest(
        Id           = 'MP.CLT.ADUA.1012',
        Title        = 'Active Directory phone numbers use international E.164 format.',
        Product      = 'ad',
        Feature      = 'users',
        Area         = 'identity-lifecycle',
        ResourceType = 'User',
        Severity     = 'Low',
        UserImpact   = 'Low',
        ImplementationCost = 'Low',
        Service      = 'CLT.ADUA.Ldap',
        Permission   = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag          = ('ADUserAttributes', 'Format', 'Phone'),
        Author       = 'DevClate'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Phone attributes to check.
        [ValidateSet('telephoneNumber', 'mobile', 'facsimileTelephoneNumber', 'otherTelephone', 'otherMobile', 'homePhone')]
        [string[]] $Attributes = ('telephoneNumber', 'mobile'),

        # Regular expression a number must match after any allowed extension and spaces are removed.
        [string] $PhonePattern = '^\+[1-9]\d{6,14}$',

        # Allow a trailing extension such as ;ext=123, x123 or ext. 123.
        [bool] $AllowExtension = $true,

        # Allow spaces inside the number, such as +1 425 555 0100.
        [bool] $AllowSpaces = $false,

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

    try {
        $rule = [regex]::new($PhonePattern)
    } catch {
        throw "PhonePattern for MP.CLT.ADUA.1012 is not a valid regular expression: $PhonePattern"
    }
    $extension = [regex]::new('(\s*;\s*ext=\d+|\s*(x|ext\.?)\s*\d+)$', 'IgnoreCase')

    $population = Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled
    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups

    $checkedNumbers = 0
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $set.Users) {
        foreach ($attribute in $Attributes) {
            foreach ($number in @($user.$attribute)) {
                if (Test-CltAduaIsBlank $number) { continue }
                $checkedNumbers++
                $candidate = "$number".Trim()
                if ($AllowExtension) { $candidate = $extension.Replace($candidate, '') }
                if ($AllowSpaces) { $candidate = $candidate -replace ' ', '' }
                if (-not $rule.IsMatch($candidate)) {
                    $rows.Add([pscustomobject]@{
                            'User'      = Get-CltAduaUserLabel -User $user
                            'Attribute' = $attribute
                            'Value'     = "``$number``"
                        })
                }
            }
        }
    }

    if ($checkedNumbers -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "None of the $population has a phone number in $($Attributes -join ', ')."
    }
    if ($rows.Count -eq 0) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. All $checkedNumbers phone numbers set on $population match the required format."
        return $true
    }

    $table = Format-CltAduaTable -Rows $rows.ToArray() -Columns 'User', 'Attribute', 'Value' -MaxRows $MaxRows
    Add-CltAduaResult -Note $set.Note -Result ("$($rows.Count) of $checkedNumbers phone numbers do not match the required format (``$PhonePattern``). " +
        "Write them as + country code and number with no punctuation, for example ``+14255550100``.`n`n$table")
    return $false
}
