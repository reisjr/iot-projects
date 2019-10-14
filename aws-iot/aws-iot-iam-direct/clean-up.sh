#!/bin/bash

# Based on Authorizing Direct Calls to AWS Services
# https://docs.aws.amazon.com/iot/latest/developerguide/authorizing-direct-aws.html

aws iam detach-user-policy \
    --user-name dreis \
    --policy-arn arn:aws:iam::340724670717:policy/IoTPassRolePermissionPolicy

aws iam detach-role-policy \
    --role-name IoTAuthDirectCallRole \
    --policy-arn "arn:aws:iam::340724670717:policy/IoTAccessS3Policy"

aws iam detach-role-policy \
    --role-name IoTAuthDirectCallRole \
    --policy-arn "arn:aws:iam::340724670717:policy/IoTAccessS3Policy"

echo "Step 2"
aws iam delete-policy \
    --policy-arn "arn:aws:iam::340724670717:policy/IoTAccessS3Policy"   

aws iam delete-policy \
    --policy-arn "arn:aws:iam::340724670717:policy/IoTPassRolePermissionPolicy"   

echo "Step 1 - Removing Role required by Direct Call..."
aws iam delete-role \
    --role-name IoTAuthDirectCallRole

aws iot delete-policy \
    --policy-name SampleDeviceIoTPolicy

aws iot delete-role-alias \
    --role-alias S3AccessRoleAlias