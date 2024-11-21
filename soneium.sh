#!/bin/bash

# 색깔 변수 정의
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Soneium 노드 설치 및 설정 스크립트입니다.${NC}"
echo ""

# 작업 공간 경로 설정
WORK="/root/soneium-node"

# 기존 작업 공간이 존재하면 자동으로 삭제
if [ -d "$WORK" ]; then
    echo "기존 작업 공간을 삭제합니다: $WORK"
    rm -rf "$WORK"
fi

# 새 작업 공간 생성
echo "새 작업 공간을 생성합니다: $WORK"
mkdir -p "$WORK"

# Docker 및 Docker Compose 설치 확인
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
echo -e "${RED}Docker 또는 Docker Compose가 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"
sudo apt update && sudo apt install -y docker.io docker-compose
else
echo -e "${GREEN}Docker 및 Docker Compose가 이미 설치되어 있습니다.${NC}"
fi

# 설정 파일 준비
echo -e "${BOLD}${CYAN}설정 파일 준비 중...${NC}"
sudo apt update && sudo apt install -y openssl
sudo apt install -y netcat
sudo apt install -y ufw
git clone https://github.com/Soneium/soneium-node.git
cd soneium-node/minato
openssl rand -hex 32 > jwt.txt
cp sample.env .env

# VPS의 공개 IP 출력
public_ip=$(curl -s ifconfig.me)
echo -e "${YELLOW}현재 VPS의 공개 IP 주소: $public_ip${NC}"

# 사용자에게 IP 입력 요청
read -p "해당 IP가 노드의 공개 IP가 됩니다. (엔터): "

# 사용자 입력 받기
echo -e "${YELLOW}노드 설정에 필요한 정보를 입력해주세요:${NC}"
read -p "L1 Beacon URL을 입력하세요 (예: https://sepolia-beacon-l1.url): " l1_beacon

# 프라이빗 키와 메모닉 주소 입력 받기
read -p "프라이빗 키를 입력하세요: " private_key
read -p "메모닉 주소를 입력하세요: " mnemonic

# .env 파일 수정
sed -i "s|L1_BEACON=.*|L1_BEACON=$l1_beacon|g" .env
sed -i "s|P2P_ADVERTISE_IP=.*|P2P_ADVERTISE_IP=$public_ip|g" .env
echo "PRIVATE_KEY=$private_key" >> .env
echo "MNEMONIC=$mnemonic" >> .env

echo -e "${GREEN}.env 파일이 성공적으로 업데이트되었습니다.${NC}"

# 포트 사용 여부 확인 및 조정 함수
check_and_adjust_port() {
    local port=$1
    while nc -z localhost $port 2>/dev/null; do
        echo -e "${YELLOW}포트 $port가 사용 중입니다. ${port}+1 포트를 시도합니다.${NC}"
        port=$((port + 1))
    done
    echo $port
}

# Docker Compose 실행 전에 포트 확인 및 조정
echo -e "${BOLD}${CYAN}포트 사용 여부를 확인하고 조정합니다...${NC}"

PORT_8551=$(check_and_adjust_port 8551)
PORT_6060=$(check_and_adjust_port 6060)
PORT_8545=$(check_and_adjust_port 8545)
PORT_8546=$(check_and_adjust_port 8546)
PORT_30303=$(check_and_adjust_port 30303)

# docker-compose.yml 파일의 포트 매핑 수정
sed -i "s/8551:8551/$PORT_8551:8551/" docker-compose.yml
sed -i "s/6060:6060/$PORT_6060:6060/" docker-compose.yml
sed -i "s/8545:8545/$PORT_8545:8545/" docker-compose.yml
sed -i "s/8546:8546/$PORT_8546:8546/" docker-compose.yml
sed -i "s/30303:30303/$PORT_30303:30303/" docker-compose.yml

echo -e "${GREEN}포트 설정이 완료되었습니다:${NC}"
echo -e "op-geth-minato 서비스 포트:"
echo -e "  - Auth RPC: $PORT_8551"
echo -e "  - Metrics: $PORT_6060"
echo -e "  - HTTP RPC: $PORT_8545"
echo -e "  - WS RPC: $PORT_8546"
echo -e "  - P2P: $PORT_30303"

# UFW를 통해 포트 개방
echo -e "${BOLD}${CYAN}방화벽 포트를 개방합니다...${NC}"
sudo ufw allow $PORT_8551/tcp
sudo ufw allow $PORT_6060/tcp
sudo ufw allow $PORT_8545/tcp
sudo ufw allow $PORT_8546/tcp
sudo ufw allow $PORT_30303/tcp
echo -e "${GREEN}방화벽 포트 개방이 완료되었습니다.${NC}"

# Docker Compose 실행
echo -e "${BOLD}${CYAN}Docker Compose 실행 중...${NC}"
docker-compose up -d

echo -e "${GREEN}Docker를 통한 Soneium 노드 설치가 완료되었습니다.${NC}"
echo -e "${YELLOW}로그를 확인하려면 다음 명령어를 사용하세요:${NC}"
echo "docker-compose logs -f op-node-minato"

echo -e "${GREEN}Soneium 노드 설치 및 설정이 완료되었습니다.${NC}"
echo -e "${GREEN}스크립트 작성자: https://github.com/Soneium/soneium-node${NC}"
