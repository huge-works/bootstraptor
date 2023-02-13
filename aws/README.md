# aws

There is a bunch of things that need to be done when starting out with AWS.  These steps are important to make sure that your AWS environment is secure, within budget, and stays organized as it grows.

## Management Account and Root Credentials

Multi-account AWS setups are the defacto standard today for anything that isn't just a toy setup.  Even if you aren't doing multi-account, it's very important to secure the root credentials for your account.  

In a multi-account setup, the account that is used to create the Organization is called the 'managagement' account.  It has also be referred to as the 'master' account in the past and is still referred to that way in some APIs.  The management account is the most critical account because, in a typical Organization setup, has the ability to create, access, and delete member accounts.  The management account delegates down to and controls the member accounts.  

Within the management account itself (or the sole aws account if you aren't multi-account), the root credentials are the most critical.  The root credentials are used to delegate access to the management account to IAM Users and Roles.  The root credentials allow full and complete access to the account (and therefor the Organization if we're talking about the mangement account root credentials).  Root credentials are also needed for special actions like changing the account email, name, and contact information.

### Access Delegation

It's very important that we setup MFA on the root and then create an IAM break-glass User for emergencies.  We also want to add MFA to that break-glass User.  Then we want to create admin Roles through AWS Identity Center (AWS SSO).  The pattern is that IAM Roles through Identity Center should be normal usage, then the break-glass User is for emergencies when the Roles don't work, and finally the root credentials are for absolute necessity.  

### Root Credential Chain

In terms of managing the root credentials, there are a few options to consider.  At the very least, the root credentials should be protected by a strong password and MFA.  In addition, the email address associated with the credentials should be similarly secure with a strong password and MFA.  The account's associated phone number can also be used as a factor to gain access, so the phone and phone provider account should be secured as well.  You might also consider using a VoIP provider, such as Google Voice, to avoid SIM-swapping attacks.  Then for that VoIP account, make sure to again use a strong password and MFA.  It's probably a good idea to _not_ rely on SMS for the VoIP MFA and to instead use either a FIDO key, an imported ToTP token, or printed ToTP import QR code.  Again, the email address associated with the VoIP account needs to be secured in the same manner.  We want to get to a point where all of the recovery options and backup emails are protected by a strong password and a non-SIM second factor.  It should also be noted that if you are using an email address that is part of a domain you control, access to that domain, DNS, and email server likewise need to be protected.

### Recovery and Redundancy

The above security steps will lock down the root credentials and the chain of authentication factors and backups.  Two problems come up from this setup: how do we recover this chain if we lose access to a link and how do we add redundancy in case of a link outage.  For example, if we use an employee's phone number for the AWS account, what happens if they are unavailable or leave the company?  That's another reason to use a VoIP provider so that two people can have access to the same virtual number.  

We also want to try and avoid sharing passwords / backup methods as much as possible so that we can properly track access and tell who used the root credentials.  Fortunately for us, AWS recently allowed multiple different MFA devices to be added to the root credentials, so even if the password / email is the same, we can have a different MFA device per authorized person.  Google Groups are a great way to "share" an email address without having to actually share the password.  Each user can be added / removed from the group individually.

Many email and other account providers allow backup codes to be downloaded.  These backup codes can be considered another way to gain access to an account.  Backup codes should be treated like a physical MFA device: they can be printed and stored physically or stored on an password-protected USB drive.  The great thing about these backup codes is that they can be replicated (printed again or downloaded to second drive) or split up so that we get some redundancy.

Physical security is a whole topic on its own, but the basics are to make sure that devices are encrypted and kept locked up.  You might consider storing the backup codes (printed or USB-drived) in a safe-deposit box at a bank.  Ideally these codes should be used rarely and only if the other access methods are broken.

## Organizations

Bootstrapping AWS Organizations can be done with the create-organization.sh script.

The script creates the organization if it's not already made.
It then creates some foundational OUs.
It moves the management Account into the Management OU.
It also sets up an initial, very low, budget that will send an email to the given email address.
