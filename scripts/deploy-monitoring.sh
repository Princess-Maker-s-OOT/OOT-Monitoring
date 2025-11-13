#!/bin/bash

# ============================================================
# 모니터링 스택 배포 스크립트
# ============================================================
# 이 스크립트는 Loki, Promtail, Grafana를 Docker Compose로 배포합니다.
#
# 사용법:
#   bash scripts/deploy-monitoring.sh
#
# 요구사항:
#   - Docker 및 Docker Compose 설치
#   - .env 파일 존재 (없으면 자동 생성)
#   - 실행 권한: chmod +x scripts/deploy-monitoring.sh
# ============================================================

set -e  # 에러 발생 시 즉시 중단

echo "==== 🛠  Deploying Monitoring Stack ===="
echo ""

# 프로젝트 루트 디렉토리로 이동 (스크립트 위치 기준)
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)
echo "📂 Project root: $PROJECT_ROOT"
echo ""

# ============================================================
# 1. 사전 확인
# ============================================================

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
  echo "❌ Error: Docker is not installed!"
  echo "Please install Docker first:"
  echo "  https://docs.docker.com/engine/install/"
  exit 1
fi

# Docker Compose 설치 확인
if ! docker compose version &> /dev/null; then
  echo "❌ Error: Docker Compose is not installed!"
  echo "Please install Docker Compose plugin:"
  echo "  https://docs.docker.com/compose/install/"
  exit 1
fi

echo "✅ Docker: $(docker --version)"
echo "✅ Docker Compose: $(docker compose version)"
echo ""

# .env 파일 확인 (필수)
if [ ! -f ".env" ]; then
  echo "❌ Error: .env file not found!"
  echo ""
  echo "Please create .env file first:"
  echo "  cat > .env << 'EOF'"
  echo "GRAFANA_ADMIN_USER=admin"
  echo "GRAFANA_ADMIN_PASSWORD=YourStrongPassword"
  echo "GRAFANA_PORT=3000"
  echo "EOF"
  echo ""
  exit 1
else
  echo "✅ .env file exists"
fi
echo ""

# ============================================================
# 2. 최신 Docker 이미지 Pull
# ============================================================

echo "📥 Pulling latest Docker images..."
echo "   - grafana/loki:3.5.8"
echo "   - grafana/promtail:3.5.8"
echo "   - grafana/grafana:latest"
echo ""

if docker compose pull; then
  echo "✅ Images pulled successfully"
else
  echo "❌ Failed to pull images"
  exit 1
fi
echo ""

# ============================================================
# 3. 기존 컨테이너 중지 및 삭제
# ============================================================

echo "🛑 Stopping existing containers..."
# 컨테이너가 없어도 에러 발생하지 않도록 처리
docker compose down 2>/dev/null || true
echo "✅ Old containers stopped and removed"
echo ""

# ============================================================
# 4. 새 버전 컨테이너 실행
# ============================================================

echo "🚀 Starting new containers..."
if docker compose up -d; then
  echo "✅ Containers started successfully"
else
  echo "❌ Failed to start containers"
  echo "Checking logs for errors..."
  docker compose logs --tail=50
  exit 1
fi
echo ""

# ============================================================
# 5. 컨테이너 헬스체크 대기
# ============================================================

echo "⏳ Waiting for services to be healthy..."
sleep 5  # 초기 시작 대기

# Loki 헬스체크 (최대 30초 대기)
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker compose exec -T loki wget --no-verbose --tries=1 --spider http://localhost:3100/ready 2>/dev/null; then
    echo "✅ Loki is healthy"
    break
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Warning: Loki health check timeout"
    echo "You can check logs with: docker compose logs loki"
  else
    echo "   Waiting for Loki... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 1
  fi
done
echo ""

# ============================================================
# 6. 실행 상태 확인
# ============================================================

echo "📊 Container Status:"
echo "===================="
docker compose ps
echo ""

# ============================================================
# 7. 완료 메시지
# ============================================================

# 서버 IP 가져오기 (가능한 경우)
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "=========================================="
echo "✅ Monitoring Stack Deployed Successfully!"
echo "=========================================="
echo ""
echo "📊 Grafana Dashboard:"
echo "   http://$SERVER_IP:3000"
echo "   Login: admin / admin (change after first login)"
echo ""
echo "🔍 Loki API:"
echo "   http://$SERVER_IP:3100"
echo "   Health: http://$SERVER_IP:3100/ready"
echo ""
echo "📝 Promtail:"
echo "   Metrics: http://$SERVER_IP:9080/metrics"
echo ""
echo "💡 Useful Commands:"
echo "   Check logs:       docker compose logs -f"
echo "   Check status:     docker compose ps"
echo "   Restart service:  docker compose restart <service>"
echo "   Stop all:         docker compose down"
echo "   View config:      docker compose config"
echo ""
echo "📚 Next Steps:"
echo "   1. Access Grafana and change admin password"
echo "   2. Navigate to Dashboards → OOT Logs Dashboard"
echo "   3. Setup alerts (optional)"
echo "   4. Configure Promtail on dev server to send logs"
echo ""
