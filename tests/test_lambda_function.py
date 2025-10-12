"""Unit tests for Lambda handler"""
import json
import pytest
from unittest.mock import Mock, patch, MagicMock
from lambda_function import lambda_handler, error_response


class TestLambdaHandler:
    """Test cases for Lambda handler"""
    
    @pytest.fixture
    def mock_context(self):
        """Mock Lambda context"""
        context = Mock()
        context.function_name = "test-function"
        context.memory_limit_in_mb = 128
        context.invoked_function_arn = "arn:aws:lambda:us-east-2:123456789012:function:test"
        context.aws_request_id = "test-request-id"
        return context
    
    @pytest.fixture
    def valid_event(self):
        """Valid EventBridge event"""
        return {
            "source": "custom.app",
            "detail-type": "Start ECS Task",
            "detail": {
                "service": "auth"
            }
        }
    
    @patch('lambda_function.ECSHandler')
    @patch('lambda_function.TargetGroupHandler')
    @patch('lambda_function.get_service_config')
    def test_successful_task_start(
        self,
        mock_get_config,
        mock_tg_handler_class,
        mock_ecs_handler_class,
        valid_event,
        mock_context
    ):
        """Test successful task start and registration"""
        # Mock configuration
        mock_get_config.return_value = {
            'cluster': 'test-cluster',
            'task_definition': 'test-task',
            'target_group_arn': 'arn:aws:elasticloadbalancing:us-east-2:123:targetgroup/test/abc',
            'container_name': 'test-container',
            'container_port': 8080,
            'subnets': ['subnet-123'],
            'security_groups': ['sg-123']
        }
        
        # Mock ECS handler
        mock_ecs_handler = MagicMock()
        mock_ecs_handler.start_task.return_value = (
            'arn:aws:ecs:us-east-2:123:task/cluster/task-id',
            '10.0.1.100'
        )
        mock_ecs_handler_class.return_value = mock_ecs_handler
        
        # Mock target group handler
        mock_tg_handler = MagicMock()
        mock_tg_handler.register_target.return_value = True
        mock_tg_handler.get_target_health.return_value = {
            'ip': '10.0.1.100',
            'port': 8080,
            'state': 'healthy'
        }
        mock_tg_handler_class.return_value = mock_tg_handler
        
        # Execute
        response = lambda_handler(valid_event, mock_context)
        
        # Assert
        assert response['statusCode'] == 200
        assert 'taskArn' in response['body']
        assert response['body']['privateIp'] == '10.0.1.100'
        assert response['body']['service'] == 'auth'
        
        # Verify handlers were called
        mock_ecs_handler.start_task.assert_called_once()
        mock_tg_handler.register_target.assert_called_once()
    
    def test_missing_detail_field(self, mock_context):
        """Test error when detail field is missing"""
        event = {
            "source": "custom.app",
            "detail-type": "Start ECS Task"
        }
        
        response = lambda_handler(event, mock_context)
        
        assert response['statusCode'] == 400
        assert 'error' in response['body']
    
    def test_missing_service_name(self, mock_context):
        """Test error when service name is missing"""
        event = {
            "source": "custom.app",
            "detail-type": "Start ECS Task",
            "detail": {}
        }
        
        response = lambda_handler(event, mock_context)
        
        assert response['statusCode'] == 400
        assert 'service' in response['body']['error'].lower()
    
    @patch('lambda_function.get_service_config')
    def test_invalid_service_name(self, mock_get_config, valid_event, mock_context):
        """Test error with invalid service name"""
        valid_event['detail']['service'] = 'invalid-service'
        mock_get_config.side_effect = ValueError("Unknown service")
        
        response = lambda_handler(valid_event, mock_context)
        
        assert response['statusCode'] == 400
        assert 'Unknown service' in response['body']['error']
    
    @patch('lambda_function.ECSHandler')
    @patch('lambda_function.get_service_config')
    def test_ecs_task_error(
        self,
        mock_get_config,
        mock_ecs_handler_class,
        valid_event,
        mock_context
    ):
        """Test handling of ECS task errors"""
        from ecs_handler import ECSTaskError
        
        mock_get_config.return_value = {
            'cluster': 'test-cluster',
            'task_definition': 'test-task',
            'target_group_arn': 'arn:aws:elasticloadbalancing:us-east-2:123:targetgroup/test/abc',
            'container_name': 'test-container',
            'container_port': 8080,
            'subnets': ['subnet-123'],
            'security_groups': ['sg-123']
        }
        
        mock_ecs_handler = MagicMock()
        mock_ecs_handler.start_task.side_effect = ECSTaskError("Task failed to start")
        mock_ecs_handler_class.return_value = mock_ecs_handler
        
        response = lambda_handler(valid_event, mock_context)
        
        assert response['statusCode'] == 500
        assert 'ECS task error' in response['body']['error']
    
    def test_error_response_helper(self):
        """Test error response helper function"""
        response = error_response("Test error", 400)
        
        assert response['statusCode'] == 400
        assert response['body']['error'] == "Test error"
    
    @patch('lambda_function.ECSHandler')
    @patch('lambda_function.TargetGroupHandler')
    @patch('lambda_function.get_service_config')
    def test_event_overrides(
        self,
        mock_get_config,
        mock_tg_handler_class,
        mock_ecs_handler_class,
        valid_event,
        mock_context
    ):
        """Test that event overrides are applied"""
        # Add overrides to event
        valid_event['detail']['cluster'] = 'override-cluster'
        valid_event['detail']['port'] = 9090
        
        mock_get_config.return_value = {
            'cluster': 'default-cluster',
            'task_definition': 'test-task',
            'target_group_arn': 'arn:aws:elasticloadbalancing:us-east-2:123:targetgroup/test/abc',
            'container_name': 'test-container',
            'container_port': 8080,
            'subnets': ['subnet-123'],
            'security_groups': ['sg-123']
        }
        
        mock_ecs_handler = MagicMock()
        mock_ecs_handler.start_task.return_value = ('task-arn', '10.0.1.100')
        mock_ecs_handler_class.return_value = mock_ecs_handler
        
        mock_tg_handler = MagicMock()
        mock_tg_handler.register_target.return_value = True
        mock_tg_handler.get_target_health.return_value = {'state': 'healthy'}
        mock_tg_handler_class.return_value = mock_tg_handler
        
        response = lambda_handler(valid_event, mock_context)
        
        # Verify override was used
        call_args = mock_ecs_handler.start_task.call_args
        assert call_args.kwargs['cluster'] == 'override-cluster'
        assert call_args.kwargs['container_port'] == 9090

