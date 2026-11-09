Checks that every enabled Active Directory user has a complete office address. By default `streetAddress`, `l` (city), `st` (state or province), `postalCode` and `co` (country) must all be set; use the `Fields` parameter to add `c` or `physicalDeliveryOfficeName`, or to leave a field out.

The address appears in the global address list and in Outlook and Teams once Microsoft Entra Connect syncs it. Emergency calling, mail routing to offices, and location-based groups and policies depend on it, and a half-filled address is often worse than none because tools trust it.

#### Remediation action

1. In **Active Directory Users and Computers**, open each user listed below and go to the **Address** tab.
2. Fill in **Street**, **City**, **State/province**, **Zip/Postal Code** and **Country/region**, and select **OK**. Choosing the country there sets `c`, `co` and `countryCode` together.
3. For many users, use PowerShell with the ActiveDirectory module (RSAT): `Set-ADUser -Identity <sAMAccountName> -StreetAddress '1 Main Street' -City 'Redmond' -State 'WA' -PostalCode '98052' -Replace @{ c = 'US'; co = 'United States'; countryCode = 840 }`. `-Country` on its own sets only `c`, which leaves `co` blank.
4. If an account legitimately has no value (a service or resource account), leave it out with `ExcludedUsers`, `ExcludedGroups` or the pack-wide `CLT.ADUA.ExcludedOUs` in `maester-config.json` rather than filling in a placeholder.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Street-Address attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-streetaddress)
* [Text-Country attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-co)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
