Checks that every enabled Active Directory user has an employee ID (`employeeID`).

The employee ID ties an account to its HR record. HR-driven provisioning, joiner-mover-leaver scripts and Microsoft Entra Lifecycle Workflows match on it, and without it a leaver's account cannot be found reliably.

#### Remediation action

1. In **Active Directory Users and Computers**, open each user listed below and go to the **Attribute Editor (turn on **View** > **Advanced Features**)** tab.
2. Fill in **employeeID** and select **OK**.
3. For many users, use PowerShell with the ActiveDirectory module (RSAT): `Set-ADUser -Identity <sAMAccountName> -EmployeeID '012345'`.
4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. If an account legitimately has no value (a service or resource account), leave it out with `ExcludedUsers`, `ExcludedGroups` or the pack-wide `CLT.ADUA.ExcludedOUs` in `maester-config.json` rather than filling in a placeholder.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Employee-ID attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-employeeid)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
