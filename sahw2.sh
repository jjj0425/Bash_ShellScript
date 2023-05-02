#!/usr/local/bin/bash
# Program:
#   This program is a homework of NCKU SA_2023 Spring.
#   Parse JSON and CSV files and create multiple users at once.
# History:
#   2023/03/30  jjj0425  First Release


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
read answer
if [[ "$answer" == "n" || "$answer" == "" ]]; then
    exit 0
fi

# Function to check if user already exists
function user_exists() {
    if id "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create a new user
function create_user() {
    # Check if user already exists
    if user_exists "$1"; then
        echo "Warning: user $1 already exists."
    else
        # Create user with specified shell
        pw useradd -n "$1" -s "$2" -m

        # Set user password
        echo "$3" | pw usermod "$1" -h 0

	    IFS=',' read -ra group_list <<< "$4"
        # Add user to specified groups
        for group in "${group_list[@]}"; do
	    group=$(echo "$group" | tr -d '\r')
	    if [ "$group" == "" ]; then
		    continue
	    fi
        if ! pw groupshow "$group" >/dev/null 2>&1; then
            pw groupadd "$group"
        fi
        pw groupmod "$group" -m "$1"
        done
    fi
}

function read_json() {
    local file="$1"
    jq -c '.[]' "$file" | while read -r user_info; do
        username=$(echo "$user_info" | jq -r '.username')
        password=$(echo "$user_info" | jq -r '.password')
        shell=$(echo "$user_info" | jq -r '.shell')
        groups=$(echo "$user_info" | jq -r '.groups | @sh' | tr -d "'")
        create_user "$username" "$shell" "$password" "${groups// /,}"
    done
}

function read_csv() {
    local file="$1"
    tail -n +2 "$file" | while IFS=, read -r username password shell groups; do
        create_user "$username" "$shell" "$password" "${groups// /,}"
    done
}

# Loop through files array and handle each file
for file in "${files[@]}"; do
    if grep -q '{' "$file"; then
        read_json "$file"
    else
        read_csv "$file"
    fi
done

exit 0
