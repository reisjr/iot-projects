#/bin/bash

aws iot delete-topic-rule \
    --rule-name "JITR_Sample_Rule"

aws lambda delete-function \
    --function-name "JITR_Register_Device"

aws iam delete-role-policy \
    --role-name "JITR_Lambda_Role" \
    --policy-name "JITR_Policy"

aws iam delete-role \
    --role-name "JITR_Lambda_Role"

