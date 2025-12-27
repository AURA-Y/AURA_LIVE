#!/bin/bash

# AURA Backend - AWS 리소스 확인 및 워크플로우 설정 자동 업데이트 스크립트

set -e

echo "🔍 AWS 리소스 확인 중..."
echo ""

# AWS 리전 설정
REGION="${AWS_REGION:-ap-northeast-2}"
echo "📍 리전: $REGION"
echo ""

# ECR 리포지토리 확인
echo "📦 ECR 리포지토리 목록:"
echo "===================="
ECR_REPOS=$(aws ecr describe-repositories \
  --region $REGION \
  --query 'repositories[*].[repositoryName]' \
  --output text 2>/dev/null || echo "")

if [ -z "$ECR_REPOS" ]; then
  echo "⚠️  ECR 리포지토리를 찾을 수 없습니다."
  echo "   다음 명령어로 생성하세요:"
  echo "   aws ecr create-repository --repository-name aura-backend --region $REGION"
  echo "   aws ecr create-repository --repository-name aura-livekit --region $REGION"
  echo ""
  BACKEND_ECR="aura-backend"
  LIVEKIT_ECR="aura-livekit"
else
  echo "$ECR_REPOS"
  echo ""

  # Backend ECR 찾기
  BACKEND_ECR=$(echo "$ECR_REPOS" | grep -i backend | head -1 || echo "aura-backend")
  LIVEKIT_ECR=$(echo "$ECR_REPOS" | grep -i livekit | head -1 || echo "aura-livekit")
fi

echo "✅ Backend ECR: $BACKEND_ECR"
echo "✅ LiveKit ECR: $LIVEKIT_ECR"
echo ""

# ECS 클러스터 확인
echo "🎯 ECS 클러스터 목록:"
echo "===================="
CLUSTERS=$(aws ecs list-clusters \
  --region $REGION \
  --query 'clusterArns[*]' \
  --output text 2>/dev/null || echo "")

if [ -z "$CLUSTERS" ]; then
  echo "⚠️  ECS 클러스터를 찾을 수 없습니다."
  echo "   다음 명령어로 생성하세요:"
  echo "   aws ecs create-cluster --cluster-name aura-cluster --region $REGION"
  echo ""
  CLUSTER_NAME="aura-cluster"
else
  # ARN에서 클러스터 이름 추출
  for cluster_arn in $CLUSTERS; do
    cluster_name=$(echo $cluster_arn | awk -F'/' '{print $NF}')
    echo "- $cluster_name"
  done
  echo ""

  # 첫 번째 클러스터 사용 (또는 aura가 들어간 클러스터 찾기)
  CLUSTER_NAME=$(echo "$CLUSTERS" | tr '\t' '\n' | grep -i aura | head -1 | awk -F'/' '{print $NF}' || echo $CLUSTERS | tr '\t' '\n' | head -1 | awk -F'/' '{print $NF}')
fi

echo "✅ 클러스터: $CLUSTER_NAME"
echo ""

# ECS 서비스 확인
echo "⚙️  ECS 서비스 목록:"
echo "===================="
SERVICES=$(aws ecs list-services \
  --cluster $CLUSTER_NAME \
  --region $REGION \
  --query 'serviceArns[*]' \
  --output text 2>/dev/null || echo "")

if [ -z "$SERVICES" ]; then
  echo "⚠️  ECS 서비스를 찾을 수 없습니다."
  echo "   클러스터에 서비스가 배포되지 않았습니다."
  echo ""
  BACKEND_SERVICE="backend-service"
  LIVEKIT_SERVICE="livekit-service"
else
  for service_arn in $SERVICES; do
    service_name=$(echo $service_arn | awk -F'/' '{print $NF}')
    echo "- $service_name"
  done
  echo ""

  # Backend와 LiveKit 서비스 찾기
  BACKEND_SERVICE=$(echo "$SERVICES" | tr '\t' '\n' | grep -i backend | head -1 | awk -F'/' '{print $NF}' || echo "backend-service")
  LIVEKIT_SERVICE=$(echo "$SERVICES" | tr '\t' '\n' | grep -i livekit | head -1 | awk -F'/' '{print $NF}' || echo "livekit-service")
fi

echo "✅ Backend 서비스: $BACKEND_SERVICE"
echo "✅ LiveKit 서비스: $LIVEKIT_SERVICE"
echo ""

