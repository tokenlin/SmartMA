import { defineConfig } from "vite"
import { extname } from "path"
import react from "@vitejs/plugin-react"
import AutoImport from "unplugin-auto-import/vite"

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [
        react(),
        AutoImport({
            imports: ["react", "react-router", "react-router-dom"],
            include: [/\.[tj]sx?$/],
        }),
    ],
    build: {
        outDir: "dist",
        chunkSizeWarningLimit: 1500,
        rollupOptions: {
            output: {
                chunkFileNames: "assets/js/[name]-[hash].js",
                entryFileNames: "assets/js/[name].[hash].js",
                compact: true,
                manualChunks: {
                    react: ["react", "react-dom", "react-icons"],
                    ethers: ["ethers", "eth-revert-reason"],
                    tailwind: ["autoprefixer", "@tailwindcss/forms", "postcss"],
                },
                assetFileNames: chunkInfo => {
                    // 用后缀名称进行区别处理
                    // 处理其他资源文件名 e.g. css png 等
                    const ext = extname(chunkInfo.name)
                    let subDir = "images"

                    if (ext === ".css") {
                        subDir = "css"
                    }

                    return `assets/${subDir}/[name].[hash].[ext]`
                },
            },
        },
    },
    css: {
        preprocessorOptions: { css: { charset: false } },
        devSourcemap: true,
        modules: {
            localsConvention: "camelCaseOnly", // 驼峰命名
            generateScopedName: "[name]__[local]___[hash:base64:5]", // 生成的类名
            scopeBehaviour: "local", // 配置当前的模块化行为是模块化还是全局化 (有hash就是模块化)
            hashPrefix: "hash", // 生成的类名前缀
            globalModulePaths: [/node_modules/], // 配置哪些模块不需要模块化
        },
    },
})
