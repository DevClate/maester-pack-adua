Checks that every enabled Active Directory user has a job title (`title`).

Job title appears in the global address list and in Outlook and Teams once Microsoft Entra Connect syncs it (as jobTitle). Dynamic groups, Conditional Access scoping and HR reports often filter on it.

#### Remediation action

1. In **Active Directory Users and Computers**, open each user listed below and go to the **Organization** tab.
2. Fill in **Job Title** and select **OK**.
3. For many users, use PowerShell with the ActiveDirectory module (RSAT): `Set-ADUser -Identity <sAMAccountName> -Title 'Accountant'`.
4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. If an account legitimately has no value (a service or resource account), leave it out with `ExcludedUsers`, `ExcludedGroups` or the pack-wide `CLT.ADUA.ExcludedOUs` in `maester-config.json` rather than filling in a placeholder.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Title attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-title)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
