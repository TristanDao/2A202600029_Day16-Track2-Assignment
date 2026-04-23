# 🚀 TinyLlama Deployment on GCP with Terraform

Dự án này triển khai một mô hình ngôn ngữ lớn (LLM) - **TinyLlama-1.1B** trên nền tảng Google Cloud Platform (GCP). Hệ thống được thiết kế với kiến trúc bảo mật, sử dụng Private Subnet và truy cập qua Global Load Balancer.

## 🏗️ Kiến trúc hệ thống

- **Networking:** VPC tùy chỉnh với 1 Private Subnet.
- **Security:**
  - Truy cập Internet qua Cloud NAT (cho phép VM tải model nhưng không cho phép Internet truy cập trực tiếp VM).
  - Firewall chỉ cho phép Health Check của Google và SSH qua IAP.
- **Compute:** Instance `e2-medium` chạy Ollama server.
- **Load Balancing:** Global HTTP Load Balancer đóng vai trò Gateway, cung cấp Public IP cố định.
- **AI Engine:** Ollama chạy TinyLlama, đi kèm một Flask Proxy để tương thích với chuẩn OpenAI API.

## 🛠️ Các thành phần đã triển khai

| Thành phần         | Công nghệ           | Port  |
| ------------------ | ------------------- | ----- |
| **Infrastructure** | Terraform           | -     |
| **Model Server**   | Ollama              | 11434 |
| **API Proxy**      | Flask (Python)      | 8000  |
| **Public IP**      | GCP Forwarding Rule | 80    |

## 🚀 Hướng dẫn triển khai

### 1. Khởi tạo hạ tầng

```bash
cd terraform-gcp
terraform init
terraform apply -auto-approve
```

### 2. Kiểm tra API

Hệ thống cung cấp 2 endpoint chính thông qua Load Balancer IP:

- **Health Check:** `http://<LB_IP>/health`
- **Chat API:** `http://<LB_IP>/v1/chat/completions`

**Ví dụ gọi API bằng cURL:**

```bash
curl -X POST http://<LB_IP>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "Chào bạn, bạn là ai?"}]
  }' | python3 -m json.tool
```

## 📊 Kết quả đạt được

- **Deployment thành công:** Hệ thống tự động cài đặt Ollama và pull model TinyLlama ngay khi khởi tạo (Startup Script).
- **Tính sẵn sàng:** Load Balancer tự động kiểm tra sức khỏe VM qua `/health` trước khi điều phối traffic.
- **Hiệu năng:** Model chạy mượt mà trên CPU `e2-medium` nhờ tối ưu hóa của Ollama.

## 🧹 Dọn dẹp tài nguyên

Để tránh phát sinh chi phí sau khi hoàn thành Lab:

```bash
cd terraform-gcp
terraform destroy -auto-approve
```

---

**Thông tin bài Lab:**

- **Sinh viên:** Đào Phước Thịnh
- **MSSV:** 2A202600029
- **LB IP đã test:** `34.54.223.148`
- **Region:** asia-southeast1 (Singapore)

---
