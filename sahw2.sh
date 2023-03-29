#!/usr/local/bin/bash

# status code:
# 	[1]invalid arguments
# 	[2]invalid values
# 	[3]only one type of hash function is allowed
# 	[4]invalid checksum
# 	[5]invalid file format

usage() {
    echo -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -i files ...\n\n--sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}

# Provide -h option to show the help message
if [ "$1" = "-h" ]; then
  usage
  exit 0
fi

# Check if there is invalid arguments
if [ "$1" != "--sha256" ] && [ "$1" != "--md5" ] && [ "$1" != "-i" ]; then
  echo "Error: Invalid arguments." >&2
  usage
  exit 1
fi

hash_type=""
hashes=()
files=()

while [ $# -gt 0 ]; do
    case "$1" in
        --sha256)
            if [[ -n "$hash_type" && "$hash_type" != "sha256" ]]; then
                echo "Error: Only one type of hash function is allowed." >&2
                exit 3
            fi
            hash_type="sha256"
            shift
            while [[ $# -gt 0 && $1 != "-i" ]]; do
                if [ $1 = "--md5" ]; then
		            echo "Error: Only one type of hash function is allowed." >&2
		            exit 3
		        fi
		        hashes+=("$1")
                shift
            done
            ;;
        --md5)
            if [[ -n "$hash_type" && "$hash_type" != "md5" ]]; then
                echo "Error: Only one type of hash function is allowed." >&2
                exit 3
            fi
            hash_type="md5"
            shift
            while [[ $# -gt 0 && $1 != "-i" ]]; do
		        if [ $1 = "--sha256" ]; then
		            echo "Error: Only one type of hash function is allowed." >&2
		            exit 3
		        fi
                hashes+=("$1")
                shift
            done
            ;;
        -i)
            shift
            while [[ $# -gt 0 && $1 != "--sha256" && $1 != "--md5" ]]; do
                files+=("$1")
                shift
            done
            ;;
        -h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Invalid arguments. 1" >&2
            usage
            exit 2
            ;;
    esac
done

# Validate input arguments
if [ "${#hashes[@]}" -ne "${#files[@]}" ]; then
    echo "Error: Invalid values." >&2
    exit 2
fi


# Hash validation
for i in "${!files[@]}"
do
    # Compute the hash of the file
    if [ "$hash_type" == "md5" ]
    then
        computed_hash=$(md5sum ${files[$i]} | awk '{ print $1 }')
    elif [ "$hash_type" == "sha256" ]
    then
        computed_hash=$(sha256sum ${files[$i]} | awk '{ print $1 }')
    fi

    # Compare the computed hash with the expected hash
    if [ "$computed_hash" != "${hashes[$i]}" ]
    then
        echo "Error: Invalid checksum." >&2
        exit 4
    fi
done

# Parsing JSON & CSV
usernames=()
for file in "${files[@]}"; do
  # Determine file type
  if file_type=$(file -b "$file"); then
      if [[ "$file_type" == *"JSON"* ]]; then
          usernames+=($(jq -r '.[].username' "$file"))
      elif [[ "$file_type" == *"CSV"* ]]; then
          usernames+=($(tail -n +2 "$file" | cut -d, -f1))
      else
          echo "Error: Invalid file format." >&2
          exit 5  
      fi
  else
      echo "Error: Invalid file format." >&2
      exit 5
  fi
done

echo "This script will create the following user(s): ${usernames[@]} Do you want to continue? [y/n]:"

exit 0