#!/bin/bash

# Based on Authorizing Direct Calls to AWS Services
# https://aws.amazon.com/pt/blogs/security/how-to-eliminate-the-need-for-hardcoded-aws-credentials-in-devices-by-using-the-aws-iot-credentials-provider

echo "Step 1 - Provisioning Role required by Direct Call..."

ROLE_1_ARN=`aws iam create-role \
    --role-name IoTAuthDirectCallRole \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Sid":"IoTAuthDirectCall","Effect":"Allow","Principal":{"Service":"credentials.iot.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --query "Role.Arn" --output text`

echo $ROLE_1_ARN

echo "Step 2 - Creating a S3 access Policy..."

ROLE_2_ARN=`aws iam create-policy \
    --policy-name IoTAccessS3Policy \
    --policy-document file://sample_s3_policy.json \
    --output text --query "Policy.Arn"`

echo $ROLE_2_ARN

echo "Step 3 - Attaching Role to Policy..."
aws iam attach-role-policy \
    --role-name IoTAuthDirectCallRole \
    --policy-arn $ROLE_2_ARN

echo "Step 4 - Creating pass Role..."
PASS_ROLE_ARN=`aws iam create-policy \
    --policy-name IoTPassRolePermissionPolicy \
    --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"IoTRoleAlias\",\"Effect\":\"Allow\",\"Resource\":\"$ROLE_1_ARN\",\"Action\":[\"iam:GetRole\", \"iam:PassRole\"]}]}" \
    --output text --query "Policy.Arn"`

echo $PASS_ROLE_ARN

echo "Step 4 - Attach user..."
aws iam attach-user-policy \
    --policy-arn $PASS_ROLE_ARN \
    --user-name dreis

echo "Step 4 - Creating a Role alias in AWS IoT..."
aws iot create-role-alias \
    --role-alias S3AccessRoleAlias \
    --role-arn $ROLE_1_ARN \
    --credential-duration-seconds 3600

# ROLE_2_ARN=`aws iam create-role \
#     --role-name IoT_Auth_Direct_Call_Alias_Role \
#     --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"IoTRoleAlias\",\"Effect\":\"Allow\",\"Resource\":\"$ROLE_1_ARN\",\"Action\":[\"iam:GetRole\", \"iam:PassRole\"]}]}" \
#     --query "Role.Arn" --output text`


# aws iot create-role-alias --role-alias Thermostat-dynamodb-access-role-alias --role-arn arn:aws:iam::<your_aws_account_id>:role/dynamodb-access-role --credential-duration-seconds 3600

# aws iot create-policy \
#     --policy-name 'IoT_Auth_Direct_Policy' \
#     --policy-document "{\"Version\": \"2012-10-17\",\"Statement\": {\"Effect\": \"Allow\",\"Action\": \"iot:AssumeRoleWithCertificate\",\"Resource\":\"$ROLE_1_ARN\"}}"
		