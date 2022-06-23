pragma solidity >=0.7.0 < 0.9.0;

interface ERC20Interface {
    // mandatory functions to be implemented
    function totalSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    
    // non-mandatory functions to be implemented
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Cryptos is ERC20Interface {
    string public name = "Cryptos";
    string public symbol = "CRPT";
    int public decimals = 0; // 18 is the most used decimal
    uint public override totalSupply;
    address public founder;
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor() {
        totalSupply = 10 ** 6;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address _owner) public view override returns (uint256 balance){
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public virtual override returns (bool success) {
        require(balances[msg.sender] >= _value, "There are not enough tokens to transfer!");
        balances[_to] += _value;
        balances[msg.sender] -= _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view override returns(uint) {
        return allowed[tokenOwner][spender];
    }

    // called by the original owner of the token
    function approve(address spender, uint tokens) public override returns(bool success) {
        require(balances[msg.sender] >= tokens, "You have allowed more funds to spend than you have!");
        require(tokens > 0, "Allowance is less than or equal to 0!");
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // called by the spender of the allowance
    function transferFrom(address from, address to, uint256 tokens) public virtual override returns (bool success) {
        require(allowed[from][msg.sender] >= tokens, "The tokens transferred are more than that of allowed!");
        require(balances[from] >= tokens, "The amount of allowance is greater than the owner's balance!");
        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens; // subtract the token from the allowance
        balances[to] += tokens;
        emit Transfer(from, to, tokens);
        return true;
    }

}

// derive ICO from Cryptos smart contract
contract CryptosICO is Cryptos {
    address public admin;
    address payable public deposit;
    uint tokenPrice = 0.001 ether; // 1 ETH = 1000 CRPT
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    uint public salesStart = block.timestamp; // ICO will start right away
    uint public salesEnd = block.timestamp + 604800; // ICO ends in one week
    uint public tokenTradeStart = salesEnd + 604800; // ICO tokens transferrable in a week after sales ended
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;
    // using enum to declare state of the ICO
    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;

    event Invest(address investor, uint value, uint tokens);

    constructor(address payable _deposit) {
        deposit = _deposit; // initialize deposit address to its argument
        admin = msg.sender; // initialize admin of contract to the address that deploy the contract
        icoState = State.beforeStart;
    }

    // contract will accept ETH sent to its address
    receive() external payable {
        invest(); // function will automatically be called if a user sends ETH directly to the ICO contract's address
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "You are not the admin!");
        _;
    }

    // stop the ICO in case of emergency
    function haltICO() public onlyAdmin {
        icoState = State.halted;
    }

    // resume ICO after emergency
    function resumeICO() public onlyAdmin {
        icoState = State.running;
    }

    // change deposit address in case original deposit address is compromised
    function changeDepositAddress(address payable newDeposit) public onlyAdmin {
        deposit = newDeposit;
    }

    // return the current ICO state
    function getICOState() public view returns(State) {
        if (icoState == State.halted) {
            return State.halted;
        }
        else if (block.timestamp < salesStart) {
            return State.beforeStart;
        }
        else if (block.timestamp >= salesStart && block.timestamp < salesEnd) {
            return State.running;
        }
        else {
            return State.afterEnd;
        }
    }

    // invest funds into ICO contract
    function invest() payable public returns (bool) {
        icoState = getICOState();
        require(icoState == State.running, "The ICO is currently not running!");
        require(minInvestment <= msg.value && msg.value <= maxInvestment, "The value sent is less than the minimum investment allowed or greater than the maximum investment allowed!");
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap, "The raised amount is greater than the hard cap of the ICO!");
        uint tokens = msg.value / tokenPrice;
        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value); // transfer the amount of investment to the ICO deposit address
        emit Invest(msg.sender, msg.value, tokens);
        return true;
    }

    // transfer tokens from owner of token to another address after trading has started
    function transfer(address _to, uint256 _token) public override returns (bool success)  {
        require(block.timestamp > tokenTradeStart, "Token trading hasn't started yet!");
        Cryptos.transfer(_to, _token); // same as super.transfer(_to, _token)
        return true;
    }

    // transfer tokens from owner account to receiver account after trading has started
    function transferFrom(address _from, address _to, uint256 _token) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart, "Token trading hasn't started yet!");
        Cryptos.transferFrom(_from, _to, _token); 
        return true;
    }

    // burn tokens that have not been sold in the ICO
    function burn() public returns(bool){
        icoState = getICOState();
        require(icoState == State.afterEnd, "The ICO hasn't ended yet!");
        balances[founder] = 0;
        return true;
    }


}