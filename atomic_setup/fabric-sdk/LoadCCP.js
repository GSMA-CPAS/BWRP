/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const Client = require('fabric-client');
      Client.addConfigFile('default.json');
const fs = require('fs');

const LoadCCP = class  {

        constructor() {
                this._network_config = null;
                this._client = new Client();
                this._channel = null;
        }

        loadFile(filename) {
                this._network_config = filename;
                this._client.loadFromConfig(this._network_config); 
        }

        async setTlsClientCertAndKey(clientCert, clientKey) {
                let clientCertBuff = fs.readFileSync(clientCert);
                let clientKeyBuff = fs.readFileSync(clientKey);
                this._client.setTlsClientCertAndKey(Buffer.from(clientCertBuff).toString(), Buffer.from(clientKeyBuff).toString());
        }

        async setUser(user, privateKey, signedCert) {
                const cryptoContentOrgAdmin = {
                        privateKey: privateKey,
                        signedCert: signedCert
                }
                await this._client.createUser({
                        username: user,
                        mspid: this._client.getMspid(),
                        cryptoContent: cryptoContentOrgAdmin,
                        skipPersistence: true
                });
                return;
        }

        async setChannel(name) {
                this._channel = await this._client.newChannel(name);
                for (const peer of this._client.getPeersForOrg()) {
                        this._channel.addPeer(peer, this._client.getMspid());
                }
                return
        }

        getChannel() {
                return this._channel;
        }

        getSigner(admin) {
                return this._client._getSigningIdentity(admin);
        }

        getTxID(admin) {
                return this._client.newTransactionID(admin);
        }

        async getTargets(msp) {
                //refresh discovery
                await this._channel.getDiscoveryResults();
                let targets = [];
                if (msp) {
                        for (const key of msp) {
                                const msp_peer = this._channel.getPeersForOrg(key);
                                if (msp_peer.length > 0) {
                                        for (const peer of msp_peer) {
                                                targets.push(peer);
                                        }
                                } else {
                                        console.log("WARN: %s Not Found is Discovery Service", key);
                                }
                        }
                } else {
                        for (const peer of this._channel.getPeersForOrg(this._client.getMspid())) {
                                targets.push(peer);
                        }
                }
                return targets;
        }

        async getEndorsementPlanTargets(name) {
                const plan = await this._channel.getEndorsementPlan({chaincodes:[{name: name}]});
                let msp_list = [];
                for (const peer in plan.groups) {
                        const peers = plan.groups[peer].peers;
                        for (const msp in peers) {
                                if (!msp_list[peers[msp].mspid]) {
                                        msp_list.push(peers[msp].mspid);
                                }
                        }
                }
                return this.getTargets(msp_list);
        }

        async getChannelEventHubsForOrg() {
                return await this._channel.getChannelEventHubsForOrg(this._client.getMspid());
        }

        getProtoLoader() {
              return ProtoLoader;
        }
}

module.exports.LoadCCP = LoadCCP;
module.exports.ProtoLoader = ProtoLoader;

