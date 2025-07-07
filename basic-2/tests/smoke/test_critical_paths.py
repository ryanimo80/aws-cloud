"""
Smoke tests for critical application paths
These tests verify core functionality after deployment
"""

import pytest
import requests
import os
import json
from typing import Dict, Any

# Test configuration
BASE_URL = os.getenv('BASE_URL', 'http://localhost')
ENVIRONMENT = os.getenv('ENVIRONMENT', 'staging')
TIMEOUT = 30


class TestCriticalPaths:
    """Critical path smoke tests"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'Smoke-Test/{ENVIRONMENT}'
        }
        
    @pytest.mark.critical
    def test_application_is_accessible(self):
        """Test that the application is accessible"""
        url = f"{self.base_url}/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        # Should be accessible (200) or redirect (3xx)
        assert response.status_code < 500, f"Application not accessible: {response.status_code}"
        
    @pytest.mark.critical
    def test_all_services_are_healthy(self):
        """Test that all services report healthy status"""
        health_endpoints = [
            '/health/',
            '/users/health/',
            '/products/health/',
            '/orders/health/',
            '/notifications/health/'
        ]
        
        for endpoint in health_endpoints:
            url = f"{self.base_url}{endpoint}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            assert response.status_code == 200, f"Health check failed for {endpoint}"
            
            data = response.json()
            assert data.get('status') == 'healthy', f"Service {endpoint} is not healthy: {data}"
            
    @pytest.mark.critical
    def test_database_connectivity(self):
        """Test database connectivity through health endpoints"""
        url = f"{self.base_url}/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        
        # Check if database info is available
        if 'database' in data:
            assert data['database'].get('status') == 'healthy', "Database is not healthy"
        elif 'status' in data:
            # If no detailed database info, overall status should be healthy
            assert data['status'] == 'healthy', "Overall health check failed"
            
    @pytest.mark.critical
    def test_cache_connectivity(self):
        """Test cache (Redis) connectivity"""
        url = f"{self.base_url}/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        
        # Check if Redis info is available
        if 'redis' in data:
            assert data['redis'].get('status') == 'healthy', "Redis is not healthy"
        elif 'cache' in data:
            assert data['cache'].get('status') == 'healthy', "Cache is not healthy"


class TestAPIEndpoints:
    """Test critical API endpoints"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'Smoke-Test/{ENVIRONMENT}'
        }
        
    @pytest.mark.critical
    def test_user_service_endpoints(self):
        """Test User Service critical endpoints"""
        # Test user list endpoint (should be accessible even if requires auth)
        url = f"{self.base_url}/api/users/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        # Should return 200 (data), 401 (auth required), or 403 (forbidden)
        # But not 500 (server error) or 404 (not found)
        assert response.status_code in [200, 401, 403], f"User service error: {response.status_code}"
        
    @pytest.mark.critical
    def test_product_service_endpoints(self):
        """Test Product Service critical endpoints"""
        url = f"{self.base_url}/api/products/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code in [200, 401, 403], f"Product service error: {response.status_code}"
        
    @pytest.mark.critical
    def test_order_service_endpoints(self):
        """Test Order Service critical endpoints"""
        url = f"{self.base_url}/api/orders/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code in [200, 401, 403], f"Order service error: {response.status_code}"
        
    @pytest.mark.critical
    def test_notification_service_endpoints(self):
        """Test Notification Service critical endpoints"""
        url = f"{self.base_url}/api/notifications/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code in [200, 401, 403], f"Notification service error: {response.status_code}"


class TestLoadBalancerAndRouting:
    """Test load balancer and routing functionality"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'Smoke-Test/{ENVIRONMENT}'
        }
        
    @pytest.mark.critical
    def test_load_balancer_routing(self):
        """Test that load balancer routes requests correctly"""
        routes = [
            ('/', 'API Gateway'),
            ('/users/', 'User Service'),
            ('/products/', 'Product Service'),
            ('/orders/', 'Order Service'),
            ('/notifications/', 'Notification Service')
        ]
        
        for route, service_name in routes:
            url = f"{self.base_url}{route}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            # Should not return 502 (bad gateway) or 503 (service unavailable)
            assert response.status_code not in [502, 503], f"{service_name} routing failed: {response.status_code}"
            
    @pytest.mark.critical
    def test_health_check_routing(self):
        """Test that health check endpoints are routed correctly"""
        health_routes = [
            '/health/',
            '/users/health/',
            '/products/health/',
            '/orders/health/',
            '/notifications/health/'
        ]
        
        for route in health_routes:
            url = f"{self.base_url}{route}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            assert response.status_code == 200, f"Health check routing failed for {route}"


class TestSecurity:
    """Test security configurations"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'Smoke-Test/{ENVIRONMENT}'
        }
        
    @pytest.mark.critical
    def test_security_headers_present(self):
        """Test that critical security headers are present"""
        url = f"{self.base_url}/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        
        # Check for critical security headers
        if ENVIRONMENT == 'production':
            critical_headers = [
                'X-Content-Type-Options',
                'X-Frame-Options'
            ]
            
            for header in critical_headers:
                assert header in response.headers, f"Critical security header {header} is missing"
                
    @pytest.mark.critical
    def test_no_debug_info_exposed(self):
        """Test that debug information is not exposed in production"""
        if ENVIRONMENT == 'production':
            # Try to access a non-existent endpoint
            url = f"{self.base_url}/non-existent-endpoint/"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            # Should return 404, not expose debug information
            assert response.status_code == 404
            
            # Response should not contain debug information
            response_text = response.text.lower()
            debug_indicators = ['traceback', 'debug', 'django', 'error details']
            
            for indicator in debug_indicators:
                assert indicator not in response_text, f"Debug information exposed: {indicator}"


class TestPerformance:
    """Basic performance smoke tests"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'Smoke-Test/{ENVIRONMENT}'
        }
        
    @pytest.mark.critical
    def test_response_time_acceptable(self):
        """Test that response times are acceptable"""
        import time
        
        endpoints = [
            '/health/',
            '/users/health/',
            '/products/health/',
            '/orders/health/',
            '/notifications/health/'
        ]
        
        for endpoint in endpoints:
            url = f"{self.base_url}{endpoint}"
            
            start_time = time.time()
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            end_time = time.time()
            
            response_time = end_time - start_time
            
            # Health checks should respond within 5 seconds
            assert response_time < 5.0, f"Response time too slow for {endpoint}: {response_time:.2f}s"
            assert response.status_code == 200, f"Health check failed for {endpoint}"


class TestDataConsistency:
    """Test data consistency across services"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'Smoke-Test/{ENVIRONMENT}'
        }
        
    @pytest.mark.critical
    def test_service_versions_consistent(self):
        """Test that all services report consistent version information"""
        health_endpoints = [
            '/health/',
            '/users/health/',
            '/products/health/',
            '/orders/health/',
            '/notifications/health/'
        ]
        
        versions = {}
        
        for endpoint in health_endpoints:
            url = f"{self.base_url}{endpoint}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            if response.status_code == 200:
                data = response.json()
                if 'version' in data:
                    versions[endpoint] = data['version']
                    
        # If version information is available, it should be consistent
        # (This depends on how version information is implemented)
        if versions:
            version_values = list(versions.values())
            # All versions should be the same for a coordinated deployment
            if len(set(version_values)) > 1:
                pytest.warning(f"Inconsistent versions detected: {versions}")


if __name__ == '__main__':
    # Run only critical tests
    pytest.main([__file__, '-v', '-m', 'critical']) 