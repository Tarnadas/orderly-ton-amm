import { Blockchain, SandboxContract, TreasuryContract, printTransactionFees } from '@ton-community/sandbox';
import { SendMode, beginCell, toNano } from 'ton-core';
import { LiquidityPool, OrderlyAmm, loadLiquidityPool, storeLiquidityPool } from '../wrappers/OrderlyAmm';
import '@ton-community/test-utils';
import { JettonMaster } from '../wrappers/JettonMaster';
import {
    addLiquidity,
    addressToHex,
    buildOnchainMetadata,
    createLp,
    depositJetton,
    lpDictionaryToObject,
    mintJetton,
    prettyLogTransactions,
    withdrawAllJetton,
} from './utils/helpers';
import { JettonWallet } from '../wrappers/JettonWallet';
import { OrderlyAmmDeposit } from '../wrappers/OrderlyAmmDeposit';
import { OrderlyAmmLiquidityPool } from '../wrappers/OrderlyAmmLp';

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
        blockchain.verbosity = {
            ...blockchain.verbosity,
            debugLogs: true,
            print: false,
        };
        owner = await blockchain.treasury('owner');

        orderlyAmm = blockchain.openContract(await OrderlyAmm.fromInit(owner.address));

        tokenA = blockchain.openContract(
            await JettonMaster.fromInit(
                owner.address,
                await buildOnchainMetadata({
                    name: 'USD Coin',
                    symbol: 'jUSDC',
                })
            )
        );

        tokenB = blockchain.openContract(
            await JettonMaster.fromInit(
                owner.address,
                await buildOnchainMetadata({
                    name: 'Orderly Token',
                    symbol: 'ORDER',
                })
            )
        );

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
        ownerJettonA = blockchain.openContract(
            JettonWallet.fromAddress(await tokenA.getGetWalletAddress(owner.address))
        );
        orderlyJettonA = blockchain.openContract(
            JettonWallet.fromAddress(await tokenA.getGetWalletAddress(orderlyAmm.address))
        );

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
        ownerJettonB = blockchain.openContract(
            JettonWallet.fromAddress(await tokenB.getGetWalletAddress(owner.address))
        );
        orderlyJettonB = blockchain.openContract(
            JettonWallet.fromAddress(await tokenB.getGetWalletAddress(orderlyAmm.address))
        );
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and orderlyAmm are ready to use
    });

    it('should receive deposit', async () => {
        let mintRes = await mintJetton(tokenA, owner, toNano('100'));
        expect(mintRes.transactions).toHaveTransaction({
            from: tokenA.address,
            to: await tokenA.getGetWalletAddress(owner.address),
            deploy: true,
            success: true,
        });
        expect((await ownerJettonA.getGetWalletData()).balance).toEqual(toNano('100'));

        mintRes = await mintJetton(tokenB, owner, toNano('100'));
        expect(mintRes.transactions).toHaveTransaction({
            from: tokenB.address,
            to: await tokenB.getGetWalletAddress(owner.address),
            deploy: true,
            success: true,
        });
        expect((await ownerJettonB.getGetWalletData()).balance).toEqual(toNano('100'));

        let depositRes = await depositJetton(ownerJettonA, owner, toNano('100'), orderlyAmm);
        prettyLogTransactions(depositRes.transactions);
        printTransactionFees(depositRes.transactions);

        const ownerWalletDataA = await ownerJettonA.getGetWalletData();
        expect(ownerWalletDataA.balance).toEqual(0n);
        const orderlyWalletDataA = await orderlyJettonA.getGetWalletData();
        expect(orderlyWalletDataA.balance).toEqual(toNano('100'));

        const ownerDepositA = blockchain.openContract(
            OrderlyAmmDeposit.fromAddress(await orderlyAmm.getGetDepositAddress(owner.address, orderlyJettonA.address))
        );
        const depositDataA = await ownerDepositA.getGetDepositData();
        expect(depositDataA.balance).toEqual(toNano('100'));

        depositRes = await depositJetton(ownerJettonB, owner, toNano('100'), orderlyAmm);
        prettyLogTransactions(depositRes.transactions);
        printTransactionFees(depositRes.transactions);

        const ownerWalletDataB = await ownerJettonB.getGetWalletData();
        expect(ownerWalletDataB.balance).toEqual(0n);
        const orderlyWalletDataB = await orderlyJettonB.getGetWalletData();
        expect(orderlyWalletDataB.balance).toEqual(toNano('100'));

        const ownerDepositB = blockchain.openContract(
            OrderlyAmmDeposit.fromAddress(await orderlyAmm.getGetDepositAddress(owner.address, orderlyJettonB.address))
        );
        const depositDataB = await ownerDepositB.getGetDepositData();
        expect(depositDataB.balance).toEqual(toNano('100'));
    });

    it('should deposit and withdraw', async () => {
        await mintJetton(tokenA, owner, toNano('100'));
        await mintJetton(tokenB, owner, toNano('100'));
        await depositJetton(ownerJettonA, owner, toNano('100'), orderlyAmm);

        const ownerDepositA = blockchain.openContract(
            OrderlyAmmDeposit.fromAddress(await orderlyAmm.getGetDepositAddress(owner.address, orderlyJettonA.address))
        );

        let depositDataA = await ownerDepositA.getGetDepositData();
        expect(depositDataA.balance).toEqual(toNano('100'));

        const res = await withdrawAllJetton(ownerDepositA, owner);
        prettyLogTransactions(res.transactions);
        printTransactionFees(res.transactions);

        depositDataA = await ownerDepositA.getGetDepositData();
        expect(depositDataA.balance).toEqual(0n);
    });

    it('should create liquidity pool', async () => {
        const res = await createLp(orderlyAmm, owner, tokenA.address, tokenB.address);
        prettyLogTransactions(res.transactions);
        printTransactionFees(res.transactions);
        const lpAddress = await orderlyAmm.getGetLpAddress(tokenA.address, tokenB.address);
        const lps = await orderlyAmm.getGetLiquidityPools();

        expect(res.transactions).toHaveTransaction({
            from: orderlyAmm.address,
            to: lpAddress,
            deploy: true,
            success: true,
        });
        expect(lpDictionaryToObject(lps)).toEqual([
            [0, { $$type: 'LiquidityPool', base: tokenA.address.toRawString(), quote: tokenB.address.toRawString() }],
        ]);
    });

    it('should add liquidity', async () => {
        await mintJetton(tokenA, owner, toNano('100'));
        await mintJetton(tokenB, owner, toNano('100'));
        await depositJetton(ownerJettonA, owner, toNano('100'), orderlyAmm);
        await depositJetton(ownerJettonB, owner, toNano('100'), orderlyAmm);
        await createLp(orderlyAmm, owner, tokenA.address, tokenB.address);

        const res = await addLiquidity(
            orderlyAmm,
            owner,
            tokenA.address,
            toNano('100'),
            orderlyJettonA.address,
            tokenB.address,
            toNano('100'),
            orderlyJettonB.address
        );
        prettyLogTransactions(res.transactions);
        printTransactionFees(res.transactions);

        const lp = blockchain.openContract(
            OrderlyAmmLiquidityPool.fromAddress(await orderlyAmm.getGetLpAddress(tokenA.address, tokenB.address))
        );
        const shares = blockchain.openContract(JettonMaster.fromAddress(await lp.getGetSharesAddress()));
        const sharesWallet = blockchain.openContract(
            JettonWallet.fromAddress(await shares.getGetWalletAddress(owner.address))
        );
        const walletData = await sharesWallet.getGetWalletData();
        console.log(walletData.balance);
    });
});
