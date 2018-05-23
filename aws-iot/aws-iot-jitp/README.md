# Just in Time Provisioning (JITP) for AWS IoT

These scripts implement the steps presented on https://aws.amazon.com/pt/blogs/aws/new-just-in-time-certificate-registration-for-aws-iot/

Just run setup_jitp.sh and setup_new_device.sh to create the certificates required (CA and EE), role, permissions, and simulate a device connecting to AWS IoT.

If you need to clean up the role, generated files (certs and keys) and permissions, just run clean-up.sh.
