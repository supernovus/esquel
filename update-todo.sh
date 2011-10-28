#!/bin/sh
grep -R TODO lib/ | grep ':' | perl -p -e 's/^lib\//* /g,s/\.pm6//g,s/\s*##\s*TODO:?//g' > doc/TODO.txt

echo "* Tests: <persistent> More test coverage." >> doc/TODO.txt

