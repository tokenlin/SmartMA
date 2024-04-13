// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./library/TransferHelper.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IAggregatorV3Interface.sol";
import "./interfaces/ISmartMA.sol";



contract SmartMA is ISmartMA, Ownable {
   
    address public immutable WETH;
    address public immutable LINK;
    address public immutable uniswapV2Router;
    address public immutable uniswapV2Factory;
    uint public nonce;
    mapping(address => bool) public validUpkeeper;  // only valid upkeeper can call performUpkeep()


    struct PriceFeedOrderType {
        address tokenA;  // pair tokenA / tokenB
        address tokenB;
        uint initialTotalAmount;
        
        uint currentTotalAmountA;  // only one token amount is available, currentTotalAmountTokenA * currentTotalAmountTokenB == 0;
        uint currentTotalAmountB;
        
        uint32 MA1;  // second
        uint32 MA2;  // second
        uint32 MAInterval;  // second, for hour is 3600; for day is 24*3600
        uint32 executionInterval;  // second, min seconds between two executions.
        uint128 timeStamp;  // update on performUpkeep
    }
    address[2][] public priceFeedAddressList;  // [feed address, address(uint160(MA1 | MA2 | MAInterval))]
    mapping(address => mapping(address => PriceFeedOrderType)) public infosForPriceFeedAddressListAt;
    mapping(address => mapping(address => uint[])) public nonceListForPriceFeedAddressListAt;
    mapping(address => mapping(address => bool)) public initializedPriceFeedOrder;
    mapping(address => mapping(address => uint)) public indexOfPriceFeedOrderAt;  // get the index of order at priceFeedAddressList


    struct UserOrder{
        
        uint userInitialAmount;
        uint userDepositAmountA;
        uint userDepositAmountB;
        address priceFeedAddress;
        address paramsAddress;
        uint nonceBefore;  // link to last one nonce
        uint nonceAfter;  // link to next one nonce
    }
    mapping(uint => UserOrder) public infosOfUserOrderForNonceAt;
    mapping(address => uint[]) public nonceListForAddressAt;  // all orders for a certain address

    constructor(address _initialOwner, address _uniswapV2Router, address _LINK) Ownable(_initialOwner){
        uniswapV2Router = _uniswapV2Router;
        LINK = _LINK;
        uniswapV2Factory = IUniswapV2Router(_uniswapV2Router).factory();
        WETH = IUniswapV2Router(_uniswapV2Router).WETH();
       
    }


    function setUpkeeper(address _add, bool _bool) public onlyOwner{
        validUpkeeper[_add] = _bool;
    }


    function createPriceFeedOrder(
        address dataFeed,               // ETH/USD:   0x694AA1769357215DE4FAC081bf1f309aDC325306
        address tokenA,                 // WETH:      0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
        address tokenB,                 // USDC:      0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590
        uint32 MA1,                     // MA1(30days) = 30*24*3600=2592000
        uint32 MA2,                     // MA2(7days) = 7*24*3600=604800
        uint32 MAInterval,              // MAInterval(1day) = 3600*24 = 86400
        uint32 executionInterval        // executionInterval(5mins) =  = 300
        ) public onlyOwner {
        require(IAggregatorV3Interface(dataFeed).decimals() > 0, "Invalid detaFeed Address");
        require(IUniswapV2Factory(uniswapV2Factory).getPair(tokenA, tokenB) != address(0), "Invalid pair of tokenA and tokenB");

        address paramsAddress = address((uint160(MA1)<<96) + (uint160(MA2)<<64) + (uint160(MAInterval)<<32) + uint160(executionInterval));

        priceFeedAddressList.push([dataFeed, paramsAddress]);
        indexOfPriceFeedOrderAt[dataFeed][paramsAddress] = priceFeedAddressList.length - 1;

        infosForPriceFeedAddressListAt[dataFeed][paramsAddress] = PriceFeedOrderType(
            tokenA,  // address tokenA;  // pair tokenA / tokenB
            tokenB,  // address tokenB;
            0,  // uint initialTotalAmount;
            0,  // uint currentTotalAmountTokenA;  // only one token amount is available, currentTotalAmountTokenA * currentTotalAmountTokenB == 0;
            0,  // uint currentTotalAmountTokenB;
           
            MA1,  // uint32 MA1;
            MA2,  // uint32 MA2;
            MAInterval,  // uint32 MAInterval;  // second, for hour is 3600; for day is 24*3600
            executionInterval,  // uint32 executionInterval;  // second, min seconds between two executions.
            uint128(block.timestamp)
        );

        // approve to Router
        TransferHelper.safeApprove(tokenA, uniswapV2Router, type(uint256).max);
        TransferHelper.safeApprove(tokenB, uniswapV2Router, type(uint256).max);
    }


    function getMA(address dataFeed, uint32 MA1, uint32 MA2, uint32 MAInterval, uint32 roundIDStep) public view returns(int valueMA1, int valueMA2, uint len1, uint len2){
    
        len1 = MA1 / MAInterval;
        len2 = MA2 / MAInterval;

        require(len1 > len2, "len1 should be more than len2");
        require(len2 > 0, "len1 and len2 should be more than 0");

        int[] memory valueList = new int[](len1);
    
        (
            uint80 roundID,
            int answer,
            /* uint startedAt */,
            uint updatedAt,
            /*uint80 answeredInRound*/
        ) = IAggregatorV3Interface(dataFeed).latestRoundData();

        uint16 phaseId = uint16(roundID >> 64);
        uint64 aggregatorRoundId = uint64(roundID);

        // save latest data
        uint timeCurrent = updatedAt;
        valueList[0] = answer;

        // start store other value
        uint index = 1;
        for(uint i=aggregatorRoundId-1; i>0; i=i-roundIDStep){
            if(index > valueList.length-1) break;

            uint80 _roundId = uint80((uint256(phaseId) << 64) | i);
            (
                /* uint80 roundID */,
                int _answer,
                /*uint startedAt*/,
                uint _updatedAt,
                /*uint80 answeredInRound*/
            ) = IAggregatorV3Interface(dataFeed).getRoundData(_roundId);

            if(_updatedAt <= timeCurrent-MAInterval){
                timeCurrent = _updatedAt;
                valueList[index] = _answer;
                index++;
            }
        }


        // set true len
        uint _len;
        for(uint i=0; i<len1; i++){
            if(valueList[i] > 0){
                _len = i+1;
            }
        }
        assembly{
            mstore(valueList, _len)
        }
        if(len1 > _len) len1 = _len;
        if(len2 > _len) len2 = _len;


        // return 
        int MA1Cumulative;
        int MA2Cumulative;
        for(uint i=0; i<len1; i++){
            MA1Cumulative += valueList[i];
        }
        for(uint i=0; i<len2; i++){
            MA2Cumulative += valueList[i];
        }

        valueMA1 = MA1Cumulative / int(len1);
        valueMA2 = MA2Cumulative / int(len2);

    }


    function depositETH(uint index) public payable{
        require(index < priceFeedAddressList.length, "index error");

        address dataFeed = priceFeedAddressList[index][0];
        address paramsAddress = priceFeedAddressList[index][1];

        address tokenA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].tokenA;
        address tokenB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].tokenB;
        
        require(tokenA == WETH || tokenB == WETH, "No WETH for tokenA or tokenB");
        
        uint amountIn = msg.value;

        // ETH to WETH
        IWETH(WETH).deposit{value: amountIn}();
        

        bool ifAmountForTokenA = (tokenA == WETH);

        _deposit(dataFeed, paramsAddress, tokenA, tokenB, amountIn, ifAmountForTokenA);

   }





    function _deposit(
        address dataFeed, 
        address paramsAddress,
        address tokenA,
        address tokenB,
        uint amount,
        bool ifAmountForTokenA
    ) internal {
        uint initialTotalAmount = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount;
        uint currentTotalAmountA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA;  // only one token amount is available, currentTotalAmountTokenA * currentTotalAmountTokenB == 0;
        uint currentTotalAmountB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB;

        uint userInitialAmount;
        uint userDepositAmountA;
        uint userDepositAmountB;
        

        address[] memory pathA_B = new address[](2);
        pathA_B[0]=tokenA;
        pathA_B[1]=tokenB;

        address[] memory pathB_A = new address[](2);
        pathB_A[0]=tokenB;
        pathB_A[1]=tokenA;

        // first add
        if(initialTotalAmount == 0){
            userInitialAmount = amount;
            infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount = amount;
            if(ifAmountForTokenA == true){    
                userDepositAmountA = amount;                        
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA = amount;
            }else{                      
                userDepositAmountB = amount;                               
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB = amount;
            }


        }else if(currentTotalAmountA > 0){
            uint _initialTotalAmount = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount;
            uint _currentTotalAmountA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA;
            // uint _currentTotalAmountB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB;

            if(ifAmountForTokenA == false){
                uint256[] memory amounts = IUniswapV2Router(uniswapV2Router).swapExactTokensForTokens(
                        amount,
                        0,
                        pathB_A,
                        address(this),
                        block.timestamp + 3600);
                amount = amounts[1];
            }
            userDepositAmountA = amount;
            userInitialAmount = _initialTotalAmount * amount / _currentTotalAmountA;
            infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount = _initialTotalAmount + userInitialAmount;
            infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA = _currentTotalAmountA + amount;

        }else if(currentTotalAmountB > 0){
            uint _initialTotalAmount = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount;
            // uint _currentTotalAmountA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA;
            uint _currentTotalAmountB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB;

            if(ifAmountForTokenA == true){
                uint256[] memory amounts = IUniswapV2Router(uniswapV2Router).swapExactTokensForTokens(
                        amount,
                        0,
                        pathA_B,
                        address(this),
                        block.timestamp + 3600);
                amount = amounts[1];
            }
            userDepositAmountB = amount;
            userInitialAmount = _initialTotalAmount * amount / _currentTotalAmountB;
            infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount = _initialTotalAmount + userInitialAmount;
            infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB = _currentTotalAmountB + amount;
        }


        uint _nonce = ++nonce;

        infosOfUserOrderForNonceAt[_nonce] = UserOrder(
           
            userInitialAmount,  // uint userInitialAmount;
            userDepositAmountA,  // uint userDepositAmountA;
            userDepositAmountB,  // uint userDepositAmountB;
            dataFeed,  // address priceFeedAddress;
            paramsAddress,  // address paramsAddress;
            0,  // uint nonceBefore;  // link to last one nonce
            0  // uint nonceAfter;  // link to next one nonce
        );

        nonceListForPriceFeedAddressListAt[dataFeed][paramsAddress].push(_nonce);
        nonceListForAddressAt[msg.sender].push(_nonce);

    }



    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool, bytes memory)
    {
        (uint index, uint32 roundIDStep) = abi.decode(checkData, (uint, uint32));

        require(index < priceFeedAddressList.length, "index error");

        address dataFeed = priceFeedAddressList[index][0];
        address paramsAddress = priceFeedAddressList[index][1];

        uint128 params = uint128(uint160(paramsAddress));
        uint32 MA1 = uint32(params>>96);
        uint32 MA2 = uint32(uint96(params)>>64);
        uint32 MAInterval = uint32(uint64(params)>>32);
        uint32 executionInterval = uint32(params);

        uint currentTotalAmountA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA;  // only one token amount is available, currentTotalAmountTokenA * currentTotalAmountTokenB == 0;
        uint currentTotalAmountB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB;
        uint128 timeStamp = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].timeStamp;

        bool ifInitialized= initializedPriceFeedOrder[dataFeed][paramsAddress];
        if(ifInitialized == false){  // no executionInterval
            (int valueMA1, int valueMA2, , ) = getMA(dataFeed, MA1, MA2, MAInterval, roundIDStep);
            bytes memory performData = abi.encode(dataFeed, paramsAddress, valueMA1, valueMA2);
            if(valueMA1 < valueMA2 && currentTotalAmountA == 0) return (true, performData);  // going cross up, buy
            if(valueMA1 > valueMA2 && currentTotalAmountB == 0) return (true, performData);  // going cross down, sell

        }else{
            if(uint128(block.timestamp) < timeStamp + executionInterval) return (false, "");
            (int valueMA1, int valueMA2, , ) = getMA(dataFeed, MA1, MA2, MAInterval, roundIDStep);
            bytes memory performData = abi.encode(dataFeed, paramsAddress, valueMA1, valueMA2);
            if(valueMA1 < valueMA2 && currentTotalAmountA == 0) return (true, performData);  // going cross up, buy
            if(valueMA1 > valueMA2 && currentTotalAmountB == 0) return (true, performData);  // going cross down, sell

        }
        return (false, "");
    }




    // only authorized contract can call this function
    function performUpkeep(bytes calldata performData) external {
        // check msg.sender
        require(validUpkeeper[msg.sender] == true, "invalid sender");

        _performUpkeep(performData);
    }


    function _performUpkeep(bytes memory performData) internal {
        (address dataFeed, address paramsAddress, int valueMA1, int valueMA2) = abi.decode(performData, (address, address, int, int));

        uint currentTotalAmountA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA;  // only one token amount is available, currentTotalAmountTokenA * currentTotalAmountTokenB == 0;
        uint currentTotalAmountB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB;
        address tokenA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].tokenA;
        address tokenB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].tokenB;

        require(((valueMA1 < valueMA2 && currentTotalAmountA == 0)) || (valueMA1 > valueMA2 && currentTotalAmountB == 0), "valueMA error");


        initializedPriceFeedOrder[dataFeed][paramsAddress] = true;
        
        if(currentTotalAmountA > 0){  // swap tokenA to tokenB
                address[] memory path = new address[](2);
                            path[0]=tokenA;
                            path[1]=tokenB;
                uint256[] memory amounts = IUniswapV2Router(uniswapV2Router).swapExactTokensForTokens(
                            currentTotalAmountA,
                            0,
                            path,
                            address(this),
                            block.timestamp + 3600);
                // update data
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA = 0;
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB = amounts[1];
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].timeStamp = uint128(block.timestamp);

        }else{  // swap tokenB to tokenA
                address[] memory path = new address[](2);
                            path[0]=tokenB;
                            path[1]=tokenA;
                uint256[] memory amounts = IUniswapV2Router(uniswapV2Router).swapExactTokensForTokens(
                            currentTotalAmountB,
                            0,
                            path,
                            address(this),
                            block.timestamp + 3600);
                // update data
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA = amounts[1];
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB = 0;
                infosForPriceFeedAddressListAt[dataFeed][paramsAddress].timeStamp = uint128(block.timestamp);
        }
    }




    function _getSinglePriceFeedOrderBytes(uint index, address dataFeed, address paramsAddress) internal view returns(bytes memory){
        PriceFeedOrderType memory _priceFeedOrder = infosForPriceFeedAddressListAt[dataFeed][paramsAddress];

        string memory description = IAggregatorV3Interface(dataFeed).description();

        return abi.encode(index, description, dataFeed, paramsAddress, _priceFeedOrder.tokenA, _priceFeedOrder.tokenB, _priceFeedOrder.initialTotalAmount, _priceFeedOrder.currentTotalAmountA, _priceFeedOrder.currentTotalAmountB, _priceFeedOrder.MA1, _priceFeedOrder.MA2, _priceFeedOrder.MAInterval, _priceFeedOrder.executionInterval, _priceFeedOrder.timeStamp);

    }





    function getPriceFeedOrderListBytes(uint _indexStart, uint _indexEnd) public view returns(bytes[] memory returnList){

        uint orderLength = priceFeedAddressList.length;
        require(orderLength > 0, "No order");
        if(_indexEnd > orderLength - 1) _indexEnd = orderLength - 1;
        require(_indexStart <= _indexEnd, "index error");
        
        uint len = _indexEnd - _indexStart + 1; // [_indexStart, _indexEnd]

        returnList = new bytes[](len);

        uint index;
        for(uint i=_indexStart; i<=_indexEnd; i++){
            address dataFeed = priceFeedAddressList[i][0];
            address paramsAddress = priceFeedAddressList[i][1];
            returnList[index] = _getSinglePriceFeedOrderBytes(index, dataFeed, paramsAddress);
            index += 1;
        }
    }


    function _getSingleUserOrderBytes(uint _nonce) internal view returns(bytes memory){

        UserOrder memory _userOrder = infosOfUserOrderForNonceAt[_nonce];
        address dataFeed = _userOrder.priceFeedAddress;
        address paramsAddress = _userOrder.paramsAddress;

        uint indexOfPriceFeedOrder = indexOfPriceFeedOrderAt[dataFeed][paramsAddress];
        string memory description = IAggregatorV3Interface(dataFeed).description();
        uint currentTotalAmountA = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountA;  // only one token amount is available, currentTotalAmountTokenA * currentTotalAmountTokenB == 0;
        uint currentTotalAmountB = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].currentTotalAmountB;
        uint initialTotalAmount = infosForPriceFeedAddressListAt[dataFeed][paramsAddress].initialTotalAmount;

        uint currentAmountA;
        uint currentAmountB;
        if(currentTotalAmountA > 0) currentAmountA = currentTotalAmountA * _userOrder.userInitialAmount / initialTotalAmount;
        if(currentTotalAmountB > 0) currentAmountB = currentTotalAmountB * _userOrder.userInitialAmount / initialTotalAmount;
        
        return abi.encode(_nonce, indexOfPriceFeedOrder, description, currentAmountA, currentAmountB, _userOrder.userInitialAmount, _userOrder.userDepositAmountA, _userOrder.userDepositAmountB, _userOrder.priceFeedAddress, _userOrder.paramsAddress, _userOrder.nonceBefore, _userOrder.nonceAfter);
    }

    function getUserOrderListBytes(address user, uint _indexStart, uint _indexEnd) public view returns(bytes[] memory returnList){
        
        uint orderLength = nonceListForAddressAt[user].length;
        require(orderLength > 0, "No order");
        if(_indexEnd > orderLength - 1) _indexEnd = orderLength - 1;
        require(_indexStart <= _indexEnd, "index error");

        uint len = _indexEnd - _indexStart + 1; // [_indexStart, _indexEnd]

        returnList = new bytes[](len);

        uint index;
        for(uint i=_indexStart; i<=_indexEnd; i++){
            uint _nonce = nonceListForAddressAt[user][i];
            returnList[index] = _getSingleUserOrderBytes(_nonce);
            index += 1;
        }
    }

   
    function getParamsAddress(
        uint32 MA1,                     // MA1(30days) = 30*24*3600=2592000
        uint32 MA2,                     // MA2(7days) = 7*24*3600=604800
        uint32 MAInterval,              // MAInterval(1day) = 3600*24 = 86400
        uint32 executionInterval        // executionInterval(5mins) = 60*5 = 300
    ) public pure returns(address){
        return address((uint160(MA1)<<96) + (uint160(MA2)<<64) + (uint160(MAInterval)<<32) + uint160(executionInterval));
    }


}