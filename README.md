# Google API 訪問方法實驗環境建置

## Terraform 操作步驟

請依照以下步驟執行 Terraform 指令：

1. 初始化 Terraform：
    ```bash
    terraform init
    ```

2. 更改 `terraform.tfvars` 參數成個人 GCP Project 和 Region

3. 計劃變更：
    ```bash
    terraform plan
    ```

4. 應用指定資源的變更：
    ```bash
    terraform apply -target=google_compute_address.gcp_ip_address -target=google_compute_address.onprem_ip_address
    ```

5. 應用所有變更：
    ```bash
    terraform apply
    ```

## 實驗結束後清除

環境清除:

```bash
terraform destroy
```
