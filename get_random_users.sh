#!/usr/bin/env bash

JQ=`which jq`
if [[ $JQ == "" ]]; then
    echo "You must have jq installed to use this script."
    exit 1
fi
CSVLOOK=`which csvlook`
if [[ $CSVLOOK == "" ]]; then
    echo "You must have csvlook installed to use this script."
    exit 1
fi
CSVSQL=`which csvsql`
if [[ $CSVSQL == "" ]]; then
    echo "You must have csvsql installed to use this script."
    exit 1
fi
JSON2CSV=`which json2csv`
if [[ $JSON2CSV == "" ]]; then
    echo "You must have json2csv installed to use this script."
    exit 1
fi
HEADER=`which header`
if [[ $HEADER == "" ]]; then
    echo "You need J. Janssens' `header` program to use this script."
    echo "  https://github.com/jeroenjanssens/data-science-at-the-command-line"
    exit 1
fi

FILEBASE="rusers"
CHATTY="false"
NUSERS=10
HELPFLAG=0

help()
{
    cat <<EOF
Usage: ./get_random_users.sh   -<f>|--<flag> arg
                               -h / --help       : print the help menu
                               -f / --filebase   : output file "base name"
                               -n / --nusers     : number of users to generate
                               -c / --chatty     : show your work...

Get a set of random users from http://api.randomuser.me and store the
output in "FILEBASE".json. Then, filter the output down to only a handful
of fields (we don't care about many of the default fields included) and
store this output in "FILEBASE"_filtered.json. You need to have the `jq`
program installed to do this. Next, turn the JSON into flat csv with
`json2csv` and store the output in "FILEBASE"_filtered.csv. This is actually
the output you probably want.

Additionally use `csvsql` to merge a couple of the fields and produce a
new file, "FILEBASE"_filtered_merged.csv. Then take that CSV and produce
files containing the header and body of the merged CSV.

EOF
}

if [[ $# == 0 ]]; then
    echo "Running with default arguments: "
    echo "   FILEBASE = $FILEBASE"
    echo "   NUSERS   = $NUSERS"
    echo "   CHATTY   = $CHATTY"
fi

#
# Parse arguments
#
while [[ $# > 0 ]]
do
    key="$1"
    shift

    case $key in
        -h|--help)
            HELPFLAG=1
            ;;
        -f|--filebase)
            FILEBASE="$1"
            shift
            ;;
        -c|--chatty)
            CHATTY="true"
            ;;
        -n|--nusers)
            NUSERS="$1"
            shift
            ;;
        *)           # unknown option
            echo "Unknown option!"
            ;;
    esac
done

if [[ $HELPFLAG == 1 ]]; then
    help
    exit 0
fi

#
# Get to work...
#

GETNEWUSERS=yes

if [[ $GETNEWUSERS == "yes" ]]; then
    # Get a set of random users
    curl -s "http://api.randomuser.me/?results=${NUSERS}" > ${FILEBASE}.json
fi

# Look at what we got
if [[ $CHATTY == "true" ]]; then
    jq "." ${FILEBASE}.json
fi

# Just get a few fields 
< ${FILEBASE}.json jq -r "[.results[] | {first: .user.name.first, last: .user.name.last, sex: .user.gender, email: .user.email, street: .user.location.street, city: .user.location.city, state: .user.location.state, zipcode: .user.location.zip}]" > ${FILEBASE}_filtered.json

# Turn the JSON to flat csv
< ${FILEBASE}_filtered.json json2csv -f first,last,sex,email,street,city,state,zipcode > ${FILEBASE}_filtered.csv

# Look at what we got
if [[ $CHATTY == "true" ]]; then
    < ${FILEBASE}_filtered.csv csvlook
fi

# Transform the csv into an sql insert script - need to create the db first
# This doesn't work as well as I would like - it only makes a `CREATE TABLE`
# and it isn't obvious how to add PRIMARY KEYs, etc. - need to do this in
# a second step anyway. Therefore, only look at the "head" of file.
# TODO - allow the user to specify the SQL dialect for insert statements
if [[ $CHATTY == "true" ]]; then
    echo "Making SQL statements..."
fi
< ${FILEBASE}_filtered.csv head | csvsql -i mysql --table users > \
                                         ${FILEBASE}_filtered.sql

# Make a head file and a body file
head -n 1 ${FILEBASE}_filtered.csv > ${FILEBASE}_filtered_header.csv
cat ${FILEBASE}_filtered.csv | header -d -n 1 > ${FILEBASE}_filtered_body.csv

exit 0
