import { Welcome, Footer, Table } from "./components"

function App() {
    return (
        <div className="min-h-screen">
            <div className="gradient-bg-welcome">  
                <Welcome />
            </div>
            <Table />
            <Footer />
        </div>
    )
}

export default App
