#!/bin/bash

NODEPOOL_LOGS="http://nodepool.openstack.org"

RAX_BUILD_CLOUD=" rax-dfw rax-iad rax-ord"
HP_BUILD_CLOUD=" hpcloud-b1 hpcloud-b2 hpcloud-b3 hpcloud-b4 hpcloud-b5"

ALL_LOGS=""

#centos/fedora check everywhere
for n in devstack-centos7 devstack-f21; do
    for b in $RAX_BUILD_CLOUD $HP_BUILD_CLOUD; do
        ALL_LOGS+=" $b.$n.log"
    done
done

#trusty / precise rax builds
for n in devstack-trusty devstack-precise; do
    for b in $RAX_BUILD_CLOUD; do
        ALL_LOGS+=" $b.$n.log"
    done
done

STATUS_FILE=$(mktemp)
OVERALL="PASS"

title="nodecheker run at $(date)"
echo $title >> $STATUS_FILE
printf "%${#title}s\n" | tr ' ' - >> $STATUS_FILE

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

if [ -d "nodechecker-output" ]; then
    d=$(date '+%Y-%m-%d')
    outfile="nodechecker-output/nodechecker-$d.txt"
    cp $STATUS_FILE $outfile
fi

if [ -f "email-addresses" ]; then
    sed -i "1iTo: $(paste -d, -s email-addresses)" $STATUS_FILE
    sed -i "1iSubject: [nodepool] devstack-node build checker $(date) : $OVERALL" $STATUS_FILE
    echo "." >> $STATUS_FILE
    /usr/sbin/sendmail $(cat email-addresses | xargs) < $STATUS_FILE
else
    cat $STATUS_FILE
fi

echo "done!"

rm $STATUS_FILE
