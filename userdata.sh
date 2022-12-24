#INSTALL kubectl BINARY WITH CURL ON LINUX









# cat << EOF >> /home/ubuntu/nginx-deployment.yaml
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: nginx-deployment
# spec:
#   replicas: 1
#   selector:
#     matchLabels:
#       app: nginx
#   template:
#     metadata:
#       labels:
#         app: nginx
#     spec:
#       containers:
#       - name: nginx
#         image: nginx:latest
#         ports:
#         - containerPort: 80
# EOF