# Task Definition 확인
echo "📋 Task Definition 목록:"
echo "===================="
TASK_DEFS=$(aws ecs list-task-definitions \
  --region $REGION \
  --family-prefix backend \
  --query 'taskDefinitionArns[*]' \
  --output text 2>/dev/null || echo "")

if [ -z "$TASK_DEFS" ]; then
  echo "⚠️  Task Definition을 찾을 수 없습니다."
  BACKEND_TASK="backend-task"
  LIVEKIT_TASK="livekit-task"
else
  # 최신 Task Definition family 이름 추출
  BACKEND_TASK=$(echo "$TASK_DEFS" | tr '\t' '\n' | head -1 | awk -F'/' '{print $NF}' | cut -d':' -f1 || echo "backend-task")

  # LiveKit Task Definition
  LIVEKIT_TASKS=$(aws ecs list-task-definitions \
    --region $REGION \
    --family-prefix livekit \
    --query 'taskDefinitionArns[*]' \
    --output text 2>/dev/null || echo "")
  LIVEKIT_TASK=$(echo "$LIVEKIT_TASKS" | tr '\t' '\n' | head -1 | awk -F'/' '{print $NF}' | cut -d':' -f1 || echo "livekit-task")

  echo "- $BACKEND_TASK"
  echo "- $LIVEKIT_TASK"
fi

echo ""
echo "✅ Backend Task Definition: $BACKEND_TASK"
echo "✅ LiveKit Task Definition: $LIVEKIT_TASK"
echo ""

# 설정 요약
echo "📊 설정 요약"
echo "===================="
echo "리전: $REGION"
echo ""
echo "Backend:"
echo "  ECR: $BACKEND_ECR"
echo "  Service: $BACKEND_SERVICE"
echo "  Task Definition: $BACKEND_TASK"
echo ""
echo "LiveKit:"
echo "  ECR: $LIVEKIT_ECR"
echo "  Service: $LIVEKIT_SERVICE"
echo "  Task Definition: $LIVEKIT_TASK"
echo ""
echo "Cluster: $CLUSTER_NAME"
echo ""

# 워크플로우 파일 업데이트
echo "🔧 워크플로우 파일 업데이트 중..."

WORKFLOW_DIR="$(dirname "$0")/../workflows"

# Backend 워크플로우 업데이트
if [ -f "$WORKFLOW_DIR/deploy-backend.yml" ]; then
  sed -i.bak \
    -e "s/AWS_REGION: .*/AWS_REGION: $REGION/" \
    -e "s/ECR_REPOSITORY: .*/ECR_REPOSITORY: $BACKEND_ECR/" \
    -e "s/ECS_CLUSTER: .*/ECS_CLUSTER: $CLUSTER_NAME/" \
    -e "s/ECS_SERVICE: .*/ECS_SERVICE: $BACKEND_SERVICE/" \
    -e "s/ECS_TASK_DEFINITION: .*/ECS_TASK_DEFINITION: $BACKEND_TASK/" \
    "$WORKFLOW_DIR/deploy-backend.yml"
  echo "✅ deploy-backend.yml 업데이트 완료"
fi

# LiveKit 워크플로우 업데이트
if [ -f "$WORKFLOW_DIR/deploy-livekit.yml" ]; then
  sed -i.bak \
    -e "s/AWS_REGION: .*/AWS_REGION: $REGION/" \
    -e "s/ECR_REPOSITORY: .*/ECR_REPOSITORY: $LIVEKIT_ECR/" \
    -e "s/ECS_CLUSTER: .*/ECS_CLUSTER: $CLUSTER_NAME/" \
    -e "s/ECS_SERVICE: .*/ECS_SERVICE: $LIVEKIT_SERVICE/" \
    -e "s/ECS_TASK_DEFINITION: .*/ECS_TASK_DEFINITION: $LIVEKIT_TASK/" \
    "$WORKFLOW_DIR/deploy-livekit.yml"
  echo "✅ deploy-livekit.yml 업데이트 완료"
fi

# 백업 파일 제거
rm -f "$WORKFLOW_DIR"/*.bak

echo ""
echo "✅ 모든 워크플로우 파일이 업데이트되었습니다!"
echo ""
echo "📝 다음 단계:"
echo "1. git add .github/"
echo "2. git commit -m 'Update workflow with actual AWS resource names'"
echo "3. git push origin main"
