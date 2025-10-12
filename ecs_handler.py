"""
ECS Task Management
Handles starting ECS tasks and waiting for them to reach RUNNING state
"""
import time
import logging
from typing import Dict, List, Optional, Tuple
import boto3
from botocore.exceptions import ClientError

from config import TASK_WAIT_TIMEOUT, TASK_POLL_INTERVAL, LAUNCH_TYPE, ASSIGN_PUBLIC_IP

logger = logging.getLogger()


class ECSTaskError(Exception):
    """Custom exception for ECS task operations"""
    pass


class ECSHandler:
    """Handles ECS task operations"""
    
    def __init__(self, region: str = 'us-east-2'):
        """
        Initialize ECS handler
        
        Args:
            region: AWS region
        """
        self.ecs_client = boto3.client('ecs', region_name=region)
        self.ec2_client = boto3.client('ec2', region_name=region)
        self.region = region
    
    def start_task(
        self,
        cluster: str,
        task_definition: str,
        subnets: List[str],
        security_groups: List[str],
        container_name: str,
        container_port: int,
    ) -> Tuple[str, str]:
        """
        Start an ECS task and wait for it to reach RUNNING state
        
        Args:
            cluster: ECS cluster name
            task_definition: Task definition family:revision or ARN
            subnets: List of subnet IDs
            security_groups: List of security group IDs
            container_name: Name of the container in the task definition
            container_port: Port the container listens on
            
        Returns:
            Tuple of (task_arn, private_ip_address)
            
        Raises:
            ECSTaskError: If task fails to start or reach RUNNING state
        """
        logger.info(f"Starting ECS task: cluster={cluster}, task_def={task_definition}")
        
        try:
            # Start the task
            response = self.ecs_client.run_task(
                cluster=cluster,
                taskDefinition=task_definition,
                launchType=LAUNCH_TYPE,
                count=1,
                networkConfiguration={
                    'awsvpcConfiguration': {
                        'subnets': subnets,
                        'securityGroups': security_groups,
                        'assignPublicIp': ASSIGN_PUBLIC_IP
                    }
                }
            )
            
            # Check for failures
            if response.get('failures'):
                failures = response['failures']
                error_msg = f"Failed to start task: {failures}"
                logger.error(error_msg)
                raise ECSTaskError(error_msg)
            
            # Get task ARN
            tasks = response.get('tasks', [])
            if not tasks:
                raise ECSTaskError("No tasks started")
            
            task = tasks[0]
            task_arn = task['taskArn']
            task_id = task_arn.split('/')[-1]
            
            logger.info(f"Task started: {task_id}")
            
            # Wait for task to reach RUNNING state
            private_ip = self._wait_for_task_running(cluster, task_arn, container_name)
            
            logger.info(f"Task {task_id} is RUNNING with IP {private_ip}")
            
            return task_arn, private_ip
            
        except ClientError as e:
            error_msg = f"AWS API error starting task: {str(e)}"
            logger.error(error_msg)
            raise ECSTaskError(error_msg) from e
        except Exception as e:
            error_msg = f"Unexpected error starting task: {str(e)}"
            logger.error(error_msg)
            raise ECSTaskError(error_msg) from e
    
    def _wait_for_task_running(
        self,
        cluster: str,
        task_arn: str,
        container_name: str,
        timeout: int = TASK_WAIT_TIMEOUT,
        poll_interval: int = TASK_POLL_INTERVAL
    ) -> str:
        """
        Wait for task to reach RUNNING state and extract private IP
        
        Args:
            cluster: ECS cluster name
            task_arn: Task ARN
            container_name: Container name
            timeout: Maximum time to wait in seconds
            poll_interval: Time between polls in seconds
            
        Returns:
            Private IP address of the task
            
        Raises:
            ECSTaskError: If task fails to reach RUNNING state within timeout
        """
        task_id = task_arn.split('/')[-1]
        start_time = time.time()
        
        logger.info(f"Waiting for task {task_id} to reach RUNNING state...")
        
        while (time.time() - start_time) < timeout:
            try:
                # Describe the task
                response = self.ecs_client.describe_tasks(
                    cluster=cluster,
                    tasks=[task_arn]
                )
                
                tasks = response.get('tasks', [])
                if not tasks:
                    raise ECSTaskError(f"Task {task_id} not found")
                
                task = tasks[0]
                last_status = task.get('lastStatus', '')
                desired_status = task.get('desiredStatus', '')
                
                logger.debug(f"Task {task_id} status: lastStatus={last_status}, desiredStatus={desired_status}")
                
                # Check if task stopped
                if last_status == 'STOPPED':
                    stop_reason = task.get('stoppedReason', 'Unknown')
                    containers = task.get('containers', [])
                    container_reasons = [
                        f"{c.get('name')}: {c.get('reason', 'N/A')}"
                        for c in containers if c.get('reason')
                    ]
                    error_msg = f"Task {task_id} stopped. Reason: {stop_reason}. Container reasons: {container_reasons}"
                    logger.error(error_msg)
                    raise ECSTaskError(error_msg)
                
                # Check if task is running
                if last_status == 'RUNNING':
                    # Extract private IP from network interface
                    private_ip = self._extract_private_ip(task)
                    if private_ip:
                        return private_ip
                    else:
                        logger.warning(f"Task {task_id} is RUNNING but IP not yet available")
                
                # Wait before next poll
                time.sleep(poll_interval)
                
            except ClientError as e:
                logger.error(f"Error describing task: {str(e)}")
                raise ECSTaskError(f"Error checking task status: {str(e)}") from e
        
        # Timeout reached
        raise ECSTaskError(f"Timeout waiting for task {task_id} to reach RUNNING state after {timeout}s")
    
    def _extract_private_ip(self, task: Dict) -> Optional[str]:
        """
        Extract private IP address from task details (awsvpc mode)
        
        Args:
            task: Task description from describe_tasks
            
        Returns:
            Private IP address or None if not found
        """
        # For awsvpc network mode, the task has network interfaces attached
        attachments = task.get('attachments', [])
        
        for attachment in attachments:
            if attachment.get('type') == 'ElasticNetworkInterface':
                details = attachment.get('details', [])
                for detail in details:
                    if detail.get('name') == 'privateIPv4Address':
                        return detail.get('value')
        
        # Alternative: check containers for network bindings (for bridge/host mode)
        containers = task.get('containers', [])
        for container in containers:
            network_interfaces = container.get('networkInterfaces', [])
            if network_interfaces:
                return network_interfaces[0].get('privateIpv4Address')
        
        return None
    
    def get_task_details(self, cluster: str, task_arn: str) -> Dict:
        """
        Get detailed information about a task
        
        Args:
            cluster: ECS cluster name
            task_arn: Task ARN
            
        Returns:
            Task details dictionary
        """
        try:
            response = self.ecs_client.describe_tasks(
                cluster=cluster,
                tasks=[task_arn]
            )
            
            tasks = response.get('tasks', [])
            if not tasks:
                raise ECSTaskError(f"Task not found: {task_arn}")
            
            return tasks[0]
            
        except ClientError as e:
            logger.error(f"Error getting task details: {str(e)}")
            raise ECSTaskError(f"Error getting task details: {str(e)}") from e
    
    def stop_task(self, cluster: str, task_arn: str, reason: str = "Stopped by Lambda") -> None:
        """
        Stop an ECS task
        
        Args:
            cluster: ECS cluster name
            task_arn: Task ARN
            reason: Reason for stopping
        """
        try:
            self.ecs_client.stop_task(
                cluster=cluster,
                task=task_arn,
                reason=reason
            )
            logger.info(f"Stopped task {task_arn}")
        except ClientError as e:
            logger.error(f"Error stopping task: {str(e)}")
            raise ECSTaskError(f"Error stopping task: {str(e)}") from e

