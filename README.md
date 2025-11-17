# OOT-Monitoring

OOT 프로젝트를 위한 중앙 집중식 로그 모니터링 시스템입니다. Grafana + Loki + Promtail 스택을 사용하여 여러 서버의 로그를 한 곳에서 수집하고 시각화합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                      모니터링 서버                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Grafana  │  │   Loki   │  │ Promtail │                  │
│  │  :3000   │◄─┤  :3100   │◄─┤  :9080   │                  │
│  └──────────┘  └─────▲────┘  └──────────┘                  │
└────────────────────────┼──────────────────────────────────────┘
                         │ 로그 전송 (HTTP)
                         │
        ┌────────────────┴────────────────┐
        │                                  │
┌───────┴───────┐              ┌──────────┴─────────┐
│  개발 서버 #1  │              │   개발 서버 #2     │
│  ┌──────────┐ │              │   ┌──────────┐    │
│  │ Promtail │ │              │   │ Promtail │    │
│  │  :9080   │ │              │   │  :9080   │    │
│  └─────┬────┘ │              │   └─────┬────┘    │
│        │      │              │         │         │
│  ┌─────▼────┐ │              │   ┌─────▼────┐    │
│  │ /app-logs│ │              │   │ /app-logs│    │
│  └──────────┘ │              │   └──────────┘    │
└───────────────┘              └────────────────────┘
```

### 구성 요소

- **Grafana**: 로그 시각화 대시보드 (포트 3000)
- **Loki**: 로그 저장소 (포트 3100)
- **Promtail**: 로그 수집기 (포트 9080)

## 주요 기능

- 중앙 집중식 로그 수집 및 저장
- 실시간 로그 모니터링 및 검색
- 에러/예외 로그 필터링
- 환경별(dev, prod) 로그 구분
- Docker 컨테이너 로그 자동 수집
- 시스템 로그 수집

## 빠른 시작

### 1. 사전 요구사항

- Docker 및 Docker Compose 설치
- 모니터링 서버: Ubuntu/Amazon Linux 서버 (최소 2GB RAM 권장)
- 개발 서버: 로그를 전송할 애플리케이션 서버

### 2. 모니터링 서버 설정

#### 2-1. 저장소 클론

```bash
git clone <repository-url> OOT-Monitoring
cd OOT-Monitoring
```

#### 2-2. 환경 변수 설정

```bash
cp .env.example .env
nano .env  # 또는 vi .env
```

`.env` 파일에서 다음 값을 수정:

```env
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=YourStrongPassword  # 강력한 비밀번호로 변경
GRAFANA_PORT=3000
```

#### 2-3. 모니터링 스택 실행

```bash
# 배포 스크립트 실행
bash scripts/deploy-monitoring.sh

# 또는 직접 Docker Compose 실행
docker compose up -d
```

#### 2-4. 서비스 확인

```bash
# 컨테이너 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f
```

#### 2-5. Grafana 접속

1. 브라우저에서 `http://<모니터링서버IP>:3000` 접속
2. `.env`에 설정한 계정으로 로그인
3. **Dashboards** → **OOT Logs Dashboard** 선택

### 3. 개발 서버에 Promtail 설치

개발 서버에서 애플리케이션 로그를 모니터링 서버로 전송하려면:

#### 3-1. Promtail 설정 파일 생성

```bash
# promtail 디렉토리 생성
mkdir -p ~/promtail
cd ~/promtail

# 템플릿 파일 다운로드 (또는 수동으로 복사)
curl -o promtail-config.yml https://raw.githubusercontent.com/<your-repo>/main/promtail/promtail-config-dev-server.yml.template
```

#### 3-2. 설정 파일 수정

```bash
nano promtail-config.yml
```

다음 값을 수정:

1. **모니터링 서버 URL**: `<MONITORING_SERVER_IP>`를 실제 모니터링 서버 IP로 변경
   ```yaml
   clients:
     - url: http://10.0.1.100:3100/loki/api/v1/push  # 예시
   ```

2. **로그 파일 경로**: 애플리케이션 로그가 저장되는 실제 경로로 변경
   ```yaml
   scrape_configs:
     - job_name: spring-app-logs
       static_configs:
         - targets:
             - localhost
           labels:
             job: oot-dev
             environment: dev
             __path__: /var/log/myapp/*.log  # 실제 경로로 변경
   ```

#### 3-3. Promtail 실행

```bash
docker run -d \
  --name promtail \
  --restart unless-stopped \
  -v $(pwd)/promtail-config.yml:/etc/promtail/config.yml:ro \
  -v /var/log:/var/log:ro \
  -v /app-logs:/app-logs:ro \
  grafana/promtail:3.5.8 \
  -config.file=/etc/promtail/config.yml
```

#### 3-4. 방화벽 설정

**모니터링 서버**에서 Loki 포트 허용:

```bash
# Ubuntu/Debian
sudo ufw allow 3100/tcp

# AWS Security Group
# 인바운드 규칙 추가: TCP 3100, 소스: 개발서버 보안그룹 또는 IP
```

## GitHub Actions 자동 배포

`main` 브랜치에 push하면 자동으로 모니터링 서버에 배포됩니다.

### GitHub Secrets 설정

Repository Settings → Secrets and variables → Actions에서 다음 Secret 추가:

- `SERVER_IP`: 모니터링 서버 IP 주소
- `SSH_USERNAME`: SSH 접속 사용자명
- `SSH_PRIVATE_KEY`: SSH Private Key 전체 내용

### 수동 배포 트리거

