#/bin/bash

AWS_ROOT_CA_1="https://www.amazontrust.com/repository/AmazonRootCA1.pem"
AWS_ROOT_CA_2="https://www.amazontrust.com/repository/AmazonRootCA2.pem"
AWS_ROOT_CA_3="https://www.amazontrust.com/repository/AmazonRootCA3.pem"
AWS_ROOT_CA_4="https://www.amazontrust.com/repository/AmazonRootCA4.pem"
AWS_ROOT_SYMANTEC="https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem"

CA_PREFIX="sample-ca-certificate"
CA_KEY="$CA_PREFIX.key"
CA_PEM="$CA_PREFIX.pem"

DEV_ID="$RANDOM"
DEV_NAME_PREFIX="device-cert"
DEV_NAME="$DEV_NAME-$DEV_ID"

DEV_CERT_NAME="$DEV_NAME.pem"
DEV_CSR_NAME="$DEV_NAME.csr"
DEV_KEY_NAME="$DEV_NAME.key"

ACC_ONE_PROFILE="sandbox"
ACC_TWO_PROFILE="ws01"

if [ -f "$CA_KEY" ]; then
    echo ""
    echo "WARN: CA_KEY exists. Ignoring CA setup step..."
    echo ""
else
    echo ""
    echo "Creating a sample CA..."
    openssl genrsa -out "$CA_KEY" 2048

    openssl req -x509 -new -nodes -key "$CA_KEY" \
        -sha256 -days 365 -out "$CA_PEM" \
        -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=Sample Root CA"
fi

if [ -z ${AWS_REGION+x} ]; then 
    echo "No region specified. export AWS_REGION=us-east-2"
    exit 1
else 
    echo ""
    echo "Working on region $AWS_REGION"
    echo ""
fi
    
echo "Generating crypto material for device $DEV_ID..."
echo "CERT $DEV_CERT_NAME..."
echo "CSR  $DEV_CSR_NAME..."
echo "KEY  $DEV_KEY_NAME..."

openssl genrsa -out "$DEV_KEY_NAME" 2048

openssl req -new -key "$DEV_KEY_NAME" -out "$DEV_CSR_NAME" \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=CA_Less_Test"

openssl x509 -req -in "$DEV_CSR_NAME" -CA "$CA_PEM" \
    -CAkey "$CA_KEY" \
    -CAcreateserial \
    -out "$DEV_CERT_NAME" -days 365 -sha256

cat "$DEV_CERT_NAME" "$CA_PEM" > device-cert-and-ca-cert.crt    

if [ -f "root-ca.pem" ]; then
    echo ""
    echo "WARN: ROOT CA cert exists. Ignoring download..."
    echo ""
else
    echo ""
    echo "Downloading root cert..."
    wget "$AWS_ROOT_CA_1" --quiet -O root-ca.pem 
fi

function provision_device {
    local ACC_PROFILE="$1"
    local THING_NAME="$2"
    local AWS_REGION="$3"
    local DEV_CONFIG_FILE="$2.cfg"
    
    echo "AWS_PROFILE=$ACC_PROFILE" > $DEV_CONFIG_FILE
    echo "AWS_REGION=$AWS_REGION" >> $DEV_CONFIG_FILE
    echo "THING_NAME=$THING_NAME" >> $DEV_CONFIG_FILE

    echo ""
    echo "[$ACC_PROFILE] - Registering certificate without CA..."

    CERT_ARN=`aws iot register-certificate-without-ca \
        --status ACTIVE \
        --certificate-pem "file://$DEV_CERT_NAME" \
        --profile $ACC_PROFILE \
        --query "certificateArn" --output text`

    echo "[$ACC_PROFILE] - CERT_ARN $CERT_ARN"
    echo "CERT_ARN=$CERT_ARN" >> $DEV_CONFIG_FILE

    # Attach thing
    echo ""
    echo "[$ACC_PROFILE] - Creating thing $THING_NAME..."

    aws iot create-thing \
        --thing-name "$THING_NAME" \
        --profile $ACC_PROFILE

    echo ""
    echo "[$ACC_PROFILE] - Attaching cert to thing - $THING_NAME..."

    aws iot attach-thing-principal \
        --thing-name "$THING_NAME" \
        --principal "$CERT_ARN" \
        --profile $ACC_PROFILE


    # Attach policy
    echo ""
    echo "[$ACC_PROFILE] - Creating policy $THING_NAME-policy..."

    aws iot create-policy \
        --policy-name "$THING_NAME-policy" \
        --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ConnectUsingClientId\",\"Effect\":\"Allow\",\"Action\":\"iot:*\",\"Resource\":\"*\"}]}" \
        --profile "$ACC_PROFILE"

    echo "POLICY=$THING_NAME-policy" >> $DEV_CONFIG_FILE

    # Attach policy
    echo ""
    echo "[$ACC_PROFILE] - Attaching policy to cert... $ACC_PROFILE $THING_NAME-policy -> $CERT_ARN"

    aws iot attach-policy \
        --policy-name "$THING_NAME-policy" \
        --target "$CERT_ARN" \
        --profile "$ACC_PROFILE"
}

provision_device $ACC_ONE_PROFILE "device-$DEV_ID-cert-acc-one" "$AWS_REGION"
provision_device $ACC_TWO_PROFILE "device-$DEV_ID-cert-acc-two" "$AWS_REGION"

echo ""
echo "Checking AWS IoT endpoint..."

ACC_ONE_ENDPOINT=`aws iot describe-endpoint --endpoint-type "iot:Data-ATS" \
            --profile "$ACC_ONE_PROFILE" \
            --output text --query "endpointAddress"`

ACC_TWO_ENDPOINT=`aws iot describe-endpoint --endpoint-type "iot:Data-ATS" \
            --profile "$ACC_TWO_PROFILE" \
            --output text --query "endpointAddress"`


echo ""
echo "[$ACC_ONE_PROFILE] - Connecting to '$ACC_ONE_ENDPOINT'..."

mosquitto_pub \
    --cafile root-ca.pem \
    --cert device-cert-and-ca-cert.crt \
    --key "$DEV_KEY_NAME" \
    -h $ACC_ONE_ENDPOINT -p 8883 \
    --repeat 5 --repeat-delay 1 \
    -q 1 -t foo/bar/test -i "$DEV_NAME-same-cert-acc-one" \
    --tls-version tlsv1.2 -m "Hello" -d &

echo ""
echo "[$ACC_TWO_PROFILE] - Connecting to '$ACC_TWO_ENDPOINT'..."

mosquitto_pub \
    --cafile root-ca.pem \
    --cert device-cert-and-ca-cert.crt \
    --key "$DEV_KEY_NAME" \
    -h "$ACC_TWO_ENDPOINT" -p 8883 \
    --repeat 5 --repeat-delay 1 \
    -q 1 -t foo/bar/test -i "$DEV_NAME-same-cert-acc-two" \
    --tls-version tlsv1.2 -m "Hello" -d \
    --insecure