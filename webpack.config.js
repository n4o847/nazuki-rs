const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const WasmPackPlugin = require('@wasm-tool/wasm-pack-plugin');

module.exports = {
  entry: './www/index.js',
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [
          MiniCssExtractPlugin.loader,
          'css-loader',
        ],
      },
    ],
  },
  resolve: {
    alias: {
      nazuki: path.resolve(__dirname, 'pkg'),
    },
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: path.resolve(__dirname, './www/index.html')
    }),
    new MiniCssExtractPlugin(),
    new WasmPackPlugin({
      crateDirectory: path.resolve(__dirname, '.')
    }),
  ],
  experiments: {
    asyncWebAssembly: true,
  },
};
