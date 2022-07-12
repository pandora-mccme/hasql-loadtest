#!/bin/bash

cat $1 \
  | grep "Status" \
  | awk '{print $NF}' \
  | LC_NUMERIC="C" awk '{print substr($1,length($1),1)=="m"?substr($1, 1, length($1)-1)*60:substr($1, 1, length($1)-1)}' \
  | ministat
