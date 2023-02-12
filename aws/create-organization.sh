#!/usr/bin/env bash

set -e

SCRIPT_NAME="create-organization.sh"
VERBOSE=0

while test $# -gt 0; do
  case "$1" in
    -h | --help)
      echo "$SCRIPT_NAME - attempt to create AWS Organization"
      echo " "
      echo "Creates the org, a Management OU, and moves management account into Management OU"
      echo "Also creates a budget 'Overall Budget' in the management account."
      echo " "
      echo "$SCRIPT_NAME [options]"
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-v, --verbose             print verbose output"
      exit 0
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      break
      ;;
  esac
done

# echo the output if VERBOSE is enabled.
function log () {
    if [[ $VERBOSE -eq 1 ]] ; then
        echo "$@"
    fi
}

# Creates an OU with the provided name in the provided parent.
# First positional argument is the OU name.
# Second positional argument is the parent-id.
function create_ou () {
    local OU_NAME=$1

    if [[ $OU_NAME == "" ]] ; then
        echo 'First parameter for create_ou call not set.' 1>&2
        caller 1>&2
        exit 1
    fi

    local OU_PARENT_ID=$2

    if [[ $OU_PARENT_ID == "" ]] ; then
        echo 'Second parameter for create_ou call not set.' 1>&2
        caller 1>&2
        exit 1
    fi

    local CREATE_OU_OUTPUT
    local CREATE_OU_EXIT_CODE
    CREATE_OU_OUTPUT=$(aws organizations create-organizational-unit --parent-id $OU_PARENT_ID --name $OU_NAME 2>&1) || CREATE_OU_EXIT_CODE=$?
    
    if [[ $CREATE_OU_EXIT_CODE -ne 0 ]] ; then

        if [[ "$CREATE_OU_OUTPUT" == *"DuplicateOrganizationalUnitException"* ]]; then
            log "An organizational unit with the specified name ('$OU_NAME') already exists under the specified parent."
        else
            echo $CREATE_OU_OUTPUT 1>&2
            exit $CREATE_OU_EXIT_CODE
        fi

    else
        log "$OU_NAME OU created."
    fi
}

log "Starting."

# The ALL feature-set is billing plus SCPs.
CREATE_ORG_OUTPUT=$(aws organizations create-organization --feature-set ALL 2>&1) || CREATE_ORG_EXIT_CODE=$?

if [[ $CREATE_ORG_EXIT_CODE -ne 0 ]] ; then

    if [[ "$CREATE_ORG_OUTPUT" == *"AlreadyInOrganizationException"* ]]; then
        log "The AWS account is already a member of an organization."
    else
        echo $CREATE_ORG_OUTPUT 1>&2
        exit $CREATE_ORG_EXIT_CODE
    fi

else
    log "Organization created."
fi

# Root ID is like: r-examplerootid111"
# This Root ID is the parent-id for the first OUs.
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
create_ou 'Management' $ROOT_ID

# Get the Master (management) Account ID
MASTER_ACCOUNT_ID=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)

# Get the management Account current parent-id.
MASTER_ACCOUNT_PARENT_ID=$(aws organizations list-parents --child-id $MASTER_ACCOUNT_ID --query 'Parents[0].Id' --output text)

# Get the ID of the Management OU.
MANAGEMENT_OU_ID=$(aws organizations list-organizational-units-for-parent --parent-id $ROOT_ID --query 'OrganizationalUnits[?Name==`Management`].Id' --output text)

# Move the management Account into the Management OU.
MOVE_ACCOUNT_OUTPUT=$(aws organizations move-account --account-id $MASTER_ACCOUNT_ID --source-parent-id $MASTER_ACCOUNT_PARENT_ID --destination-parent-id $MANAGEMENT_OU_ID 2>&1) || MOVE_ACCOUNT_EXIT_CODE=$?

if [[ $MOVE_ACCOUNT_EXIT_CODE -ne 0 ]] ; then

    if [[ "$MOVE_ACCOUNT_OUTPUT" == *"DuplicateAccountException"* ]]; then
        log "That account is already present at the specified destination."
    else
        echo $MOVE_ACCOUNT_OUTPUT 1>&2
        exit $MOVE_ACCOUNT_EXIT_CODE
    fi

else
    log "management Account moved into Management OU."
fi

# Create budget in management Account.
export AWS_BUDGET_ACCOUNT_ID=$MASTER_ACCOUNT_ID

if [[ $AWS_BUDGET_EMAIL == "" ]] ; then

    echo 'Environment variable AWS_BUDGET_EMAIL not set.' 1>&2
    exit 1

fi

AWS_BUDGET_TEMP_FILE=$(mktemp)
envsubst < aws/create-budget-input-template.yaml > $AWS_BUDGET_TEMP_FILE
CREATE_BUDGET_OUTPUT=$(aws budgets create-budget --cli-input-yaml file://$AWS_BUDGET_TEMP_FILE 2>&1) || CREATE_BUDGET_EXIT_CODE=$?

if [[ $CREATE_BUDGET_EXIT_CODE -ne 0 ]] ; then

    if [[ "$CREATE_BUDGET_OUTPUT" == *"DuplicateRecordException"* ]]; then
        log "Overall Budget - the budget already exists."
    else
        echo $CREATE_BUDGET_OUTPUT 1>&2
        exit $CREATE_BUDGET_EXIT_CODE
    fi

else
    log "Budget 'Overal Budget' created in management Account."
fi

# Create additional OUs.
create_ou 'Infrastructure' $ROOT_ID
create_ou 'Deployments' $ROOT_ID
create_ou 'Security' $ROOT_ID
create_ou 'Workloads' $ROOT_ID

log "Finished."
