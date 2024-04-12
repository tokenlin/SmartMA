import { TransactionContext } from "../context/TransactionContext"

import Loader from "./Loader"
import "../styles/gradient.css"


function Input({ placeholder, name, type, value, handleChange }) {
    return (
        <input
            placeholder={placeholder}
            type={type}
            step="0.001"
            value={value}
            onChange={(e) => handleChange(e, name)}
            className="w-full rounded-sm outline-none bg-transparent text-white border-none text-sm white-glassmorphism"
        />
    )
}

function Table() {
    // const [open, setOpen] = useState(false)
    const [detail, setDetail] = useState(null)
    const tableClass = "grid xl:grid-cols-[50px_100px_100px_100px_minmax(100px,_1fr)_minmax(100px,_1fr)_minmax(200px,_1fr)_100px] xl:gap-4 xl:py-3 xl:gap-2 py-1.5 grid-cols-[30px_minmax(100px,_1fr)_60px_60px_minmax(120px,_1fr)_minmax(120px,_1fr)_minmax(120px,_1fr)_60px]"

    // const { handleChange, transactions, orders, confirmSend } = useContext(TransactionContext)
    const {open, setOpen, isLoading, sendTransactionDeposit, handleChange, transactions_UserOrders, transactions_FeedOrders} = useContext(TransactionContext)


    function handleDeposit(index) {
        const item = transactions_FeedOrders[index]
        setDetail(item)
        setOpen(true)
    }

    function handleKeyUp(e) {
        if (!open) return
        const key = e.key
        if (key === "Escape") {
            setOpen(false)
        }
    }


    useEffect(() => {
        window.addEventListener("keyup", handleKeyUp)
        return () => window.removeEventListener("keyup", handleKeyUp)
    }, [open])

    return (
        <>
            <div className="table-gradient">
                {transactions_UserOrders.length ? (
                    <div
                        className="flex w-full justify-center items-center flex-col md:p-14 md:pb-0 pt-10 px-4 text-white"
                    >
                        <h1 className="text-center md:mb-6 mb-3 text-3xl">My Orders</h1>
                        <div>
                            <ul className={`${tableClass} border-b-2 border-[#302D2E]`}>
                                {["nonce", "SN", "Description", "AmountA", "AmountB", "userDepositAmountA", "userDepositAmountB", "Action"].map(li => (
                                    <li key={li}>{li} </li>
                                ))}
                            </ul>
                            {transactions_UserOrders.map((li, i) => (
                                <ul key={li + i} className={`${tableClass} border-b border-[#302D2E]`}>
                                    <li>{li.nonce}</li>
                                    <li>{li.indexOfPriceFeedOrder}</li>
                                    <li>{li.description}</li>
                                    <li>{li.currentAmountA}</li>
                                    <li>{li.currentAmountB}</li>
                                    <li>{li.userDepositAmountA}</li>
                                    <li>{li.userDepositAmountB}</li>
                                    <li>
                                        <button className="rounded-xl bg-[#2952E3] py-1 px-2"> Withdraw</button>
                                    </li>
                                </ul>
                            ))}
                        </div>
                    </div>
                ) : <Loader />}
                <div
                    className="flex w-full justify-center items-center flex-col md:p-14 py-10 px-4 text-white"
                >
                    <h1 className="text-center md:mb-6 mb-3 text-3xl">Total FeedData Orders</h1>
                    <div>
                        <ul className={`${tableClass} border-b-2 border-[#302D2E]`}>
                            {["SN", "Description", "MA1", "MA2", "Execution Interval", "Current AmountA", "Current AmountB", "Action"].map(li => (
                                <li key={li}>{li} </li>
                            ))}
                        </ul>
                        {transactions_FeedOrders.map((li, i) => (
                            <ul key={li + i} className={`${tableClass} border-b border-[#302D2E]`}>
                                <li>{li.index}</li>
                                <li>{li.description}</li>
                                <li>{li.MA1}</li>
                                <li>{li.MA2}</li>
                                <li>{li.executionInterval}</li>
                                <li>{li.currentTotalAmountA}</li>
                                <li>{li.currentTotalAmountB}</li>
                                <li>
                                    <button
                                        className="rounded-xl bg-[#2952E3] py-1 px-2"
                                        onClick={() => handleDeposit(i)}
                                    >
                                        Deposit
                                    </button>
                                </li>
                            </ul>
                        ))}
                        {transactions_FeedOrders.map((li, i) => (
                            <ul key={li + i} className={`${tableClass} border-b border-[#302D2E]`}>
                                <li>{li.index}</li>
                                <li>{li.description}</li>
                                <li>{li.MA1}</li>
                                <li>{li.MA2}</li>
                                <li>{li.executionInterval}</li>
                                <li>{li.currentTotalAmountA}</li>
                                <li>{li.currentTotalAmountB}</li>
                                <li>
                                    <button
                                        className="rounded-xl bg-[#2952E3] py-1 px-2"
                                        onClick={() => handleDeposit(i)}
                                    >
                                        Deposit
                                    </button>
                                </li>
                            </ul>
                        ))}
                    </div>
                </div>
            </div>
            {open && (
                <div
                    className={`fixed top-0 flex justify-center items-center bg-[#100F14D9] w-full h-full transition-all ease-in-out backdrop-saturate-50 backdrop-blur-lg`}
                    onClick={() => setOpen(false)}
                >
                    <div className="rounded-xl bg-[#1A1C2F] w-1/4 p-6 text-white shadow-md"
                         onClick={e => e.stopPropagation()}
                    >
                        <ul className="border-b-2 border-white grid grid-cols-2 gap-3 py-3 items-center">
                            <li>SN:</li>
                            <li>{detail.SN}</li>
                            <li>Description:</li>
                            <li>{detail.Description}</li>
                            <li>MA1:</li>
                            <li>{detail.MA1}</li>
                            <li>MA2:</li>
                            <li>{detail.MA2}</li>
                            <li>Execution Interval:</li>
                            <li>{detail.ExecutionInterval}</li>
                            <li>Amounts(ETH):</li>
                            <li><Input placeholder="ETH" name="amount" type="number" handleChange={handleChange} /></li>
                        </ul>
                        <div className="flex justify-between items-center p-3">
                            <button className="rounded-2xl border border-[#37456E] p-1 " onClick={sendTransactionDeposit}
                            >Deposit
                            </button>
                            <button className="rounded-2xl border border-[#37456E] p-1 " onClick={() => setOpen(false)}
                            >Cancel
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </>
    )
}

export default Table