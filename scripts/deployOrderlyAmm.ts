import { config } from 'dotenv';
import { Address, toNano } from 'ton-core';
import { OrderlyAmm } from '../wrappers/OrderlyAmm';
import { NetworkProvider } from '@ton-community/blueprint';

export async function run(provider: NetworkProvider) {
    config();
    if (!process.env.OWNER_ADDRESS) {
        throw new Error('`OWNER_ADDRESS` environment variable required');
    }
    if (!process.env.MNEMONIC) {
        throw new Error('`MNEMONIC` environment variable required');
    }
    const owner = Address.parse(process.env.OWNER_ADDRESS);
    const orderlyAmm = provider.open(await OrderlyAmm.fromInit(owner));

    await orderlyAmm.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(orderlyAmm.address);

    console.log(`Deployed AMM: ${orderlyAmm.address}`);
    // EQBtn3U97Mb4zqlK61PgxADpvOygiiLmmKwW_l9J3t6c3QHp
}
