"""
Integration tests for Django microservices
These tests verify the interaction between different services
"""

import pytest
import requests
import os
import time
from typing import Dict, Any

# Test configuration
BASE_URL = os.getenv('BASE_URL', 'http://localhost')
TIMEOUT = 30


class TestAPIIntegration:
    """Integration tests for API endpoints"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Integration-Test/1.0'
        }
        
    def test_api_gateway_health(self):
        """Test API Gateway health endpoint"""
        url = f"{self.base_url}/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        assert data.get('status') == 'healthy'
        assert 'timestamp' in data
        
    def test_user_service_health(self):
        """Test User Service health endpoint"""
        url = f"{self.base_url}/users/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        assert data.get('status') == 'healthy'
        assert data.get('service') == 'user-service'
        
    def test_product_service_health(self):
        """Test Product Service health endpoint"""
        url = f"{self.base_url}/products/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        assert data.get('status') == 'healthy'
        assert data.get('service') == 'product-service'
        
    def test_order_service_health(self):
        """Test Order Service health endpoint"""
        url = f"{self.base_url}/orders/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        assert data.get('status') == 'healthy'
        assert data.get('service') == 'order-service'
        
    def test_notification_service_health(self):
        """Test Notification Service health endpoint"""
        url = f"{self.base_url}/notifications/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        data = response.json()
        assert data.get('status') == 'healthy'
        assert data.get('service') == 'notification-service'


class TestServiceCommunication:
    """Test communication between services"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Integration-Test/1.0'
        }
        
    def test_api_gateway_to_user_service(self):
        """Test API Gateway can communicate with User Service"""
        # This would test actual API calls through the gateway
        # For now, we'll test that the gateway can reach user endpoints
        url = f"{self.base_url}/api/users/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        # Expect either 200 (with data) or 401 (authentication required)
        # Both indicate the service is reachable
        assert response.status_code in [200, 401, 404]
        
    def test_api_gateway_to_product_service(self):
        """Test API Gateway can communicate with Product Service"""
        url = f"{self.base_url}/api/products/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code in [200, 401, 404]
        
    def test_api_gateway_to_order_service(self):
        """Test API Gateway can communicate with Order Service"""
        url = f"{self.base_url}/api/orders/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code in [200, 401, 404]
        
    def test_api_gateway_to_notification_service(self):
        """Test API Gateway can communicate with Notification Service"""
        url = f"{self.base_url}/api/notifications/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code in [200, 401, 404]


class TestLoadBalancer:
    """Test Load Balancer functionality"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Integration-Test/1.0'
        }
        
    def test_load_balancer_health(self):
        """Test that load balancer is working"""
        # Test multiple requests to ensure load balancing is working
        responses = []
        
        for i in range(5):
            try:
                url = f"{self.base_url}/health/"
                response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
                responses.append(response.status_code)
                time.sleep(0.5)  # Small delay between requests
            except requests.RequestException:
                responses.append(0)
                
        # At least 80% of requests should be successful
        successful_requests = sum(1 for code in responses if code == 200)
        success_rate = successful_requests / len(responses)
        
        assert success_rate >= 0.8, f"Success rate {success_rate} is below 80%"
        
    def test_service_discovery(self):
        """Test that services can be discovered through load balancer"""
        services = [
            ('users', '/users/health/'),
            ('products', '/products/health/'),
            ('orders', '/orders/health/'),
            ('notifications', '/notifications/health/')
        ]
        
        for service_name, endpoint in services:
            url = f"{self.base_url}{endpoint}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            assert response.status_code == 200, f"{service_name} service not reachable"
            
            data = response.json()
            assert data.get('status') == 'healthy', f"{service_name} service not healthy"


class TestDatabaseConnectivity:
    """Test database connectivity through services"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Integration-Test/1.0'
        }
        
    def test_database_health_check(self):
        """Test database connectivity through health endpoints"""
        services = [
            '/health/',
            '/users/health/',
            '/products/health/',
            '/orders/health/',
            '/notifications/health/'
        ]
        
        for endpoint in services:
            url = f"{self.base_url}{endpoint}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            assert response.status_code == 200
            
            data = response.json()
            # Check if database status is included in health check
            if 'database' in data:
                assert data['database'].get('status') == 'healthy'


class TestRedisConnectivity:
    """Test Redis connectivity through services"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Integration-Test/1.0'
        }
        
    def test_redis_health_check(self):
        """Test Redis connectivity through health endpoints"""
        services = [
            '/health/',
            '/users/health/',
            '/products/health/',
            '/orders/health/',
            '/notifications/health/'
        ]
        
        for endpoint in services:
            url = f"{self.base_url}{endpoint}"
            response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
            
            assert response.status_code == 200
            
            data = response.json()
            # Check if Redis status is included in health check
            if 'redis' in data:
                assert data['redis'].get('status') == 'healthy'


class TestSecurity:
    """Test security configurations"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.base_url = BASE_URL.rstrip('/')
        self.headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Integration-Test/1.0'
        }
        
    def test_security_headers(self):
        """Test that security headers are present"""
        url = f"{self.base_url}/health/"
        response = requests.get(url, headers=self.headers, timeout=TIMEOUT)
        
        assert response.status_code == 200
        
        # Check for important security headers
        security_headers = [
            'X-Content-Type-Options',
            'X-Frame-Options',
            'X-XSS-Protection'
        ]
        
        for header in security_headers:
            assert header in response.headers, f"Security header {header} is missing"
            
    def test_cors_configuration(self):
        """Test CORS configuration"""
        url = f"{self.base_url}/health/"
        
        # Test preflight request
        response = requests.options(
            url, 
            headers={
                'Origin': 'http://localhost:3000',
                'Access-Control-Request-Method': 'GET',
                'Access-Control-Request-Headers': 'Content-Type'
            },
            timeout=TIMEOUT
        )
        
        # Should allow the request or return appropriate CORS headers
        assert response.status_code in [200, 204]


if __name__ == '__main__':
    pytest.main([__file__, '-v']) 