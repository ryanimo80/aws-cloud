#!/usr/bin/env python3
"""
AWS ECS Microservices Monitoring Script

This script monitors the health and performance of Django microservices
deployed on AWS ECS Fargate with comprehensive metrics collection.
"""

import boto3
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from dataclasses import dataclass
from tabulate import tabulate
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ServiceHealth:
    """Service health status"""
    service_name: str
    status: str
    running_tasks: int
    desired_tasks: int
    cpu_utilization: float
    memory_utilization: float
    health_score: int
    last_deployment: str
    errors_count: int

@dataclass
class InfrastructureHealth:
    """Infrastructure health status"""
    rds_status: str
    redis_status: str
    alb_status: str
    alb_response_time: float
    alb_healthy_targets: int
    alb_unhealthy_targets: int

class AWSMonitor:
    """AWS Resources Monitor"""
    
    def __init__(self, project_name: str, environment: str, region: str = 'us-east-1'):
        self.project_name = project_name
        self.environment = environment
        self.region = region
        
        # Initialize AWS clients
        self.ecs_client = boto3.client('ecs', region_name=region)
        self.rds_client = boto3.client('rds', region_name=region)
        self.elasticache_client = boto3.client('elasticache', region_name=region)
        self.elbv2_client = boto3.client('elbv2', region_name=region)
        self.cloudwatch_client = boto3.client('cloudwatch', region_name=region)
        self.logs_client = boto3.client('logs', region_name=region)
        
        # Resource identifiers
        self.cluster_name = f"{project_name}-cluster"
        self.db_instance_id = f"{project_name}-db"
        self.redis_cluster_id = f"{project_name}-redis"
        
        # Service list
        self.services = [
            'api-gateway',
            'user-service',
            'product-service',
            'order-service',
            'notification-service'
        ]
    
    def get_ecs_cluster_info(self) -> Dict:
        """Get ECS cluster information"""
        try:
            response = self.ecs_client.describe_clusters(
                clusters=[self.cluster_name]
            )
            
            if not response['clusters']:
                return {'error': 'Cluster not found'}
            
            cluster = response['clusters'][0]
            return {
                'name': cluster['clusterName'],
                'status': cluster['status'],
                'running_tasks': cluster['runningTasksCount'],
                'pending_tasks': cluster['pendingTasksCount'],
                'services': cluster['activeServicesCount'],
                'capacity_providers': cluster.get('capacityProviders', [])
            }
        except Exception as e:
            logger.error(f"Error getting cluster info: {e}")
            return {'error': str(e)}
    
    def get_service_health(self, service_name: str) -> ServiceHealth:
        """Get health status for a specific service"""
        try:
            service_arn = f"{self.project_name}-{service_name}"
            
            # Get service details
            response = self.ecs_client.describe_services(
                cluster=self.cluster_name,
                services=[service_arn]
            )
            
            if not response['services']:
                return ServiceHealth(
                    service_name=service_name,
                    status='NOT_FOUND',
                    running_tasks=0,
                    desired_tasks=0,
                    cpu_utilization=0.0,
                    memory_utilization=0.0,
                    health_score=0,
                    last_deployment='Never',
                    errors_count=0
                )
            
            service = response['services'][0]
            
            # Get CloudWatch metrics
            cpu_util = self.get_service_cpu_utilization(service_name)
            memory_util = self.get_service_memory_utilization(service_name)
            error_count = self.get_service_error_count(service_name)
            
            # Calculate health score
            health_score = self.calculate_health_score(
                service['status'],
                service['runningCount'],
                service['desiredCount'],
                cpu_util,
                memory_util,
                error_count
            )
            
            return ServiceHealth(
                service_name=service_name,
                status=service['status'],
                running_tasks=service['runningCount'],
                desired_tasks=service['desiredCount'],
                cpu_utilization=cpu_util,
                memory_utilization=memory_util,
                health_score=health_score,
                last_deployment=service['deployments'][0]['createdAt'].isoformat() if service['deployments'] else 'Never',
                errors_count=error_count
            )
            
        except Exception as e:
            logger.error(f"Error getting service health for {service_name}: {e}")
            return ServiceHealth(
                service_name=service_name,
                status='ERROR',
                running_tasks=0,
                desired_tasks=0,
                cpu_utilization=0.0,
                memory_utilization=0.0,
                health_score=0,
                last_deployment='Error',
                errors_count=999
            )
    
    def get_service_cpu_utilization(self, service_name: str) -> float:
        """Get CPU utilization for a service"""
        try:
            response = self.cloudwatch_client.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='CPUUtilization',
                Dimensions=[
                    {
                        'Name': 'ServiceName',
                        'Value': f"{self.project_name}-{service_name}"
                    },
                    {
                        'Name': 'ClusterName',
                        'Value': self.cluster_name
                    }
                ],
                StartTime=datetime.now() - timedelta(minutes=10),
                EndTime=datetime.now(),
                Period=300,
                Statistics=['Average']
            )
            
            if response['Datapoints']:
                return round(response['Datapoints'][-1]['Average'], 2)
            return 0.0
        except Exception as e:
            logger.error(f"Error getting CPU utilization for {service_name}: {e}")
            return 0.0
    
    def get_service_memory_utilization(self, service_name: str) -> float:
        """Get memory utilization for a service"""
        try:
            response = self.cloudwatch_client.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='MemoryUtilization',
                Dimensions=[
                    {
                        'Name': 'ServiceName',
                        'Value': f"{self.project_name}-{service_name}"
                    },
                    {
                        'Name': 'ClusterName',
                        'Value': self.cluster_name
                    }
                ],
                StartTime=datetime.now() - timedelta(minutes=10),
                EndTime=datetime.now(),
                Period=300,
                Statistics=['Average']
            )
            
            if response['Datapoints']:
                return round(response['Datapoints'][-1]['Average'], 2)
            return 0.0
        except Exception as e:
            logger.error(f"Error getting memory utilization for {service_name}: {e}")
            return 0.0
    
    def get_service_error_count(self, service_name: str) -> int:
        """Get error count from logs for a service"""
        try:
            log_group_name = f"/ecs/{self.project_name}-{service_name}"
            
            response = self.logs_client.filter_log_events(
                logGroupName=log_group_name,
                startTime=int((datetime.now() - timedelta(hours=1)).timestamp() * 1000),
                filterPattern="ERROR"
            )
            
            return len(response['events'])
        except Exception as e:
            logger.error(f"Error getting error count for {service_name}: {e}")
            return 0
    
    def calculate_health_score(self, status: str, running: int, desired: int, 
                             cpu: float, memory: float, errors: int) -> int:
        """Calculate health score (0-100)"""
        score = 100
        
        # Status check
        if status != 'ACTIVE':
            score -= 30
        
        # Running tasks check
        if running < desired:
            score -= 20 * (desired - running)
        
        # Resource utilization check
        if cpu > 80:
            score -= 15
        elif cpu > 60:
            score -= 5
        
        if memory > 80:
            score -= 15
        elif memory > 60:
            score -= 5
        
        # Error count check
        if errors > 10:
            score -= 20
        elif errors > 5:
            score -= 10
        elif errors > 0:
            score -= 5
        
        return max(0, score)
    
    def get_infrastructure_health(self) -> InfrastructureHealth:
        """Get infrastructure health status"""
        try:
            # RDS Status
            rds_response = self.rds_client.describe_db_instances(
                DBInstanceIdentifier=self.db_instance_id
            )
            rds_status = rds_response['DBInstances'][0]['DBInstanceStatus']
            
            # Redis Status
            redis_response = self.elasticache_client.describe_cache_clusters(
                CacheClusterId=self.redis_cluster_id
            )
            redis_status = redis_response['CacheClusters'][0]['CacheClusterStatus']
            
            # ALB Status
            alb_response = self.elbv2_client.describe_load_balancers()
            alb_status = 'unknown'
            alb_response_time = 0.0
            healthy_targets = 0
            unhealthy_targets = 0
            
            for lb in alb_response['LoadBalancers']:
                if self.project_name in lb['LoadBalancerName']:
                    alb_status = lb['State']['Code']
                    
                    # Get ALB metrics
                    alb_response_time = self.get_alb_response_time(lb['LoadBalancerArn'])
                    healthy_targets, unhealthy_targets = self.get_alb_target_health(lb['LoadBalancerArn'])
                    break
            
            return InfrastructureHealth(
                rds_status=rds_status,
                redis_status=redis_status,
                alb_status=alb_status,
                alb_response_time=alb_response_time,
                alb_healthy_targets=healthy_targets,
                alb_unhealthy_targets=unhealthy_targets
            )
            
        except Exception as e:
            logger.error(f"Error getting infrastructure health: {e}")
            return InfrastructureHealth(
                rds_status='error',
                redis_status='error',
                alb_status='error',
                alb_response_time=0.0,
                alb_healthy_targets=0,
                alb_unhealthy_targets=0
            )
    
    def get_alb_response_time(self, alb_arn: str) -> float:
        """Get ALB response time"""
        try:
            response = self.cloudwatch_client.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='TargetResponseTime',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_arn.split('/')[-1]
                    }
                ],
                StartTime=datetime.now() - timedelta(minutes=10),
                EndTime=datetime.now(),
                Period=300,
                Statistics=['Average']
            )
            
            if response['Datapoints']:
                return round(response['Datapoints'][-1]['Average'], 3)
            return 0.0
        except Exception as e:
            logger.error(f"Error getting ALB response time: {e}")
            return 0.0
    
    def get_alb_target_health(self, alb_arn: str) -> tuple:
        """Get ALB target health counts"""
        try:
            # Get target groups
            tg_response = self.elbv2_client.describe_target_groups(
                LoadBalancerArn=alb_arn
            )
            
            healthy_count = 0
            unhealthy_count = 0
            
            for tg in tg_response['TargetGroups']:
                health_response = self.elbv2_client.describe_target_health(
                    TargetGroupArn=tg['TargetGroupArn']
                )
                
                for target in health_response['TargetHealthDescriptions']:
                    if target['TargetHealth']['State'] == 'healthy':
                        healthy_count += 1
                    else:
                        unhealthy_count += 1
            
            return healthy_count, unhealthy_count
            
        except Exception as e:
            logger.error(f"Error getting ALB target health: {e}")
            return 0, 0
    
    def generate_report(self) -> Dict:
        """Generate comprehensive monitoring report"""
        logger.info("Generating monitoring report...")
        
        # Get cluster info
        cluster_info = self.get_ecs_cluster_info()
        
        # Get service health
        services_health = []
        for service in self.services:
            health = self.get_service_health(service)
            services_health.append(health)
        
        # Get infrastructure health
        infra_health = self.get_infrastructure_health()
        
        # Calculate overall health score
        overall_score = sum(s.health_score for s in services_health) / len(services_health)
        
        return {
            'timestamp': datetime.now().isoformat(),
            'project_name': self.project_name,
            'environment': self.environment,
            'region': self.region,
            'cluster_info': cluster_info,
            'services_health': services_health,
            'infrastructure_health': infra_health,
            'overall_health_score': round(overall_score, 2),
            'summary': {
                'total_services': len(self.services),
                'healthy_services': len([s for s in services_health if s.health_score >= 80]),
                'warning_services': len([s for s in services_health if 60 <= s.health_score < 80]),
                'critical_services': len([s for s in services_health if s.health_score < 60])
            }
        }
    
    def print_report(self, report: Dict):
        """Print formatted monitoring report"""
        print("\n" + "="*80)
        print(f"AWS ECS MICROSERVICES MONITORING REPORT")
        print("="*80)
        print(f"Project: {report['project_name']}")
        print(f"Environment: {report['environment']}")
        print(f"Region: {report['region']}")
        print(f"Timestamp: {report['timestamp']}")
        print(f"Overall Health Score: {report['overall_health_score']}/100")
        
        # Cluster Info
        print(f"\n📊 CLUSTER INFORMATION")
        print("-" * 40)
        cluster = report['cluster_info']
        if 'error' not in cluster:
            print(f"Name: {cluster['name']}")
            print(f"Status: {cluster['status']}")
            print(f"Running Tasks: {cluster['running_tasks']}")
            print(f"Pending Tasks: {cluster['pending_tasks']}")
            print(f"Active Services: {cluster['services']}")
        else:
            print(f"Error: {cluster['error']}")
        
        # Services Health
        print(f"\n🚀 SERVICES HEALTH")
        print("-" * 40)
        
        service_table = []
        for service in report['services_health']:
            status_emoji = "✅" if service.health_score >= 80 else "⚠️" if service.health_score >= 60 else "❌"
            service_table.append([
                f"{status_emoji} {service.service_name}",
                service.status,
                f"{service.running_tasks}/{service.desired_tasks}",
                f"{service.cpu_utilization}%",
                f"{service.memory_utilization}%",
                f"{service.health_score}/100",
                service.errors_count
            ])
        
        headers = ["Service", "Status", "Tasks", "CPU", "Memory", "Health", "Errors"]
        print(tabulate(service_table, headers=headers, tablefmt="grid"))
        
        # Infrastructure Health
        print(f"\n🏗️ INFRASTRUCTURE HEALTH")
        print("-" * 40)
        infra = report['infrastructure_health']
        infra_table = [
            ["RDS Database", infra.rds_status],
            ["Redis Cache", infra.redis_status],
            ["Load Balancer", infra.alb_status],
            ["ALB Response Time", f"{infra.alb_response_time}s"],
            ["Healthy Targets", infra.alb_healthy_targets],
            ["Unhealthy Targets", infra.alb_unhealthy_targets]
        ]
        print(tabulate(infra_table, headers=["Component", "Status"], tablefmt="grid"))
        
        # Summary
        print(f"\n📈 SUMMARY")
        print("-" * 40)
        summary = report['summary']
        print(f"Total Services: {summary['total_services']}")
        print(f"✅ Healthy Services: {summary['healthy_services']}")
        print(f"⚠️ Warning Services: {summary['warning_services']}")
        print(f"❌ Critical Services: {summary['critical_services']}")
        
        # Recommendations
        print(f"\n💡 RECOMMENDATIONS")
        print("-" * 40)
        
        recommendations = []
        
        if summary['critical_services'] > 0:
            recommendations.append("🔴 CRITICAL: Immediate attention needed for failing services")
        
        if summary['warning_services'] > 0:
            recommendations.append("🟡 WARNING: Monitor services with degraded performance")
        
        if infra.alb_unhealthy_targets > 0:
            recommendations.append("🔧 Check load balancer target health")
        
        if infra.alb_response_time > 1.0:
            recommendations.append("⚡ Optimize application response time")
        
        for service in report['services_health']:
            if service.cpu_utilization > 80:
                recommendations.append(f"📊 Scale up {service.service_name} - High CPU usage")
            if service.memory_utilization > 80:
                recommendations.append(f"💾 Scale up {service.service_name} - High memory usage")
            if service.errors_count > 10:
                recommendations.append(f"🐛 Check {service.service_name} logs - High error rate")
        
        if not recommendations:
            recommendations.append("✅ All systems operating normally")
        
        for rec in recommendations:
            print(f"  {rec}")
        
        print("\n" + "="*80)


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Monitor AWS ECS Microservices')
    parser.add_argument('--project', default='django-microservices', 
                       help='Project name')
    parser.add_argument('--environment', default='dev', 
                       help='Environment (dev/staging/prod)')
    parser.add_argument('--region', default='us-east-1', 
                       help='AWS region')
    parser.add_argument('--output', choices=['console', 'json'], 
                       default='console', help='Output format')
    parser.add_argument('--watch', action='store_true', 
                       help='Watch mode - continuous monitoring')
    parser.add_argument('--interval', type=int, default=60, 
                       help='Watch interval in seconds')
    
    args = parser.parse_args()
    
    # Initialize monitor
    monitor = AWSMonitor(
        project_name=args.project,
        environment=args.environment,
        region=args.region
    )
    
    try:
        if args.watch:
            print(f"Starting continuous monitoring (interval: {args.interval}s)")
            print("Press Ctrl+C to stop...")
            
            while True:
                report = monitor.generate_report()
                
                if args.output == 'json':
                    print(json.dumps(report, indent=2, default=str))
                else:
                    monitor.print_report(report)
                
                time.sleep(args.interval)
        else:
            # Single run
            report = monitor.generate_report()
            
            if args.output == 'json':
                print(json.dumps(report, indent=2, default=str))
            else:
                monitor.print_report(report)
                
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user")
    except Exception as e:
        logger.error(f"Error in monitoring: {e}")
        raise


if __name__ == "__main__":
    main() 