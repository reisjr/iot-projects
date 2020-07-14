#/bin/bash

AWS_ROOT_CA_1="https://www.amazontrust.com/repository/G2-RootCA1.pem"
AWS_ROOT_CA_2="https://www.amazontrust.com/repository/G2-RootCA2.pem"
AWS_ROOT_CA_3="https://www.amazontrust.com/repository/G2-RootCA3.pem"
AWS_ROOT_CA_4="https://www.amazontrust.com/repository/G2-RootCA4.pem"
AWS_ROOT_SYMANTEC="https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem"

CA_PREFIX="sample-ca-certificate"
CA_KEY="$CA_PREFIX.key"
CA_PEM="$CA_PREFIX.pem"

DEV_ID="$RANDOM"
DEV_CERT_NAME="device-cert-$DEV_ID.pem"
DEV_CSR_NAME="device-cert-$DEV_ID.csr"
DEV_KEY_NAME="device-cert-$DEV_ID.key"

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

echo ""
echo "Checking AWS IoT endpoint..."

ENDPOINT=`aws iot describe-endpoint --endpoint-type "iot:Data-ATS" --output text --query "endpointAddress"`

echo ""
echo "Connecting to '$ENDPOINT'..."

mosquitto_pub \
    --cafile root-ca.pem \
    --cert device-cert-and-ca-cert.crt \
    --key "$DEV_KEY_NAME" -h $ENDPOINT -p 8883 \
    -q 1 -t foo/bar/test -i anyclientID \
    --tls-version tlsv1.2 -m "Hello" -d

echo ""
echo "Registering certificate without CA..."

CERT_ID=`aws iot register-certificate-without-ca \
    --status ACTIVE \
    --certificate-pem file://"$DEV_CERT_NAME" \
    --query "certificateId" --output text`

# Attach thing
# Attach policy

sleep 3

mosquitto_pub \
    --cafile root-ca.pem \
    --cert device-cert-and-ca-cert.crt \
    --key "$DEV_KEY_NAME" -h $ENDPOINT -p 8883 \
    -q 1 -t "foo/bar/test" -i anyclientID \
    --tls-version tlsv1.2 -m "Hello" -d

echo ""
echo "Deactivating certificate $CERT_ID..."

aws iot update-certificate \
    --certificate-id "$CERT_ID" \
    --new-status "INACTIVE"

echo ""
echo "Removing certificate $CERT_ID..."

aws iot delete-certificate \
    --certificate-id "$CERT_ID"