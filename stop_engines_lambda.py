"""
Stop All ECS Tasks Lambda
Stops all running tasks in configured ECS clusters and optionally deregisters from target groups
"""
import json
import logging
from typing import Dict, Any, List
import boto3
from botocore.exceptions import ClientError

from config import get_all_service_names, get_service_config, AWS_REGION, LOG_LEVEL

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL))


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler to stop all ECS tasks
    
    Event format:
    {
        "source": "custom.app",
        "detail-type": "Stop ECS Tasks",
        "detail": {
            "services": ["auth", "pdf", "fa"],  # Optional: specific services, or empty for all
            "deregister_targets": true           # Optional: deregister from target groups (default: true)
        }
    }
    
    Or trigger without detail to stop all services
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse event
        detail = event.get('detail', {})
        
        # Get list of services to stop (default: all)
        services_to_stop = detail.get('services', get_all_service_names())
        deregister_targets = detail.get('deregister_targets', True)
        
        if not services_to_stop:
            services_to_stop = get_all_service_names()
        
        logger.info(f"Stopping tasks for services: {services_to_stop}")
        
        # Initialize AWS clients
        ecs_client = boto3.client('ecs', region_name=AWS_REGION)
        elbv2_client = boto3.client('elbv2', region_name=AWS_REGION)
        
        results = []
        total_stopped = 0
        
        # Process each service
        for service_name in services_to_stop:
            try:
                logger.info(f"Processing service: {service_name}")
                
                # Get service configuration
                try:
                    config = get_service_config(service_name)
                except ValueError as e:
                    logger.warning(f"Skipping unknown service: {service_name}")
                    results.append({
                        'service': service_name,
                        'status': 'skipped',
                        'reason': str(e)
                    })
                    continue
                
                cluster = config['cluster']
                target_group_arn = config['target_group_arn']
                container_port = config['container_port']
                
                # List all running tasks in the cluster
                list_response = ecs_client.list_tasks(
                    cluster=cluster,
                    desiredStatus='RUNNING'
                )
                
                task_arns = list_response.get('taskArns', [])
                
                if not task_arns:
                    logger.info(f"No running tasks found for {service_name} in cluster {cluster}")
                    results.append({
                        'service': service_name,
                        'cluster': cluster,
                        'tasks_stopped': 0,
                        'status': 'no_tasks'
                    })
                    continue
                
                logger.info(f"Found {len(task_arns)} running tasks for {service_name}")
                
                # Get task details to extract IPs (for deregistration)
                task_ips = []
                if deregister_targets:
                    describe_response = ecs_client.describe_tasks(
                        cluster=cluster,
                        tasks=task_arns
                    )
                    
                    for task in describe_response.get('tasks', []):
                        ip = extract_private_ip(task)
                        if ip:
                            task_ips.append(ip)
                
                # Stop all tasks
                stopped_tasks = []
                for task_arn in task_arns:
                    try:
                        ecs_client.stop_task(
                            cluster=cluster,
                            task=task_arn,
                            reason='Stopped by stop-engines-lambda'
                        )
                        stopped_tasks.append(task_arn.split('/')[-1])
                        total_stopped += 1
                        logger.info(f"Stopped task: {task_arn.split('/')[-1]}")
                    except ClientError as e:
                        logger.error(f"Error stopping task {task_arn}: {str(e)}")
                
                # Deregister from target group
                deregistered_count = 0
                if deregister_targets and task_ips:
                    try:
                        targets = [
                            {'Id': ip, 'Port': container_port}
                            for ip in task_ips
                        ]
                        
                        elbv2_client.deregister_targets(
                            TargetGroupArn=target_group_arn,
                            Targets=targets
                        )
                        deregistered_count = len(task_ips)
                        logger.info(f"Deregistered {deregistered_count} targets from {target_group_arn}")
                    except ClientError as e:
                        logger.warning(f"Error deregistering targets: {str(e)}")
                
                results.append({
                    'service': service_name,
                    'cluster': cluster,
                    'tasks_stopped': len(stopped_tasks),
                    'targets_deregistered': deregistered_count,
                    'task_ids': stopped_tasks,
                    'status': 'success'
                })
                
            except Exception as e:
                logger.error(f"Error processing service {service_name}: {str(e)}")
                results.append({
                    'service': service_name,
                    'status': 'error',
                    'error': str(e)
                })
        
        # Success response
        response = {
            'statusCode': 200,
            'body': {
                'message': f'Successfully stopped {total_stopped} tasks across {len(services_to_stop)} services',
                'total_tasks_stopped': total_stopped,
                'services_processed': len(services_to_stop),
                'results': results
            }
        }
        
        logger.info(f"Completed: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': {
                'error': f"Unexpected error: {str(e)}"
            }
        }


def extract_private_ip(task: Dict) -> str:
    """
    Extract private IP from task details (awsvpc mode)
    
    Args:
        task: Task description from describe_tasks
        
    Returns:
        Private IP address or None
    """
    # For awsvpc network mode
    attachments = task.get('attachments', [])
    
    for attachment in attachments:
        if attachment.get('type') == 'ElasticNetworkInterface':
            details = attachment.get('details', [])
            for detail in details:
                if detail.get('name') == 'privateIPv4Address':
                    return detail.get('value')
    
    # Alternative: check containers
    containers = task.get('containers', [])
    for container in containers:
        network_interfaces = container.get('networkInterfaces', [])
        if network_interfaces:
            return network_interfaces[0].get('privateIpv4Address')
    
    return None


# For local testing
if __name__ == "__main__":
    # Test event
    test_event = {
        "source": "custom.app",
        "detail-type": "Stop ECS Tasks",
        "detail": {
            "services": ["auth", "pdf"],
            "deregister_targets": True
        }
    }
    
    class MockContext:
        function_name = "test-function"
        memory_limit_in_mb = 128
        invoked_function_arn = "arn:aws:lambda:us-east-2:123456789012:function:test-function"
        aws_request_id = "test-request-id"
    
    result = lambda_handler(test_event, MockContext())
    print(json.dumps(result, indent=2))

