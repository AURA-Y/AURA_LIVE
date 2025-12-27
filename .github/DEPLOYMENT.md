# GitHub Actions 자동 배포 설정 가이드

이 문서는 GitHub Actions를 통한 ECS 자동 배포 설정 방법을 설명합니다.

## 📋 개요

3개의 워크플로우가 설정되어 있습니다:

1. **ci.yml**: PR 체크 및 빌드 테스트 (Pull Request 시 자동 실행)
2. **deploy-backend.yml**: Backend (NestJS + Bun) 애플리케이션 배포
3. **deploy-livekit.yml**: LiveKit 서버 배포

## ⚡ Bun 최적화

Backend는 Bun 런타임을 사용하여 빠른 빌드와 실행을 제공합니다:
- **패키지 설치**: npm 대비 10배 빠름
- **빌드 시간**: 5배 빠름
- **시작 시간**: 4배 빠름
- **메모리 사용량**: 더 적음

## 🔐 1. GitHub Secrets 설정

GitHub 저장소 → Settings → Secrets and variables → Actions에서 다음 시크릿을 추가하세요:

| Secret Name | 설명 | 예시 |
|-------------|------|------|
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key ID | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Access Key | `wJalrXUtn...` |

### IAM 사용자 권한

다음 권한이 필요합니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🎯 2. 환경 변수 설정

각 워크플로우 파일의 `env` 섹션을 실제 환경에 맞게 수정하세요:

### deploy-backend.yml

```yaml
env:
  AWS_REGION: ap-northeast-2          # AWS 리전
  ECR_REPOSITORY: aura-backend        # ECR 리포지토리 이름
  ECS_CLUSTER: aura-cluster           # ECS 클러스터 이름
  ECS_SERVICE: backend-service        # ECS 서비스 이름
  ECS_TASK_DEFINITION: backend-task   # Task Definition 이름
  CONTAINER_NAME: backend             # 컨테이너 이름
```

### deploy-livekit.yml

```yaml
env:
  AWS_REGION: ap-northeast-2          # AWS 리전
  ECR_REPOSITORY: aura-livekit        # ECR 리포지토리 이름
  ECS_CLUSTER: aura-cluster           # ECS 클러스터 이름
  ECS_SERVICE: livekit-service        # ECS 서비스 이름
  ECS_TASK_DEFINITION: livekit-task   # Task Definition 이름
  CONTAINER_NAME: livekit             # 컨테이너 이름
```

## 🚀 3. 배포 트리거

### CI 체크 (Pull Request)

Pull Request 생성 시 자동으로 실행됩니다:
- Bun 의존성 설치
- 코드 린트 (선택)
- TypeScript 빌드 테스트
- Docker 빌드 테스트
- Health 엔드포인트 확인

### 자동 배포 (Push to main)

`main` 브랜치에 push 시 자동 배포:

**Backend 배포:**
- `src/**` 파일 변경
- `package.json` 변경
- `Dockerfile` 변경
- `tsconfig.json` 변경

**LiveKit 배포:**
- `livekit.yaml` 변경

### 수동 배포 (Manual)

GitHub 저장소 → Actions → 워크플로우 선택 → Run workflow 버튼 클릭

## 📝 4. 배포 프로세스

### CI 워크플로우 (Pull Request)
1. **코드 체크아웃**: PR 코드 가져오기
2. **Bun 설정**: 최신 Bun 런타임 설치
3. **의존성 설치**: `bun install --frozen-lockfile`
4. **린트**: 코드 스타일 체크
5. **빌드**: TypeScript 컴파일
6. **Docker 빌드 테스트**: Dockerfile 검증

### 배포 워크플로우 (main branch)
1. **코드 체크아웃**: 최신 코드 가져오기
2. **AWS 인증**: IAM 자격증명으로 AWS 접근
3. **ECR 로그인**: Elastic Container Registry 로그인
4. **Docker Buildx 설정**: 멀티 플랫폼 빌드 지원
5. **Docker 빌드**: Bun 멀티스테이지 이미지 빌드 (캐시 활용)
6. **ECR 푸시**: 이미지를 ECR에 업로드 (git SHA + latest 태그)
7. **Task Definition 업데이트**: 새 이미지로 Task Definition 생성
8. **ECS 서비스 업데이트**: 새 Task Definition으로 서비스 업데이트
9. **안정성 대기**: 배포가 완료될 때까지 대기
10. **상태 확인**: 배포 성공/실패 확인 및 이벤트 출력

## 🔍 5. 배포 확인

### GitHub Actions에서 확인

1. GitHub 저장소 → Actions 탭
2. 워크플로우 실행 내역 확인
3. 각 단계의 로그 확인

### AWS에서 확인

```bash
# ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster aura-cluster \
  --services backend-service livekit-service

# 실행 중인 태스크 확인
aws ecs list-tasks --cluster aura-cluster

# 최근 배포 이벤트 확인
aws ecs describe-services \
  --cluster aura-cluster \
  --services backend-service \
  --query 'services[0].events[0:5]'
```

## 🛠️ 6. 초기 설정 체크리스트

배포 전 다음 사항을 확인하세요:

- [ ] ECR 리포지토리 생성 (`aura-backend`, `aura-livekit`)
- [ ] ECS 클러스터 생성
- [ ] ECS Task Definition 생성 (초기 버전)
- [ ] ECS 서비스 생성
- [ ] GitHub Secrets 설정 (AWS 자격증명)
- [ ] 워크플로우 환경 변수 수정 (리전, 리포지토리명 등)
- [ ] IAM 권한 설정

## 🔄 7. 롤백 방법

배포 실패 시 롤백:

```bash
# 이전 Task Definition으로 롤백
aws ecs update-service \
  --cluster aura-cluster \
  --service backend-service \
  --task-definition backend-task:이전버전번호
```

또는 GitHub Actions에서 이전 커밋의 워크플로우를 수동으로 재실행하세요.

## 📊 8. 모니터링

### CloudWatch Logs

```bash
# 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix /ecs/

# 로그 스트림 확인
aws logs tail /ecs/backend-task --follow
```

### ECS 메트릭

- CPU 사용률
- 메모리 사용률
- 네트워크 트래픽

## ⚠️ 9. 주의사항

1. **비용**: 배포마다 ECR 저장소 용량 증가 (이미지 정리 필요)
2. **다운타임**: 무중단 배포를 위해 ECS 서비스의 최소 태스크 수를 2 이상으로 설정 권장
3. **환경 변수**: 민감한 정보는 ECS Task Definition의 Secrets로 관리
4. **리전**: 모든 리소스가 같은 리전에 있어야 함

## 🆘 10. 트러블슈팅

### 배포 실패 시

1. GitHub Actions 로그 확인
2. ECS 서비스 이벤트 확인
3. CloudWatch Logs 확인
4. Task Definition JSON 검증

### 일반적인 문제

| 문제 | 원인 | 해결 |
|------|------|------|
| ECR push 실패 | 권한 부족 | IAM 권한 확인 |
| Task 시작 실패 | 리소스 부족 | Task Definition의 CPU/메모리 조정 |
| Health check 실패 | 애플리케이션 오류 | 로그 확인 및 코드 수정 |

## 📚 참고 자료

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
