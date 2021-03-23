#!/bin/bash

kubectl create serviceaccount cluster-user
kubectl create clusterrolebinding cluster-user-binding --clusterrole=cluster-admin --serviceaccount=default:cluster-user
SECRET=$(kubectl get secrets | grep cluster-user |  awk '{print $1}')

echo "Secret is ${SECRET}"

export TOKEN=$(kubectl get secret ${SECRET} -o=jsonpath="{.data.token}" | base64 -D -i -)

echo "Token is ${TOKEN}"

CADATA=$(kubectl config view --minify=true --raw | grep  'certificate-authority-data:' | awk '{print $2}')
APISERVER=$(kubectl config view --minify=true --raw | grep  'server' | awk '{print $2}')
echo "Certificate Authority Data is ${CADATA}"

echo "Creating the K8S config file ./k8sconfig"

echo "apiVersion: v1" > ./k8sconfig
echo "clusters:" >> ./k8sconfig
echo "- cluster:" >> ./k8sconfig
echo "    certificate-authority-data: ${CADATA}" >> ./k8sconfig
echo "    server: ${APISERVER}" >> ./k8sconfig
echo "  name: k8s" >> ./k8sconfig
echo "contexts:" >> ./k8sconfig
echo "- context:" >> ./k8sconfig
echo "    cluster: k8s" >> ./k8sconfig
echo "    user: cluster-user" >> ./k8sconfig
echo "  name: k8scontext" >> ./k8sconfig
echo "current-context: k8scontext" >> ./k8sconfig
echo "kind: Config" >> ./k8sconfig
echo "preferences: {}" >> ./k8sconfig
echo "users:" >> ./k8sconfig
echo "- name: cluster-user" >> ./k8sconfig
echo "  user:" >> ./k8sconfig
echo "    token: ${TOKEN}" >> ./k8sconfig
