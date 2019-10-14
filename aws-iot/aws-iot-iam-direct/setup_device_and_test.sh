#!/bin/bash

aws iot create-thing \
    --thing-name        

CERT_ARN=`aws iot create-keys-and-certificate \
    --set-as-active \
    --certificate-pem-outfile my-device.pem \
    --public-key-outfile my-device-pub.key \
    --private-key-outfile my-device-priv.key \
    --query "certificateArn" --output text`

aws iot attach-thing-principal \
    --thing-name MyAuthDirectIoTDevice \
    --principal $CERT_ARN

aws iot create-policy \
    --policy-name SampleDeviceIoTPolicy \
    --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":{\"Effect\":\"Allow\",\"Action\":\"iot:AssumeRoleWithCertificate\",\"Resource\":\"arn:aws:iot:*:*:rolealias/\${iot:Connection.Thing.ThingName}-S3AccessRoleAlias\",\"Condition\":{\"Bool\":{\"iot:Connection.Thing.IsAttached\":\"true\"}}}}"

aws iot attach-policy \
    --policy-name SampleDeviceIoTPolicy \
    --target $CERT_ARN

CRED_ENDPOINT=`aws iot describe-endpoint \
    --endpoint-type iot:CredentialProvider \
    --output text --query endpointAddress`

openssl pkcs12 -export -out device_cert.pfx -inkey my-device-priv.key -in my-device.pem -passout pass:changeit

CREDENTIALS=`curl --cert device_cert.pfx \
    --key device_cert.pfx \
    --pass "changeit" \
    -H "x-amzn-iot-thingname: MyAuthDirectIoTDevice" \
    https://$CRED_ENDPOINT/role-aliases/S3AccessRoleAlias/credentials`


export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_SESSION_TOKEN=""

