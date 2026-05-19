vim.lsp.enable({
  "nixd",
  "lua_ls",
  "markdown_oxide",
  "tinymist"
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" }
      }
    }
  }
})

vim.lsp.config("tinymist", {
  cmd = { "tinymist" },
  settings = {
    lint = {
      enabled = "true",
      when = "onSave"
    },
    formatterMode = "typstyle",
    exportPdf = "onSave",
  }
})

vim.diagnostic.config({ virtual_text = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp", { clear = true }),
  callback = function(args)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = args.buf,
      callback = function()
        vim.lsp.buf.format { async = false, id = args.data.client_id }
      end,
    })
  end
})
