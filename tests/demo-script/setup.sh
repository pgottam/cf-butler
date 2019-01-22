#!/usr/bin/env bash

## Create environment on PCF One consisting of one org and 3 spaces
## Deploys a collection of apps and services 
## then deploys cf-butler, cf-app-inventory-report, and cf-service-inventory-report

set -e

# Change me
export ORGS=( pivot-cphillipson )
export TODAY=`date +%Y-%m-%d`-$(uuidgen)
export DELAY=10m

cd ../../../
mkdir -p cf-butler-demo-$TODAY
cd cf-butler-demo-$TODAY

export SPACES=( dev test stage )
export REPOS1=( devops-workshop )
export REPOS2=( track-shipments )
export REPOS3=( jdbc-demo reactive-jdbc-demo )
export REPOS4=( spring-boot-gzip-compression-example )


## Build Phase

## Create app not bound to any services, leave it running
for r in "${REPOS2[@]}"
do
   git clone https://github.com/pacphi/$r
   cd $r
   gradle clean build
   cd ..
done

## Create app not bound to any services, then stop it
for x in "${REPOS4[@]}"
do
   git clone https://github.com/pacphi/$x
   cd $x
   gradle clean build
   cd ..
done

## Create apps and bind to services, then stop apps
for q in "${REPOS3[@]}"
do
   git clone https://github.com/pacphi/$q
   cd $q
   gradle clean build
   cd ..
done

## Create app bound to service, leave it running
for p in "${REPOS1[@]}"
do
   git clone https://github.com/Pivotal-Field-Engineering/$p
   cd $p/labs/solutions/03/cloud-native-spring
   gradle clean build
   cd ../../../../..
done


## Deployment Phase

for o in "${ORGS[@]}"
do
   #cf create-org $o

   for s in "${SPACES[@]}"
   do
      #cf create-space $s
      cf target -o $o -s $s

      ## Create app not bound to any services, leave it running
      for r in "${REPOS2[@]}"
      do
         cd $r
         cf push $r-$s -b java_buildpack_offline -s cflinuxfs3 -m 1G
         cd ..
      done

      ## Create app not bound to any services, then stop it
      for x in "${REPOS4[@]}"
      do
         cd $x
         cf push $x-$s -b java_buildpack_offline -s cflinuxfs3 -m 1G
         cf stop $x-$s
         cd ..
      done

      ## Create apps and bind to services, then stop apps
      for q in "${REPOS3[@]}"
      do
         cd $q
         cf push $q-$s -b java_buildpack_offline -s cflinuxfs3 -m 1G --no-start
         cf create-service postgresql-10-odb standalone postgres-$s -c ../../cf-butler/tests/demo-script/postgres.json
         sleep $DELAY
         cf bind-service $q-$s postgres-$s
         cf start $q-$s
         cf stop $q-$s
         cd ..
      done

      ## Create app bound to service, leave it running
      for p in "${REPOS1[@]}"
      do
         cd $p/labs/solutions/03/cloud-native-spring
         cf push $p-$s -b java_buildpack_offline -s cflinuxfs3 -m 1G --no-start
         cf create-service p.mysql db-small mysql-$s
         sleep $DELAY
         cf bind-service $p-$s mysql-$s
         cf start cloud-native-spring
         cd ../../../../..
      done

      ## Create service orphans 
      cf create-service p.redis cache-small redis-$s
      sleep $DELAY
      cf create-service p-service-registry standard service-registry-s$
      sleep $DELAY

   done
done


## Deploy cf-butler
cf target -o pivot-cphillipson -s system
git clone https://github.com/pacphi/cf-butler
cd cf-butler
gradle clean build
cf push --no-start
cf create-service credhub default cf-butler-secrets -c config/secrets.pcfone.json
cf bind-service cf-butler cf-butler-secrets
cf start cf-butler
cd ..


## Deploy cf-app-inventory-report
cf target -o pivot-cphillipson -s system
git clone https://github.com/pacphi/cf-app-inventory-report
cd cf-app-inventory-report
gradle clean build
cf push --no-start
cf create-service credhub default cf-app-inventory-report-secrets -c config/secrets.pcfone.json
cf bind-service cf-app-inventory-report cf-app-inventory-report-secrets
cf start cf-app-inventory-report
cd ..


## Deploy cf-app-inventory-report
cf target -o pivot-cphillipson -s system
git clone https://github.com/pacphi/cf-service-inventory-report
cd cf-service-inventory-report
gradle clean build
cf push --no-start
cf create-service credhub default cf-service-inventory-report-secrets -c config/secrets.pcfone.json
cf bind-service cf-service-inventory-report cf-service-inventory-report-secrets
cf start cf-service-inventory-report
cd ..
