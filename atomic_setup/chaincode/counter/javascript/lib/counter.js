/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Contract } = require('fabric-contract-api');

class Counter extends Contract {

    async initLedger(ctx) {
        console.info('============= START : Initialize Ledger ===========');

        const state = {
            count: 0
        };


        await ctx.stub.putState('STATE', Buffer.from(JSON.stringify(state)));
        console.info('Initialized <--> ', state);
        console.info('============= END : Initialize Ledger ===========');
    }

    async increaseCount(ctx) {
        console.info('============= START : Increase Count ===========');

        const currentAsBytes = await ctx.stub.getState('STATE'); // get the car from chaincode state
        if (!currentAsBytes || currentAsBytes.length === 0) {
            throw new Error(`NOT Initialized`);
        }
        const current = JSON.parse(currentAsBytes.toString());
        current.count++;

        await ctx.stub.putState('STATE', Buffer.from(JSON.stringify(current)));
        console.info('============= END : Increase Count ===========');
    }

    async queryCount(ctx) {
        const currentAsBytes = await ctx.stub.getState('STATE'); // get the car from chaincode state
        if (!currentAsBytes || currentAsBytes.length === 0) {
            throw new Error(`NOT Initialized`);
        }
        console.log(currentAsBytes.toString());
        return currentAsBytes.toString();
    }


}

module.exports = Counter;
