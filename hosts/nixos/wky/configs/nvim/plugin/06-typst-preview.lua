vim.pack.add({ 'https://github.com/chomosuke/typst-preview.nvim' })

require('typst-preview').setup({
  invert_colors = '{"rest": "auto","image": "never"}',
  dependencies_bin = {
    ['tinymist'] = '/run/current-system/sw/bin/tinymist',
    ['websocat'] = '/run/current-system/sw/bin/websocat'
  }
})
