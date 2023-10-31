import { config } from 'dotenv';
import { Address, Builder, Cell, toNano } from 'ton-core';
import { JettonMaster, Mint } from '../wrappers/JettonMaster';
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
    const jettonMaster = provider.open(await JettonMaster.fromInit(owner, Cell.EMPTY));

    await jettonMaster.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(jettonMaster.address);

    // const receiver = Address.parseRaw('0:5845c15abe7af4a1aad752de181ce89304f41d6fa58a44e40d200720b6e401a0');
    // await jettonMaster.send(
    //     provider.sender(),
    //     {
    //         value: toNano('0.1'),
    //     },
    //     {
    //         $$type: 'Mint',
    //         amount: toNano('100'),
    //         receiver,
    //         responseDestination: receiver,
    //     }
    // );

    // EQAOj2JC6zZlMr4-gqKEChqeUNBQMkn_IBIgQQNFglM6dELe
}
