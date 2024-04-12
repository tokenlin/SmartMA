import React from "react"

// import logo from "/images/logo.png"

function Footer() {
    return (
        <div className="w-full flex md:justify-center justify-between items-center flex-col p-4 gradient-bg-transactions">
           
            <div className="flex justify-center items-center flex-col mt-5">
                <p className="text-white text-sm text-center">Come join us and get more surprises</p>
                <p className="text-white text-sm text-center font-medium mt-2">lkw040535@gmail.com</p>
            </div>

            <div className="sm:w-[90%] w-full h-[0.25px] bg-gray-400 mt-5 " />

            <div className="sm:w-[90%] w-full flex justify-between items-center mt-3">
                <p className="text-white text-left text-xs">@0xkevinlin</p>
                <p className="text-white text-right text-xs">All rights reserved</p>
            </div>
        </div>
    )
}

export default Footer
