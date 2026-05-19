vim.api.nvim_create_user_command("OpenPdf", function()
  local filepath = vim.api.nvim_buf_get_name(0)

  if filepath:match("%.typ$") then
    local pdf_path = vim.fn.fnamemodify(filepath, ":r") .. ".pdf"

    vim.system({ "zathura", "--fork", pdf_path })
  else
    vim.notify("Current file is not a .typ file", vim.log.levels.WARN)
  end
end, {})

vim.keymap.set('n', '<leader>fr', ':OpenPdf<CR>', { silent = true, desc = 'Open PDF with Zathura' })
