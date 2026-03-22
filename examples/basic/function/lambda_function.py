import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    logger.info(json.dumps({"request_id": context.aws_request_id, "event": event}))
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Hello from Lambda Managed Instances",
                "request_id": context.aws_request_id,
            }
        ),
    }
