#!/bin/bash

function remove_device {
    local CERT_ARN=$(cat $1 | grep "CERT_ARN" | cut -f2 -d=)
    local AWS_REGION=$(cat $1 | grep "AWS_REGION" | cut -f2 -d=)
    local AWS_PROFILE=$(cat $1 | grep "AWS_PROFILE" | cut -f2 -d=)
    local DEV_NAME_A=$(cat $1 | grep "DEV_NAME_A" | cut -f2 -d=)
    local DEV_NAME_B=$(cat $1 | grep "DEV_NAME_B" | cut -f2 -d=)
    local POLICY=$(cat $1 | grep "POLICY" | cut -f2 -d=)

    echo " AWS_REGION '$AWS_REGION'"
    echo "AWS_PROFILE '$AWS_PROFILE'"
    echo "   CERT_ARN '$CERT_ARN'"
    echo " DEV_NAME_A '$DEV_NAME_A'"
    echo " DEV_NAME_B '$DEV_NAME_B'"
    echo "     POLICY '$POLICY'"
    

    aws iot detach-thing-principal \
        --thing-name "$DEV_NAME_A" \
        --principal "$CERT_ARN" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE

    aws iot detach-thing-principal \
        --thing-name "$DEV_NAME_B" \
        --principal "$CERT_ARN" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE

    aws iot detach-policy \
        --policy-name "$POLICY" \
        --target "$CERT_ARN" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE

    CERT_ID=`echo $CERT_ARN | cut -f2 -d/`

    echo ""
    echo "Deactivating certificate $CERT_ID..."

    aws iot update-certificate \
        --certificate-id "$CERT_ID" \
        --new-status "INACTIVE" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE

    echo ""
    echo "Removing certificate $CERT_ID..."

    aws iot delete-certificate \
        --certificate-id "$CERT_ID" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
    
    mv $CFG /tmp # schedule deletion
}

CFG_FILES=$(find . -type f -iname "*.cfg")

for CFG in $CFG_FILES; do
    echo "Cleaning using $CFG..."
    remove_device $CFG
done

rm root-ca.pem
rm sample-ca-certificate.*
rm device-shared-cert-*
