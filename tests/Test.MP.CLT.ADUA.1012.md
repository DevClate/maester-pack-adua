Checks that phone numbers on enabled Active Directory users are in international E.164 format: a plus sign, the country code and the number, with no spaces or punctuation, such as `+14255550100`. By default it checks `telephoneNumber` and `mobile`; the `Attributes` parameter can add `otherTelephone`, `otherMobile`, `homePhone` and `facsimileTelephoneNumber`.

Teams Phone, click-to-call, MFA phone registration and mobile device enrolment read these numbers once they are synced to Microsoft Entra ID, and they only dial reliably when the number is in E.164. A trailing extension such as `;ext=123` or `x123` is allowed by default (`AllowExtension`).

#### Remediation action

1. Rewrite each number listed below as + country code and number, for example `(425) 555-0100` becomes `+14255550100`.
2. In **Active Directory Users and Computers**, change the number on the **General** tab (Telephone number) or the **Telephones** tab (Mobile, Fax, Home), or use PowerShell: `Set-ADUser -Identity <sAMAccountName> -OfficePhone '+14255550100' -MobilePhone '+14255550101'`.
3. If your organisation writes numbers with spaces (`+1 425 555 0100`), set `AllowSpaces` to `$true` for this test. For a different rule, set `PhonePattern` to your own regular expression.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Telephone-Number attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-telephonenumber)
* [E.164 numbering (ITU-T)](https://www.itu.int/rec/T-REC-E.164)

<!--- Results --->
%TestResult%
