import { defineConfig } from 'vite'
import path from 'path';

export default defineConfig({
    test: {
        environment: 'node',
        globals: true,
        poolOptions:{
            threads:{
                singleThread: true
            }
        },
        include: ['src/**/*.test.ts'],
    },
    resolve: {
        alias: {
            '~': path.resolve(__dirname, './src')
        }
    },
})