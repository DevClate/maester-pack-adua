function Get-CltAduaExtensionAttributeValueInstance {
    <#
    .SYNOPSIS
    Instance source of MP.CLT.ADUA.1025: one instance per extension attribute whose values to check.

    .DESCRIPTION
    Checks every extension attribute that is in use, listed in GlobalSettings."CLT.ADUA.RequiredExtensionAttributes",
    or has approved values in CLT.ADUA.AllowedValues (or CLT.UA.AllowedValues). Unused attributes with no
    approved values are left out, so a directory that uses none gets no rows. Covers extensionAttribute1-15
    and msDS-cloudExtensionAttribute1-20.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $usage = Get-CltAduaExtensionAttributeUsage
    $required = @(Get-CltAduaRequiredExtensionAttribute)
    $lists = (Get-CltAduaAllowedValueSet).Lists
    foreach ($name in Get-CltAduaExtensionAttributeName) {
        if ($usage[$name] -eq 0 -and $required -notcontains $name -and -not @($lists[$name]).Count) { continue }
        $label = Get-CltAduaExtensionAttributeLabel -Attribute $name
        [pscustomobject]@{
            Id    = $name
            Title = "Active Directory $(Get-CltAduaExtensionAttributeTitle -Attribute $name -Label $label) values are on the approved list."
            Data  = @{
                Attribute = $name; Label = $label; UsedBy = $usage[$name]
                InSchema  = (Test-CltAduaExtensionAttributeInSchema -Attribute $name)
                NamedIn   = if ($required -contains $name) { '**CLT.ADUA.RequiredExtensionAttributes**' } else { 'the approved values (**CLT.ADUA.AllowedValues**)' }
            }
        }
    }
}

function Test-CltAduaExtensionAttributeValue {
    <#
    .SYNOPSIS
    Checks that every value set in each extension attribute (extensionAttribute1-15, msDS-cloudExtensionAttribute1-20) of enabled Active Directory users is an approved value.

    .DESCRIPTION
    A family: one result per extension attribute in use. Approved values come from extensionAttribute1 ...
    extensionAttribute15 and msDS-cloudExtensionAttribute1 ... 20 in CLT.ADUA.AllowedValues, or from AllowedValues set on one instance in TestSettings.
    Blank values are not checked; MP.CLT.ADUA.1024 checks those. Without approved values the instance reports
    Investigate and lists the values in use. An attribute named in the config that this forest's schema does
    not have reports Investigate and says why.

    .EXAMPLE
    Invoke-MtTest -Id MP.CLT.ADUA.1025.extensionAttribute2 -Parameter @{ AllowedValues = 'Employee', 'Contractor' }
    #>
    [MaesterTest(
        Id             = 'MP.CLT.ADUA.1025',
        Title          = 'Active Directory extension attribute values are on the approved list.',
        Product        = 'ad',
        Feature        = 'users',
        Area           = 'identity-lifecycle',
        ResourceType   = 'User',
        Severity       = 'Low',
        UserImpact     = 'Low',
        ImplementationCost = 'Low',
        Service        = 'CLT.ADUA.Ldap',
        Permission     = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty'),
        Tag            = ('ADUserAttributes', 'Validation', 'ExtensionAttributes'),
        Author         = 'DevClate',
        InstanceSource = 'Get-CltAduaExtensionAttributeValueInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The extension attribute to check, supplied by the engine.
        $Instance,

        # Approved values for this attribute only (set on the instance ID in TestSettings); when set, CLT.ADUA.AllowedValues is not used.
        [string[]] $AllowedValues,

        # Treat values that differ only in letter case (contractor and Contractor) as different.
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

    $attribute = $Instance.Data.Attribute
    if (-not $Instance.Data.InSchema) {
        Add-MtTestResultDetail -Investigate -Result (Get-CltAduaMissingSchemaMessage -Attribute $attribute -Source $Instance.Data.NamedIn)
        return $true
    }
    $label = if ($Instance.Data.Label) { $Instance.Data.Label } else { $attribute }
    $column = if ($Instance.Data.Label) { $Instance.Data.Label } else { 'Value' }
    $set = Get-CltAduaUser -IncludeDisabled $IncludeDisabled -ExcludedUsers $ExcludedUsers -ExcludedGroups $ExcludedGroups
    return (Invoke-CltAduaAllowedValueCheck -Set $set -Attribute $attribute -Label $label -Column $column -Population (Get-CltAduaPopulation -IncludeDisabled $IncludeDisabled) -AllowedValues $AllowedValues -CaseSensitive $CaseSensitive -MaxRows $MaxRows)
}
