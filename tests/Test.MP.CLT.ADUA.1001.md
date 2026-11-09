Checks that every enabled Active Directory user has a manager (`manager`), except people at the top of the organisation (by default, job titles CEO and Chief Executive Officer).

Microsoft Entra Connect syncs `manager` to Microsoft Entra ID, where access reviews, access package approvals, Lifecycle Workflows and the organisation chart in Outlook and Teams use it. The address book and many HR and ticketing tools read it straight from Active Directory. A user without a manager makes those steps fail or fall back to an administrator.

#### Remediation action

1. In **Active Directory Users and Computers**, open each user listed below and go to the **Organization** tab.
2. Under **Manager**, select **Change**, pick the manager and select **OK**.
3. For many users, use PowerShell with the ActiveDirectory module (RSAT): `Set-ADUser -Identity <sAMAccountName> -Manager <manager sAMAccountName>`.
4. If someone legitimately has no manager, add their job title to `ExcludedJobTitles` for this test, or the user to `ExcludedUsers`, in `maester-config.json`.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Manager attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-manager)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
