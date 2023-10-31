import "@stdlib/deploy";

import "./message";
import "./jetton_wallet";

contract JettonMaster with Deployable {
    totalSupply: Int as coins;
    owner: Address;
    content: Cell;

    init(owner: Address, content: Cell) {
        self.totalSupply = 0;
        self.owner = owner;
        self.content = content;
    }

    receive(msg: Mint) {
        dump("Mint");
        let ctx: Context = context();
        // require(ctx.sender == self.owner, "Not Owner");

        self.totalSupply = self.totalSupply + msg.amount;

        let stateInit: StateInit = self.getJettonWalletInit(msg.receiver);
        send(SendParameters{
            to: contractAddress(stateInit), 
            value: 0, 
            bounce: true,
            mode: SendRemainingValue,
            body: TokenTransferInternal { 
                queryId: 0,
                amount: msg.amount,
                from: myAddress(),
                response_destination: msg.responseDestination,
                forward_ton_amount: 0,
                forward_payload: emptySlice()
            }.toCell(),
            code: stateInit.code,
            data: stateInit.data
        });
    }

    receive(msg: TokenUpdateContent) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not Owner");
        self.content = msg.content;
    }

    receive(msg: TokenBurnNotification) {
        self.requireSenderAsWalletOwner(msg.response_destination);
        self.totalSupply = self.totalSupply - msg.amount;
        if (msg.response_destination != null) {
            send(SendParameters{
                to: msg.response_destination, 
                value: 0,
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: TokenExcesses { queryId: msg.queryId }.toCell()
            });
        }
    }

    fun requireSenderAsWalletOwner(owner: Address) {
        let ctx: Context = context();
        let stateInit: StateInit = self.getJettonWalletInit(owner);
        require(contractAddress(stateInit) == ctx.sender, "Invalid sender");
    }

    fun getJettonWalletInit(address: Address): StateInit {
        return initOf JettonWallet(myAddress(), address);
    }

    get fun get_jetton_data(): JettonData {
        let code: Cell = self.getJettonWalletInit(myAddress()).code;
        return JettonData { 
            totalSupply: self.totalSupply, 
            mintable: true, 
            owner: self.owner, 
            content: self.content, 
            walletCode: code
        };
    }

    get fun get_wallet_address(owner: Address): Address {
        let stateInit: StateInit = self.getJettonWalletInit(owner);
        return contractAddress(stateInit);
    }
} 
