# AURA Backend

NestJS 기반의 WebRTC 백엔드 서버입니다. LiveKit을 사용하여 실시간 통신을 제공합니다.

## Tech Stack

- **Framework**: NestJS
- **Runtime**: Bun
- **WebRTC**: LiveKit
- **Language**: TypeScript

## Prerequisites

- Bun >= 1.0
- Docker & Docker Compose (for containerized deployment)

## Getting Started

### 1. Environment Setup

```bash
# .env 파일 생성
cp .env.example .env
```

필요한 경우 `.env` 파일을 수정하세요.

### 2. Install Dependencies

```bash
bun install
```

### 3. Development

```bash
# 로컬 개발 (LiveKit은 Docker로 실행)
docker-compose up -d livekit
bun run dev

# 또는 전체를 Docker로 실행
docker-compose up
```

### 4. Build

```bash
bun run build
```

### 5. Production

```bash
bun run start
```

## Docker Deployment

### Using Docker Compose

```bash
# 전체 스택 실행 (LiveKit + Backend)
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 중지
docker-compose down
```

### Building Docker Image

```bash
# 빌드
docker build -t aura-backend .

# 실행
docker run -p 3001:3001 aura-backend
```

### VPC 구성
- VPC, Subnet, Internet Gateway 등의 인프라 설정
- Security Group 규칙
- EC2/ECS 배포 스크립트

## Project Structure

```
.
├── src/
│   ├── main.ts           # 애플리케이션 진입점
│   ├── app.module.ts     # 루트 모듈
│   └── room/             # 방 관련 모듈
├── dist/                 # 빌드 출력
├── aws/                  # AWS 배포 설정
├── docker-compose.yml    # Docker Compose 설정
├── livekit.yaml         # LiveKit 서버 설정
└── Dockerfile           # Docker 이미지 정의
```

## API Endpoints

- `POST /room/create` - 새 방 생성
- `POST /room/join` - 방 참여 토큰 생성
- 추가 API는 개발 중...

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LIVEKIT_API_KEY` | LiveKit API 키 | devkey |
| `LIVEKIT_API_SECRET` | LiveKit API 시크릿 | - |
| `LIVEKIT_URL` | LiveKit 서버 URL | ws://livekit:7880 |
| `PORT` | 서버 포트 | 3001 |

## TODO..
 현재 livekit.yaml 설정:
  - STUN 서버: Google 무료 STUN 서버 사용 중 (이미 설정됨)
  - TURN 서버: 설정 안 됨

  TURN 서버가 필요한 경우:
  - 방화벽이나 엄격한 NAT 환경에서 WebRTC 연결이 실패할 때
  - 프로덕션 환경에서 더 안정적인 연결을 원할 때

## License

MIT
