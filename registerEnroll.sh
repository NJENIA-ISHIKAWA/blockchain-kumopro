function setTLSCA() {
    infoln "enroll TLSCA admin"
    export PATH=${PWD}/bin:$PATH
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/tls-ca/tls-cert.pem
    export FABRIC_CA_CLIENT_HOME=${PWD}/tls-ca/admin
    sudo chmod 777 ${PWD}/tls-ca

    set -x
    fabric-ca-client enroll -d -u https://tls-ca-admin:tls-ca-adminpw@0.0.0.0:7052
    { set +x; } 2>/dev/null

    echo 'NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/0-0-0-0-7052.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/0-0-0-0-7052.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/0-0-0-0-7052.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/0-0-0-0-7052.pem
        OrganizationalUnitIdentifier: orderer' >"${PWD}/tls-ca/admin/msp/config.yaml"

    infoln "register id"
    fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1PW --id.type peer -u https://0.0.0.0:7052
    fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2PW --id.type peer -u https://0.0.0.0:7052
    fabric-ca-client register -d --id.name orderer1-org0 --id.secret ordererPW --id.type orderer -u https://0.0.0.0:7052
}

function setOrdererOrgCA() {
    infoln "enroll ordererOrgCA admin"
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrg/
    sudo chmod 777 ${PWD}/organizations

    set -x
    fabric-ca-client enroll -d -u https://rca-org0-admin:rca-org0-adminpw@0.0.0.0:7053
    { set +x; } 2>/dev/null

    sudo echo 'NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/0-0-0-0-7053.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/0-0-0-0-7053.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/0-0-0-0-7053.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/0-0-0-0-7053.pem
        OrganizationalUnitIdentifier: orderer' >"${PWD}/organizations/ordererOrg/msp/config.yaml"

    infoln "register id"
    fabric-ca-client register -d --id.name orderer1-org0 --id.secret ordererpw --id.type orderer -u https://0.0.0.0:7053
    fabric-ca-client register -d --id.name admin-org0 --id.secret org0adminpw --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://0.0.0.0:7053
}

function setOrg1CA() {
    infoln "enroll Org1CA admin"
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/org1/tls-cert.pem
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrgs/org1
    sudo mkdir ${PWD}/organizations/peerOrgs 
    sudo chmod 777 ${PWD}/organizations/peerOrgs

    set -x
    fabric-ca-client enroll -d -u https://rca-org1-admin:rca-org1-adminpw@0.0.0.0:7054
    { set +x; } 2>/dev/null

    sudo echo 'NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/0-0-0-0-7054.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/0-0-0-0-7054.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/0-0-0-0-7054.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/0-0-0-0-7054.pem
        OrganizationalUnitIdentifier: orderer' >"${PWD}/organizations/peerOrgs/org1/msp/config.yaml"

    infoln "register id"
    fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1PW --id.type peer -u https://0.0.0.0:7054
    fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2PW --id.type peer -u https://0.0.0.0:7054
    fabric-ca-client register -d --id.name admin-org1 --id.secret org1AdminPW --id.type admin -u https://0.0.0.0:7054
    fabric-ca-client register -d --id.name user-org1 --id.secret org1UserPW --id.type user -u https://0.0.0.0:7054
}

function setOrg1Peer() {

    infoln "enroll peer1-org1"
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrgs/org1/peers/peer1
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/org1/tls-cert.pem
    export FABRIC_CA_CLIENT_MSPDIR=msp
    sudo chmod 777 ${PWD}/organizations/peerOrgs

    set -x
    fabric-ca-client enroll -d -u https://peer1-org1:peer1PW@0.0.0.0:7054
    { set +x; } 2>/dev/null

    cp "${PWD}/organizations/peerOrgs/org1/msp/config.yaml" "${PWD}/organizations/peerOrgs/org1/peers/peer1/msp/config.yaml"

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrgs/org1
    export FABRIC_CA_CLIENT_MSPDIR=${PWD}/organizations/peerOrgs/org1/peers/peer1/tls-msp
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/tls-ca/tls-cert.pem

    set -x
    fabric-ca-client enroll -d -u https://peer1-org1:peer1PW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts peer1-org1
    { set +x; } 2>/dev/null

    sudo mv ${PWD}/organizations/peerOrgs/org1/peers/peer1/tls-msp/keystore/*_sk ${PWD}/organizations/peerOrgs/org1/peers/peer1/tls-msp/keystore/key.pem

    infoln "enroll peer2-org1"
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrgs/org1/peers/peer2
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/org1/tls-cert.pem
    export FABRIC_CA_CLIENT_MSPDIR=msp

    set -x
    fabric-ca-client enroll -d -u https://peer2-org1:peer2PW@0.0.0.0:7054
    { set +x; } 2>/dev/null

    cp "${PWD}/organizations/peerOrgs/org1/msp/config.yaml" "${PWD}/organizations/peerOrgs/org1/peers/peer2/msp/config.yaml"

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrgs/org1
    export FABRIC_CA_CLIENT_MSPDIR=${PWD}/organizations/peerOrgs/org1/peers/peer2/tls-msp
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/tls-ca/tls-cert.pem

    set -x
    fabric-ca-client enroll -d -u https://peer2-org1:peer2PW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts peer2-org1
    { set +x; } 2>/dev/null

    sudo mv ${PWD}/organizations/peerOrgs/org1/peers/peer2/tls-msp/keystore/*_sk ${PWD}/organizations/peerOrgs/org1/peers/peer2/tls-msp/keystore/key.pem

    infoln "enroll admin-org1"
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrgs/org1/users/admin@org1
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/org1/tls-cert.pem
    export FABRIC_CA_CLIENT_MSPDIR=msp

    set -x
    fabric-ca-client enroll -d -u https://admin-org1:org1AdminPW@0.0.0.0:7054
    { set +x; } 2>/dev/null

    cp "${PWD}/organizations/peerOrgs/org1/msp/config.yaml" "${PWD}/organizations/peerOrgs/org1/users/admin@org1/msp/config.yaml"
}

function setOrderer() {
    infoln "enroll orderer-org0"
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrg/orderers/orderer
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    export FABRIC_CA_CLIENT_MSPDIR=msp

    set -x
    fabric-ca-client enroll -d -u https://orderer1-org0:ordererpw@0.0.0.0:7053
    { set +x; } 2>/dev/null

    cp "${PWD}/organizations/ordererOrg/msp/config.yaml" "${PWD}/organizations/ordererOrg/orderers/orderer/msp/config.yaml"

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrg/orderers/orderer
    export FABRIC_CA_CLIENT_MSPDIR=tls-msp
    export FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/tls-ca/tls-cert.pem

    set -x
    fabric-ca-client enroll -d -u https://orderer1-org0:ordererPW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts orderer1-org0
    { set +x; } 2>/dev/null

    sudo mv ${PWD}/organizations/ordererOrg/orderers/orderer/tls-msp/keystore/*_sk ${PWD}/organizations/ordererOrg/orderers/orderer/tls-msp/keystore/key.pem

    infoln "enroll admin-org0"
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrg/orderers/users/admin@ordererOrg
    FABRIC_CA_CLIENT_TLS_CERTFILES=${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    export FABRIC_CA_CLIENT_MSPDIR=msp

    set -x
    fabric-ca-client enroll -d -u https://admin-org0:org0adminpw@0.0.0.0:7053
    { set +x; } 2>/dev/null
    cp "${PWD}/organizations/ordererOrg/msp/config.yaml" "${PWD}/organizations/ordererOrg/orderers/users/admin@ordererOrg/msp/config.yaml"
}
