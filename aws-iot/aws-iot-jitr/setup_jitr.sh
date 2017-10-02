#!/bin/bash

# Based on AWS IoT Blog
# https://aws.amazon.com/pt/blogs/iot/just-in-time-registration-of-device-certificates-on-aws-iot/

echo "Creating a sample CA..."

openssl genrsa -out sampleCACertificate.key 2048
openssl req -x509 -new -nodes -key sampleCACertificate.key -sha256 -days 365 -out sampleCACertificate.pem \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=Sample Root CA"

echo "Getting registration code from AWS IoT..."
REG_CODE=`aws iot get-registration-code --query "registrationCode" | tr -d "\""`

echo "Generating CSR to prove that you own the CA..."
openssl genrsa -out privateKeyVerification.key 2048
openssl req -new -key privateKeyVerification.key -out privateKeyVerification.csr \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=$REG_CODE"

echo "Issuing certificate to complete the proof..."
openssl x509 -req -in privateKeyVerification.csr -CA sampleCACertificate.pem -CAkey sampleCACertificate.key -CAcreateserial -out privateKeyVerification.crt -days 365 -sha256

echo "Registering CA certificate in AWS IoT..."
CERTIFICATE_ID=`aws iot register-ca-certificate --ca-certificate file://sampleCACertificate.pem --verification-certificate file://privateKeyVerification.crt --query certificateId | tr -d "\""`

aws iot describe-ca-certificate --certificate-id $CERTIFICATE_ID

echo "Activate CA..."
aws iot update-ca-certificate --certificate-id $CERTIFICATE_ID --new-status ACTIVE

echo "Activating auto registration for CA $CERTIFICATE_ID..."
aws iot update-ca-certificate --certificate-id $CERTIFICATE_ID --new-auto-registration-status ENABLE

echo "DONE!"

echo -e "\n#########\n"
echo "       Your CA cert : sampleCACertificate.pem"
echo "Your Certificate ID : $CERTIFICATE_ID"
echo -e "\n#########\n"
