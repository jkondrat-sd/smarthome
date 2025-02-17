#!/bin/sh
timestamp=$(date +%Y%m%d_%H%M%S)
jmeter -n -t /test/simple_test.xml \
       -l /result/result_${timestamp}.log \
       -j /result/jmeter_${timestamp}.log