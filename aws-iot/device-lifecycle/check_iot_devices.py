import boto3
import os
import json
import datetime

TIMEOUT_THRESHOLD = 40000 # Setup a maximum loop processing time to avoid finishing the function in middle due to lambda timeout
SQS_QUEUE_NAME = os.environ['SQS_QUEUE_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
DDB_TABLE_DEVICE_STATUS = os.environ['DDB_TABLE_DEVICE_STATUS']
DDB_TABLE_DEVICE_EVENTS = os.environ['DDB_TABLE_DEVICE_EVENTS']

# This function notifies the email address specified in the tempate creation
# It could be more functions, such as notifying an internal system through HTTP endpoint
# or getting the device owner contact info from a DDB table before sending the message.

def notify_device_owner(device, record):

    s = float(record['Item']['time'])/1000.0
    time = datetime.datetime.fromtimestamp(s).strftime('%Y-%m-%d %H:%M:%S')
    text = 'The device {} is offline since {}.'.format(device, time)
    
    sns_client = boto3.client('sns')

    response = sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,    
        Message=text
    )

    return text

# This function stores the notification event with date in a separate table, creating 
# a history of events

def save_event(device, text):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(DDB_TABLE_DEVICE_EVENTS)

    table.put_item(
        Item={
                'device': device,
                'time': datetime.datetime.now().isoformat(),
                'desc': text
            }
    )

def get_device_status(payload):
    device = payload['device']
    time = payload['time']
    
    #search device status in dynamodb
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(DDB_TABLE_DEVICE_STATUS)

    record = table.get_item(
        Key={
            'device': device,
        }
    )

    return record
    
def lambda_handler(event, context):
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName=SQS_QUEUE_NAME)

    msgs_processed = 0 

    while context.get_remaining_time_in_millis() > TIMEOUT_THRESHOLD: # finish the function before lambda timeout
        
        messages = queue.receive_messages(WaitTimeSeconds=5)
        
        for message in messages:
            payload = json.loads(message.body)

            device = payload['device']

            print("Processing {} ...".format(device))
            
            record = get_device_status(payload)

            if 'Item' not in record:
                print("Device {} not found in table {}.".format(device, DDB_TABLE_DEVICE_STATUS))
            elif record['Item']['status'] == 'disconnected': # can consider also if the connection was normal or not
                last_status_ts = int(record['Item']['time'])
                event_ts = int(payload['time'])
                
                if last_status_ts <= event_ts: # check if there was a more recent event
                    text = notify_device_owner(device, record)
                    save_event(device, text)
                
            message.delete()
            msgs_processed += 1
    
    return "Messages processed {}".format(msgs_processed)
