import { toNano } from 'ton-core';
import { OrderlyAmm } from '../wrappers/OrderlyAmm';
import { NetworkProvider } from '@ton-community/blueprint';

export async function run(provider: NetworkProvider) {
    const orderlyAmm = provider.open(await OrderlyAmm.fromInit(BigInt(Math.floor(Math.random() * 10000))));

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

    console.log('ID', await orderlyAmm.getId());
}
