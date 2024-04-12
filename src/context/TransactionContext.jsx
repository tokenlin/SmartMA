import { useEffect, useState, createContext } from "react"
import { ethers, utils} from "ethers";

import { contractABI, contractAddress } from "../utils/constants"

export const TransactionContext = createContext()

const { ethereum } = window

function createEthereumContract() {
    const provider = new ethers.providers.Web3Provider(ethereum)
    const signer = provider.getSigner()
    return new ethers.Contract(contractAddress, contractABI, signer)
}

export function TransactionsProvider({ children }) {
    const [formData, setformData] = useState({ addressTo: "", amount: "", keyword: "", message: "" })
    const [currentAccount, setCurrentAccount] = useState("")
    const [isLoading, setIsLoading] = useState(false)
    const [transactionCount, setTransactionCount] = useState(localStorage.getItem("transactionCount"))
    const [transactions_UserOrders, setTransactions_UserOrders] = useState([]);
    const [transactions_FeedOrders, setTransactions_FeedOrders] = useState([]);

    const handleChange = (e, name) => {
        setformData((prevState) => ({ ...prevState, [name]: e.target.value }))
    }





  const getAllTransactions_UserOrders = async () => {
    try {
      if (ethereum) {
        // console.log("availableTransactions: ");
        const transactionsContract = createEthereumContract();
        const accounts = await ethereum.request({ method: "eth_accounts" });
        const availableTransactions = await transactionsContract.getUserOrderListBytes(accounts[0], 0, 1000000);

        // console.log(availableTransactions);
        
        var structuredTransactions =[];
        for(let i=0; i<availableTransactions.length; i++){
          const abi = new utils.AbiCoder();

          // return abi.encode(_nonce, indexOfPriceFeedOrder, description, currentAmountA, currentAmountB, _userOrder.userInitialAmount, _userOrder.userDepositAmountA, _userOrder.userDepositAmountB, _userOrder.priceFeedAddress, _userOrder.paramsAddress, _userOrder.nonceBefore, _userOrder.nonceAfter);
    
          const _transactionList = abi.decode(["uint", "uint", "string", "uint", "uint", "uint", "uint", "uint", "address", "address", "uint", "uint"], availableTransactions[i]);
          
          structuredTransactions.push({
            nonce:                        _transactionList[0].toString(),
            indexOfPriceFeedOrder:        _transactionList[1].toString(),
            description:                  _transactionList[2],
            currentAmountA:               _transactionList[3].toString(),
            currentAmountB:               _transactionList[4].toString(),
            userInitialAmount:            _transactionList[5].toString(),
            userDepositAmountA:           _transactionList[6].toString(),
            userDepositAmountB:           _transactionList[7].toString(),
            priceFeedAddress:             _transactionList[8],
            paramsAddress:                _transactionList[9],
            nonceBefore:                  _transactionList[10].toString(),
            nonceAfter:                   _transactionList[11].toString()
          });
        }

        console.log(structuredTransactions)



        // const structuredTransactions = availableTransactions.map((transaction) => ({
        //   addressTo: transaction.receiver,
        //   addressFrom: transaction.sender,
        //   timestamp: new Date(transaction.timestamp.toNumber() * 1000).toLocaleString(),
        //   message: transaction.message,
        //   keyword: transaction.keyword,
        //   amount: parseInt(transaction.amount._hex) / (10 ** 18)
        // }));


        // console.log(structuredTransactions[0]);

        setTransactions_UserOrders(structuredTransactions);
      } else {
        console.log("Ethereum is not present");
      }
    } catch (error) {
      console.log(error);
    }
  };







    async function getAllTransactions_FeedOrders() {
        try {
            const transactionsContract = createEthereumContract()
            const availableTransactions = await transactionsContract.getPriceFeedOrderListBytes(0, 100)
            // console.log("availableTransactions")
            console.log(availableTransactions)

            var structuredTransactions =[];
            for(let i=0; i<availableTransactions.length; i++){
              const abi = new utils.AbiCoder();
    
              // return abi.encode(index, description, dataFeed, paramsAddress, _priceFeedOrder.tokenA, _priceFeedOrder.tokenB, _priceFeedOrder.initialTotalAmount, _priceFeedOrder.currentTotalAmountA, _priceFeedOrder.currentTotalAmountB, _priceFeedOrder.MA1, _priceFeedOrder.MA2, _priceFeedOrder.MAInterval, _priceFeedOrder.executionInterval, _priceFeedOrder.timeStamp);
    
              const _transactionList = abi.decode(["uint", "string", "address", "address", "address", "address", "uint", "uint", "uint", "uint32", "uint32", "uint32", "uint32", "uint128"], availableTransactions[i]);
              const MAInterval = _transactionList[11];

              structuredTransactions.push({
                index:                        _transactionList[0].toString(),
                description:                  _transactionList[1],
                dataFeed:                     _transactionList[2],
                paramsAddress:                _transactionList[3],
                tokenA:                       _transactionList[4],
                tokenB:                       _transactionList[5],
                initialTotalAmount: _transactionList[6].toString(),
                currentTotalAmountA:          _transactionList[7].toString(),
                currentTotalAmountB:          _transactionList[8].toString(),
                MA1:                          (_transactionList[9]/MAInterval).toString(),
                MA2:                          (_transactionList[10]/MAInterval).toString(),
                MAInterval:                   MAInterval.toString(),
                executionInterval:            _transactionList[12].toString(),
                timeStamp:                    _transactionList[13].toString(),
              });
            }
    
            console.log(structuredTransactions)

            setTransactions_FeedOrders(structuredTransactions)
            if (ethereum) {
            } else {
                console.log("Ethereum is not present")
            }
        } catch (error) {
            console.log(error)
        }




    }

    async function checkIfWalletIsConnectAndGetAllOrders() {
        try {
            if (!ethereum) return alert("Please install MetaMask.")

            const accounts = await ethereum.request({ method: "eth_accounts" })

            console.log("accounts", accounts)
            if (accounts.length) {
                setCurrentAccount(accounts[0])
                getAllTransactions_UserOrders();
                getAllTransactions_FeedOrders();
            } else {
                console.log("No accounts found")
            }
        } catch (error) {
            console.log(error)
        }
    }

    async function checkIfTransactionsExists() {
        try {
            if (ethereum) {
                const transactionsContract = createEthereumContract()
                const currentTransactionCount = await transactionsContract.retrieve()

                window.localStorage.setItem("transactionCount", currentTransactionCount)
            }
        } catch (error) {
            console.log(error)

            throw new Error("No ethereum object")
        }
    }

    async function connectWallet() {
        try {
            if (!ethereum) return alert("Please install MetaMask.")

            const accounts = await ethereum.request({ method: "eth_requestAccounts" })

            setCurrentAccount(accounts[0])
            window.location.reload()
        } catch (error) {
            console.log(error)

            throw new Error("No ethereum object")
        }
    }

    async function sendTransaction() {
        try {
            if (ethereum) {
                const { addressTo, amount, keyword, message } = formData
                const transactionsContract = createEthereumContract()
                const parsedAmount = ethers.utils.parseEther(amount)

                await ethereum.request({
                    method: "eth_sendTransaction",
                    params: [{
                        from: currentAccount,
                        to: addressTo,
                        gas: "0x5208",
                        value: parsedAmount._hex,
                    }],
                })

                const transactionHash = await transactionsContract.store(parsedAmount)

                setIsLoading(true)
                console.log(`Loading - ${transactionHash.hash}`)
                await transactionHash.wait()
                console.log(`Success - ${transactionHash.hash}`)
                setIsLoading(false)

                const transactionsCount = await transactionsContract.retrieve()

                setTransactionCount(transactionsCount.toString())
                // window.location.reload();
            } else {
                console.log("No ethereum object")
            }
        } catch (error) {
            console.log(error)

            throw new Error("No ethereum object")
        }
    }

    // useEffect(() => {
    //     checkIfWalletIsConnect()
    //     // checkIfTransactionsExists()
    // }, [transactionCount])

    useEffect(()=>{
        setInterval(()=>{
          console.log("checkIfWalletIsConnectAndGetAllOrders");
          checkIfWalletIsConnectAndGetAllOrders();
        }, 5000);
      }, []);

    return (
        <TransactionContext.Provider
            value={{
                transactionCount,
                connectWallet,
                transactions_UserOrders,
                transactions_FeedOrders,
                currentAccount,
                isLoading,
                sendTransaction,
                handleChange,
                formData,
            }}
        >
            {children}
        </TransactionContext.Provider>
    )
}
