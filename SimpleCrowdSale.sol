pragma solidity ^0.4.11;
import './SafeMath.sol';
import './ERC20Token.sol';

contract SimpleCrowdSale is ERC20Token {

    string public constant version = "0.1";

    bool public transfersEnabled = false; // true if transfer/transferFrom are enabled, false if not
    bool public funding = true; // funding state

    uint256 public startTime = 0; //crowdsale start time (in seconds)
    uint256 public endTime = 0; //crowdsale end time (in seconds)

    uint256 public tokenContributionRate = 0; // how many tokens one QTUM equals
    uint256 public tokenContributionCap = 0; // max amount raised during crowdsale
    uint256 public tokenContributionMin = 0; // min amount raised during crowdsale

    uint8 public founderPercentOfTotal = 0; // should between 0 to 99
    address public founder = 0x0; // the contract creator's address

    // triggered when this contract is deployed
    event ContractCreated(address _this);
    // triggered when contribute successful
    event Contribution(address indexed _contributor, uint256 _amount, uint256 _return);
    // triggered when refund successful
    event Refund(address indexed _from, uint256 _value);
    // triggered when crowdsale is over
    event Finalized(uint256 _time);


    modifier between(uint256 _startTime, uint256 _endTime) {
        assert(now >= _startTime && now < _endTime);
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0);
        _;
    }

    modifier transfersAllowed {
        assert(transfersEnabled);
        _;
    }

    // 设定ICO的 开始时间、持续时间、汇率、最小目标、最大目标、代币名称、符号、小数位
    function SimpleCrowdSale(uint256 _startTime,
                     uint256 _duration,
                     uint256 _tokenContributionMin,
                     uint256 _tokenContributionCap,
                     uint256 _tokenContributionRate,
                     uint8 _founderPercentOfTotal,
                     string _name,
                     string _symbol,
                     uint8 _decimals)
        ERC20Token(_name, _symbol, _decimals)
        validAmount(_tokenContributionRate)
        validAmount(_tokenContributionMin)
        validAmount(_tokenContributionCap)
        validAmount(_tokenContributionCap - _tokenContributionMin)
        validAmount(_founderPercentOfTotal)
        validAmount(100 - founderPercentOfTotal)
    {
        assert(now < _startTime);
        founder = msg.sender;
        startTime = _startTime;
        endTime = safeAdd(_startTime, _duration);
        tokenContributionRate = _tokenContributionRate;
        tokenContributionMin = _tokenContributionMin;
        tokenContributionCap = _tokenContributionCap;
        founderPercentOfTotal = _founderPercentOfTotal;
        ContractCreated(address(this));
    }

    function ()
        payable
    {
        contribute();
    }


    function contribute()
        public
        payable
        between(startTime, endTime)
        validAmount(msg.value)
        returns (uint256 amount)
    {
        assert(funding);
        uint256 tokenAmount = safeMul(msg.value, tokenContributionRate)/100000000;
        assert(safeAdd(totalSupply, tokenAmount) <= tokenContributionCap);
        totalSupply = safeAdd(totalSupply, tokenAmount);
        balanceOf[msg.sender] = safeAdd(balanceOf[msg.sender], tokenAmount);
        Contribution(msg.sender, msg.value, tokenAmount);
        return tokenAmount;
    }


    function finalize()
        public
    {
        assert(funding);
        assert(now >= startTime && totalSupply >= tokenContributionMin);

        funding = false;
        uint256 additionalTokens =
            totalSupply * founderPercentOfTotal / (100 - founderPercentOfTotal);
        totalSupply = safeAdd(totalSupply, additionalTokens);
        balanceOf[founder] = safeAdd(balanceOf[founder], additionalTokens);
        Transfer(0, founder, additionalTokens);
        transfersEnabled = true;
        Finalized(now);
        founder.transfer(this.balance);
    }


    function refund()
        public
    {
        assert(funding);
        assert(now >= endTime && totalSupply <= tokenContributionMin);

        uint256 tokenAmount = balanceOf[msg.sender];
        assert(tokenAmount > 0);

        balanceOf[msg.sender] = 0;
        totalSupply = safeSub(totalSupply, tokenAmount);

        uint256 refundValue = safeMul(tokenAmount, 100000000) / tokenContributionRate;
        Refund(msg.sender, refundValue);
        msg.sender.transfer(refundValue);
    }


    function transfer(address _to, uint256 _value)
        public
        transfersAllowed
        returns (bool success)
    {
        assert(super.transfer(_to, _value));
        return true;
    }


    function transferFrom(address _from, address _to, uint256 _value)
        public
        transfersAllowed
        returns (bool success)
    {
        assert(super.transferFrom(_from, _to, _value));
        return true;
    }

}