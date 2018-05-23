# Just in Time Provisioning (JITP) for AWS IoT

These scripts implement the steps presented on https://aws.amazon.com/pt/blogs/aws/new-just-in-time-certificate-registration-for-aws-iot/

## Requirements

* openssl (tested with OpenSSL 0.9.8zh 14 Jan 2016)
* mosquitto client (brew install mosquitto)
* AWS CLI (>=1.14) 
* IAM permission to run the required commands (Create Role, Attach Policy, Register CA, etc)

## Steps

* To provisioning role, create a sample CA, register the CA in AWS IoT, and activate the CA, run:
```
./setup_jitp.sh
```
* To issue a device certificate and simulate a device connection, run:
 ```
./setup_new_device.sh
```

If you need to clean up the role, generated files (certs and keys) and permissions, just run:
```
./clean-up.sh
```
