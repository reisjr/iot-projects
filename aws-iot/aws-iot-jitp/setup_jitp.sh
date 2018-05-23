#!/bin/bash

# Based on AWS IoT Blog
# https://aws.amazon.com/pt/blogs/iot/setting-up-just-in-time-provisioning-with-aws-iot-core/



echo "Provisioning Role required by JITP..."
ROLE_ARN=`aws iam create-role \
    --role-name JITP_Role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Sid":"","Effect":"Allow","Principal":{"Service":"iot.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --query "Role.Arn" | tr -d "\""`

aws iam attach-role-policy \
    --role-name JITP_Role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTLogging"

aws iam attach-role-policy \
    --role-name JITP_Role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTThingsRegistration"

aws iam attach-role-policy \
    --role-name JITP_Role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTRuleActions"

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

echo "Getting Account ID to create a valid provisioning template..."
ACC_ID=`aws sts get-caller-identity --output text --query 'Account'`
sed "s/<ACC_ID>/$ACC_ID/g" provisioning-template.json > provisioning-template-output.json 

echo "Registering CA certificate in AWS IoT using the provisioning template..."
CERTIFICATE_ID=`aws iot register-ca-certificate --ca-certificate file://sampleCACertificate.pem \
    --verification-certificate file://privateKeyVerification.crt --set-as-active --allow-auto-registration \
    --registration-config file://provisioning-template-output.json --query certificateId | tr -d "\""`

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
