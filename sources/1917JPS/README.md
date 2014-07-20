
Run "make" to extract text from the PDF using PDF miner and
build XML and HTML files.

But you'll probably want to run "make clean" first, since the files already
exist in which case make won't do anything.

Troubleshooting:

Error about absolutize: See https://github.com/opensiddur/opensiddur/wiki/Building

This is kind of weird in that build outputs are checked in.
But, git(hub) also seems the best way to manage text-file artifacts.
In other words, some thought was put into this, but there's still potential 
for a future cleaner iteration.

Create a shortcut to code directory 
(optional but recommended if you'll be hacking on this code):

ln -s ../../code/input-conversion/1917JPS/
