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
DEV_NAME_PREFIX="device-shared-cert"
DEV_NAME="$DEV_NAME_PREFIX-$DEV_ID"
DEV_NAME_A="$DEV_NAME-a"
DEV_NAME_B="$DEV_NAME-b"

DEV_CERT_NAME="$DEV_NAME.pem"
DEV_CSR_NAME="$DEV_NAME.csr"
DEV_KEY_NAME="$DEV_NAME.key"

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

echo "Generating crypto material for device $DEV_NAME_A / $DEV_NAME_B..."
echo "CERT $DEV_CERT_NAME..."
echo "CSR  $DEV_CSR_NAME..."
echo "KEY  $DEV_KEY_NAME..."

DEV_CONFIG_FILE="$DEV_NAME.cfg"

echo "DEV_ID=$DEV_ID"  >> $DEV_CONFIG_FILE
echo "DEV_NAME_PREFIX=$DEV_NAME_PREFIX" > $DEV_CONFIG_FILE
echo "DEV_NAME=$DEV_NAME" >> $DEV_CONFIG_FILE
echo "DEV_NAME_A=$DEV_NAME_A" >> $DEV_CONFIG_FILE
echo "DEV_NAME_B=$DEV_NAME_B" >> $DEV_CONFIG_FILE
echo "AWS_REGION=$AWS_REGION" >> $DEV_CONFIG_FILE
echo "AWS_PROFILE=$AWS_PROFILE" >> $DEV_CONFIG_FILE

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

echo ""
echo "Registering certificate without CA..."

CERT_ARN=`aws iot register-certificate-without-ca \
    --status ACTIVE \
    --certificate-pem "file://$DEV_CERT_NAME" \
    --query "certificateArn" --output text`

echo "CERT_ARN $CERT_ARN"
echo "CERT_ARN=$CERT_ARN" >> $DEV_CONFIG_FILE

# Attach thing

aws iot create-thing \
    --thing-name "$DEV_NAME_A" \
    --region $AWS_REGION

aws iot create-thing \
    --thing-name "$DEV_NAME_B" \
    --region $AWS_REGION

aws iot attach-thing-principal \
    --thing-name "$DEV_NAME_A" \
    --principal "$CERT_ARN" \
    --region $AWS_REGION

aws iot attach-thing-principal \
    --thing-name "$DEV_NAME_B" \
    --principal "$CERT_ARN" \
    --region $AWS_REGION

# Attach policy

aws iot create-policy \
    --policy-name "$DEV_NAME-policy" \
    --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ConnectUsingClientId\",\"Effect\":\"Allow\",\"Action\":\"iot:*\",\"Resource\":\"*\"}]}" \
    --region $AWS_REGION

echo "POLICY=$DEV_NAME-policy" >> $DEV_CONFIG_FILE

aws iot attach-policy \
    --policy-name "$DEV_NAME-policy" \
    --target $CERT_ARN \
    --region $AWS_REGION

echo ""
echo "Checking AWS IoT endpoint..."

ENDPOINT=`aws iot describe-endpoint --endpoint-type "iot:Data-ATS" --output text --query "endpointAddress"`

echo "ENDPOINT=$ENDPOINT" >> $DEV_CONFIG_FILE

echo ""
echo "Connecting to '$ENDPOINT'..."

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

wait