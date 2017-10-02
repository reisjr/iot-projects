import boto3
import os
import json

SQS_QUEUE_NAME = os.environ['SQS_QUEUE_NAME']
SQS_QUEUE_DELAY_SECS = int(os.environ['SQS_QUEUE_DELAY_SECS']) # Max. 900 s / 15 minutes
DDB_TABLE_DEVICE_STATUS = os.environ['DDB_TABLE_DEVICE_STATUS']

def enqueue_message(device, time, status, isNormalDisconnect):
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName=SQS_QUEUE_NAME)

    message = {
        "device" : device,
        "time" : time,
        "status" : status,
        "isNormalDisconnect" : isNormalDisconnect
    }

    return queue.send_message(MessageBody=json.dumps(message), DelaySeconds=SQS_QUEUE_DELAY_SECS)

def parseDisconnectInfo(event):
    isNormalDisconnect = "unknown"
    
    if 'isNormalDisconnect' in event:
        isNormalDisconnect = str(event['isNormalDisconnect'])

    return isNormalDisconnect

def lambda_handler(event, context):
    #print(event)
    #{'clientId': 'testasdfe', 'timestamp': 1498482143710, 'eventType': 'connected'}

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(DDB_TABLE_DEVICE_STATUS)
 
    status = event['status']
    time = str(event['time'])
    device = event['deviceId']
    isNormalDisconnect = parseDisconnectInfo(event)

    ddb_resp = table.put_item(
        Item={
                'device': device,
                'time': time,
                'status': status
            },
        ConditionExpression=':ts >= #ts_old OR attribute_not_exists(#ts_old)',
        ExpressionAttributeValues={':ts': time },
        ExpressionAttributeNames={'#ts_old': 'time'}
    )

    if ddb_resp['ResponseMetadata']['HTTPStatusCode'] != 200:
        raise Exception("Error updating status in DDB for device '{}'.".format(device)) 

    if status == "disconnected":
        r = enqueue_message(device, time, status, isNormalDisconnect)
        if "MessageId" in r:
            return "Disconnect status OK - MessageId {}.".format(r["MessageId"])
        else:
            raise Exception("Disconnect status NOK - Failure enqueuing message for device '{}'.".format(device)) 

    return "Connect status OK"