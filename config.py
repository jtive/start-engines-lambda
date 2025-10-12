"""
Configuration for ECS Task Starter Lambda
Maps service names to their ECS clusters, task definitions, and target groups
"""
import os
from typing import Dict, TypedDict


class ServiceConfig(TypedDict):
    """Type definition for service configuration"""
    cluster: str
    task_definition: str
    target_group_arn: str
    container_name: str
    container_port: int
    subnets: list[str]
    security_groups: list[str]


# AWS Configuration
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-2')
AWS_ACCOUNT_ID = os.environ.get('AWS_ACCOUNT_ID', '486151888818')

# Default ECS Configuration (can be overridden per service)
DEFAULT_SUBNETS = os.environ.get('SUBNETS', '').split(',') if os.environ.get('SUBNETS') else []
DEFAULT_SECURITY_GROUPS = os.environ.get('SECURITY_GROUPS', '').split(',') if os.environ.get('SECURITY_GROUPS') else []

# Service to ECS/Target Group Mappings
# Based on your existing services: AuthAPI, PDFCreator, FaEngine, UserManagement, BatchEngineCall
SERVICE_MAPPINGS: Dict[str, ServiceConfig] = {
    'auth': {
        'cluster': os.environ.get('AUTH_CLUSTER', 'authapi-cluster'),
        'task_definition': os.environ.get('AUTH_TASK_DEF', 'authapi-task-def'),
        'target_group_arn': os.environ.get('AUTH_TARGET_GROUP_ARN', f"arn:aws:elasticloadbalancing:{AWS_REGION}:{AWS_ACCOUNT_ID}:targetgroup/unified-auth-tg/cecaa72dcd652062"),
        'container_name': 'authapi-container',
        'container_port': 8080,
        'subnets': os.environ.get('AUTH_SUBNETS', '').split(',') if os.environ.get('AUTH_SUBNETS') else DEFAULT_SUBNETS,
        'security_groups': os.environ.get('AUTH_SECURITY_GROUPS', '').split(',') if os.environ.get('AUTH_SECURITY_GROUPS') else DEFAULT_SECURITY_GROUPS,
    },
    'pdf': {
        'cluster': os.environ.get('PDF_CLUSTER', 'pdfcreator-cluster'),
        'task_definition': os.environ.get('PDF_TASK_DEF', 'pdfcreator-task-def'),
        'target_group_arn': os.environ.get('PDF_TARGET_GROUP_ARN', f"arn:aws:elasticloadbalancing:{AWS_REGION}:{AWS_ACCOUNT_ID}:targetgroup/unified-pdf-tg/c608c00789aa70a9"),
        'container_name': 'pdfcreator-container',
        'container_port': 9080,
        'subnets': os.environ.get('PDF_SUBNETS', '').split(',') if os.environ.get('PDF_SUBNETS') else DEFAULT_SUBNETS,
        'security_groups': os.environ.get('PDF_SECURITY_GROUPS', '').split(',') if os.environ.get('PDF_SECURITY_GROUPS') else DEFAULT_SECURITY_GROUPS,
    },
    'fa': {
        'cluster': os.environ.get('FA_CLUSTER', 'fa-engine-cluster'),
        'task_definition': os.environ.get('FA_TASK_DEF', 'fa-engine-task-def'),
        'target_group_arn': os.environ.get('FA_TARGET_GROUP_ARN', f"arn:aws:elasticloadbalancing:{AWS_REGION}:{AWS_ACCOUNT_ID}:targetgroup/unified-fa-tg/c1c35818b5273bfc"),
        'container_name': 'faengine-container',
        'container_port': 2531,
        'subnets': os.environ.get('FA_SUBNETS', '').split(',') if os.environ.get('FA_SUBNETS') else DEFAULT_SUBNETS,
        'security_groups': os.environ.get('FA_SECURITY_GROUPS', '').split(',') if os.environ.get('FA_SECURITY_GROUPS') else DEFAULT_SECURITY_GROUPS,
    },
    'users': {
        'cluster': os.environ.get('USERS_CLUSTER', 'user-management-cluster'),
        'task_definition': os.environ.get('USERS_TASK_DEF', 'user-management-task-def'),
        'target_group_arn': os.environ.get('USERS_TARGET_GROUP_ARN', f"arn:aws:elasticloadbalancing:{AWS_REGION}:{AWS_ACCOUNT_ID}:targetgroup/users-tg/f9a22b2edc13281f"),
        'container_name': 'usermanagement-container',
        'container_port': 8080,
        'subnets': os.environ.get('USERS_SUBNETS', '').split(',') if os.environ.get('USERS_SUBNETS') else DEFAULT_SUBNETS,
        'security_groups': os.environ.get('USERS_SECURITY_GROUPS', '').split(',') if os.environ.get('USERS_SECURITY_GROUPS') else DEFAULT_SECURITY_GROUPS,
    },
    'batch': {
        'cluster': os.environ.get('BATCH_CLUSTER', 'batch-engine'),
        'task_definition': os.environ.get('BATCH_TASK_DEF', 'batch-engine-task-def'),
        'target_group_arn': os.environ.get('BATCH_TARGET_GROUP_ARN', f"arn:aws:elasticloadbalancing:{AWS_REGION}:{AWS_ACCOUNT_ID}:targetgroup/batch-tg/4016a351002f823f"),
        'container_name': 'batchengine-container',
        'container_port': 8080,
        'subnets': os.environ.get('BATCH_SUBNETS', '').split(',') if os.environ.get('BATCH_SUBNETS') else DEFAULT_SUBNETS,
        'security_groups': os.environ.get('BATCH_SECURITY_GROUPS', '').split(',') if os.environ.get('BATCH_SECURITY_GROUPS') else DEFAULT_SECURITY_GROUPS,
    }
}

# Lambda Configuration
TASK_WAIT_TIMEOUT = int(os.environ.get('TASK_WAIT_TIMEOUT', '300'))  # 5 minutes
TASK_POLL_INTERVAL = int(os.environ.get('TASK_POLL_INTERVAL', '5'))  # 5 seconds
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

# ECS Task Launch Type (FARGATE or EC2)
LAUNCH_TYPE = os.environ.get('LAUNCH_TYPE', 'FARGATE')

# Network Configuration
# For FARGATE, use awsvpc network mode
# assign_public_ip: ENABLED if tasks need internet access (for pulling images, etc.)
ASSIGN_PUBLIC_IP = os.environ.get('ASSIGN_PUBLIC_IP', 'ENABLED')


def get_service_config(service_name: str) -> ServiceConfig:
    """
    Get configuration for a specific service
    
    Args:
        service_name: Name of the service (auth, pdf, fa, users, batch)
        
    Returns:
        ServiceConfig dictionary
        
    Raises:
        ValueError: If service name is not found
    """
    service_name = service_name.lower()
    if service_name not in SERVICE_MAPPINGS:
        raise ValueError(
            f"Unknown service: {service_name}. "
            f"Valid services: {', '.join(SERVICE_MAPPINGS.keys())}"
        )
    
    config = SERVICE_MAPPINGS[service_name]
    
    # Validate required fields
    if not config['target_group_arn']:
        raise ValueError(f"Target group ARN not configured for service: {service_name}")
    
    if not config['subnets']:
        raise ValueError(f"Subnets not configured for service: {service_name}")
    
    if not config['security_groups']:
        raise ValueError(f"Security groups not configured for service: {service_name}")
    
    return config


def get_all_service_names() -> list[str]:
    """Get list of all configured service names"""
    return list(SERVICE_MAPPINGS.keys())

