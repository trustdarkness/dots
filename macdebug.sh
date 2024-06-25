#!/usr/bin/env bash

# again, mostly as a reminder, like objdump -t on linux
# args: binary to inspect, prints to console, no explicit return
function bindumpsymbols() {
  dsymutil -s "${1:?Please provide the path to a binary or library}"
}

# https://stackoverflow.com/questions/65488856/how-to-print-all-symbols-that-a-mach-o-binary-imports-from-dylibs
# args: binary to inspect, prints to console, no explicit return
function bindumpimportedsymbols() {
  exe="${1:?Please provide the path to a binary or library}"
  xcrun dyldinfo -bind "${exe}"
  xcrun dyldinfo -weak_bind "${exe}"
  xcrun dyldinfo -lazy_bind "${exe}"
}

# https://stackoverflow.com/questions/50657646/how-to-inspect-a-macos-executable-file-mach-o
# args: binary to inspect, prints to console, no explicit return
function bindumpsharedlibraries() {
  otool -L "${1:?Please provide the path to a binary or library}"
}

# dumps syscalls from a binary executable or library, if original source
# was c++ and function names are mangled, use c++filt to demangle
# args: binary to inspect, prints to console, no explicit return
function bindumpsyscalls() {
  nm -ju "${1:?Please provide the path to a binary or library}"
}

# https://book.hacktricks.xyz/macos-hardening/macos-security-and-privilege-escalation/macos-files-folders-and-binaries/universal-binaries-and-mach-o-format
# args: binary to inspect, prints to console, no explicit return
function binmachheader() {
   otool -arch $(system_arch) -hv \
     "${1:?Please provide the path to a binary or library}"
}

# https://newosxbook.com/tools/disarm.html
# args: binary to inspect, prints to console, no explicit return
function binstringsearch() {
  exe="${1:?Please provide the path to a binary or library as arg1}"
  sterm="${2:?Please provide a search term as arg2}"
  if ! disarm=$(type -p disarm); then
    disarm_bootstrap
  fi
  disarm -f "${sterm}" "${exe}"
}

# Uses looto to search for a given library in binaries present in the provided
# path, recursively
# https://github.com/krypted/looto
# args:
# -r recursive
# pos arg1 path to search
# pos arg2 search term
function binslookuplibraries() {
  if ! (type -p looto); then 
    mnlooto_bootstrap
  fi
  minusr=false
  while getopts 'r' OPTION; do 
    case OPTION in 
      'r')
        minusr=true
        ;;
      ?)
        echo "Usage: binslookuplibraries [options: -r] [path] [search_param]"
        ;;
    esac
  done
  path=${@:$OPTIND:1}
  sterm=${@:$OPTIND+1:1}
  if $minusr; then 
    looto -r "${path}" "${sterm}"
  else 
    looto "${path}" "${sterm}"
  fi
}

# Use mn.sh  to search for a given symbol in binaries present in the provided
# path, recursively, with additional grep options, if you'd like
# https://github.com/krypted/looto
# args:
# -r recursive
# -g grep args
# pos arg1 path to search
# pos arg2 search term
function binlookupsymbols() {
  if ! (type -p mn); then 
    mnlooto_bootstrap
  fi
  minusr=false
  while getopts 'r' OPTION; do 
    case OPTION in 
      'r')
        minusr=true
        ;;
      'g')
        grepflags="${OPTARG}"
        ;;
      ?)
        echo "Usage: binslookupsymbols [options: -r -g \$grepflags ] [path] [search_param]"
        ;;
    esac
  done
  path=${@:$OPTIND:1}
  sterm=${@:$OPTIND+1:1}
  if $minusr; then 
    mn -r "${path}" "${sterm}" "${grepflags}"
  else 
    mn "${path}" "${sterm}" "${grepflags}"
  fi
}