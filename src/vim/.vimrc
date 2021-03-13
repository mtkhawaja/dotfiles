set nocompatible " Disable vi-compatible mode
set encoding=utf-8 " Use Unicode Supported Encoding

" Plugins ("vim-plug, https://github.com/junegunn/vim-plug)
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
      \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

"" 'PlugInstall' after adding new plugins.
call plug#begin('~/.vim/plugged')
  Plug 'https://github.com/gryf/wombat256grf.git' " wombat256grf Theme
call plug#end()


"" General
syntax on " Turn syntax highlighting on
set cursorline " Highlight Current Line
set title " Show File Name in Terminal Title Bar
colorscheme wombat256grf " Theme Selection
set number " Show Line Numbers
set mouse=a "Enable Mouse Scrolliong & Resizing
set wrap " Wrap long lines.
set showmatch " Show matching brackets
set showcmd " Show command being typed

"" Indentation 
set autoindent " Indentation
set expandtab  " Treat Tabs as Spaces
set tabstop=4  " Tabs == 4 Spaces
set pastetoggle=<F2> " Toggle 'set paste' for copying text from external sources.

"" Folding 
set foldenable " Enable Folding
set foldnestmax=10 " Folding Nest Limit
set ruler " Show Cursor Position 

"" Invisible Characters
set list "Show invisibles
set listchars=tab:>-,trail:· " Show tabs and trailing white spaces.

"" Command Line Completion
set wildmenu 
set wildmode=longest:full,full 

"" Get rid of infernal beeping
set noerrorbells
set novisualbell 