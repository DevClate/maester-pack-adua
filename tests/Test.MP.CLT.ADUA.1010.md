Checks that every enabled Active Directory user has an office location (`physicalDeliveryOfficeName`).

`physicalDeliveryOfficeName` is the Office field in Active Directory Users and Computers, synced to Microsoft Entra ID as officeLocation. Room finders, seating plans and location-based groups use it.

#### Remediation action

1. In **Active Directory Users and Computers**, open each user listed below and go to the **General** tab.
2. Fill in **Office** and select **OK**.
3. For many users, use PowerShell with the ActiveDirectory module (RSAT): `Set-ADUser -Identity <sAMAccountName> -Office 'Redmond HQ'`.
4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. If an account legitimately has no value (a service or resource account), leave it out with `ExcludedUsers`, `ExcludedGroups` or the pack-wide `CLT.ADUA.ExcludedOUs` in `maester-config.json` rather than filling in a placeholder.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Physical-Delivery-Office-Name attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-physicaldeliveryofficename)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
