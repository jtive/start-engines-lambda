"""
ECS Task Starter Lambda
Main handler for starting ECS tasks and registering them with target groups
Triggered by EventBridge events
"""
import json
import logging
import os
from typing import Dict, Any

from config import get_service_config, get_all_service_names, LOG_LEVEL, AWS_REGION
from ecs_handler import ECSHandler, ECSTaskError
from target_group_handler import TargetGroupHandler, TargetGroupError

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL))


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for EventBridge events
    
    Expected event format:
    {
        "source": "custom.app",
        "detail-type": "Start ECS Task",
        "detail": {
            "service": "auth|pdf|fa|users|batch",
            
            # Optional overrides (if not provided, uses config.py defaults)
            "cluster": "optional-cluster-override",
            "taskDefinition": "optional-task-def-override",
            "targetGroupArn": "optional-tg-arn-override",
            "subnets": ["subnet-xxx"],
            "securityGroups": ["sg-xxx"],
            "port": 8080,
            "waitForHealthy": false
        }
    }
    
    Args:
        event: EventBridge event
        context: Lambda context
        
    Returns:
        Response dictionary with status and details
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse event
        detail = event.get('detail', {})
        
        if not detail:
            return error_response(
                "Invalid event format: missing 'detail' field",
                status_code=400
            )
        
        # Get service name
        service_name = detail.get('service', '').lower()
        
        if not service_name:
            return error_response(
                "Missing required field: 'service'. "
                f"Valid services: {', '.join(get_all_service_names())}",
                status_code=400
            )
        
        # Get service configuration (with optional overrides from event)
        try:
            config = get_service_config(service_name)
        except ValueError as e:
            return error_response(str(e), status_code=400)
        
        # Apply overrides from event if provided
        cluster = detail.get('cluster', config['cluster'])
        task_definition = detail.get('taskDefinition', config['task_definition'])
        target_group_arn = detail.get('targetGroupArn', config['target_group_arn'])
        subnets = detail.get('subnets', config['subnets'])
        security_groups = detail.get('securityGroups', config['security_groups'])
        container_name = detail.get('containerName', config['container_name'])
        container_port = detail.get('port', config['container_port'])
        wait_for_healthy = detail.get('waitForHealthy', False)
        
        # Validate required fields
        if not target_group_arn:
            return error_response(
                f"Target group ARN not configured for service: {service_name}",
                status_code=400
            )
        
        if not subnets:
            return error_response(
                f"Subnets not configured for service: {service_name}",
                status_code=400
            )
        
        if not security_groups:
            return error_response(
                f"Security groups not configured for service: {service_name}",
                status_code=400
            )
        
        logger.info(
            f"Starting task for service '{service_name}': "
            f"cluster={cluster}, task_def={task_definition}, "
            f"port={container_port}"
        )
        
        # Initialize handlers
        ecs_handler = ECSHandler(region=AWS_REGION)
        tg_handler = TargetGroupHandler(region=AWS_REGION)
        
        # Step 1: Start ECS task
        logger.info("Step 1: Starting ECS task...")
        task_arn, private_ip = ecs_handler.start_task(
            cluster=cluster,
            task_definition=task_definition,
            subnets=subnets,
            security_groups=security_groups,
            container_name=container_name,
            container_port=container_port
        )
        
        task_id = task_arn.split('/')[-1]
        logger.info(f"Task started successfully: {task_id} with IP {private_ip}")
        
        # Step 2: Register with target group
        logger.info("Step 2: Registering task with target group...")
        tg_handler.register_target(
            target_group_arn=target_group_arn,
            private_ip=private_ip,
            port=container_port,
            wait_for_healthy=wait_for_healthy
        )
        
        logger.info(f"Task registered with target group successfully")
        
        # Get final target health status
        health_status = tg_handler.get_target_health(
            target_group_arn,
            private_ip,
            container_port
        )
        
        # Success response
        response = {
            'statusCode': 200,
            'body': {
                'message': f'Successfully started and registered {service_name} task',
                'service': service_name,
                'taskArn': task_arn,
                'taskId': task_id,
                'privateIp': private_ip,
                'port': container_port,
                'targetGroupArn': target_group_arn,
                'healthStatus': health_status
            }
        }
        
        logger.info(f"Success: {json.dumps(response)}")
        return response
        
    except ECSTaskError as e:
        logger.error(f"ECS task error: {str(e)}")
        return error_response(f"ECS task error: {str(e)}", status_code=500)
    
    except TargetGroupError as e:
        logger.error(f"Target group error: {str(e)}")
        return error_response(f"Target group error: {str(e)}", status_code=500)
    
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return error_response(f"Unexpected error: {str(e)}", status_code=500)


def error_response(message: str, status_code: int = 500) -> Dict[str, Any]:
    """
    Create error response
    
    Args:
        message: Error message
        status_code: HTTP status code
        
    Returns:
        Error response dictionary
    """
    return {
        'statusCode': status_code,
        'body': {
            'error': message
        }
    }


# For local testing
if __name__ == "__main__":
    # Example test event
    test_event = {
        "source": "custom.app",
        "detail-type": "Start ECS Task",
        "detail": {
            "service": "auth"
        }
    }
    
    # Mock context
    class MockContext:
        function_name = "test-function"
        memory_limit_in_mb = 128
        invoked_function_arn = "arn:aws:lambda:us-east-2:123456789012:function:test-function"
        aws_request_id = "test-request-id"
    
    result = lambda_handler(test_event, MockContext())
    print(json.dumps(result, indent=2))

