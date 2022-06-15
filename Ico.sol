// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.9.0;

// ERC is Ethereum Request for Comment
//ERC-20 is the protocol used for token.
// ERC-20 is fungible token and can be transfered.
// protocol has 6 function and 2 events.
interface ERC20Interface {
    //mandatory functions
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns(uint balance);
    function transfer(address to, uint tokens) external returns(bool success);

    function allowance(address tokenOwner, address spender) external view returns(uint remaining);
    function approve(address spender, uint tokens) external returns(bool success);
    function transferFrom(address from, address to, uint tokens) external returns(bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
} 

// derive the interface
contract Cryptos is ERC20Interface {
    string public name = "crypto";
    string public symbol = "CRPT";
    uint public decimals = 0; //after decimal place. can be 0 to 18
    // since totalSupply is already declared in interface. we must override it.
    uint public override totalSupply;
    address public founder;
    mapping(address => uint) public balances;
    // owner can allow user to transfer amount/tokens
    // ex: 0x111... (owner) allows 0x222.. (user) to withdraw 100 tokens.
    mapping(address => mapping(address => uint)) public allowed;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    //balanceOf func interface
    function balanceOf(address tokenOwner) public view override returns(uint balance) {
        return balances[tokenOwner];
    }

    // transfer func interface
    // virtual keyword because transfer interface func can be overriden in other derived contract also.
    function transfer(address to, uint tokens) public virtual override returns(bool success) {
        // check the balance before transfer
        require(balances[msg.sender] >= tokens, "Insufficiant Balance!");

        // after transfer the balance will increase
        balances[to] += tokens; //recipient
        balances[msg.sender] -= tokens; //sender

        // emit transfer event
        emit Transfer(msg.sender, to, tokens);

        return true;
    }

     // approve the amount/tokens that can be withdraw from spender.
    function approve(address spender, uint tokens) public override returns(bool success) {
        // owner must have the sufficient tokens
        require(balances[msg.sender] >= tokens);
        // tokens must be greater then 0;
        require(tokens > 0);
        // add tokens allowed to spend.
        allowed[msg.sender][spender] = tokens;
        // emit the approval event
        emit Approval(msg.sender, spender, tokens);

        return true;
    }

    // get amount/tokens allowed spender to withdraw
    function allowance(address tokenOwner, address spender) public override view returns(uint remaining) {
        // returns the tokens allowed to withdraw from owner
        return allowed[tokenOwner][spender];
    }


    // transfer the token to another account or same account after approval.
    // only the allowed spender can transfer the tokens
    // virtual keyword because transferFrom interface func can be overriden in other derived contract also.
    function transferFrom(address from, address to, uint tokens) public virtual override returns(bool success) {
        // check if allowed spender has sufficient tokens
        // from is the owner
        require(allowed[from][msg.sender] >= tokens);
        // check balance of owner
        require(balances[from] >= tokens);
        // reduce the owner balance
        balances[from] -= tokens;
        // reduce the allowed spender balance
        allowed[from][msg.sender] -= tokens;
        // increase the balance of recipient
        balances[to] += tokens;

        //emit Transfer event
        emit Transfer(from, to, tokens);

        return true;
    }


}

// ICO - Initial Coin Offering
// when a company needs funds, it will offer coins/tokens in exchange of the ether or other tokens.
// it is like the share of company.
// The ICO contract must be derived from ERC20 token contract.
// CryptoICO is derived from Cryptos
contract CryptoICO is Cryptos {
    address public admin;
    // deposit all ethers into a account
    address payable public deposit; 
    // token in exchange of ether
    uint tokenPrice = 0.001 ether; // for 1 CRPT = 0.001 ether OR 1 ether = 1000 CRPT
    // total investment that can be done.
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    // offering starts when block is created/deployed
    uint public saleStart = block.timestamp;
    // sales ends after 1 week i.e 604800 sec
    uint public saleEnd = block.timestamp + 604800;
    // To avoid trading of coins immediately, which will cause decrease in coin value
    // trade will start 1 week after sales end.
    uint public tokenTradeStart = saleEnd + 604800;
    // maximum and minimum investment
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;
    // to store the states of ICO
    enum State { beforeStart, running, afterEnd, halted }
    State public icoState;

    // constructor is called when contract is deployed.
    constructor(address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    // modifier can be used whenever needed in function.
    modifier onlyAdmin() {
        require(msg.sender == admin); // only admin can access
        _;
    }

    // if some security issue occures or anything error then we can halt the ICO.
    function halt() public onlyAdmin {
        icoState = State.halted;
    }

    // To resume halted ICO
    function resume() public onlyAdmin {
        icoState = State.running;
    }

    // To change the deposit address
    function changeDepositAddress(address payable newDeposit) public onlyAdmin {
        deposit = newDeposit;
    }

    //Get the current state of ICO
    function getCurrentState() public view returns(State) {
        if (icoState == State.halted) {
            return State.halted;
        } else if(block.timestamp < saleStart) {
            return State.beforeStart;
        } else if(block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return State.running;
        } else {
            return State.afterEnd;
        }
    }

    // event for invest
    event Invest(address investor, uint value, uint tokens);

    // invest in ICO
    function invest() payable public returns(bool) {
        // check if the state is running
        icoState = getCurrentState();
        require(icoState == State.running, "ICO is not active!");
        // check min and max investment
        require(msg.value >= minInvestment && msg.value <= maxInvestment, "Investment must be between 0.1 to 5 ether.");
        // total raised amount
        raisedAmount += msg.value;
        // check the hardcap limit
        require(raisedAmount <= hardCap, "Reached the hardcap limit!");
        // calculate number of token user has got from ether investment
        // 1 token = 0.001 ether then how much token = 2 ether => 2/0.001 = 2000 crpt token.
        uint tokens = msg.value / tokenPrice;
        // add CRPT(crypto) token to investor
        balances[msg.sender] += tokens;
        // substract CRPT from CRPT founder
        balances[founder] -= tokens;
        // transfer the amount to deposit account
        deposit.transfer(msg.value);
        //emit the invest event
        emit Invest( msg.sender, msg.value, tokens);

        return true;
    }

    // since contract receive money, must have payable receive method
    // this function is called automatically when someone sends ETH to the contract's address
    receive() payable external {
        invest();
    }

    // Overide the virtual interface function derived from base contract(Cryptos).
    function transfer(address to, uint tokens) public  override returns(bool success) {
        // check trade time is after tokenTradeStart i.e 1 week later
        require(block.timestamp > tokenTradeStart);
        // call the transfer func in Cryptos contract(base contract).
        // super.transfer(to, tokens); 
        // OR
        Cryptos.transfer(to, tokens);

        return true;
    }

    // Overide the virtual interface function derived from base contract(Cryptos).
    function transferFrom(address from, address to, uint tokens) public override returns(bool success) {
        // check trade time is after tokenTradeStart i.e 1 week later
        require(block.timestamp > tokenTradeStart);
        // call the func in Cryptos contract(base contract).
        Cryptos.transferFrom(from, to, tokens);
        return true;
    }

    //burn tokens that are not sold
    function burn() public returns(bool) {
        icoState = getCurrentState();
        // done after ICO ends
        require(icoState == State.afterEnd);
        // make the balance of cryptos account to 0
        balances[founder] = 0;
        return true;
    }

    
}
