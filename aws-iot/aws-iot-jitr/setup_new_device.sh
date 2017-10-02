#/bin/bash

openssl genrsa -out deviceCert.key 2048

openssl req -new -key deviceCert.key -out deviceCert.csr \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AWS IOT Test/CN=Sample Device"

openssl x509 -req -in deviceCert.csr -CA sampleCACertificate.pem \
    -CAkey sampleCACertificate.key \
    -CAcreateserial \
    -out deviceCert.crt -days 365 -sha256

cat deviceCert.crt sampleCACertificate.pem > deviceCertAndCACert.crt

echo "Downloading root cert..."

wget "https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem" -O rootCA.pem

echo "Checking AWS IoT endpoint..."

ENDPOINT=`aws iot describe-endpoint --query "endpointAddress" | tr -d "\""`

echo "Connecting..."

mosquitto_pub \
    --cafile rootCA.pem \
    --cert deviceCertAndCACert.crt \
    --key deviceCert.key -h $ENDPOINT -p 8883 \
    -q 1 -t  foo/bar/test -i  anyclientID \
    --tls-version tlsv1.2 -m "Hello" -d

echo "Device as disonnected to process the registration (JITR). Trying to reconnect now registered..."

for i in {1..10}; do
    sleep 3
    
    mosquitto_pub \
        --cafile rootCA.pem \
        --cert deviceCertAndCACert.crt \
        --key deviceCert.key \
        -h $ENDPOINT -p 8883 \
        -q 1 -t  foo/bar/test -i  anyclientID \
        --tls-version tlsv1.2 -m "Hello" -d    
done