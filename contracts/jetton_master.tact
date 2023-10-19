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
        require(ctx.sender == self.owner, "Not Owner");
        self.mint(msg.receiver, msg.amount, self.owner); // TODO gas refund
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

    // Private Methods // 
    // @to The Address receive the Jetton token after minting
    // @amount The amount of Jetton token being minted
    // @response_destination The previous owner address
    fun mint(to: Address, amount: Int, response_destination: Address) {
        self.totalSupply = self.totalSupply + amount; // Update total supply

        let winit: StateInit = self.getJettonWalletInit(to); // Create message
        send(SendParameters{
            to: contractAddress(winit), 
            value: 0, 
            bounce: true,
            mode: SendRemainingValue,
            body: TokenTransferInternal { 
                queryId: 0,
                amount: amount,
                from: myAddress(),
                response_destination: response_destination,
                forward_ton_amount: 0,
                forward_payload: emptySlice()
            }.toCell(),
            code: winit.code,
            data: winit.data
        });
    }

    fun requireSenderAsWalletOwner(owner: Address) {
        let ctx: Context = context();
        let winit: StateInit = self.getJettonWalletInit(owner);
        require(contractAddress(winit) == ctx.sender, "Invalid sender");
    }

    fun getJettonWalletInit(address: Address): StateInit {
        return initOf JettonWallet(myAddress(), address);
    }

    // ====== Get Methods ====== //
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
        let winit: StateInit = self.getJettonWalletInit(owner);
        return contractAddress(winit);
    }
} 
