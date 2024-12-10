PAT=$1
B64_PAT=$(echo -n $PAT | base64)
SECRET_CONTENT="{"auths":{"ghcr.io":{"auth":${B64_PAT}}}}"
B64_SECRET_CONTENT=$(echo -n $SECRET_CONTENT | base64)

SECRET_YAML="kind: Secret \n
type: kubernetes.io/dockerconfigjson \n
apiVersion: v1 \n
metadata: \n
\t name: dockerconfigjson-github-com \n
\t labels: \n
\t\t app: app-name \n
data: \n
\t .dockerconfigjson: ${B64_SECRET_CONTENT}"

echo -e $SECRET_YAML > secret.yaml
