#!/bin/bash

NODEPOOL_LOGS="http://nodepool.openstack.org"

ALL_LOGS=""

# dib builds

# "old" image based build
ALL_LOGS+=" dib.devstack-centos7.log"

# minimal build
ALL_LOGS+=" dib.centos-7.log"
ALL_LOGS+=" dib.fedora-23.log"

ALL_LOGS+=" dib.ubuntu-trusty.log"
ALL_LOGS+=" dib.debian-jessie.log"

STATUS_FILE=$(mktemp)
OVERALL="PASS"

title="nodecheker run at $(date)"
echo $title >> $STATUS_FILE
printf "%${#title}s\n" | tr ' ' - >> $STATUS_FILE

echo >> $STATUS_FILE

for l in $ALL_LOGS; do
    url=$NODEPOOL_LOGS/$l
    echo "Checking $url"
    # grab the last 100 lines or so.  This is usually enough to get a
    # useful bit of the error in there.
    output=$(wget -qO- --header="accept-encoding: gzip" $url \
                    | zcat | tail -n 100)

    # this is a pretty crappy check, but this is the last thing in the
    # build scripts.  change out to give better values.
    pass=True
    if [[ $l =~ dib* ]]; then
        if  ! grep -q "Image file .* created..." <<< $output; then
            pass=False
        fi
    elif ! grep -q "sleep 5" <<< $output; then
        pass=False
    fi

    if [[ $pass == False ]]; then
        OVERALL="FAIL"
        echo "FAIL: $url" >> $STATUS_FILE
        echo "----" >> $STATUS_FILE
        # there's a lot of unmounting, etc when an image fails
        # we usually find a helpful error here
        echo -e "$output" | head -n 50 >> $STATUS_FILE
        echo "... [snip] ..." >> $STATUS_FILE
        echo -e "$output" | tail -n 5 >> $STATUS_FILE
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
    sed -i "1iSubject: [nodepool] build $(date) : $OVERALL" $STATUS_FILE
    echo "." >> $STATUS_FILE
    /usr/sbin/sendmail $(cat email-addresses | xargs) < $STATUS_FILE
else
    cat $STATUS_FILE
fi

echo "done!"

rm $STATUS_FILE
