import { Blockchain, SandboxContract, TreasuryContract } from '@ton-community/sandbox';
import { SendMode, beginCell, toNano } from 'ton-core';
import { OrderlyAmm } from '../wrappers/OrderlyAmm';
import '@ton-community/test-utils';
import { JettonMaster } from '../wrappers/JettonMaster';
import { buildOnchainMetadata } from './utils/helpers';
import { JettonWallet } from '../wrappers/JettonWallet';

describe('OrderlyAmm', () => {
    let blockchain: Blockchain;
    let orderlyAmm: SandboxContract<OrderlyAmm>;
    let owner: SandboxContract<TreasuryContract>;

    let tokenA: SandboxContract<JettonMaster>;
    let ownerJettonA: SandboxContract<JettonWallet>;
    let orderlyJettonA: SandboxContract<JettonWallet>;

    let tokenB: SandboxContract<JettonMaster>;
    let ownerJettonB: SandboxContract<JettonWallet>;
    let orderlyJettonB: SandboxContract<JettonWallet>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        owner = await blockchain.treasury('owner');

        orderlyAmm = blockchain.openContract(await OrderlyAmm.fromInit(owner.address));

        tokenA = blockchain.openContract(
            await JettonMaster.fromInit(
                owner.address,
                await buildOnchainMetadata({
                    name: 'USD Coin',
                    symbol: 'jUSDC',
                }),
                toNano(1_000_000_000)
            )
        );
        ownerJettonA = blockchain.openContract(await JettonWallet.fromInit(tokenA.address, owner.address));
        orderlyJettonA = blockchain.openContract(await JettonWallet.fromInit(tokenA.address, orderlyAmm.address));

        tokenB = blockchain.openContract(
            await JettonMaster.fromInit(
                owner.address,
                await buildOnchainMetadata({
                    name: 'Orderly Token',
                    symbol: 'ORDER',
                }),
                toNano(1_000_000_000)
            )
        );
        ownerJettonB = blockchain.openContract(await JettonWallet.fromInit(tokenB.address, owner.address));
        orderlyJettonB = blockchain.openContract(await JettonWallet.fromInit(tokenB.address, orderlyAmm.address));

        const deployer = await blockchain.treasury('deployer');

        let deployResult = await orderlyAmm.send(
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

        deployResult = await tokenA.send(
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
            to: tokenA.address,
            deploy: true,
            success: true,
        });

        deployResult = await tokenB.send(
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
            to: tokenB.address,
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

    it('should receive deposit', async () => {
        let mintRes = await tokenA.send(
            owner.getSender(),
            { value: toNano('1') },
            {
                $$type: 'Mint',
                amount: toNano('100'),
                receiver: owner.address,
            }
        );
        expect(mintRes.transactions).toHaveTransaction({
            from: tokenA.address,
            to: await tokenA.getGetWalletAddress(owner.address),
            deploy: true,
            success: true,
        });
        console.log('ownerJettonA', ownerJettonA.address);
        console.log('await tokenA.getGetWalletAddress(owner.address)', await tokenA.getGetWalletAddress(owner.address));
        expect((await ownerJettonA.getGetWalletData()).balance).toEqual(toNano('100'));

        await tokenB.send(
            owner.getSender(),
            { value: toNano('1') },
            {
                $$type: 'Mint',
                amount: toNano('100'),
                receiver: owner.address,
            }
        );
        expect(mintRes.transactions).toHaveTransaction({
            from: tokenA.address,
            to: await tokenA.getGetWalletAddress(owner.address),
            deploy: true,
            success: true,
        });
        expect((await ownerJettonB.getGetWalletData()).balance).toEqual(toNano('100'));

        const res = await ownerJettonA.send(
            owner.getSender(),
            { value: toNano('1') },
            {
                $$type: 'TokenTransfer',
                queryId: 6n,
                amount: toNano('100'),
                destination: orderlyAmm.address,
                response_destination: owner.address,
                custom_payload: null,
                forward_ton_amount: toNano('0.5'),
                forward_payload: beginCell().storeAddress(tokenB.address).storeCoins(toNano('1')).endCell(),
            }
        );
        console.log('res', res);

        const ownerWalletDataA = await ownerJettonA.getGetWalletData();
        console.log('ownerWalletDataA', ownerWalletDataA);

        const orderlyWalletDataA = await ownerJettonA.getGetWalletData();
        console.log('orderlyWalletDataA', orderlyWalletDataA);

        // jettonA.send(owner.getSender(), {
        //     value: toNano(0.1),
        // }, )
        // const data = await jettonA.ge(orderlyAmm.address);
        // console.log('DATA', data);
        // owner.getSender().send({
        //     to: jettonA.address,
        //     value: toNano('0.5'),
        //     bounce: true,
        //     sendMode: SendMode.CARRY_ALL_REMAINING_INCOMING_VALUE + SendMode.IGNORE_ERRORS,
        //     body: beginCell()..endCell()
        // });
    });
});
