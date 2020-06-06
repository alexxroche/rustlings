#!/usr/bin/env bash

echo "Let's get you set up with Rustlings!"

echo "Checking requirements..."
# check that our shell has `command` else fall back to `which` 
WHICH_CMD=$(command -v command && printf '%s' '-v'||echo 'which');
if [ -x "$($WHICH_CMD git)" ]
then
    echo "SUCCESS: Git is installed"
else
    echo "ERROR: Git does not seem to be installed."
    echo "Please download Git using your package manager or over https://git-scm.com/!"
    exit 1
fi

if [ -x "$($WHICH_CMD rustc)" ]
then
    echo "SUCCESS: Rust is installed"
else
    echo "ERROR: Rust does not seem to be installed."
    echo "Please download Rust using https://rustup.rs!"
    exit 1
fi

if [ -x "$($WHICH_CMD cargo)" ]
then
    echo "SUCCESS: Cargo is installed"
else
    echo "ERROR: Cargo does not seem to be installed."
    echo "Please download Rust and Cargo using https://rustup.rs!"
    exit 1
fi

INSTALL_JQ=0 # If you would like this scrip to install jq then set this to "1"

if [ "$INSTALL_JQ" ]&&[ "$INSTALL_JQ" -eq 1 ]
then
    # install jq for faster and more efficient json parsing
    if [ -x "$($WHICH_CMD brew)" ] && uname -a|grep -q Darwin;
    then # probably OSX
        command -v jq 1>/dev/null|| $($WHICH_CMD brew) install jq
    elif [ -x "$($WHICH_CMD apt)" ] && uname -a|grep -q Linux;
    then # debian flavour
        command -v jq 1>/dev/null|| sudo $($WHICH_CMD apt) install -y jq
    elif [ -x "$($WHICH_CMD apt-get)" ] && uname -a|grep -q Linux;
    then # (older) debian flavour
        command -v jq 1>/dev/null|| sudo $($WHICH_CMD apt-get) install -y jq
    elif [ -x "$($WHICH_CMD yum)" ] && uname -a|grep -q Linux;
    then # Linux with `yum` package manager
        $WHICH_CMD jq 1>/dev/null|| sudo $($WHICH_CMD yum) install -y jq
    fi
fi #/end of optional `jq` install

if [ -x "$($WHICH_CMD jq)" ]
then
    JQ="$($WHICH_CMD jq)" #jq is much faster than python for json parsing
else
    echo "INFO: jq not located; falling back to sub-optimal native shell json parsing"
    JQ=""
fi


# Function that compares two versions strings v1 and v2 given in arguments (e.g 1.31 and 1.33.0).
# Returns 1 if v1 > v2, 0 if v1 == v2, 2 if v1 < v2.
vercomp() {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    v1=( ${1//./ } )
    v2=( ${2//./ } )
    len1=${#v1[@]}
    len2=${#v2[@]}
    max_len=$len1
    if [[ $max_len -lt $len2 ]]
    then
        max_len=$len2
    fi
    for i in $(seq 0 $max_len)
    do
        # Fill empty fields with zeros in v1
        if [ -z "${v1[$i]}" ]
        then
            v1[$i]=0
        fi
        # And in v2
        if [ -z "${v2[$i]}" ]
        then
            v2[$i]=0
        fi
        if [ ${v1[$i]} -gt ${v2[$i]} ]
        then
            return 1
        fi
        if [ ${v1[$i]} -lt ${v2[$i]} ]
        then
            return 2
        fi
    done
    return 0
}

RustVersion=$(rustc --version | cut -d " " -f 2)
MinRustVersion=1.31
vercomp $RustVersion $MinRustVersion
if [ $? -eq 2 ]
then
    echo "ERROR: Rust version is too old: $RustVersion - needs at least $MinRustVersion"
    echo "Please update Rust with 'rustup update'"
    exit 1
else
    echo "SUCCESS: Rust is up to date"
fi

Path=${1:-rustlings/}
echo "Cloning Rustlings at $Path..."
git clone -q https://github.com/rust-lang/rustlings $Path

# function to locate the version number from the latest releases JSON
locate_version(){
  if [ "$JQ" ]&&[ -x "$JQ" ]
  then
    curl -s https://api.github.com/repos/rust-lang/rustlings/releases/latest | $JQ -r .tag_name
  else # try to use shell to locate the version number in the json
    VER=$(curl -s https://api.github.com/repos/rust-lang/rustlings/releases/latest|grep tag_name)
    VER=${VER%\"*}
    VER=${VER##*\"}
    if [ "$VER" ]&& echo "$VER"|grep -q '^[[:digit:]]*\.[[:digit:]]*'
    then # check that we have something that resembles a reasonable and valid version number
        echo $VER
    else
      # last chance to find a version number by asking git itself
      VER=$(git tag|tail -n1|tr -d '\n') #take the last tag and strip new lines
      if [ "$VER" ]&& echo "$VER"|grep -q '^[[:digit:]]*\.[[:digit:]]*'
      then
        echo $VER
      else
        echo "ERROR: unable to locate version number" >&2
        exit 1
      fi
    fi
  fi
}

Version="$(locate_version)"
CargoBin="${CARGO_HOME:-$HOME/.cargo}/bin"

echo "Checking out version $Version..."
cd $Path
git checkout -q tags/$Version

echo "Installing the 'rustlings' executable..."
cargo install --force --path .

if ! [ -x "$($WHICH_CMD rustlings)" ]
then
    echo "WARNING: Please check that you have '$CargoBin' in your PATH environment variable!"
fi

# Checking whether Clippy is installed.
# Due to a bug in Cargo, this must be done with Rustup: https://github.com/rust-lang/rustup/issues/1514
Clippy=$(rustup component list | grep "clippy" | grep "installed")
if [ -z "$Clippy" ]
then
    echo "Installing the 'cargo-clippy' executable..."
    rustup component add clippy
fi

echo "All done! Run 'rustlings' to get started."
