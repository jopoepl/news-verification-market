// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;





contract PredictionMarket {
    enum MarketStatus { Active, Resolved }
    
    struct Market {
        string question;
        uint256 endTime;
        MarketStatus status;
        mapping(address => uint256) yesShares;
        mapping(address => uint256) noShares;
        uint256 yesPrice;
        uint256 noPrice;
        bool outcome;
    }
    
    Market public market;
    address public owner;
    
    event SharesPurchased(address buyer, bool position, uint256 amount);
    event MarketResolved(bool outcome);
    
    constructor(string memory _question, uint256 _endTime) {
        market.question = _question;
        market.endTime = _endTime;
        market.status = MarketStatus.Active;
        owner = msg.sender;
    }
    
    function buyShares(bool position) public payable {
        require(market.status == MarketStatus.Active, "Market not active");
        require(block.timestamp < market.endTime, "Market expired");
        
        if(position) {
            market.yesShares[msg.sender] += msg.value;
            market.yesPrice += msg.value;
        } else {
            market.noShares[msg.sender] += msg.value;
            market.noPrice += msg.value;
        }
        
        emit SharesPurchased(msg.sender, position, msg.value);
    }
    
    function resolveMarket(bool outcome) public {
        require(msg.sender == owner, "Only owner can resolve");
        require(block.timestamp >= market.endTime, "Market not expired");
        require(market.status == MarketStatus.Active, "Market already resolved");
        
        market.outcome = outcome;
        market.status = MarketStatus.Resolved;
        
        emit MarketResolved(outcome);
    }
    
    function getMarketInfo() public view returns (
        string memory question,
        uint256 endTime,
        MarketStatus status,
        uint256 yesPrice,
        uint256 noPrice
    ) {
        return (
            market.question,
            market.endTime,
            market.status,
            market.yesPrice,
            market.noPrice
        );
    }
}