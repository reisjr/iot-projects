#!/bin/bash

function reconnect_devices {
    local CERT_ARN=$(cat $1 | grep "CERT_ARN" | cut -f2 -d=)
    local AWS_REGION=$(cat $1 | grep "AWS_REGION" | cut -f2 -d=)
    local AWS_PROFILE=$(cat $1 | grep "AWS_PROFILE" | cut -f2 -d=)
    local DEV_ID=$(cat $1 | grep "DEV_ID" | cut -f2 -d=)
    local DEV_NAME_PREFIX=$(cat $1 | grep "DEV_NAME_PREFIX" | cut -f2 -d=)
    local DEV_NAME_A=$(cat $1 | grep "DEV_NAME_A" | cut -f2 -d=)
    local DEV_NAME_B=$(cat $1 | grep "DEV_NAME_B" | cut -f2 -d=)
    local POLICY=$(cat $1 | grep "POLICY" | cut -f2 -d=)
    local ENDPOINT=$(cat $1 | grep "ENDPOINT" | cut -f2 -d=)

    echo "     AWS_REGION '$AWS_REGION'"
    echo "    AWS_PROFILE '$AWS_PROFILE'"
    echo "       CERT_ARN '$CERT_ARN'"
    echo "         DEV_ID '$DEV_ID'"
    echo "DEV_NAME_PREFIX '$DEV_NAME_PREFIX'"
    echo "     DEV_NAME_A '$DEV_NAME_A'"
    echo "     DEV_NAME_B '$DEV_NAME_B'"
    echo "       ENDPOINT '$ENDPOINT'"

    DEV_NAME="$DEV_NAME_PREFIX-$DEV_ID"

    DEV_CERT_NAME="$DEV_NAME.pem"
    DEV_KEY_NAME="$DEV_NAME.key"


    CA_PREFIX="sample-ca-certificate"
    CA_PEM="$CA_PREFIX.pem"
    
    cat "$DEV_CERT_NAME" "$CA_PEM" > device-cert-and-ca-cert.crt

    mosquitto_pub \
        --cafile root-ca.pem \
        --cert device-cert-and-ca-cert.crt \
        --key "$DEV_KEY_NAME" -h $ENDPOINT -p 8883 \
        --repeat 5000 --repeat-delay 5 \
        -q 1 -t foo/bar/test -i "$DEV_NAME_A" \
        --tls-version tlsv1.2 -m "Hello" -d &


    mosquitto_pub \
        --cafile root-ca.pem \
        --cert device-cert-and-ca-cert.crt \
        --key "$DEV_KEY_NAME" -h $ENDPOINT -p 8883 \
        --repeat 5000 --repeat-delay 5 \
        -q 1 -t foo/bar/test -i "$DEV_NAME_B" \
        --tls-version tlsv1.2 -m "Hello" -d &
}

CFG_FILES=$(find . -type f -iname "*.cfg")

for CFG in $CFG_FILES; do
    echo "Reconnecting using $CFG..."
    reconnect_devices $CFG
done

wait
