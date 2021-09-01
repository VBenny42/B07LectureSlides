for texfile in `find . -name "$1" | tr " " "_"` ; do
    texfile=$(basename "$texfile" .tex)
    texfile=$(echo "$texfile" | tr "_" " ")
    for file in `find . -name "$texfile.*" | grep -v "pdf" | grep -v "$texfile.tex" | tr " " "_"` ; do
        file=$(echo "$file" | tr "_" " ")
        echo "$file"
        # rm "$file"
    done
done