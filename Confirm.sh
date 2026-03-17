#!/bin/bash
# ============================================
# Subnet Resource Inventory Script
# Target: subnet-025bdda24d36bc235
# ============================================

SUBNET_ID="subnet-025bdda24d36bc235"
OUTPUT_FILE="Before.txt"
REGION="ap-northeast-1"

echo "=====================================================" > $OUTPUT_FILE
echo " Subnet Resource Inventory" >> $OUTPUT_FILE
echo " Subnet ID : $SUBNET_ID" >> $OUTPUT_FILE
echo " Date      : $(date '+%Y-%m-%d %H:%M:%S')" >> $OUTPUT_FILE
echo " Account   : $(aws sts get-caller-identity --query Account --output text)" >> $OUTPUT_FILE
echo "=====================================================" >> $OUTPUT_FILE

# ----- 1. サブネット詳細 -----
echo "" >> $OUTPUT_FILE
echo "### [1] Subnet Detail ###" >> $OUTPUT_FILE
aws ec2 describe-subnets \
  --subnet-ids $SUBNET_ID \
  --region $REGION \
  --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone,State,VpcId]' \
  --output table >> $OUTPUT_FILE

# ----- 2. ENI（全リソース横断） -----
echo "" >> $OUTPUT_FILE
echo "### [2] Network Interfaces (ENI) ###" >> $OUTPUT_FILE
aws ec2 describe-network-interfaces \
  --filters Name=subnet-id,Values=$SUBNET_ID \
  --region $REGION \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,PrivateIpAddress,InterfaceType,Status,Description,Attachment.InstanceId]' \
  --output table >> $OUTPUT_FILE

# ----- 3. EC2インスタンス -----
echo "" >> $OUTPUT_FILE
echo "### [3] EC2 Instances ###" >> $OUTPUT_FILE
aws ec2 describe-instances \
  --filters Name=subnet-id,Values=$SUBNET_ID \
  --region $REGION \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table >> $OUTPUT_FILE

# ----- 4. RDS -----
echo "" >> $OUTPUT_FILE
echo "### [4] RDS Instances ###" >> $OUTPUT_FILE
aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?DBSubnetGroup.Subnets[?SubnetIdentifier=='$SUBNET_ID']].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,Engine,Endpoint.Address]" \
  --output table >> $OUTPUT_FILE

# ----- 5. ALB/NLB -----
echo "" >> $OUTPUT_FILE
echo "### [5] Load Balancers (ALB/NLB) ###" >> $OUTPUT_FILE
aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[?contains(AvailabilityZones[].SubnetId, '$SUBNET_ID')].[LoadBalancerName,Type,State.Code,DNSName]" \
  --output table >> $OUTPUT_FILE

# ----- 6. Lambda（VPC内） -----
echo "" >> $OUTPUT_FILE
echo "### [6] Lambda Functions (VPC) ###" >> $OUTPUT_FILE
aws lambda list-functions \
  --region $REGION \
  --query "Functions[?VpcConfig.SubnetIds && contains(VpcConfig.SubnetIds, '$SUBNET_ID')].[FunctionName,Runtime,State]" \
  --output table >> $OUTPUT_FILE

# ----- 7. ElastiCache -----
echo "" >> $OUTPUT_FILE
echo "### [7] ElastiCache Clusters ###" >> $OUTPUT_FILE
aws elasticache describe-cache-clusters \
  --region $REGION \
  --query "CacheClusters[?CacheSubnetGroupName!=''].[CacheClusterId,CacheNodeType,CacheClusterStatus,Engine]" \
  --output table >> $OUTPUT_FILE

# ----- 8. ECS タスク -----
echo "" >> $OUTPUT_FILE
echo "### [8] ECS Tasks ###" >> $OUTPUT_FILE
CLUSTERS=$(aws ecs list-clusters --region $REGION --query 'clusterArns[]' --output text)
for CLUSTER in $CLUSTERS; do
  TASKS=$(aws ecs list-tasks --cluster $CLUSTER --region $REGION --query 'taskArns[]' --output text)
  if [ -n "$TASKS" ]; then
    aws ecs describe-tasks \
      --cluster $CLUSTER \
      --tasks $TASKS \
      --region $REGION \
      --query "tasks[?attachments[?details[?name=='subnetId' && value=='$SUBNET_ID']]].[taskArn,lastStatus,taskDefinitionArn]" \
      --output table >> $OUTPUT_FILE
  fi
done

echo "" >> $OUTPUT_FILE
echo "=====================================================" >> $OUTPUT_FILE
echo " Export Complete: $OUTPUT_FILE" >> $OUTPUT_FILE
echo "=====================================================" >> $OUTPUT_FILE

echo "Done! -> $OUTPUT_FILE"
cat $OUTPUT_FILE
