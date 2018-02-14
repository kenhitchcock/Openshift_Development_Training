#!/bin/bash

oc new-project kh-nexus
oc new-app sonatype/nexus3:latest
oc rollout pause dc/nexus3
oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
oc set resources dc nexus3 --limits=memory=2Gi --requests=memory=1Gi
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc 
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -
oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc
oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/
oc rollout resume dc/nexus3
oc expose svc nexus3
for ((i=1;i<=120;i++)); 
do 
echo "Waiting $i secs" 
sleep 1
done
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')
rm -rf setup_nexus3.sh

ROUTE=`oc get routes | grep -v HOST | awk '{print $2}'`
echo "Nexus is now available at https://$ROUTE"
