# aws

Bootstrapping AWS Organizations can be done with the create-organization.sh script.

The script creates the organization if it's not already made.
It then creates some foundational OUs.
It moves the management Account into the Management OU.
It also sets up an initial, very low, budget that will send an email to the given email address.
