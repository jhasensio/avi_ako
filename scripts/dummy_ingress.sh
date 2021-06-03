#!/bin/bash
# Creates a simple loop to produce dummy ingress/ClusterIP services for an existing application
# Intended for testing AKO VS sharding

if [[ $# -ne 3 ]] ; then
    echo 'Usage: dummy_ingress.sh #ingresses action'
    echo " where  # ingresses = number of new ingress helloX that will be created"
    echo "        action = apply | delete"
    echo "        app = app name (e.g hello)
    echo "
    echo "   Example:"
    echo -e "\033[1;33m"./dummy_ingress.sh 5 apply hello"\033[0m"
    exit 0
fi


number=$1
action=$2
app=$3
i="1"

while [ $i -le $number ]
do
cat << EOF | kubectl $action -f -
apiVersion: v1
kind: Service
metadata:
  name: $app$i
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: $app
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $app$i
  labels:
    app: $app$i
spec:
  ingressClassName: critical-ic
  rules:
    - host: $app$i.avi.iberia.local
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: $app$i
              port:
                number: 8080
EOF
i=$[$i+1]
done
