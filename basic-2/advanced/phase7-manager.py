#!/usr/bin/env python3
"""
Phase 7 Advanced Features & Performance Optimization Manager
Django Microservices trên AWS ECS Fargate

Features:
- Advanced Auto-scaling Management
- Performance Monitoring & Optimization
- Load Testing Orchestration
- Cost Optimization Analysis
- Real-time Metrics Dashboard
- Advanced Alerting System
"""

import boto3
import json
import time
import argparse
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import requests
import threading
from tabulate import tabulate
import colorama
from colorama import Fore, Style, Back

# Initialize colorama for cross-platform colored output
colorama.init()

class Phase7Manager:
    def __init__(self, project_name: str = "django-microservices", environment: str = "dev"):
        self.project_name = project_name
        self.environment = environment
        
        # Initialize AWS clients
        self.ecs = boto3.client('ecs')
        self.cloudwatch = boto3.client('cloudwatch')
        self.lambda_client = boto3.client('lambda')
        self.sns = boto3.client('sns')
        self.elb = boto3.client('elbv2')
        self.rds = boto3.client('rds')
        self.autoscaling = boto3.client('application-autoscaling')
        self.apigateway = boto3.client('apigateway')
        
        # Configuration
        self.services = ['api-gateway', 'user-service', 'product-service', 'order-service', 'notification-service']
        self.cluster_name = f"{project_name}-cluster"
        
        # Performance thresholds
        self.performance_thresholds = {
            'cpu_warning': 70,
            'cpu_critical': 85,
            'memory_warning': 70,
            'memory_critical': 85,
            'response_time_warning': 1.0,
            'response_time_critical': 2.0,
            'error_rate_warning': 1.0,
            'error_rate_critical': 5.0
        }
        
        print(f"{Fore.CYAN}🚀 Phase 7 Manager Initialized{Style.RESET_ALL}")
        print(f"Project: {Fore.GREEN}{project_name}{Style.RESET_ALL}")
        print(f"Environment: {Fore.GREEN}{environment}{Style.RESET_ALL}")
        print(f"Cluster: {Fore.GREEN}{self.cluster_name}{Style.RESET_ALL}")
        print("=" * 60)

    def display_menu(self):
        """Display main menu"""
        print(f"\n{Fore.CYAN}📋 Phase 7 Advanced Features Management{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}1.{Style.RESET_ALL} Auto-scaling Management")
        print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Performance Monitoring")
        print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Load Testing")
        print(f"{Fore.YELLOW}4.{Style.RESET_ALL} Cost Optimization")
        print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Real-time Dashboard")
        print(f"{Fore.YELLOW}6.{Style.RESET_ALL} Advanced Alerting")
        print(f"{Fore.YELLOW}7.{Style.RESET_ALL} Health Check")
        print(f"{Fore.YELLOW}8.{Style.RESET_ALL} Generate Report")
        print(f"{Fore.YELLOW}9.{Style.RESET_ALL} Exit")
        print("-" * 40)

    def get_service_metrics(self, service_name: str, hours: int = 1) -> Dict:
        """Get comprehensive metrics for a service"""
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        
        metrics = {
            'service': service_name,
            'status': 'Unknown',
            'cpu_avg': 0,
            'cpu_max': 0,
            'memory_avg': 0,
            'memory_max': 0,
            'task_count': 0,
            'running_tasks': 0,
            'desired_tasks': 0,
            'response_time': 0,
            'error_rate': 0,
            'health_score': 0
        }
        
        try:
            # Get ECS service status
            response = self.ecs.describe_services(
                cluster=self.cluster_name,
                services=[f"{self.project_name}-{service_name}"]
            )
            
            if response['services']:
                service_info = response['services'][0]
                metrics['status'] = service_info['status']
                metrics['running_tasks'] = service_info['runningCount']
                metrics['desired_tasks'] = service_info['desiredCount']
                metrics['task_count'] = service_info['runningCount']
            
            # Get CloudWatch metrics
            dimensions = [
                {'Name': 'ServiceName', 'Value': f"{self.project_name}-{service_name}"},
                {'Name': 'ClusterName', 'Value': self.cluster_name}
            ]
            
            # CPU Utilization
            cpu_response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='CPUUtilization',
                Dimensions=dimensions,
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average', 'Maximum']
            )
            
            if cpu_response['Datapoints']:
                metrics['cpu_avg'] = round(sum(dp['Average'] for dp in cpu_response['Datapoints']) / len(cpu_response['Datapoints']), 2)
                metrics['cpu_max'] = round(max(dp['Maximum'] for dp in cpu_response['Datapoints']), 2)
            
            # Memory Utilization
            memory_response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='MemoryUtilization',
                Dimensions=dimensions,
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average', 'Maximum']
            )
            
            if memory_response['Datapoints']:
                metrics['memory_avg'] = round(sum(dp['Average'] for dp in memory_response['Datapoints']) / len(memory_response['Datapoints']), 2)
                metrics['memory_max'] = round(max(dp['Maximum'] for dp in memory_response['Datapoints']), 2)
            
            # Calculate health score
            metrics['health_score'] = self.calculate_health_score(metrics)
            
        except Exception as e:
            print(f"{Fore.RED}❌ Error getting metrics for {service_name}: {str(e)}{Style.RESET_ALL}")
        
        return metrics

    def calculate_health_score(self, metrics: Dict) -> int:
        """Calculate health score based on metrics"""
        score = 100
        
        # CPU penalty
        if metrics['cpu_avg'] > self.performance_thresholds['cpu_critical']:
            score -= 30
        elif metrics['cpu_avg'] > self.performance_thresholds['cpu_warning']:
            score -= 15
        
        # Memory penalty
        if metrics['memory_avg'] > self.performance_thresholds['memory_critical']:
            score -= 30
        elif metrics['memory_avg'] > self.performance_thresholds['memory_warning']:
            score -= 15
        
        # Task availability penalty
        if metrics['running_tasks'] < metrics['desired_tasks']:
            score -= 20
        
        # Status penalty
        if metrics['status'] != 'ACTIVE':
            score -= 40
        
        return max(0, score)

    def autoscaling_management(self):
        """Advanced Auto-scaling Management"""
        print(f"\n{Fore.CYAN}🔄 Auto-scaling Management{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}1.{Style.RESET_ALL} View Current Scaling Policies")
        print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Update Scaling Targets")
        print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Test Scaling Policies")
        print(f"{Fore.YELLOW}4.{Style.RESET_ALL} Enable/Disable Predictive Scaling")
        print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Scheduled Scaling Management")
        print(f"{Fore.YELLOW}6.{Style.RESET_ALL} Back to Main Menu")
        
        choice = input(f"{Fore.CYAN}Enter your choice (1-6): {Style.RESET_ALL}")
        
        if choice == '1':
            self.view_scaling_policies()
        elif choice == '2':
            self.update_scaling_targets()
        elif choice == '3':
            self.test_scaling_policies()
        elif choice == '4':
            self.manage_predictive_scaling()
        elif choice == '5':
            self.manage_scheduled_scaling()
        elif choice == '6':
            return
        else:
            print(f"{Fore.RED}❌ Invalid choice{Style.RESET_ALL}")

    def view_scaling_policies(self):
        """View current auto-scaling policies"""
        print(f"\n{Fore.CYAN}📊 Current Auto-scaling Policies{Style.RESET_ALL}")
        
        headers = ['Service', 'Min Capacity', 'Max Capacity', 'Current Tasks', 'CPU Target', 'Memory Target']
        table_data = []
        
        for service in self.services:
            try:
                resource_id = f"service/{self.cluster_name}/{self.project_name}-{service}"
                
                # Get scaling target
                response = self.autoscaling.describe_scalable_targets(
                    ServiceNamespace='ecs',
                    ResourceIds=[resource_id]
                )
                
                if response['ScalableTargets']:
                    target = response['ScalableTargets'][0]
                    
                    # Get current task count
                    service_info = self.ecs.describe_services(
                        cluster=self.cluster_name,
                        services=[f"{self.project_name}-{service}"]
                    )
                    
                    current_tasks = service_info['services'][0]['runningCount'] if service_info['services'] else 0
                    
                    table_data.append([
                        service,
                        target['MinCapacity'],
                        target['MaxCapacity'],
                        current_tasks,
                        "70%",  # Default CPU target
                        "70%"   # Default Memory target
                    ])
                
            except Exception as e:
                table_data.append([service, 'Error', 'Error', 'Error', 'Error', 'Error'])
        
        print(tabulate(table_data, headers=headers, tablefmt='grid'))

    def update_scaling_targets(self):
        """Update auto-scaling targets"""
        print(f"\n{Fore.CYAN}🎯 Update Scaling Targets{Style.RESET_ALL}")
        
        service = input(f"{Fore.CYAN}Enter service name: {Style.RESET_ALL}")
        if service not in self.services:
            print(f"{Fore.RED}❌ Invalid service name{Style.RESET_ALL}")
            return
        
        try:
            min_capacity = int(input(f"{Fore.CYAN}Enter minimum capacity: {Style.RESET_ALL}"))
            max_capacity = int(input(f"{Fore.CYAN}Enter maximum capacity: {Style.RESET_ALL}"))
            
            if min_capacity >= max_capacity:
                print(f"{Fore.RED}❌ Minimum capacity must be less than maximum capacity{Style.RESET_ALL}")
                return
            
            resource_id = f"service/{self.cluster_name}/{self.project_name}-{service}"
            
            # Update scaling target
            self.autoscaling.register_scalable_target(
                ServiceNamespace='ecs',
                ResourceId=resource_id,
                ScalableDimension='ecs:service:DesiredCount',
                MinCapacity=min_capacity,
                MaxCapacity=max_capacity
            )
            
            print(f"{Fore.GREEN}✅ Updated scaling targets for {service}{Style.RESET_ALL}")
            print(f"Min: {min_capacity}, Max: {max_capacity}")
            
        except ValueError:
            print(f"{Fore.RED}❌ Please enter valid numbers{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}❌ Error updating scaling targets: {str(e)}{Style.RESET_ALL}")

    def performance_monitoring(self):
        """Advanced Performance Monitoring"""
        print(f"\n{Fore.CYAN}⚡ Performance Monitoring{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}1.{Style.RESET_ALL} Real-time Performance Dashboard")
        print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Performance Analysis")
        print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Service Health Check")
        print(f"{Fore.YELLOW}4.{Style.RESET_ALL} Performance Trends")
        print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Resource Utilization")
        print(f"{Fore.YELLOW}6.{Style.RESET_ALL} Back to Main Menu")
        
        choice = input(f"{Fore.CYAN}Enter your choice (1-6): {Style.RESET_ALL}")
        
        if choice == '1':
            self.real_time_dashboard()
        elif choice == '2':
            self.performance_analysis()
        elif choice == '3':
            self.service_health_check()
        elif choice == '4':
            self.performance_trends()
        elif choice == '5':
            self.resource_utilization()
        elif choice == '6':
            return
        else:
            print(f"{Fore.RED}❌ Invalid choice{Style.RESET_ALL}")

    def real_time_dashboard(self):
        """Real-time performance dashboard"""
        print(f"\n{Fore.CYAN}📊 Real-time Performance Dashboard{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}Press Ctrl+C to stop monitoring{Style.RESET_ALL}")
        
        try:
            while True:
                os.system('clear' if os.name == 'posix' else 'cls')
                
                print(f"{Fore.CYAN}🔴 LIVE DASHBOARD - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Style.RESET_ALL}")
                print("=" * 80)
                
                headers = ['Service', 'Status', 'Tasks', 'CPU%', 'Memory%', 'Health']
                table_data = []
                
                for service in self.services:
                    metrics = self.get_service_metrics(service)
                    
                    # Color coding based on health score
                    if metrics['health_score'] >= 80:
                        health_color = Fore.GREEN
                    elif metrics['health_score'] >= 60:
                        health_color = Fore.YELLOW
                    else:
                        health_color = Fore.RED
                    
                    table_data.append([
                        service,
                        metrics['status'],
                        f"{metrics['running_tasks']}/{metrics['desired_tasks']}",
                        f"{metrics['cpu_avg']:.1f}%",
                        f"{metrics['memory_avg']:.1f}%",
                        f"{health_color}{metrics['health_score']}{Style.RESET_ALL}"
                    ])
                
                print(tabulate(table_data, headers=headers, tablefmt='grid'))
                
                # Overall system health
                overall_health = sum(self.get_service_metrics(service)['health_score'] for service in self.services) / len(self.services)
                
                if overall_health >= 80:
                    health_status = f"{Fore.GREEN}EXCELLENT{Style.RESET_ALL}"
                elif overall_health >= 60:
                    health_status = f"{Fore.YELLOW}GOOD{Style.RESET_ALL}"
                else:
                    health_status = f"{Fore.RED}NEEDS ATTENTION{Style.RESET_ALL}"
                
                print(f"\n{Fore.CYAN}Overall System Health: {health_status} ({overall_health:.1f}/100){Style.RESET_ALL}")
                
                time.sleep(10)
                
        except KeyboardInterrupt:
            print(f"\n{Fore.CYAN}📊 Dashboard monitoring stopped{Style.RESET_ALL}")

    def load_testing(self):
        """Load Testing Management"""
        print(f"\n{Fore.CYAN}🧪 Load Testing Management{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}1.{Style.RESET_ALL} Start Load Test")
        print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Check Test Status")
        print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Stop Load Test")
        print(f"{Fore.YELLOW}4.{Style.RESET_ALL} View Test Results")
        print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Configure Test Parameters")
        print(f"{Fore.YELLOW}6.{Style.RESET_ALL} Back to Main Menu")
        
        choice = input(f"{Fore.CYAN}Enter your choice (1-6): {Style.RESET_ALL}")
        
        if choice == '1':
            self.start_load_test()
        elif choice == '2':
            self.check_test_status()
        elif choice == '3':
            self.stop_load_test()
        elif choice == '4':
            self.view_test_results()
        elif choice == '5':
            self.configure_test_parameters()
        elif choice == '6':
            return
        else:
            print(f"{Fore.RED}❌ Invalid choice{Style.RESET_ALL}")

    def start_load_test(self):
        """Start load testing"""
        print(f"\n{Fore.CYAN}🚀 Starting Load Test{Style.RESET_ALL}")
        
        try:
            # Get load test parameters
            target_rps = int(input(f"{Fore.CYAN}Target RPS (10-1000): {Style.RESET_ALL}") or "100")
            duration = int(input(f"{Fore.CYAN}Duration in minutes (1-60): {Style.RESET_ALL}") or "10")
            
            # Call load test orchestrator Lambda
            response = self.lambda_client.invoke(
                FunctionName=f"{self.project_name}-load-test-orchestrator",
                InvocationType='RequestResponse',
                Payload=json.dumps({
                    'action': 'run',
                    'target_rps': target_rps,
                    'duration': duration
                })
            )
            
            result = json.loads(response['Payload'].read())
            
            if result['statusCode'] == 200:
                print(f"{Fore.GREEN}✅ Load test started successfully{Style.RESET_ALL}")
                print(f"Target: {target_rps} RPS for {duration} minutes")
                
                # Monitor test progress
                print(f"\n{Fore.CYAN}🔍 Monitoring test progress...{Style.RESET_ALL}")
                self.monitor_load_test(duration)
            else:
                print(f"{Fore.RED}❌ Failed to start load test: {result.get('error', 'Unknown error')}{Style.RESET_ALL}")
                
        except ValueError:
            print(f"{Fore.RED}❌ Please enter valid numbers{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}❌ Error starting load test: {str(e)}{Style.RESET_ALL}")

    def monitor_load_test(self, duration_minutes: int):
        """Monitor load test progress"""
        start_time = time.time()
        end_time = start_time + (duration_minutes * 60)
        
        while time.time() < end_time:
            try:
                # Get current performance metrics
                headers = ['Metric', 'Value']
                table_data = []
                
                # Get ALB metrics
                alb_response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/ApplicationELB',
                    MetricName='RequestCount',
                    Dimensions=[
                        {'Name': 'LoadBalancer', 'Value': f"{self.project_name}-alb"}
                    ],
                    StartTime=datetime.now() - timedelta(minutes=5),
                    EndTime=datetime.now(),
                    Period=300,
                    Statistics=['Sum']
                )
                
                current_rps = 0
                if alb_response['Datapoints']:
                    current_rps = alb_response['Datapoints'][-1]['Sum'] / 300  # Convert to RPS
                
                table_data.append(['Current RPS', f"{current_rps:.1f}"])
                
                # Calculate progress
                elapsed = time.time() - start_time
                progress = (elapsed / (duration_minutes * 60)) * 100
                remaining = duration_minutes - (elapsed / 60)
                
                table_data.append(['Progress', f"{progress:.1f}%"])
                table_data.append(['Remaining Time', f"{remaining:.1f} minutes"])
                
                print(f"\n{Fore.CYAN}📊 Load Test Progress{Style.RESET_ALL}")
                print(tabulate(table_data, headers=headers, tablefmt='grid'))
                
                time.sleep(30)
                
            except KeyboardInterrupt:
                print(f"\n{Fore.YELLOW}⏹️  Load test monitoring stopped{Style.RESET_ALL}")
                break
            except Exception as e:
                print(f"{Fore.RED}❌ Error monitoring load test: {str(e)}{Style.RESET_ALL}")
                break

    def cost_optimization(self):
        """Cost Optimization Analysis"""
        print(f"\n{Fore.CYAN}💰 Cost Optimization Analysis{Style.RESET_ALL}")
        
        try:
            # Trigger cost optimizer Lambda
            response = self.lambda_client.invoke(
                FunctionName=f"{self.project_name}-cost-optimizer",
                InvocationType='RequestResponse',
                Payload=json.dumps({})
            )
            
            result = json.loads(response['Payload'].read())
            
            if result['statusCode'] == 200:
                cost_data = json.loads(result['body'])
                
                print(f"{Fore.GREEN}✅ Cost analysis completed{Style.RESET_ALL}")
                print(f"Analysis Date: {cost_data['timestamp']}")
                print(f"Estimated Savings: ${cost_data['estimated_savings']:.2f}/month")
                
                print(f"\n{Fore.CYAN}💡 Recommendations:{Style.RESET_ALL}")
                for i, recommendation in enumerate(cost_data['recommendations'], 1):
                    print(f"{i}. {recommendation}")
                
                # Resource utilization summary
                print(f"\n{Fore.CYAN}📊 Resource Utilization Summary{Style.RESET_ALL}")
                self.display_resource_utilization()
                
            else:
                print(f"{Fore.RED}❌ Cost analysis failed: {result.get('error', 'Unknown error')}{Style.RESET_ALL}")
                
        except Exception as e:
            print(f"{Fore.RED}❌ Error running cost optimization: {str(e)}{Style.RESET_ALL}")

    def display_resource_utilization(self):
        """Display resource utilization summary"""
        headers = ['Resource', 'Current Usage', 'Recommendation']
        table_data = []
        
        for service in self.services:
            metrics = self.get_service_metrics(service)
            
            if metrics['cpu_avg'] < 20:
                recommendation = "Consider downsizing"
            elif metrics['cpu_avg'] > 80:
                recommendation = "Consider scaling up"
            else:
                recommendation = "Optimal"
            
            table_data.append([
                service,
                f"CPU: {metrics['cpu_avg']:.1f}%, Memory: {metrics['memory_avg']:.1f}%",
                recommendation
            ])
        
        print(tabulate(table_data, headers=headers, tablefmt='grid'))

    def generate_comprehensive_report(self):
        """Generate comprehensive Phase 7 report"""
        print(f"\n{Fore.CYAN}📋 Generating Comprehensive Report{Style.RESET_ALL}")
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'project': self.project_name,
            'environment': self.environment,
            'services': [],
            'infrastructure': {},
            'performance': {},
            'cost': {},
            'recommendations': []
        }
        
        # Service metrics
        for service in self.services:
            metrics = self.get_service_metrics(service)
            report['services'].append(metrics)
        
        # Calculate overall metrics
        avg_cpu = sum(s['cpu_avg'] for s in report['services']) / len(self.services)
        avg_memory = sum(s['memory_avg'] for s in report['services']) / len(self.services)
        overall_health = sum(s['health_score'] for s in report['services']) / len(self.services)
        
        report['performance'] = {
            'avg_cpu': round(avg_cpu, 2),
            'avg_memory': round(avg_memory, 2),
            'overall_health': round(overall_health, 2)
        }
        
        # Generate recommendations
        if overall_health < 70:
            report['recommendations'].append("System health is below optimal. Consider scaling up resources.")
        
        if avg_cpu > 80:
            report['recommendations'].append("High CPU utilization detected. Consider horizontal scaling.")
        
        if avg_memory > 80:
            report['recommendations'].append("High memory utilization detected. Consider memory optimization.")
        
        # Save report
        report_filename = f"phase7_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_filename, 'w') as f:
            json.dump(report, indent=2, fp=f)
        
        print(f"{Fore.GREEN}✅ Report generated: {report_filename}{Style.RESET_ALL}")
        
        # Display summary
        print(f"\n{Fore.CYAN}📊 Report Summary{Style.RESET_ALL}")
        print(f"Overall Health Score: {overall_health:.1f}/100")
        print(f"Average CPU Usage: {avg_cpu:.1f}%")
        print(f"Average Memory Usage: {avg_memory:.1f}%")
        print(f"Total Services: {len(self.services)}")
        print(f"Active Services: {sum(1 for s in report['services'] if s['status'] == 'ACTIVE')}")

    def run(self):
        """Main execution loop"""
        try:
            while True:
                self.display_menu()
                choice = input(f"{Fore.CYAN}Enter your choice (1-9): {Style.RESET_ALL}")
                
                if choice == '1':
                    self.autoscaling_management()
                elif choice == '2':
                    self.performance_monitoring()
                elif choice == '3':
                    self.load_testing()
                elif choice == '4':
                    self.cost_optimization()
                elif choice == '5':
                    self.real_time_dashboard()
                elif choice == '6':
                    print(f"{Fore.CYAN}🔔 Advanced Alerting - Feature in development{Style.RESET_ALL}")
                elif choice == '7':
                    self.service_health_check()
                elif choice == '8':
                    self.generate_comprehensive_report()
                elif choice == '9':
                    print(f"{Fore.CYAN}👋 Goodbye!{Style.RESET_ALL}")
                    break
                else:
                    print(f"{Fore.RED}❌ Invalid choice. Please try again.{Style.RESET_ALL}")
                
                input(f"\n{Fore.CYAN}Press Enter to continue...{Style.RESET_ALL}")
                
        except KeyboardInterrupt:
            print(f"\n{Fore.CYAN}👋 Goodbye!{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}❌ An error occurred: {str(e)}{Style.RESET_ALL}")

    def service_health_check(self):
        """Comprehensive service health check"""
        print(f"\n{Fore.CYAN}🏥 Service Health Check{Style.RESET_ALL}")
        
        headers = ['Service', 'Status', 'Health Score', 'Issues', 'Recommendation']
        table_data = []
        
        for service in self.services:
            metrics = self.get_service_metrics(service)
            issues = []
            recommendations = []
            
            # Check for issues
            if metrics['cpu_avg'] > 80:
                issues.append("High CPU")
                recommendations.append("Scale up")
            
            if metrics['memory_avg'] > 80:
                issues.append("High Memory")
                recommendations.append("Optimize memory")
            
            if metrics['running_tasks'] < metrics['desired_tasks']:
                issues.append("Task deficit")
                recommendations.append("Check logs")
            
            if metrics['status'] != 'ACTIVE':
                issues.append("Service inactive")
                recommendations.append("Restart service")
            
            if not issues:
                issues.append("None")
                recommendations.append("None")
            
            table_data.append([
                service,
                metrics['status'],
                f"{metrics['health_score']}/100",
                ", ".join(issues),
                ", ".join(recommendations)
            ])
        
        print(tabulate(table_data, headers=headers, tablefmt='grid'))

def main():
    parser = argparse.ArgumentParser(description='Phase 7 Advanced Features Manager')
    parser.add_argument('--project', default='django-microservices', help='Project name')
    parser.add_argument('--environment', default='dev', help='Environment name')
    
    args = parser.parse_args()
    
    # Initialize and run manager
    manager = Phase7Manager(args.project, args.environment)
    manager.run()

if __name__ == "__main__":
    main() 