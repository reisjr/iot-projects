#/bin/bash

aws iam detach-role-policy \
    --role-name JITP_Role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTLogging"

aws iam detach-role-policy \
    --role-name JITP_Role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTThingsRegistration"

aws iam detach-role-policy \
    --role-name JITP_Role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTRuleActions"

aws iam delete-role \
    --role-name "JITP_Role"

rm *.key
rm *.crt
rm *.pem
rm *.srl
rm *.csr
rm provisioning-template-output.json