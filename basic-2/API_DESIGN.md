# API Design - Django Microservices

## 🎯 Overview

Tài liệu này mô tả thiết kế API cho Django microservices architecture, bao gồm các endpoints, request/response formats, và communication patterns giữa các services.

## 🏗️ API Architecture

### Service Communication
```
Client → API Gateway → Microservices
       ↓
   Authentication & Authorization
   Rate Limiting
   Request Routing
   Response Aggregation
```

### Base URL Structure
```
https://api.yourdomain.com/v1/
├── auth/          # Authentication endpoints
├── users/         # User management
├── products/      # Product catalog
├── orders/        # Order processing
└── notifications/ # Notification system
```

## 🔐 Authentication & Authorization

### JWT Token Authentication
```http
POST /auth/login/
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

### Token Refresh
```http
POST /auth/refresh/
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Authorization Header
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## 👥 User Service API

### User Registration
```http
POST /users/register/
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890",
  "is_verified": false,
  "created_at": "2024-01-01T10:00:00Z"
}
```

### User Profile
```http
GET /users/profile/
Authorization: Bearer <token>
```

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890",
  "profile": {
    "avatar": "https://example.com/avatar.jpg",
    "bio": "Software developer",
    "location": "San Francisco, CA",
    "website": "https://johndoe.com"
  },
  "settings": {
    "email_notifications": true,
    "push_notifications": true,
    "theme": "light",
    "language": "en"
  }
}
```

### Update Profile
```http
PUT /users/profile/
Content-Type: application/json
Authorization: Bearer <token>

{
  "first_name": "John",
  "last_name": "Doe",
  "profile": {
    "bio": "Full-stack developer",
    "location": "New York, NY"
  }
}
```

### User List (Admin)
```http
GET /users/?page=1&limit=20&search=john
Authorization: Bearer <admin_token>
```

**Response:**
```json
{
  "count": 150,
  "next": "https://api.yourdomain.com/v1/users/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "is_active": true,
      "created_at": "2024-01-01T10:00:00Z"
    }
  ]
}
```

## 📦 Product Service API

### Product List
```http
GET /products/?page=1&limit=20&category=electronics&search=laptop
```

**Response:**
```json
{
  "count": 250,
  "next": "https://api.yourdomain.com/v1/products/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "MacBook Pro 16-inch",
      "slug": "macbook-pro-16-inch",
      "description": "Powerful laptop for professionals",
      "price": "2499.00",
      "category": {
        "id": 1,
        "name": "Electronics",
        "slug": "electronics"
      },
      "images": [
        {
          "id": 1,
          "url": "https://example.com/product1.jpg",
          "alt": "MacBook Pro front view"
        }
      ],
      "inventory": {
        "stock": 50,
        "is_available": true
      },
      "created_at": "2024-01-01T10:00:00Z"
    }
  ]
}
```

### Product Detail
```http
GET /products/1/
```

**Response:**
```json
{
  "id": 1,
  "name": "MacBook Pro 16-inch",
  "slug": "macbook-pro-16-inch",
  "description": "Powerful laptop for professionals",
  "price": "2499.00",
  "category": {
    "id": 1,
    "name": "Electronics",
    "slug": "electronics"
  },
  "images": [
    {
      "id": 1,
      "url": "https://example.com/product1.jpg",
      "alt": "MacBook Pro front view"
    }
  ],
  "specifications": {
    "processor": "Apple M2 Pro",
    "memory": "16GB",
    "storage": "512GB SSD"
  },
  "inventory": {
    "stock": 50,
    "is_available": true
  },
  "reviews": {
    "count": 25,
    "average_rating": 4.5
  },
  "created_at": "2024-01-01T10:00:00Z"
}
```

### Create Product (Admin)
```http
POST /products/
Content-Type: application/json
Authorization: Bearer <admin_token>

{
  "name": "iPad Pro 12.9-inch",
  "description": "Professional tablet",
  "price": "1099.00",
  "category_id": 1,
  "specifications": {
    "processor": "Apple M2",
    "memory": "8GB",
    "storage": "256GB"
  },
  "inventory": {
    "stock": 100
  }
}
```

### Product Categories
```http
GET /products/categories/
```

**Response:**
```json
{
  "results": [
    {
      "id": 1,
      "name": "Electronics",
      "slug": "electronics",
      "parent": null,
      "children": [
        {
          "id": 2,
          "name": "Laptops",
          "slug": "laptops"
        }
      ]
    }
  ]
}
```

## 🛒 Order Service API

### Create Order
```http
POST /orders/
Content-Type: application/json
Authorization: Bearer <token>

{
  "items": [
    {
      "product_id": 1,
      "quantity": 2,
      "price": "2499.00"
    }
  ],
  "shipping_address": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "zip_code": "94105",
    "country": "US"
  },
  "payment_method": "credit_card"
}
```

**Response:**
```json
{
  "id": 1,
  "order_number": "ORD-2024-001",
  "status": "pending",
  "total_amount": "4998.00",
  "items": [
    {
      "id": 1,
      "product": {
        "id": 1,
        "name": "MacBook Pro 16-inch",
        "price": "2499.00"
      },
      "quantity": 2,
      "unit_price": "2499.00",
      "total_price": "4998.00"
    }
  ],
  "shipping_address": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "zip_code": "94105",
    "country": "US"
  },
  "created_at": "2024-01-01T10:00:00Z"
}
```

### Order List
```http
GET /orders/?page=1&limit=10&status=pending
Authorization: Bearer <token>
```

**Response:**
```json
{
  "count": 15,
  "next": "https://api.yourdomain.com/v1/orders/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "order_number": "ORD-2024-001",
      "status": "pending",
      "total_amount": "4998.00",
      "created_at": "2024-01-01T10:00:00Z"
    }
  ]
}
```

### Order Detail
```http
GET /orders/1/
Authorization: Bearer <token>
```

### Update Order Status
```http
PATCH /orders/1/status/
Content-Type: application/json
Authorization: Bearer <admin_token>

