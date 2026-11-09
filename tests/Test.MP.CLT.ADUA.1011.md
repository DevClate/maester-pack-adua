Checks that no two Active Directory users share an employee ID (`employeeID`). Disabled accounts are checked too by default, because the old account of a rehired person often still holds the ID.

HR provisioning, joiner-mover-leaver scripts and Microsoft Entra Lifecycle Workflows match accounts to people by employee ID. When two accounts share one, a leaver process can disable the wrong person, or an HR update lands on the old account.

#### Remediation action

1. For each ID listed below, find out which account belongs to the person in HR today.
2. Clear or correct the ID on the other accounts: `Set-ADUser -Identity <sAMAccountName> -Clear employeeID`, or set the right ID with `-EmployeeID`.
3. If your HR system pads IDs with zeros inconsistently (00123 and 123), run this test with `IgnoreLeadingZeros` set to `$true` to catch those as duplicates.
4. To check only active accounts, set `IncludeDisabled` to `$false` for this test.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Employee-ID attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-employeeid)

<!--- Results --->
%TestResult%
