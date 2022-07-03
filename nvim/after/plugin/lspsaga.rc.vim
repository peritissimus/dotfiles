if !exists('g:loaded_lspsaga') | finish | endif

lua << EOF
local saga = require 'lspsaga'

saga.init_lsp_saga()

EOF
nnoremap <silent> gh <cmd>lua require'lspsaga.provider'.lsp_finder()<CR>

"nnoremap <silent> <C-j> <Cmd>Lspsaga diagnostic_jump_next<CR>
"nnoremap <silent>K <Cmd>Lspsaga hover_doc<CR>
""nnoremap <silent> K <Cmd>lua require('lspsaga.hover').render_hover_doc()<CR>
"inoremap <silent> <C-k> <Cmd>Lspsaga signature_help<CR>
"nnoremap <silent> gh :Lspsaga lsp_finder<CR>
"nnoremap <silent> gp <Cmd>Lspsaga preview_definition<CR>
"nnoremap <silent> gr <Cmd>Lspsaga rename<CR>
