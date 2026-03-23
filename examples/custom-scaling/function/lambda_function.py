import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def lambda_handler(event, context):
    logger.debug(json.dumps({"request_id": context.aws_request_id, "event": event}))
    logger.info(
        json.dumps(
            {
                "request_id": context.aws_request_id,
                "env": os.environ.get("ENV", "unknown"),
                "memory_limit_mb": context.memory_limit_in_mb,
            }
        )
    )
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Hello from Lambda Managed Instances (custom scaling)",
                "request_id": context.aws_request_id,
                "env": os.environ.get("ENV", "unknown"),
            }
        ),
    }
