import { BlockchainTransaction, SandboxContract, SendMessageResult, TreasuryContract } from '@ton-community/sandbox';
import { Address, Cell, Dictionary, beginCell, fromNano, toNano } from 'ton-core';
import { sha256 } from 'ton-crypto';
import { JettonWallet } from '../../wrappers/JettonWallet';
import { LiquidityPool, OrderlyAmm } from '../../wrappers/OrderlyAmm';
import { OrderlyAmmDeposit } from '../../wrappers/OrderlyAmmDeposit';
import { JettonMaster } from '../../wrappers/JettonMaster';

const ONCHAIN_CONTENT_PREFIX = 0x00;
const SNAKE_PREFIX = 0x00;
const CELL_MAX_SIZE_BYTES = Math.floor((1023 - 8) / 8);

const toKey = async (key: string) => {
    return BigInt(`0x${(await sha256(key)).toString('hex')}`);
};

export function mintJetton(
    jetton: SandboxContract<JettonMaster>,
    sender: SandboxContract<TreasuryContract>,
    amount: bigint
): Promise<SendMessageResult> {
    return jetton.send(
        sender.getSender(),
        { value: toNano('1') },
        {
            $$type: 'Mint',
            amount,
            receiver: sender.address,
        }
    );
}

export function depositJetton(
    jettonWallet: SandboxContract<JettonWallet>,
    sender: SandboxContract<TreasuryContract>,
    amount: bigint,
    amm: SandboxContract<OrderlyAmm>
): Promise<SendMessageResult> {
    return jettonWallet.send(
        sender.getSender(),
        { value: toNano('1') },
        {
            $$type: 'TokenTransfer',
            queryId: 0n,
            amount,
            destination: amm.address,
            response_destination: sender.address,
            custom_payload: null,
            forward_ton_amount: toNano('0.6'),
            forward_payload: beginCell().storeUint(0, 8).endCell(),
        }
    );
}

export function withdrawAllJetton(
    depositWallet: SandboxContract<OrderlyAmmDeposit>,
    sender: SandboxContract<TreasuryContract>
): Promise<SendMessageResult> {
    return depositWallet.send(
        sender.getSender(),
        {
            value: toNano('1'),
        },
        {
            $$type: 'WithdrawAll',
            queryId: 0n,
        }
    );
}

export function createLp(
    amm: SandboxContract<OrderlyAmm>,
    sender: SandboxContract<TreasuryContract>,
    base: Address,
    quote: Address
): Promise<SendMessageResult> {
    return amm.send(
        sender.getSender(),
        { value: toNano('1') },
        {
            $$type: 'CreateLp',
            base,
            quote,
        }
    );
}

export function lpDictionaryToObject(dict: Dictionary<number, LiquidityPool>) {
    return Array.from(dict).map(([index, lp]) => [
        index,
        {
            $$type: 'LiquidityPool',
            base: lp.base.toRawString(),
            quote: lp.quote.toRawString(),
        },
    ]);
}

export function prettyLogTransaction(tx: BlockchainTransaction) {
    let res = `${tx.inMessage?.info.src!}  ➡️  ${tx.inMessage?.info.dest}\n`;

    for (let message of tx.outMessages.values()) {
        if (message.info.type === 'internal') {
            res += `     ➡️  ${fromNano(message.info.value.coins)} 💎 ${message.info.dest}\n`;
        } else {
            res += `      ➡️  ${message.info.dest}\n`;
        }
    }
    if (tx.debugLogs) {
        for (const log of tx.debugLogs.split('\n')) {
            res += `     📝 ${log}\n`;
        }
    }

    return res;
}

export function prettyLogTransactions(txs: BlockchainTransaction[]) {
    let out = '';

    for (let tx of txs) {
        out += prettyLogTransaction(tx) + '\n\n';
    }

    console.log(out);
}

export function addressToHex(address: Address): bigint {
    return BigInt('0x' + beginCell().storeAddress(address).endCell().hash().toString('hex'));
}

export async function buildOnchainMetadata(data: { name: string; symbol: string }): Promise<Cell> {
    let dict = Dictionary.empty(Dictionary.Keys.BigUint(256), Dictionary.Values.Cell());

    for (const [key, value] of Object.entries(data)) {
        dict.set(await toKey(key), makeSnakeCell(Buffer.from(value, 'utf8')));
    }

    return beginCell().storeInt(ONCHAIN_CONTENT_PREFIX, 8).storeDict(dict).endCell();
}

export function makeSnakeCell(data: Buffer) {
    // Create a cell that package the data
    let chunks = bufferToChunks(data, CELL_MAX_SIZE_BYTES);

    const b = chunks.reduceRight((curCell, chunk, index) => {
        if (index === 0) {
            curCell.storeInt(SNAKE_PREFIX, 8);
        }
        curCell.storeBuffer(chunk);
        if (index > 0) {
            const cell = curCell.endCell();
            return beginCell().storeRef(cell);
        } else {
            return curCell;
        }
    }, beginCell());
    return b.endCell();
}

function bufferToChunks(buff: Buffer, chunkSize: number) {
    let chunks: Buffer[] = [];
    while (buff.byteLength > 0) {
        chunks.push(buff.slice(0, chunkSize));
        buff = buff.slice(chunkSize);
    }
    return chunks;
}
