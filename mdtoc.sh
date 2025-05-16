#!/bin/bash

function usage()
{
    echo "Usage:"
    echo "    $0 [-h|--help]"
    echo "        Prints this text and exits"
    echo "    $0 [-l l] [-u u] [-e e] [-i[EXT]] file.md"
    echo "        Generates a table of contents for file.md and prints it to stdout."
    echo "        The heading levels between l (1) and u (6) number of '#' are included."
    echo "        Any line starting with a '#' followed by at least e (2) or more spaces is excluded."
    echo "        With -i specified, file.md is modified in-place, and a backup, file.mdEXT, is created iff EXT is specified."
}


lower=1
upper=3
exclude=2
inline=""


# Read cmd line args to update properties
while [ "$1" != "" ]; do
  case $1 in
    -h|--help )
        usage $0
        exit 0
        ;;
    -l )
        lower=$2
        shift
        ;;
    -u )
        upper=$2
        shift
        ;;
    -e )
        exclude=$2
        shift
        ;;
    -i* )
        inline=$1
        ;;
    * )
        file=$1
        ;;
  esac
  shift
done


# Print usage
if [ "$file" = "" ] ; then
    usage $0
    exit 0
fi


# Sanity
if [ "$lower" = "" ] ; then
    echo "ERROR: lower heading level must be defined"
    exit 1
fi
if [ "$upper" = "" ] ; then
    echo "ERROR: upper heading level must be defined"
    exit 1
fi
if (( $lower < 1 ))  ||  (( $lower > 6 )) ; then
    echo "ERROR: lower heading level must be in range [1,6]"
    exit 1
fi
if (( $upper < 1 ))  ||  (( $upper > 6 )) ; then
    echo "ERROR: upper heading level must be in range [1,6]"
    exit 1
fi
if (( $upper < $lower )) ; then
    echo "ERROR: upper heading level must be greater than or equal to the lower"
    exit 1
fi


# Save original titles
titles="$(cat $file | egrep "^#{$lower,$upper} " | egrep -iv "Contents?" | egrep -v "# {$exclude}")"

# Generate ToC lines
titlespecs=$(echo "$titles" | perl -pe "s/^(#{$lower,$upper}) /length("'$1'") . ' '/e")
links=$(echo "$titlespecs" | while read -r titlespec
do
    echo ${titlespec:2} | tr 'A-Z+. ' 'a-z---'
done)
toclines=$(while IFS= read -r link && IFS= read -r titlespec <&3; do
    level=${titlespec:0:1}
    if (( level > 1 )) ; then
        printf "%0.s    " $(seq 1 "$((level - 1))")
    fi
    echo  "- [${titlespec:2}](#$link)"
done <<< "$links" 3<<< "$titlespecs")


# # Perl example
# replacements=(foo:bar hello:world test:end)
#
# subs=""
# for item in "${replacements[@]}"; do
#   word="${item%%:*}"        # part before colon
#   not_followed="${item##*:}"  # part after colon
#   subs+="s/$word(?!$not_followed)/<$word>/g;"
# done
#
# input="foo foobar hello helloworld test testend"
# echo "$input" | perl -pe "$subs"


# Insert a custom anchor before the title, if not already present, and replace the ToC
perltocexp="s/(# Contents?)(\n.*[^\s]+.*)*/\1\n$toclines/"
perlexp=""
while IFS= read -r link && IFS= read -r title <&3; do
    # Some characters in the search pattern must be escaped!
    # TODO: more chars
    title_escaped=$(echo ${title} | sed 's/\+/\\+/g')
    aid="<a id=$link\/>"
#     # After the title
#     perlexp+="s/$title_escaped(?!\n$aid)/$title\n$aid/;"
    # Before the title
    perlexp+="s/(?<!$aid\n)$title_escaped/$aid\n$title/;"
done <<< "$links" 3<<< "$titles"
perl $inline -0777 -pe "$perlexp" -e "$perltocexp" $file
