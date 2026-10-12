#!/bin/bash
set -e

# ========================================================
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# ========================================================

echo "=========================================================="
echo "BƯỚC 1: Dọn dẹp tài nguyên cũ nếu có"
echo "=========================================================="
docker rm -f app-container db-server 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true

echo "=========================================================="
echo "BƯỚC 2: Tạo Custom Bridge Network: app-net"
echo "=========================================================="
docker network create app-net
docker network ls | grep app-net

echo "=========================================================="
echo "BƯỚC 3: Tạo Named Volume: db-data"
echo "=========================================================="
docker volume create db-data
docker volume ls | grep db-data

echo "=========================================================="
echo "BƯỚC 4: Khởi chạy Database Container (PostgreSQL 15 Alpine)"
echo "=========================================================="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=app_db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword123 \
  postgres:15-alpine

echo "Đang đợi PostgreSQL khởi động sẵn sàng (5 giây)..."
sleep 5

echo "=========================================================="
echo "BƯỚC 5: Khởi chạy Backend Container tham gia app-net"
echo "=========================================================="
# Kiểm tra nếu chưa có image hw-backend:multistage thì tự động build từ ex3
if ! docker image inspect hw-backend:multistage >/dev/null 2>&1; then
  echo "Chưa tìm thấy image hw-backend:multistage, tiến hành build từ ex3..."
  docker build -t hw-backend:multistage ../ex3
fi

docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -p 3000:3000 \
  hw-backend:multistage

echo "=========================================================="
echo "BƯỚC 6: Kiểm tra DNS Resolution (Ping từ app-container sang db-server)"
echo "=========================================================="
docker exec app-container ping -c 2 db-server

echo "=========================================================="
echo "BƯỚC 7: Test Data Persistence (Lưu trữ dữ liệu bền vững)"
echo "=========================================================="
echo "7.1. Tạo bảng và thêm dữ liệu vào db-server:"
docker exec -i db-server psql -U postgres -d app_db -c "
CREATE TABLE IF NOT EXISTS test_data (
    id SERIAL PRIMARY KEY,
    content VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_data (content) VALUES ('Session 10 Persistent Data Verification');
SELECT * FROM test_data;
"

echo "7.2. Xóa cứng container db-server (docker rm -f db-server):"
docker rm -f db-server

echo "7.3. Khởi chạy lại container DB mới gắn cùng Volume db-data:"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=app_db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword123 \
  postgres:15-alpine

echo "Đang đợi container DB mới khởi động sẵn sàng (5 giây)..."
sleep 5

echo "7.4. Xác minh dữ liệu vẫn nguyên vẹn:"
docker exec -i db-server psql -U postgres -d app_db -c "SELECT * FROM test_data;"

echo "=========================================================="
echo "HOÀN TẤT: Kiểm tra Bài 4 thành công 100%!"
echo "=========================================================="
