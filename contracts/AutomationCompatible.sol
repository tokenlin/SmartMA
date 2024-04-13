// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IAutomationCompatible.sol";
import "./interfaces/ISmartMA.sol";

// contract:    

contract AutomationCompatible is IAutomationCompatible {
    address public owner;

    address public performContract;

    uint256 public timeGap;

    constructor(address _performContract) {
        performContract = _performContract;
        owner = msg.sender;
    }

    function setPerformContract(address _new) public {
        require(msg.sender == owner, "Only owner");
        performContract = _new;
    }

   
    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return ISmartMA(performContract).checkUpkeep(checkData);
    }


    
    function performUpkeep(bytes calldata performData) external override {

        ISmartMA(performContract).performUpkeep(performData);

    }

}
