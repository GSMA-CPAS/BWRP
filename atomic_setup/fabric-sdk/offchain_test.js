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

        const endorser = await loadCCP.getEndorsementPlanTargets("offchain");

        const signer = loadCCP.getSigner(true);
        const txId = loadCCP.getTxID(true);

        const uuid = txId._transaction_id;

        const payload = {"TXH":uuid, "test":123, "example":"hello world"};
        

        const hash = crypto.createHmac('SHA256', "Org1MSP").update(JSON.stringify(payload)).digest('base64');

        console.log(JSON.stringify(payload, null, 2));
        console.log(hash);

        const request = {
                targets: endorser,
                chaincodeId: 'offchain',
                txId: txId,
                signer: signer,
                fcn: 'PutState',
                args: [uuid, hash]
        };

        const targeted = await loadCCP.getTargets(["Org2MSP"]);
        const target_request = {
                targets: targeted,
                chaincodeId: 'offchain',
                fcn: 'PutData',
                args: ["abc", JSON.stringify(payload)]
        };

        const channel_event_hubs = await loadCCP.getChannelEventHubsForOrg();

        loadCCP.getChannel().sendTransactionProposal(request).then((results) => {

                let event_monitor = new Promise((resolve, reject) => {
                        // do the housekeeping when there is a problem
                        let handle = setTimeout(() => {
                                channel_event_hubs[0].unregisterTxEvent(txId._transaction_id);
                                console.log('Timeout - Failed to receive the transaction event');
                                reject(new Error('Timed out waiting for block event'));
                        }, 20000);


                        // transaction listener waiting for Block to be written
                        channel_event_hubs[0].registerTxEvent(
                                txId._transaction_id, // listen to the same TXID
                                (tx, status, block_num) => {
                                        clearTimeout(handle);
                                        channel_event_hubs[0].unregisterTxEvent(txId._transaction_id);
                                        channel_event_hubs[0].disconnect();
                                        console.log(tx + "|" + status + "|" + block_num);
                                        resolve(status);
                                },
                                (err) => {
                                        channel_event_hubs[0].unregisterTxEvent(txId._transaction_id);
                                        console.log("Transaction listener has been deregistered");
                                },
                                {unregister: true, disconnect: true}
                        );


                        // connect to the event hub.
                        channel_event_hubs[0].connect({full_block: true}, (err, status) => {
                                if (err) {
                                        console.log(err);
                                }
                        });

                });

                //Submit Endorsed transaction to Orderer.
                let send_trans = loadCCP.getChannel().sendTransaction({proposalResponses: results[0], proposal: results[1], txId: txId});

                return Promise.all([event_monitor, send_trans]);
        }).then((results) => {
                if (results[0] == "VALID") {
                        console.log(results[1]);
                        //When we Confirm the Transaction has been written.
                        return loadCCP.getChannel().queryByChaincode(target_request, true);
                } else {
                        throw "sendTransaction Was not successful";
                }
        }).then((queryResult) => {
                for (let i = 0; i < queryResult.length; i++) {
                        console.log(queryResult[i].toString('utf8'));
                 }
//writing to local DB.
//To be done.
        }).catch((err) => {
                console.log(err);
        });


//        const transactionResponse = await loadCCP.getChannel().sendTransaction({
//                                                                  proposalResponses: proposalResult[0],
//                                                                  proposal: proposalResult[1]
//                                                                  });
//        console.log(transactionResponse);

return;
}

main("mychannel");
