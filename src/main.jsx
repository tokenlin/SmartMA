import { createRoot } from "react-dom/client"
import { TransactionsProvider } from "./context/TransactionContext"

import App from "./App"

import "./index.css"

createRoot(document.getElementById("root")).render(
    <TransactionsProvider>
        <App />
    </TransactionsProvider>,
)
