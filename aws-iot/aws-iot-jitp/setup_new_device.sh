#/bin/bash

AWS_ROOT_CA_1="https://www.amazontrust.com/repository/AmazonRootCA1.pem"
AWS_ROOT_CA_2="https://www.amazontrust.com/repository/AmazonRootCA2.pem"
AWS_ROOT_CA_3="https://www.amazontrust.com/repository/AmazonRootCA3.pem"
AWS_ROOT_CA_4="https://www.amazontrust.com/repository/AmazonRootCA4.pem"
AWS_ROOT_SYMANTEC="https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem"

CONFIG_FILE="jitr.cfg"

if [ -f "root-ca.pem" ]; then
    echo ""
    echo "WARN: ROOT CA cert exists. Ignoring download..."
    echo ""
else
    echo ""
    echo "Downloading root cert..."
    wget "$AWS_ROOT_CA_1" --quiet -O root-ca.pem
fi

openssl genrsa -out device-cert.key 2048

openssl req -new -key device-cert.key -out device-cert.csr \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=Sample Device"

openssl x509 -req -in device-cert.csr -CA sample-ca-certificate.pem \
    -CAkey sample-ca-certificate.key \
    -CAcreateserial \
    -out device-cert.crt -days 365 -sha256 \
    -extfile openssl.cnf -extensions usr_cert

cat device-cert.crt sample-ca-certificate.pem > device-certAndCACert.crt

echo "Checking AWS IoT endpoint..."

ENDPOINT=`aws iot describe-endpoint --endpoint-type "iot:Data-ATS" --output text --query "endpointAddress" | tr -d "\""`

echo "Connecting..."

mosquitto_pub \
    --cafile root-ca.pem \
    --cert device-certAndCACert.crt \
    --key device-cert.key -h $ENDPOINT -p 8883 \
    -q 1 -t  foo/bar/test -i  anyclientID \
    --tls-version tlsv1.2 -m "Hello" -d

echo "Device has disconnected to process the registration (JITR). Trying to reconnect after registration..."

for i in {1..10}; do
    sleep 3
    
    mosquitto_pub \
        --cafile root-ca.pem \
        --cert device-certAndCACert.crt \
        --key device-cert.key \
        -h $ENDPOINT -p 8883 \
        -q 1 -t foo/bar/test -i  anyclientID \
        --tls-version tlsv1.2 -m "Hello" -d    
done
