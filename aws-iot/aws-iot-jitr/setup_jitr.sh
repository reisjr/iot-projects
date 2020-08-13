#!/bin/bash -e

# Based on AWS IoT Blog
# https://aws.amazon.com/pt/blogs/iot/just-in-time-registration-of-device-certificates-on-aws-iot/

# Link to openssl config - https://access.redhat.com/solutions/28965

CONFIG_FILE="jitr.cfg"

echo "Creating a sample CA..."

openssl genrsa -out sample-ca-certificate.key 2048
openssl req -x509 -new -nodes -key sample-ca-certificate.key -sha256 -days 365 -out sample-ca-certificate.pem \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=Sample Root CA" \
    -config openssl.cnf -extensions v3_req

echo "OPENSSL_FILE=openssl.cnf" > $CONFIG_FILE
echo "AWS_REGION=$AWS_REGION" >> $CONFIG_FILE
echo "AWS_PROFILE=$AWS_PROFILE" >> $CONFIG_FILE

echo "Getting registration code from AWS IoT..."
REG_CODE=`aws iot get-registration-code --query "registrationCode" | tr -d "\""`

echo "REG_CODE=$REG_CODE" >> $CONFIG_FILE

echo "Generating CSR to prove that you own the CA..."
openssl genrsa -out private-key-verification.key 2048
openssl req -new -key private-key-verification.key -out private-key-verification.csr \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=$REG_CODE" \
    -config openssl.cnf -extensions v3_req

echo "Issuing certificate to complete the proof..."
openssl x509 -req -in private-key-verification.csr -CA sample-ca-certificate.pem -CAkey sample-ca-certificate.key \
    -CAcreateserial -out private-key-verification.crt \
    -days 365 -sha256 -extfile openssl.cnf -extensions usr_cert

echo "Registering CA certificate in AWS IoT..."
CERTIFICATE_ID=`aws iot register-ca-certificate --ca-certificate file://sample-ca-certificate.pem --verification-certificate file://private-key-verification.crt --query certificateId | tr -d "\""`

echo "CERTIFICATE_ID=$CERTIFICATE_ID" >> $CONFIG_FILE

aws iot describe-ca-certificate --certificate-id $CERTIFICATE_ID

echo "Activate CA..."
aws iot update-ca-certificate --certificate-id $CERTIFICATE_ID --new-status ACTIVE

echo "Activating auto registration for CA $CERTIFICATE_ID..."
aws iot update-ca-certificate --certificate-id $CERTIFICATE_ID --new-auto-registration-status ENABLE

echo "DONE!"

echo -e "\n#########\n"
echo "       Your CA cert : sample-ca-certificate.pem"
echo "Your Certificate ID : $CERTIFICATE_ID"
echo -e "\n#########\n"
