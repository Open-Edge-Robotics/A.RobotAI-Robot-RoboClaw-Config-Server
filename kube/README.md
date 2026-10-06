# K3s 배포 가이드

이 디렉토리는 `ai-config-server` 프로젝트를 K3s(쿠버네티스) 환경에 배포하기 위한 YAML 매니페스트 모음입니다.  
내부망 서버로 사용하기 위해 인그레스(Ingress) 없이 구성되었으며, SQLite DB의 데이터 보존을 위해 K3s의 `local-path` 스토리지 클래스를 통한 영속 볼륨(PVC) 마운트와 설정 관리용 ConfigMap이 구현되어 있습니다.

---

## 1. 이미지 빌드 및 K3s 등록

쿠버네티스 노드에서 컨테이너 이미지를 로드할 수 있도록 먼저 빌드한 후 이미지를 K3s의 런타임(containerd)에 주입해야 합니다.

### A. Docker 이미지 빌드
프로젝트 루트 디렉토리에서 아래 명령을 실행합니다.
```bash
docker build -t ai-config-server:latest .
```

### B. K3s 이미지 임포트 (외부 레지스트리를 안 쓰는 경우)
외부 프라이빗 레지스트리를 사용하지 않고 로컬에서 빌드한 이미지를 직접 주입하는 경우, 아래 명령어를 실행합니다.
```bash
docker save lgecloudroboticstask/ai-config-server:latest | sudo k3s ctr images import -
```
> [!NOTE]
> 이미지가 정상적으로 등록되었는지 확인하려면 다음 명령을 사용합니다:
> `sudo k3s ctr images list | grep ai-config-server`

### C. Private Registry 자격 증명 등록 (외부 프라이빗 레지스트리 사용 시)
외부 프라이빗 도커 레지스트리(`lgecloudroboticstask` 등)에 이미지가 푸시되어 있고 K3s 클러스터가 이를 직접 풀(Pull)해야 하는 경우, 로컬의 도커 로그인 정보(`~/.docker/config.json`)를 기반으로 쿠버네티스 시크릿을 생성해야 합니다.

1. 먼저 `ai-config` 네임스페이스를 생성합니다.
   ```bash
   kubectl apply -f namespace.yaml
   ```
2. 로컬 도커 로그인 자격 증명을 기반으로 `regcred` 이름의 Secret을 생성합니다.
   ```bash
   kubectl create secret generic regcred \
     --from-file=.dockerconfigjson=$HOME/.docker/config.json \
     --type=kubernetes.io/dockerconfigjson \
     -n ai-config
   ```

---

## 2. 배포 및 관리

Kustomize가 포함되어 있으므로 디렉토리 내의 모든 매니페스트를 한 번에 적용할 수 있습니다.

### A. 서버 인증 Secret 생성
`ai-config-server`는 관리자 API와 디바이스 API 인증 토큰을 Kubernetes Secret에서 환경변수로 주입받습니다. 배포 전에 예시 파일을 복사해 실제 토큰으로 변경한 뒤 적용합니다.

```bash
kubectl apply -f namespace.yaml
cp secret.example.yaml secret.yaml
vi secret.yaml
kubectl apply -f secret.yaml
```

`secret.yaml`에는 실제 운영 토큰이 들어가므로 Git에 커밋하지 않습니다.

### B. 배포 적용
`kube` 폴더 안으로 이동하여 아래 명령을 사용해 배포를 적용합니다.
(위 단계에서 `regcred` 시크릿을 생성한 후 실행해야 Private Registry로부터 이미지를 정상적으로 가져옵니다.)
```bash
kubectl apply -k .
```

### C. 배포 상태 확인
```bash
# Pod 및 서비스 상태 조회
kubectl get all -n ai-config
```

### D. 서비스 노출 및 테스트
- **로컬 테스트 (포트 포워딩)**:
  배포된 서비스가 정상 작동하는지 확인하려면 포트 포워딩을 수행할 수 있습니다.
  ```bash
  kubectl port-forward -n ai-config svc/ai-config-server-service 8080:8080
  ```
  이후 브라우저에서 `http://localhost:8080` 또는 `http://localhost:8080/web/`로 접속이 가능합니다.

- **망내 외부 노출**:
  보안을 위해 서비스 타입이 `ClusterIP`로 설정되어 있습니다. 외부 및 동일 LAN 대역에 노출하려면 Ingress/LoadBalancer를 구성하거나, 필요한 경우 `service.yaml`의 타입을 `NodePort`로 변경하여 사용할 수 있습니다.

---

## 3. 리소스 구조 안내

- [namespace.yaml](file:///home/seoyc/Workspace/rcf/ai-config-server/kube/namespace.yaml): 격리된 배포 환경 `ai-config`을 구성합니다.
- [configmap.yaml](file:///home/seoyc/Workspace/rcf/ai-config-server/kube/configmap.yaml): 애플리케이션의 `config.yaml` 설정을 관리합니다.
- [pvc.yaml](file:///home/seoyc/Workspace/rcf/ai-config-server/kube/pvc.yaml): K3s 기본 `local-path` 스토리지 클래스를 기반으로 `/app/data` 디렉토리와 연동될 볼륨을 정의합니다.
- [deployment.yaml](file:///home/seoyc/Workspace/rcf/ai-config-server/kube/deployment.yaml): Pod replicas 1개 제약 조건(SQLite 파일 동시 쓰기 제약 방지) 및 환경 변수, 볼륨 서브패스 마운트를 설정합니다.
- [service.yaml](file:///home/seoyc/Workspace/rcf/ai-config-server/kube/service.yaml): 내부 통신 및 Ingress 연동을 위한 ClusterIP 서비스를 제공합니다.
