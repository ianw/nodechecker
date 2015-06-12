#!/bin/bash

NODEPOOL_LOGS="http://nodepool.openstack.org"

NODE_TYPES="devstack-centos7 devstack-f21"
BUILD_CLOUD="rax-dfw rax-iad rax-ord hpcloud-b1 \
           hpcloud-b2 hpcloud-b3 hpcloud-b4 hpcloud-b5"

ALL_LOGS=""
for n in $NODE_TYPES; do
    for b in $BUILD_CLOUD; do
        ALL_LOGS+=" $b.$n.log"
    done
done

STATUS_FILE=$(mktemp)
OVERALL="PASS"

echo "Nodepool status run $(date)" >> $STATUS_FILE
echo "------------------------------------------------" >> $STATUS_FILE
echo >> $STATUS_FILE

for l in $ALL_LOGS; do
    url=$NODEPOOL_LOGS/$l
    echo "Checking $url"
    output=$(wget -qO- --header="accept-encoding: gzip" $url \
                    | zcat | tail -n 4)

    # this is a pretty crappy check, but this is the last thing in the
    # devstack build scripts.  change out to give better values.
    if ! grep -q "sleep 5" <<< $output; then
        OVERALL="FAIL"
        echo "FAIL: $url" >> $STATUS_FILE
        echo "----" >> $STATUS_FILE
        echo -e "$output" >> $STATUS_FILE
        echo "----" >> $STATUS_FILE
    else
        echo "PASS: $url" >> $STATUS_FILE
    fi
    echo >> $STATUS_FILE
done

if [ -f "email-addresses" ]; then
    sed -i "1iSubject: nodepool checker $(date) : $OVERALL" $STATUS_FILE
    echo "." >> $STATUS_FILE
    /usr/sbin/sendmail $(cat email-addresses | xargs) < $STATUS_FILE
fi

echo "done!"

rm $STATUS_FILE
