#!/bin/bash -

set -o nounset # Treat unset variables as an error

# uncomment only-test
sed -i'.bak' 's/\/\/ only-test //g' test/SmartExchangeRouter.test.js

npm run ganache 2>&1 > /dev/null &
pid=$!
sleep 10 # wait ganache setup

child="`pgrep -P ${pid}`"
while [ x"${child}" != x"" ]
do
  pid="${child}"
  child="`pgrep -P ${pid}`"
done
trap "kill ${pid}" EXIT

npm run test
