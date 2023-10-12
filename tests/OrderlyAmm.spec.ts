import { Blockchain, SandboxContract, TreasuryContract } from '@ton-community/sandbox';
import { toNano } from 'ton-core';
import { OrderlyAmm } from '../wrappers/OrderlyAmm';
import '@ton-community/test-utils';

describe('OrderlyAmm', () => {
    let blockchain: Blockchain;
    let orderlyAmm: SandboxContract<OrderlyAmm>;
    let owner: SandboxContract<TreasuryContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        owner = await blockchain.treasury('owner');

        orderlyAmm = blockchain.openContract(await OrderlyAmm.fromInit(owner.address));

        const deployer = await blockchain.treasury('deployer');

        const deployResult = await orderlyAmm.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: orderlyAmm.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and orderlyAmm are ready to use
    });

    it('should increase counter', async () => {
        const increaseTimes = 3;
        for (let i = 0; i < increaseTimes; i++) {
            console.log(`increase ${i + 1}/${increaseTimes}`);

            const increaser = await blockchain.treasury('increaser' + i);

            const counterBefore = await orderlyAmm.getCounter();

            console.log('counter before increasing', counterBefore);

            const increaseBy = BigInt(Math.floor(Math.random() * 100));

            console.log('increasing by', increaseBy);

            const increaseResult = await orderlyAmm.send(
                increaser.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: 'Add',
                    queryId: 0n,
                    amount: increaseBy,
                }
            );

            expect(increaseResult.transactions).toHaveTransaction({
                from: increaser.address,
                to: orderlyAmm.address,
                success: true,
            });

            const counterAfter = await orderlyAmm.getCounter();

            console.log('counter after increasing', counterAfter);

            expect(counterAfter).toBe(counterBefore + increaseBy);
        }
    });
});
