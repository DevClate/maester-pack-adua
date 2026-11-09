function Get-CltAduaExtensionAttributePresenceInstance {
    <#
    .SYNOPSIS
    Instance source of MP.CLT.ADUA.1024: one instance per extension attribute to check.

    .DESCRIPTION
    When GlobalSettings."CLT.ADUA.RequiredExtensionAttributes" lists attributes, those are checked and must be set
    on every user. When it lists none, every extension attribute that at least one user has a value in is
    listed for review, and unused ones are left out. With nothing listed and nothing in use, the family has
    no instances and is skipped. Covers extensionAttribute1-15 and msDS-cloudExtensionAttribute1-20.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $required = @(Get-CltAduaRequiredExtensionAttribute)
    $usage = Get-CltAduaExtensionAttributeUsage
    $names = if ($required.Count) { $required } else { @(Get-CltAduaExtensionAttributeName | Where-Object { $usage[$_] -gt 0 }) }
    foreach ($name in $names) {
        $label = Get-CltAduaExtensionAttributeLabel -Attribute $name
        [pscustomobject]@{
            Id    = $name
            Title = "All Active Directory users have $(Get-CltAduaExtensionAttributeTitle -Attribute $name -Label $label) set."
            Data  = @{ Attribute = $name; Label = $label; Required = [bool]$required.Count; UsedBy = $usage[$name]; InSchema = (Test-CltAduaExtensionAttributeInSchema -Attribute $name) }
        }
    }
}

function Test-CltAduaExtensionAttributePresence {
    <#
    .SYNOPSIS
    Checks that every enabled Active Directory user has a value in each extension attribute your organisation requires (extensionAttribute1-15 or msDS-cloudExtensionAttribute1-20).

    .DESCRIPTION
    A family: one result per extension attribute. List the attributes every user must have in
    GlobalSettings."CLT.ADUA.RequiredExtensionAttributes". Until you do, each extension attribute in use is
    listed for review (Investigate), with how many users have it. Name what each attribute holds in
    GlobalSettings."CLT.ADUA.ExtensionAttributeNames" to show that name in results.

    .EXAMPLE
    Invoke-MtTest -Id MP.CLT.ADUA.1024.extensionAttribute1 -Parameter @{ ExcludedGroups = 'Contractors' }
    #>
    [MaesterTest(
        Id             = 'MP.CLT.ADUA.1024',
        Title          = 'All Active Directory users have the extension attributes your organisation requires.',
        Product        = 'ad',
        Feature        = 'users',
        Area           = 'identity-lifecycle',
        ResourceType   = 'User',
        Severity       = 'Low',
        UserImpact     = 'Low',
        ImplementationCost = 'Medium',
        Service        = 'CLT.ADUA.Ldap',
        Permission     = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag            = ('ADUserAttributes', 'Presence', 'ExtensionAttributes'),
        Author         = 'DevClate',
        InstanceSource = 'Get-CltAduaExtensionAttributePresenceInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The extension attribute to check, supplied by the engine.
        $Instance,

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

    $attribute = $Instance.Data.Attribute
    $label = $Instance.Data.Label
    $population = Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled
    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    $valueLabel = if ($label) { "a value for $label" } else { 'a value' }

    if ($Instance.Data.Required -and -not $Instance.Data.InSchema) {
        Add-MtTestResultDetail -Investigate -Result (Get-CltAduaMissingSchemaMessage -Attribute $attribute -Source '**CLT.ADUA.RequiredExtensionAttributes**')
        return $true
    }

    if ($Instance.Data.Required) {
        return (Invoke-CltAduaPresenceCheck -Users $set.Users -Attribute $attribute -Label $valueLabel -Population $population -MaxRows $MaxRows -Note $set.Note)
    }

    $users = @($set.Users)
    if ($users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "There are no $population to check after exclusions."
    }
    $with = @($users | Where-Object { -not (Test-CltAduaIsBlank $_.$attribute) }).Count
    if ($with -eq $users.Count) {
        Add-CltAduaResult -Note $set.Note -Result "Well done. All $($users.Count) $population have $valueLabel (``$attribute``)."
        return $true
    }

    $name = Get-CltAduaExtensionAttributeTitle -Attribute $attribute -Label $label
    Add-CltAduaResult -Note $set.Note -Investigate -Result ("$with of $($users.Count) $population have $valueLabel (``$attribute``), and it is not in **CLT.ADUA.RequiredExtensionAttributes**, so this test does not know whether everyone should.`n`n" +
        "- If **every** user should have $name, add ``$attribute`` to **CLT.ADUA.RequiredExtensionAttributes** under GlobalSettings in maester-config.json. This test then lists the users without it, and stops listing extension attributes you have not named.`n" +
        "- If only some users should have it, turn this one off: ``{ ""Id"": ""MP.CLT.ADUA.1024.$attribute"", ""Enabled"": false, ""Reason"": ""Not required"" }`` in TestSettings. MP.CLT.ADUA.1025 still checks its values.")
    return $true
}
