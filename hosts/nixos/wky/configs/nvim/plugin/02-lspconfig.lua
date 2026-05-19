vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })

-- Load lspconfig to register its server configurations for vim.lsp.enable()
require('lspconfig')
require('config.lsp')
