"""Unit tests for configuration module"""
import pytest
import os
from unittest.mock import patch
from config import get_service_config, get_all_service_names, SERVICE_MAPPINGS


class TestConfig:
    """Test cases for configuration"""
    
    def test_get_all_service_names(self):
        """Test getting all service names"""
        services = get_all_service_names()
        
        assert 'auth' in services
        assert 'pdf' in services
        assert 'fa' in services
        assert 'users' in services
        assert 'batch' in services
        assert len(services) == 5
    
    @patch.dict(os.environ, {
        'SUBNETS': 'subnet-123,subnet-456',
        'SECURITY_GROUPS': 'sg-789'
    })
    def test_get_service_config_auth(self):
        """Test getting auth service config"""
        config = get_service_config('auth')
        
        assert config['cluster'] == 'auth-cluster'
        assert config['container_name'] == 'authapi-container'
        assert config['container_port'] == 8080
        assert 'auth-lb' in config['target_group_arn']
        assert config['subnets'] == ['subnet-123', 'subnet-456']
        assert config['security_groups'] == ['sg-789']
    
    @patch.dict(os.environ, {
        'SUBNETS': 'subnet-123',
        'SECURITY_GROUPS': 'sg-789'
    })
    def test_get_service_config_pdf(self):
        """Test getting PDF service config"""
        config = get_service_config('pdf')
        
        assert config['cluster'] == 'pdf-cluster'
        assert config['container_port'] == 9080
        assert 'pdf-lb' in config['target_group_arn']
    
    @patch.dict(os.environ, {
        'SUBNETS': 'subnet-123',
        'SECURITY_GROUPS': 'sg-789'
    })
    def test_get_service_config_fa(self):
        """Test getting FA service config"""
        config = get_service_config('fa')
        
        assert config['cluster'] == 'fa-cluster'
        assert config['container_port'] == 2531
        assert 'fa2-tg' in config['target_group_arn']
    
    @patch.dict(os.environ, {
        'SUBNETS': 'subnet-123',
        'SECURITY_GROUPS': 'sg-789',
        'USERS_TARGET_GROUP_ARN': 'arn:aws:elasticloadbalancing:us-east-2:123:targetgroup/users-tg/xyz'
    })
    def test_get_service_config_users(self):
        """Test getting users service config"""
        config = get_service_config('users')
        
        assert config['cluster'] == 'users-cluster'
        assert config['container_port'] == 8080
        assert 'users-tg' in config['target_group_arn']
    
    def test_get_service_config_invalid_service(self):
        """Test error with invalid service name"""
        with pytest.raises(ValueError, match="Unknown service"):
            get_service_config('invalid-service')
    
    def test_get_service_config_case_insensitive(self):
        """Test service name is case insensitive"""
        with patch.dict(os.environ, {'SUBNETS': 'subnet-123', 'SECURITY_GROUPS': 'sg-789'}):
            config1 = get_service_config('AUTH')
            config2 = get_service_config('auth')
            config3 = get_service_config('Auth')
            
            assert config1 == config2 == config3
    
    @patch.dict(os.environ, {
        'AUTH_CLUSTER': 'custom-auth-cluster',
        'AUTH_TASK_DEF': 'custom-auth-task',
        'SUBNETS': 'subnet-123',
        'SECURITY_GROUPS': 'sg-789'
    })
    def test_environment_overrides(self):
        """Test environment variable overrides"""
        config = get_service_config('auth')
        
        assert config['cluster'] == 'custom-auth-cluster'
        assert config['task_definition'] == 'custom-auth-task'
    
    def test_missing_target_group_arn(self):
        """Test error when target group ARN is missing"""
        # Temporarily modify the mapping
        original_arn = SERVICE_MAPPINGS['batch']['target_group_arn']
        SERVICE_MAPPINGS['batch']['target_group_arn'] = ''
        
        try:
            with pytest.raises(ValueError, match="Target group ARN not configured"):
                get_service_config('batch')
        finally:
            # Restore original value
            SERVICE_MAPPINGS['batch']['target_group_arn'] = original_arn
    
    def test_missing_subnets(self):
        """Test error when subnets are missing"""
        with pytest.raises(ValueError, match="Subnets not configured"):
            get_service_config('auth')
    
    @patch.dict(os.environ, {'SUBNETS': 'subnet-123'})
    def test_missing_security_groups(self):
        """Test error when security groups are missing"""
        with pytest.raises(ValueError, match="Security groups not configured"):
            get_service_config('auth')

