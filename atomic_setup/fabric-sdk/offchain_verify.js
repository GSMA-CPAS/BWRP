'use strict';

const { LoadCCP, ProtoLoader } = require('./LoadCCP');
const path = require('path');
const crypto = require('crypto');

async function main(argv1) {
        const loadCCP = new LoadCCP();

//link to the generated CCP file.
//please run ./generateCCP.sh to generate it.
        loadCCP.loadFile("/mnt/data/org1-example-com-pv-volume/peer/connection-example.com.json");

//mtls keys (copy a local copy or link)
        const mtls_cert ="/mnt/data/org1-example-com-pv-volume/peer/peers/peer0.org1.example.com/tls/server.crt"
        const mtls_key ="/mnt/data/org1-example-com-pv-volume/peer/peers/peer0.org1.example.com/tls/server.key"

        loadCCP.setTlsClientCertAndKey(mtls_cert, mtls_key);

        await loadCCP.setChannel(argv1);

//Payload from sender
        const payload = {
  "TXH": "6512358ba5f86fd98167bb82421e4ecf103e62651719f576b617e8877a7f13d6",
  "abc": 123
};



        const myself = await loadCCP.getTargets();
        const proposalResult = await loadCCP.getChannel().queryTransaction(payload['TXH'], myself[0], true, false);


        const creator = proposalResult.transactionEnvelope.payload.header.signature_header.creator.Mspid;
        console.log(creator);        
        const hash = crypto.createHmac('SHA256', creator).update(JSON.stringify(payload)).digest('base64');
        console.log(JSON.stringify(payload, null, 2));
        console.log(hash);

        const chaincode = proposalResult.transactionEnvelope.payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[1].namespace;
        const state_value = proposalResult.transactionEnvelope.payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[1].rwset.writes[0];
        console.log(state_value);

        if (state_value.key == payload["TXH"] && !state_value.is_delete && state_value.value == hash && chaincode == "offchain") {
                console.log("Payload is valid!");
        } else {
                console.log("Payload is NOT valid!");
        }
//        console.log(proposalResult.transactionEnvelope.payload.header);
//        console.log(proposalResult.transactionEnvelope.payload.data.actions[0].payload);
//console.log(JSON.stringify(proposalResult, null, 2));




return;
}

main("mychannel");
