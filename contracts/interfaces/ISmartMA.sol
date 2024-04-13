// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISmartMA {

    function checkUpkeep(bytes calldata checkData) external view returns(bool, bytes memory);

    function performUpkeep(bytes calldata performData) external;
}
