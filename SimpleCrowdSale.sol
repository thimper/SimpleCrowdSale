pragma solidity ^0.4.11;
import './SafeMath.sol';
import './ERC20Token.sol';

contract SimpleCrowdSale is ERC20Token {

    string public constant version = "0.1";

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

    // 设定ICO的 开始时间、持续时间、汇率、最小目标、最大目标、代币名称、符号
    function SimpleCrowdSale(uint256 _startTime,
                     uint256 _duration,
                     uint256 _tokenContributionMin,
                     uint256 _tokenContributionCap,
                     uint256 _tokenContributionRate,
                     uint8 _founderPercentOfTotal,
                     string _name,
                     string _symbol)
        ERC20Token(_name, _symbol, 8)
        validAmount(_tokenContributionRate)
        validAmount(_tokenContributionMin)
        validAmount(_tokenContributionCap)
        validAmount(_tokenContributionCap - _tokenContributionMin)
        validAmount(_founderPercentOfTotal)
        validAmount(100 - founderPercentOfTotal)
    {
        assert(now <= _startTime);
        founder = msg.sender;
        startTime = _startTime;
        endTime = safeAdd(_startTime, _duration);
        tokenContributionRate = _tokenContributionRate;
        tokenContributionMin = _tokenContributionMin*100000000;
        tokenContributionCap = _tokenContributionCap*100000000;
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
        assert(totalSupply < tokenContributionCap);

        uint256 tokenAmount = safeMul(msg.value, tokenContributionRate);
        uint back_qtum = 0;

        if (safeAdd(totalSupply, tokenAmount) > tokenContributionCap) {
            uint over = safeAdd(totalSupply, tokenAmount) - tokenContributionCap;
            back_qtum = over/tokenContributionRate;
            tokenAmount = tokenContributionCap - totalSupply;
        }

        totalSupply = safeAdd(totalSupply, tokenAmount);
        balanceOf[msg.sender] = safeAdd(balanceOf[msg.sender], tokenAmount);
        Contribution(msg.sender, msg.value, tokenAmount);
        if (back_qtum > 0) {
            msg.sender.transfer(back_qtum);
        }
        return tokenAmount;
    }


    function finalize()
        public
    {
        assert(funding);
        assert(now >= endTime && totalSupply >= tokenContributionMin);

        funding = false;
        uint256 additionalTokens =
            safeMul(totalSupply, founderPercentOfTotal) / (100 - founderPercentOfTotal);
        totalSupply = safeAdd(totalSupply, additionalTokens);
        balanceOf[founder] = safeAdd(balanceOf[founder], additionalTokens);
        Transfer(0, founder, additionalTokens);
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

        uint256 refundValue = tokenAmount/tokenContributionRate;
        Refund(msg.sender, refundValue);
        msg.sender.transfer(refundValue);
    }
}