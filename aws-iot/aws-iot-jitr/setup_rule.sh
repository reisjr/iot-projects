#!/bin/bash -e

# Based on AWS IoT Blog
# https://aws.amazon.com/pt/blogs/iot/just-in-time-registration-of-device-certificates-on-aws-iot/

PACKAGE="deviceActivation.zip"

SCRIPT=`basename "$0"`

if [ $# -lt 2 ]
  then
    echo "No arguments supplied"
    echo "./$SCRIPT bucket-to-upload-lambda-function certificate-id"
    echo "Ex: ./$SCRIPT my-bucket 3902784092380948320982309840392"
    exit
fi

BUCKET=$1
CERTIFICATE_ID=$2

echo "Provisioning Role required in Lambda..."

ROLE_ARN=`aws iam create-role \
    --role-name JITR_Lambda_Role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Sid":"","Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --query "Role.Arn" | tr -d "\""`

aws iam put-role-policy \
          --role-name JITR_Lambda_Role \
          --policy-name JITR_Policy \
          --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:*:*:*"},{"Effect":"Allow","Action":["iot:UpdateCertificate","iot:CreatePolicy","iot:AttachPrincipalPolicy"],"Resource":"*"}]}'

echo "Packaging Lambda function..."

zip $PACKAGE deviceActivation.js

aws s3 cp deviceActivation.zip s3://$BUCKET/

# Let permission sync

echo "Lambda Role $ROLE_ARN"

FUNCTION_ARN=`aws lambda create-function \
    --function-name JITR_Register_Device \
    --runtime "nodejs4.3" \
    --role "$ROLE_ARN" \
    --handler "deviceActivation.handler" \
    --timeout 60 \
    --code "S3Bucket=$BUCKET,S3Key=$PACKAGE" \
    --query "FunctionArn" | tr -d "\""`

for i in {1..5}; do 
    echo "Function ARN $FUNCTION_ARN"
    
    if [ -n "$FUNCTION_ARN" ]; then
        break
    fi
    
    sleep 3

    FUNCTION_ARN=`aws lambda create-function \
        --function-name JITR_Register_Device \
        --runtime "nodejs4.3" \
        --role "$ROLE_ARN" \
        --handler "deviceActivation.handler" \
        --timeout 60 \
        --code "S3Bucket=$BUCKET,S3Key=$PACKAGE" \
        --query "FunctionArn" | tr -d "\""`
done

echo "Creating AWS IoT Rule..."

aws iot create-topic-rule \
    --rule-name "JITR_Sample_Rule" \
    --topic-rule-payload "{\"sql\":\"SELECT * FROM '\$aws/events/certificates/registered/$CERTIFICATE_ID'\",\"description\":\"JITR sample rule.\",\"actions\":[{\"lambda\":{\"functionArn\":\"$FUNCTION_ARN\"}}]}"

#TOPIC_ARN=`aws iot list-topic-rules \
#   --topic "\$aws/events/certificates/registered/$CERTIFICATE_ID" --query "rules[0].ruleArn" | tr -d "\""`

for i in {1..5}; do  
    TOPIC_ARN=`aws iot list-topic-rules \
        --topic '\$aws/events/certificates/registered/'$CERTIFICATE_ID \
        --query "rules[0].ruleArn" | tr -d "\""`

    if [ -n "$TOPIC_ARN" ]; then
        break
    fi
    
    sleep 3
done

echo "Getting account number..."

ACC_NUMBER=`aws sts get-caller-identity --output text --query 'Account'`

echo "Adding permission to lambda function..."

aws lambda add-permission \
    --function-name "JITR_Register_Device" \
    --region us-east-1 \
    --principal iot.amazonaws.com \
    --source-arn "$TOPIC_ARN" \
    --source-account "$ACC_NUMBER" \
    --statement-id "Id-123456" \
    --action "lambda:InvokeFunction"

echo "DONE!"

echo -e "\n#########\n"
echo "       Your CA cert : sampleCACertificate.pem"
echo "Your Certificate ID : $CERTIFICATE_ID"

echo -e "\n#########\n"