#!/bin/bash
#
# createpdf.sh
# Creates a pdf document from a plaintext file.
#
# Brandon Amos <http://bamos.github.io>
# 2013.04.16

function die { echo $1; exit 42; }

[[ $# != 1 ]] && die "Usage: $0 <plaintext file>"

TEXT_FILE=$1
[[ -a $TEXT_FILE ]] || die "$TEXT_FILE is not a file."

# les options de la mise en page dans vim 
# http://vimdoc.sourceforge.net/htmldoc/print.html#popt-option
vim -e -s $TEXT_FILE <<EOF
set printoptions=number:n,paper:A4,portrait:n
set guifont=Fixed\ 8
set printheader=%<%f%h%m%=Page\ %N\ of\ %{line('$')/69+1}
hardcopy > $TEXT_FILE.ps
EOF
ps2pdf14 $TEXT_FILE.ps $TEXT_FILE.pdf
[[ $? != 0 ]] && echo "Unable to create pdf."

rm -f $TEXT_FILE.ps

