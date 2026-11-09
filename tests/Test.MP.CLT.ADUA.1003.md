Checks that every enabled Active Directory user has a department (`department`).

Department is the attribute dynamic groups, licence assignment and reports use most once it is synced to Microsoft Entra ID. A user without one falls outside every group built on it.

#### Remediation action

1. In **Active Directory Users and Computers**, open each user listed below and go to the **Organization** tab.
2. Fill in **Department** and select **OK**.
3. For many users, use PowerShell with the ActiveDirectory module (RSAT): `Set-ADUser -Identity <sAMAccountName> -Department 'Finance'`.
4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. If an account legitimately has no value (a service or resource account), leave it out with `ExcludedUsers`, `ExcludedGroups` or the pack-wide `CLT.ADUA.ExcludedOUs` in `maester-config.json` rather than filling in a placeholder.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Department attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-department)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