Actions 탭에서 "CD Monitoring Stack" 워크플로우를 선택하고 "Run workflow" 클릭

## 대시보드 구성

### OOT Logs Dashboard

1. **All Logs**: 모든 서버의 전체 로그
2. **Log Count by Job**: job별 로그 개수 통계
3. **Error Logs**: 전체 에러/예외 로그
4. **Dev Server Logs**: 개발서버(job="oot-dev") 전용 로그
5. **Dev Server Error Logs**: 개발서버 에러 로그만 필터링

### 로그 검색 예시

Grafana의 Explore 메뉴에서 다음과 같은 쿼리 사용:

```logql
# 특정 job의 로그
{job="oot-dev"}

# 환경별 로그
{environment="dev"}

# 에러 로그만
{job="oot-dev"} |~ "(?i)(error|exception|fail|fatal)"

# 특정 키워드 검색
{job="oot-dev"} |= "NullPointerException"

# 시간 범위 지정하여 개수 세기
sum by (job) (count_over_time({job=~".+"}[1h]))
```

## 프로젝트 구조

```
OOT-Monitoring/
├── .github/
│   └── workflows/
│       └── cd-monitoring.yml        # GitHub Actions 배포 워크플로우
├── grafana/
│   ├── dashboards/
│   │   └── OOT-Logs.json           # 메인 로그 대시보드
│   └── provisioning/
│       ├── dashboards/             # 대시보드 자동 프로비저닝 설정
│       └── datasources/            # Loki 데이터소스 설정
├── loki/
│   └── loki-config.yml             # Loki 서버 설정
├── promtail/
│   ├── promtail-config.yml         # 모니터링 서버용 Promtail 설정
│   └── promtail-config-dev-server.yml.template  # 개발서버용 템플릿
├── scripts/
│   └── deploy-monitoring.sh        # 배포 자동화 스크립트
├── docker-compose.yml              # Docker Compose 설정
├── .env.example                    # 환경변수 템플릿
└── README.md
```

## 유용한 명령어

### Docker Compose 관리

```bash
# 서비스 시작
docker compose up -d

# 서비스 중지
docker compose down

# 특정 서비스만 재시작
docker compose restart grafana

# 로그 확인
docker compose logs -f
docker compose logs -f loki  # 특정 서비스만

# 컨테이너 상태 확인
docker compose ps

# 설정 파일 검증
docker compose config
```

### 로그 관리

```bash
# Loki 데이터 디렉토리 확인
docker volume ls

# 데이터 볼륨 백업
docker run --rm -v oot-monitoring_loki_data:/data -v $(pwd):/backup \
  busybox tar czf /backup/loki-backup-$(date +%Y%m%d).tar.gz /data

# 데이터 볼륨 완전 삭제 (주의!)
docker compose down -v
```

### Loki API 테스트

```bash
# Loki 상태 확인
curl http://localhost:3100/ready

# 레이블 목록 조회
curl http://localhost:3100/loki/api/v1/labels

# 특정 레이블의 값 조회
curl http://localhost:3100/loki/api/v1/label/job/values

# 로그 쿼리 (최근 1시간)
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="oot-dev"}' \
  --data-urlencode 'start=1h'
```

## 트러블슈팅

### Grafana에 로그가 표시되지 않는 경우

1. **Loki 상태 확인**
   ```bash
   docker compose logs loki
   curl http://localhost:3100/ready
   ```

2. **Promtail 상태 확인**
   ```bash
   docker compose logs promtail
   curl http://localhost:9080/metrics | grep promtail_targets_active_total
   ```

3. **Loki에 데이터가 들어오는지 확인**
   ```bash
   curl http://localhost:3100/loki/api/v1/labels
   ```

### 개발서버 로그가 수집되지 않는 경우

1. **네트워크 연결 확인**
   ```bash
   # 개발서버에서 실행
   telnet <모니터링서버IP> 3100
   curl http://<모니터링서버IP>:3100/ready
   ```

2. **Promtail 설정 확인**
   ```bash
   docker logs promtail
   ```

3. **로그 파일 경로 및 권한 확인**
   ```bash
   ls -la /var/log/myapp/
   # Promtail이 읽을 수 있는 권한이 있는지 확인
   ```

4. **방화벽/보안그룹 확인**
   - 모니터링 서버의 3100 포트가 개발서버 IP에서 접근 가능한지 확인

### 메모리 부족 오류

Loki나 Grafana가 메모리 부족으로 재시작되는 경우:

```bash
# docker-compose.yml에 메모리 제한 추가
services:
  loki:
    deploy:
      resources:
        limits:
          memory: 2G
```

## 보안 고려사항

1. **Grafana 관리자 비밀번호 변경**: 첫 로그인 후 반드시 변경
2. **Loki 포트 제한**: 3100 포트는 신뢰할 수 있는 IP만 접근 가능하도록 방화벽 설정
3. **HTTPS 적용**: 프로덕션 환경에서는 Nginx 등을 통해 HTTPS 적용 권장
4. **인증 강화**: Grafana OAuth 또는 LDAP 연동 고려

## 성능 최적화

- **로그 보관 기간**: `loki-config.yml`에서 `retention_period` 조정
- **로그 압축**: Loki는 자동으로 청크를 압축하여 저장
- **인덱싱 최적화**: 레이블을 너무 많이 사용하지 않도록 주의 (high cardinality 문제)

## 참고 자료

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/send-data/promtail/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/query/)

## 라이선스

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.

## 기여

이슈나 PR은 언제나 환영합니다!
