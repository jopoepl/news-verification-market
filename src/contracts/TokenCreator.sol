// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@gnosis.pm/conditional-tokens-contracts/contracts/ConditionalTokens.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IConditionalTokens {
    function prepareCondition(
        address oracle,
        bytes32 questionId,
        uint outcomeSlotCount
    ) external;

    function getOutcomeSlotCount(bytes32 conditionId) external view returns (uint);
    
    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint[] calldata partition,
        uint amount
    ) external;

    function mergePosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint[] calldata partition,
        uint amount
    ) external;
}


contract NewsVerificationTokenCreator is ERC1155, Ownable, Pausable {
    // 1. Initialize the Conditional Tokens contract
    // create condition
    // create outcomes
    // create positions
    // create split and merge functions
    // 2. Set the collateral token and amount
    // 3. Create the outcome tokens
    // 4. Mint the outcome tokens to the caller

    struct Condition {
        bool exists;                  // Tracks if condition exists
        mapping(uint256 => bytes32) outcomeSlots;  //Holds position ids for each outcome
        uint256 creationTime;         // When the condition was created
        address creator;              // Who created the condition
        bool isResolved;              // Has the condition been resolved
        uint256 totalCollateral;      // Total collateral locked
        bytes32 conditionId;
        mapping(address => mapping(uint256 => uint256)) userPositions; // user => outcomeIndex => amount

    }


    //State Variables
    IConditionalTokens public ctf;
    address public oracle;
    bytes32 public questionId;
    mapping(bytes32 => Condition) public conditions;
    IERC20 public collateralToken;
    uint256 public collateralAmount;


    //Events

    // Condition Creation
    // event 
    event ConditionCreated(bytes32 indexed conditionId, address indexed oracle, bytes32 indexed questionId,uint256 outcomeSlotCount, uint256 creationTime, address creator);

    // Outcome Token Split
    event OutcomeTokenSplit(
        address indexed stakeholder,
        IERC20 collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 indexed conditionId,
        uint[] partition,
        uint amount
    );

    // Outcome Token Burn
    event OutcomeTokenBurned(
        address indexed stakeholder,
        IERC20 collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 indexed conditionId,
        uint[] partition,
        uint amount
    );

    // Payout Redemption
    event PayoutRedemption(
        address indexed redeemer,
        IERC20 indexed collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 conditionId,
        uint[] indexSets,
        uint payout
    );

    constructor(address _ctfAddress, address _oracle, address _collateralToken, string memory _uri) ERC1155(_uri) {
        ctf = IConditionalTokens(_ctfAddress);
    oracle = _oracle;
    collateralToken = IERC20(_collateralToken);

    }

    function createCondition(bytes32 _questionId, uint256 _outcomeSlotCount) external onlyOwner {
        require(_outcomeSlotCount > 0, "Outcome slot count must be greater than 0");
        require(conditions[_questionId].exists == false, "Condition already exists");

        ctf.prepareCondition(oracle, _questionId, _outcomeSlotCount);
        bytes32 conditionId = keccak256(abi.encodePacked(oracle, _questionId, _outcomeSlotCount));
                
        Condition storage condition = conditions[_questionId];
    condition.exists = true;
    condition.creationTime = block.timestamp;
    condition.creator = msg.sender;
    condition.isResolved = false;
    condition.totalCollateral = 0;
    condition.conditionId = conditionId;

    emit ConditionCreated(conditionId, oracle, _questionId, _outcomeSlotCount, block.timestamp, msg.sender);
    }

    function createPositions(bytes32 _conditionId, uint256[] memory _outcomes) external onlyOwner {
        require(conditions[_conditionId].exists, "Condition does not exist");
        Condition storage condition = conditions[_questionId];
         // Calculate position IDs for each outcome
     uint[] memory indexSets = new uint[](2);
    indexSets[0] = 1; // represents outcome 0 (False)
    indexSets[1] = 2; // represents outcome 1 (True)

        bytes32 parentCollectionId = bytes32(0); // Empty parent for base positions

             for(uint i = 0; i < 2; i++) {
        // Get collection ID for each outcome
        bytes32 collectionId = ctf.getCollectionId(
            parentCollectionId,
            condition.conditionId,
            indexSets[i]
        );
        
        // Get position ID using collateral token and collection ID
        uint positionId = ctf.getPositionId(collateralToken, collectionId);
        
        // Store position ID
        condition.outcomeSlots[i] = bytes32(positionId);
    }
    }

    //Now we have the complete Condition struct with outcome slots filled with respective position ids, time for split and merge functions
    function splitPosition(
    bytes32 _questionId,
    uint amount
) external whenNotPaused {
    require(conditions[_questionId].exists, "Condition does not exist");
    Condition storage condition = conditions[_questionId];
    
    // For binary outcomes, partition is [1, 2] (representing outcomes 0 and 1)
    uint[] memory partition = new uint[](2);
    partition[0] = 1;  // False outcome (01 in binary)
    partition[1] = 2;  // True outcome (10 in binary)
    
    
    // Split the position
    ctf.splitPosition(
        collateralToken,          // The ERC20 token used as collateral
        bytes32(0),              // Empty parent collection for base positions
        condition.conditionId,    // The condition ID we're splitting on
        partition,               // The partition array [1,2] for binary outcomes
        amount                   // Amount of collateral to split
    );
    
    condition.totalCollateral += amount;
      // Update user positions in the condition
    condition.userPositions[msg.sender][0] += amount;  // False position
    condition.userPositions[msg.sender][1] += amount;  // True position
    condition.totalCollateral += amount;
    
    
    emit OutcomeTokenSplit(
        msg.sender,
        collateralToken,
        bytes32(0),
        condition.conditionId,
        partition,
        amount
    );

}

function mergePosition(
    bytes32 _questionId,
    uint amount
) external {
    require(conditions[_questionId].exists, "Condition does not exist");
    Condition storage condition = conditions[_questionId];
    
    // Must use same partition as split: [1, 2]
    uint[] memory partition = new uint[](2);
    partition[0] = 1;  // False outcome (01 in binary)
    partition[1] = 2;  // True outcome (10 in binary)
    
    // Verify user has enough position tokens to merge
    require(condition.userPositions[msg.sender][0] >= amount, "Insufficient FALSE tokens");
    require(condition.userPositions[msg.sender][1] >= amount, "Insufficient TRUE tokens");
    
    // Merge the positions back to collateral
    ctf.mergePosition(
        collateralToken,
        bytes32(0),
        condition.conditionId,
        partition,
        amount
    );
    
    // Update user positions
    condition.userPositions[msg.sender][0] -= amount;
    condition.userPositions[msg.sender][1] -= amount;
    condition.totalCollateral -= amount;
    
    emit OutcomeTokenMerged(
        msg.sender,
        collateralToken,
        bytes32(0),
        condition.conditionId,
        partition,
        amount
    );
}

function reportPayouts(
    bytes32 _questionId,
    uint[] calldata _payouts
) external {
    require(msg.sender == oracle, "Only oracle can report");
    require(!conditions[_questionId].isResolved, "Already resolved");
    
    Condition storage condition = conditions[_questionId];
    condition.isResolved = true;
    
    ctf.reportPayouts(_questionId, _payouts);
    
    emit ConditionResolved(_questionId, _payouts);
}

// Oracle reports outcome
function reportPayouts(
    bytes32 _questionId,
    uint[] calldata _payouts  // e.g., [0,1] for TRUE outcome
) external {
    require(msg.sender == oracle, "Only oracle can report");
    require(!conditions[_questionId].isResolved, "Already resolved");
    
    ctf.reportPayouts(_questionId, _payouts);  // CTF handles all payout calculations
    
    conditions[_questionId].isResolved = true;
    emit ConditionResolved(_questionId, _payouts);
}

// Users can redeem their positions after oracle reports
function redeemPositions(bytes32 _questionId) external whenNotPaused {
    require(conditions[_questionId].isResolved, "Condition not resolved");
    Condition storage condition = conditions[_questionId];
    
    uint[] memory indexSets = new uint[](2);
    indexSets[0] = 1;
    indexSets[1] = 2;
    
    // Let's get user's current position amounts before redemption - emitted in event
    uint amount0 = condition.userPositions[msg.sender][0];
    uint amount1 = condition.userPositions[msg.sender][1];
    
    // Redeem all positions
    ctf.redeemPositions(
        collateralToken,
        bytes32(0),
        condition.conditionId,
        indexSets
    );
    
    // Clear user's positions as they've all been redeemed
    condition.userPositions[msg.sender][0] = 0;
    condition.userPositions[msg.sender][1] = 0;
    
    emit PayoutRedeemed(
        msg.sender,
        _questionId,
        amount0,
        amount1
    );
}



//Admin Function below

// Change oracle function
function setOracle(address _newOracle) external onlyOwner {
    require(_newOracle != address(0), "Invalid oracle address");
    oracle = _newOracle;
    emit OracleChanged(_newOracle);
}

// Set collateral token
function setCollateralToken(IERC20 _collateralToken) external onlyOwner {
    require(address(_collateralToken) != address(0), "Invalid token address");
    collateralToken = _collateralToken;
    emit CollateralTokenSet(address(_collateralToken));
}


function pause() external onlyOwner {
    _pause();
}

function unpause() external onlyOwner {
    _unpause();
}


//Pure Getter functions

// Get condition details
function getCondition(bytes32 _questionId) 
    external 
    view 
    returns (
        bool exists,
        uint256 creationTime,
        address creator,
        bool isResolved,
        uint256 totalCollateral
    ) 
{
    Condition storage condition = conditions[_questionId];
    return (
        condition.exists,
        condition.creationTime,
        condition.creator,
        condition.isResolved,
        condition.totalCollateral
    );
}

// Get total collateral locked

function getConditionCollateral(bytes32 _questionId) external view returns (uint256) {
    require(conditions[_questionId].exists, "Condition does not exist");
    return conditions[_questionId].totalCollateral;
}

// Helper to check user's position
function getUserPosition(
    bytes32 _questionId, 
    address user,
    uint256 outcomeIndex
) external view returns (uint256) {
    require(conditions[_questionId].exists, "Condition does not exist");
    return conditions[_questionId].userPositions[user][outcomeIndex];
}



}