{
  "status": "shipped",
  "tracking_number": "1Z999AA1234567890"
}
```

### Payment Processing
```http
POST /orders/1/payment/
Content-Type: application/json
Authorization: Bearer <token>

{
  "payment_method": "credit_card",
  "card_token": "tok_visa_debit",
  "amount": "4998.00"
}
```

## 🔔 Notification Service API

### Send Notification
```http
POST /notifications/
Content-Type: application/json
Authorization: Bearer <token>

{
  "type": "email",
  "recipient": "user@example.com",
  "template": "order_confirmation",
  "data": {
    "order_number": "ORD-2024-001",
    "total_amount": "4998.00"
  }
}
```

### Notification History
```http
GET /notifications/?page=1&limit=20&type=email
Authorization: Bearer <token>
```

**Response:**
```json
{
  "count": 50,
  "next": "https://api.yourdomain.com/v1/notifications/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "type": "email",
      "recipient": "user@example.com",
      "subject": "Order Confirmation",
      "status": "sent",
      "sent_at": "2024-01-01T10:00:00Z"
    }
  ]
}
```

### Notification Templates
```http
GET /notifications/templates/
Authorization: Bearer <admin_token>
```

## 📊 API Standards

### HTTP Status Codes
- **200 OK**: Successful GET, PUT, PATCH
- **201 Created**: Successful POST
- **204 No Content**: Successful DELETE
- **400 Bad Request**: Client error
- **401 Unauthorized**: Authentication required
- **403 Forbidden**: Permission denied
- **404 Not Found**: Resource not found
- **409 Conflict**: Resource conflict
- **422 Unprocessable Entity**: Validation error
- **500 Internal Server Error**: Server error

### Error Response Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "email": ["This field is required"],
      "password": ["Password must be at least 8 characters"]
    }
  }
}
```

### Pagination
```json
{
  "count": 150,
  "next": "https://api.yourdomain.com/v1/users/?page=3",
  "previous": "https://api.yourdomain.com/v1/users/?page=1",
  "results": []
}
```

### Filtering và Searching
```http
GET /products/?category=electronics&price_min=100&price_max=1000&search=laptop&ordering=-created_at
```

## 🔄 Inter-Service Communication

### Service-to-Service Authentication
```http
POST /internal/users/validate-token/
Content-Type: application/json
X-Service-Token: <service_token>

{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Event-Driven Communication
```json
{
  "event_type": "order.created",
  "data": {
    "order_id": 1,
    "user_id": 1,
    "total_amount": "4998.00"
  },
  "timestamp": "2024-01-01T10:00:00Z"
}
```

## 📈 API Versioning

### URL Versioning
```
https://api.yourdomain.com/v1/users/
https://api.yourdomain.com/v2/users/
```

### Header Versioning
```http
GET /users/
Accept: application/vnd.api+json;version=1
```

### Deprecation Notice
```http
HTTP/1.1 200 OK
Warning: 299 - "Deprecated API"
Sunset: Sun, 01 Jan 2025 00:00:00 GMT
```

## 🔒 Security Best Practices

### Rate Limiting
```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1609459200
```

### Input Validation
- Validate all input data
- Sanitize user inputs
- Use parameterized queries
- Implement CSRF protection

### HTTPS Only
- All API endpoints must use HTTPS
- Implement HSTS headers
- Use secure cookies

## 📋 API Documentation

### OpenAPI Specification
```yaml
openapi: 3.0.0
info:
  title: Django Microservices API
  version: 1.0.0
  description: API documentation for Django microservices
paths:
  /users/:
    get:
      summary: List users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  count:
                    type: integer
                  results:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
```

### Interactive Documentation
- **Swagger UI**: `/docs/`
- **ReDoc**: `/redoc/`
- **Postman Collection**: Export OpenAPI to Postman

## 🧪 Testing

### API Testing with curl
```bash
# Test authentication
curl -X POST http://localhost:8000/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Test protected endpoint
curl -X GET http://localhost:8000/users/profile/ \
  -H "Authorization: Bearer <token>"
```

### Load Testing
```javascript
// k6 load test
import http from 'k6/http';

export let options = {
  stages: [
    { duration: '5m', target: 100 },
    { duration: '10m', target: 200 },
    { duration: '5m', target: 0 },
  ],
};

export default function() {
  http.get('https://api.yourdomain.com/v1/products/');
}
```

## 📊 Monitoring và Analytics

### API Metrics
- Request count
- Response time
- Error rate
- Success rate

### Custom Headers
```http
X-Request-ID: 123e4567-e89b-12d3-a456-426614174000
X-Response-Time: 150ms
X-Service-Version: 1.0.0
```

### Health Check Endpoint
```http
GET /health/
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T10:00:00Z",
  "version": "1.0.0",
  "services": {
    "database": "healthy",
    "cache": "healthy",
    "queue": "healthy"
  }
}
``` 