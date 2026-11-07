AWS_REGION="ap-south-1"
BACKEND_ECR_URI=$(terraform -chdir=terraform output -raw ecr_backend_repository_uri)
FRONTEND_ECR_URI=$(terraform -chdir=terraform output -raw ecr_frontend_repository_uri)

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${BACKEND_ECR_URI%/*}"

docker build -t $BACKEND_ECR_URI:latest ./application/backend
docker push $BACKEND_ECR_URI:latest

docker build -t $FRONTEND_ECR_URI:latest ./application/frontend
docker push $FRONTEND_ECR_URI:latest
