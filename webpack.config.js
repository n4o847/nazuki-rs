const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const WasmPackPlugin = require('@wasm-tool/wasm-pack-plugin');

module.exports = {
  entry: './www/index.js',
  resolve: {
    alias: {
      nazuki: path.resolve(__dirname, 'pkg'),
    },
  },
  plugins: [
    new HtmlWebpackPlugin(),
    new WasmPackPlugin({
      crateDirectory: path.resolve(__dirname, '.')
    }),
  ],
};
