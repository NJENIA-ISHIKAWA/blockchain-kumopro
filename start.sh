#!/bin/bash

export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

# infoln echos in blue color
function infoln() {
    println "${C_BLUE}${1}${C_RESET}"
}
# println echos string
function println() {
    echo -e "$1"
}

function clearContainers() {
    infoln "Removing remaining containers"
    docker rm -f $(docker ps -aq --filter name='org') 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter name='ca-tls') 2>/dev/null || true
}

function removeUnwantedImages() {
    infoln "Removing generated chaincode docker images"
    docker image rm -f $(docker images --filter=reference='hyperledger/*') 2>/dev/null || true
}

function networkDown() {
    infoln "remove directories[peerOrgs/ordererOrg/fabric-ca]"
    sudo rm -Rf organizations && sudo rm -Rf tls-ca
    # stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
    DOCKER_SOCK=$DOCKER_SOCK
    docker-compose -f $COMPOSE_FILE_BASE -f $COMPOSE_FILE_CA -f $COMPOSE_FILE_TLSCA down --volumes --remove-orphans
    # Don't remove the generated artifacts -- note, the ledgers are always removed
    # Bring down the network, deleting the volumes
    #Cleanup the chaincode containers
    clearContainers
    #Cleanup images
    removeUnwantedImages
    # remove orderer block and other channel configuration transactions and certs
    docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations'
    ## remove fabric ca artifacts
    docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/org1/msp organizations/fabric-ca/org1/tls-cert.pem organizations/fabric-ca/org1/ca-cert.pem organizations/fabric-ca/org1/IssuerPublicKey organizations/fabric-ca/org1/IssuerRevocationPublicKey organizations/fabric-ca/org1/fabric-ca-server.db'
    docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/org2/msp organizations/fabric-ca/org2/tls-cert.pem organizations/fabric-ca/org2/ca-cert.pem organizations/fabric-ca/org2/IssuerPublicKey organizations/fabric-ca/org2/IssuerRevocationPublicKey organizations/fabric-ca/org2/fabric-ca-server.db'
    docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/ordererOrg/msp organizations/fabric-ca/ordererOrg/tls-cert.pem organizations/fabric-ca/ordererOrg/ca-cert.pem organizations/fabric-ca/ordererOrg/IssuerPublicKey organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey organizations/fabric-ca/ordererOrg/fabric-ca-server.db'
    docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf addOrg3/fabric-ca/org3/msp addOrg3/fabric-ca/org3/tls-cert.pem addOrg3/fabric-ca/org3/ca-cert.pem addOrg3/fabric-ca/org3/IssuerPublicKey addOrg3/fabric-ca/org3/IssuerRevocationPublicKey addOrg3/fabric-ca/org3/fabric-ca-server.db'
    # remove channel and script artifacts
    docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
}

# Create Organization crypto material using cryptogen or CAs
function createOrgs() {
    infoln "remove directories[peerOrgs/ordererOrg/fabric-ca]"
    sudo rm -Rf organizations && sudo rm -Rf tls-ca

    if [ -d "system-genesis-block" ]; then
        infoln "remove genesis-block"
        rm -Rf system-genesis-block
    fi

    . registerEnroll.sh

    # Create crypto material using Fabric CA
    infoln "Generating certificates using Fabric TLSCA"
    docker-compose -f $COMPOSE_FILE_TLSCA up -d 2>&1

    while :; do
        if [ ! -f "tls-ca/tls-cert.pem" ]; then
            sleep 1
        else
            break
        fi
    done

    #set TLS
    setTLSCA

    # Create crypto material using Fabric CA
    infoln "Generating certificates using Fabric CA"
    docker-compose -f $COMPOSE_FILE_CA up -d 2>&1

    while :; do
        if [ ! -f "organizations/fabric-ca/org1/tls-cert.pem" ]; then
            sleep 1
        else
            break
        fi
    done

    # set Org1
    setOrg1CA
    setOrg1Peer

    #set Org2
    setOrg2CA
    setOrg2Peer

    # set OrdererOrg
    setOrdererOrgCA
    setOrderer

}

function createChannel() {
    set -x
    configtxgen -profile OrgsOrdererGenesis -outputBlock system-genesis-block/genesis.block -channelID syschannel
    { set +x; } 2>/dev/null

    cp system-genesis-block/genesis.block organizations/ordererOrg/orderers/orderer

    set -x
    configtxgen -profile OrgsChannel -outputCreateChannelTx channel-artifacts/channel.tx -channelID mychannel
    { set +x; } 2>/dev/null

    cp channel-artifacts/channel.tx organizations/peerOrgs/org1/peers/peer1
}

function networkUp() {
    createOrgs

    createChannel

    COMPOSE_FILES="-f ${COMPOSE_FILE_BASE}"

    DOCKER_SOCK="${DOCKER_SOCK}" docker-compose ${COMPOSE_FILES} up -d 2>&1

    docker ps -a
    if [ $? -ne 0 ]; then
        fatalln "Unable to start network"
    fi

}

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

# use this as the default docker-compose yaml definition
COMPOSE_FILE_BASE=docker/docker-compose-net.yaml
# certificate authorities compose file
COMPOSE_FILE_CA=docker/docker-compose-ca.yaml
COMPOSE_FILE_TLSCA=docker/docker-compose-tls-ca.yaml

## Parse mode
if [[ $# -lt 1 ]]; then
    "error"
    exit 0
else
    MODE=$1
    shift
fi

if [ "${MODE}" == "remove" ]; then
    networkDown
elif [ "${MODE}" == "up" ]; then
    networkUp
else
    #   printHelp
    exit 1
fi
