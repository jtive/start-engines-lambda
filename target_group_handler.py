"""
Target Group Management
Handles registering ECS task IPs with Application Load Balancer target groups
"""
import logging
import time
from typing import Optional
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()


class TargetGroupError(Exception):
    """Custom exception for target group operations"""
    pass


class TargetGroupHandler:
    """Handles target group registration operations"""
    
    def __init__(self, region: str = 'us-east-2'):
        """
        Initialize target group handler
        
        Args:
            region: AWS region
        """
        self.elbv2_client = boto3.client('elbv2', region_name=region)
        self.region = region
    
    def register_target(
        self,
        target_group_arn: str,
        private_ip: str,
        port: int,
        wait_for_healthy: bool = False,
        health_check_timeout: int = 60
    ) -> bool:
        """
        Register a target (IP) with a target group
        
        Args:
            target_group_arn: ARN of the target group
            private_ip: Private IP address of the ECS task
            port: Port number the container listens on
            wait_for_healthy: Whether to wait for target to become healthy
            health_check_timeout: Max time to wait for health check (seconds)
            
        Returns:
            True if registration successful
            
        Raises:
            TargetGroupError: If registration fails
        """
        logger.info(f"Registering target {private_ip}:{port} with target group {target_group_arn}")
        
        try:
            # Register the target
            response = self.elbv2_client.register_targets(
                TargetGroupArn=target_group_arn,
                Targets=[
                    {
                        'Id': private_ip,
                        'Port': port
                    }
                ]
            )
            
            logger.info(f"Successfully registered target {private_ip}:{port}")
            
            # Optionally wait for target to become healthy
            if wait_for_healthy:
                self._wait_for_target_healthy(
                    target_group_arn,
                    private_ip,
                    port,
                    timeout=health_check_timeout
                )
            
            return True
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            error_msg = e.response.get('Error', {}).get('Message', '')
            
            # Handle specific errors
            if error_code == 'TargetNotFound':
                logger.warning(f"Target group not found: {target_group_arn}")
            elif error_code == 'InvalidTarget':
                logger.warning(f"Invalid target: {private_ip}:{port}")
            
            full_error = f"Failed to register target: {error_code} - {error_msg}"
            logger.error(full_error)
            raise TargetGroupError(full_error) from e
        except Exception as e:
            error_msg = f"Unexpected error registering target: {str(e)}"
            logger.error(error_msg)
            raise TargetGroupError(error_msg) from e
    
    def deregister_target(
        self,
        target_group_arn: str,
        private_ip: str,
        port: int
    ) -> bool:
        """
        Deregister a target from a target group
        
        Args:
            target_group_arn: ARN of the target group
            private_ip: Private IP address to deregister
            port: Port number
            
        Returns:
            True if deregistration successful
        """
        logger.info(f"Deregistering target {private_ip}:{port} from target group {target_group_arn}")
        
        try:
            response = self.elbv2_client.deregister_targets(
                TargetGroupArn=target_group_arn,
                Targets=[
                    {
                        'Id': private_ip,
                        'Port': port
                    }
                ]
            )
            
            logger.info(f"Successfully deregistered target {private_ip}:{port}")
            return True
            
        except ClientError as e:
            error_msg = f"Failed to deregister target: {str(e)}"
            logger.error(error_msg)
            raise TargetGroupError(error_msg) from e
    
    def get_target_health(
        self,
        target_group_arn: str,
        private_ip: Optional[str] = None,
        port: Optional[int] = None
    ) -> dict:
        """
        Get health status of targets in a target group
        
        Args:
            target_group_arn: ARN of the target group
            private_ip: Optional - filter by specific IP
            port: Optional - filter by specific port
            
        Returns:
            Dictionary of target health information
        """
        try:
            # Build request parameters
            params = {'TargetGroupArn': target_group_arn}
            
            if private_ip and port:
                params['Targets'] = [{'Id': private_ip, 'Port': port}]
            
            response = self.elbv2_client.describe_target_health(**params)
            
            target_health = response.get('TargetHealthDescriptions', [])
            
            # If filtering by IP, return specific target
            if private_ip:
                for target in target_health:
                    target_info = target.get('Target', {})
                    if target_info.get('Id') == private_ip:
                        return {
                            'ip': private_ip,
                            'port': target_info.get('Port'),
                            'state': target.get('TargetHealth', {}).get('State'),
                            'reason': target.get('TargetHealth', {}).get('Reason'),
                            'description': target.get('TargetHealth', {}).get('Description')
                        }
                return {'ip': private_ip, 'state': 'not_found'}
            
            # Return all targets
            return {
                'targets': [
                    {
                        'ip': t.get('Target', {}).get('Id'),
                        'port': t.get('Target', {}).get('Port'),
                        'state': t.get('TargetHealth', {}).get('State'),
                        'reason': t.get('TargetHealth', {}).get('Reason')
                    }
                    for t in target_health
                ]
            }
            
        except ClientError as e:
            error_msg = f"Error getting target health: {str(e)}"
            logger.error(error_msg)
            raise TargetGroupError(error_msg) from e
    
    def _wait_for_target_healthy(
        self,
        target_group_arn: str,
        private_ip: str,
        port: int,
        timeout: int = 60,
        poll_interval: int = 5
    ) -> bool:
        """
        Wait for target to become healthy
        
        Args:
            target_group_arn: ARN of the target group
            private_ip: Private IP of the target
            port: Port number
            timeout: Maximum time to wait (seconds)
            poll_interval: Time between polls (seconds)
            
        Returns:
            True if target becomes healthy
            
        Raises:
            TargetGroupError: If target doesn't become healthy within timeout
        """
        logger.info(f"Waiting for target {private_ip}:{port} to become healthy...")
        
        start_time = time.time()
        
        while (time.time() - start_time) < timeout:
            try:
                health = self.get_target_health(target_group_arn, private_ip, port)
                state = health.get('state', 'unknown')
                
                logger.debug(f"Target {private_ip}:{port} state: {state}")
                
                if state == 'healthy':
                    logger.info(f"Target {private_ip}:{port} is healthy")
                    return True
                elif state == 'unhealthy':
                    reason = health.get('reason', 'Unknown')
                    description = health.get('description', '')
                    logger.warning(
                        f"Target {private_ip}:{port} is unhealthy. "
                        f"Reason: {reason}, Description: {description}"
                    )
                
                time.sleep(poll_interval)
                
            except Exception as e:
                logger.warning(f"Error checking target health: {str(e)}")
                time.sleep(poll_interval)
        
        # Timeout reached - log warning but don't fail
        # Target may still become healthy after Lambda completes
        logger.warning(
            f"Timeout waiting for target {private_ip}:{port} to become healthy "
            f"after {timeout}s. Target may still be initializing."
        )
        return False
    
    def list_targets(self, target_group_arn: str) -> list:
        """
        List all targets in a target group
        
        Args:
            target_group_arn: ARN of the target group
            
        Returns:
            List of target dictionaries
        """
        try:
            health = self.get_target_health(target_group_arn)
            return health.get('targets', [])
        except Exception as e:
            logger.error(f"Error listing targets: {str(e)}")
            return []
    
    def get_target_group_attributes(self, target_group_arn: str) -> dict:
        """
        Get attributes of a target group
        
        Args:
            target_group_arn: ARN of the target group
            
        Returns:
            Dictionary of target group attributes
        """
        try:
            response = self.elbv2_client.describe_target_group_attributes(
                TargetGroupArn=target_group_arn
            )
            
            attributes = response.get('Attributes', [])
            return {attr['Key']: attr['Value'] for attr in attributes}
            
        except ClientError as e:
            logger.error(f"Error getting target group attributes: {str(e)}")
            return {}

