#!/bin/bash

# Install fonts
cp Arial.ttf /usr/local/share/fonts/
cp Dotum.ttf /usr/local/share/fonts/
fc-cache -fv
fc-list

# Install tinytex
Rscript -e "install.packages('tinytex')"
Rscript -e "tinytex::install_tinytex(force = TRUE)"

# Build EasyPeasy
Rscript -e "bookdown::render_book('index.Rmd', 'all')"

# Build EasyPeasy translations
if [ "${BUILD_TRANSLATIONS:-0}" != "1" ]; then
    exit 0
fi

buildpath=`pwd`
langs="de it sv ru so ro sq nl pt-br pl ko uk"
for lang in $langs
do
    mkdir -p _book/$lang
    cd translations/$lang



    ######################################################################
    # This fixes a problem with Unicode characters in chapter/header
    # names causing the pages to glitch. This was especially a problem
    # in the Korean and Russian pages.
    # What this does is first locally rewrite every markdown file,
    # writing an ASCII-safe tagname to each header.
    # Then, after the HTML files are generated, edit the HTML files with
    # find and replace, changing every tagname back to proper sanitized
    # Unicode tagnames.
    ######################################################################

    backtick='`'
    newline=$'\n'
    headerid="0"
    sedargs=""

    rmdfiles=`ls -1 | grep -iE '\.rmd'`
    while IFS= read -r rmdfile
    do
        filecontent=`cat "$rmdfile"`
        newfilecontent=""
        while IFS= read -r fileline
        do
            lineisheader="0"
            headerisnamed="0"
            headerisunnumbered="0"
            if [[ "${fileline:0:1}" == "#" ]]
            then
                if grep -Po "^((#)|(##))( |\t).*$" <<< "$fileline" &> /dev/null
                then
                    lineisheader="1"
                    if grep -Po "^((#)|(##))( |\t).*{[ \t]{0,}#.*}[ \t]{0,}$" <<< "$fileline" &> /dev/null
                    then
                        headerisnamed="1"
                    fi
                    if grep -Po "^((#)|(##))( |\t).*{[ \t]{0,}-[ \t]{0,}[ \t]{0,}#.*}[ \t]{0,}$" <<< "$fileline" &> /dev/null
                    then
                        headerisnamed="1"
                    fi
                    if grep -Po "^((#)|(##))( |\t).*{[ \t]{0,}-[ \t]{0,}}[ \t]{0,}$" <<< "$fileline" &> /dev/null
                    then
                        headerisunnumbered="1"
                    fi
                fi
            fi
            if [ $lineisheader = 1 ] && [ $headerisnamed = 0 ]
            then
                headerunsignaled=`sed -e "s/{[ \t]\{0,\}-[ \t]\{0,\}}[ \t]\{0,\}$//g" <<< "$fileline"`
                headername=`sed -e "s/^((#)|(##))//g" <<< "$headerunsignaled"`
                sanitizedname=`sed -e "s/^\(\(#\)\|\(##\)\)//g" -e "s/[#\\\/?!.<>${backtick}',()&@%^$~{}+=;:\"|\*\x00-\x1F]//g" -e "s/\[//g" -e "s/]//g" -e "s/^[ \t]\+//g" -e "s/[ \t]\+$//g" -e "s/[ \t]\+/-/g" -e "s/[-]\+/-/g" -e "s/[[:upper:]]*/\L&/g" <<< "$headername"`
                headerid=$((headerid+1))
                if [ $headerisunnumbered = 0 ]
                then
                    newheader="$headerunsignaled {#headerplaceholder${headerid}id}"
                else
                    newheader="$headerunsignaled {-#headerplaceholder${headerid}id}"
                fi
                newfilecontent+="$newheader$newline"
                sedargs+="-e s/headerplaceholder${headerid}id/${sanitizedname}/g "
            else
                newfilecontent+="$fileline$newline"
            fi
        done <<< "$filecontent"
        echo "$newfilecontent" > "$rmdfile"
    done <<< "$rmdfiles"

    Rscript -e "bookdown::render_book('index.Rmd', 'all')"

    shopt -s globstar
    for file in _book/**
    do
        if [ -f "$file" ]
        then
            sed -i $sedargs "$file"
            newfilename=`sed $sedargs <<< "$file"`
            mv "$file" "$newfilename" &> /dev/null
        fi
    done

    cp -r _book/* ../../_book/$lang/
    cd $buildpath
done
