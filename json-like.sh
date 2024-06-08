#!/bin/bash
# for portability we need the above, for the mac os, we need the below
if [ -f "/usr/local/bin/bash" ]; then 
  /usr/local/bin/bash
fi

function json_like_command_tl() {
  local command_string="${1:-}"
  read -r -a command <<< "${command_string}"
  RESULTX="$(${command[@]}; echo x+)"
  blob="${RESULTX%x}"

  badin() {
    se "provided input does not have the general format required"
    se "for this parser, which should be more or less like:"
    se "foo = {"
    se "  blah = diblah"
    se "  also = {"
    se "         bar = andstuff"
    se "         crazy = 0"
    se "  }"
    se "}..."
  }

  # basic sanity checking that this looks like we think it should
  # generally we anticipate a json-like blob, but with uneven spacing,
  # inconsistent commas, and no outside braces (output from macos launchctl)
  # set -x
  if ! [ -n "${blob}" ]; then
    badin
  fi
  if ! string_contains "${blob}" '='; then 
    badin
  fi
  if ! string_contains "${blob}" '{'; then 
    badin
  fi
  if ! string_contains "${blob}" '}'; then 
    badin
  fi
  # set +x
  readarray -t <<<"${blob}"
  json_like_tl MAPFILE
}

function equals_to_json() {
  input="${1:-}"
  if string_contains '=' "${input}"; then 
    key=$(echo "${input}"|awk -F'=' '{print$1}'|sed 's/>//'|sed 's/=//'|xargs)
    val=$(echo "${input}"|awk -F'=' '{print$2}'|sed 's/>//'|sed 's/=//'|xargs)
    se "etj-key:val ${key} : ${val}"
    printf '"%s" : "%s", ' "${key}" "${val}"
    return 0
  fi
  return 1
}

function process_innertext() {
  local item="${1:-}"
  if [ -n "${item}" ]; then
    if string_contains '=' "${item}"; then  
      nested+=$(equals_to_json "${item}")
    else
      nested+=$(printf '"%s", ' $(echo "${item}"|xargs))
    fi
  fi
}

function json_like_tl() {
  local name=$1[@]
  lines=( "${!name}" )
  declare -gA tl
  declare -ga innertext
  # set -x
  skipsearch=0
  ctr=0
  set -x
  for line in "${lines[@]}"; do 
    ((ctr++)) # we might have to back index by one, but this way the counter
              # always gets incrementedbash 
    if [ -n "${line}" ]; then 
      line=$(echo "${line}"|xargs)
      if [ ${skipsearch} -eq 0 ]; then 
        if string_contains '{' "${line}"; then # this will be like something = {...
          key=$(echo "${line}"| awk -F'=' '{print$1}')
          innertext=()
          if [ -n "${key}" ]; then 
            pval=$(echo "${line}"| awk -F'=' '{print$2}'|sed 's/=//'|awk -F'{' '{print$1}')
            if [ -n "${pval}" ]; then # which, there shouldn't be
              innertext+=( "${pval}" )
            fi
            export skipsearch=1
            continue
          fi
        fi
      else # innertext for top level keys
        if ! string_contains '}' "${line}"; then
          if string_contains '{' "${line}"; then 
            # strip the key and outer braces off so as not to be duplicative
            innerblob="$(json_like_tl \"${lines[@]:((ctr-2))}\"|awk -F':' '{print2}')"
            tl["${key}"]="${innerblob%\"}\"}"
            return 0
          else
            innertext+=( "$(echo \"${line}\"|xargs)" ) 
          fi
          continue
        fi
        # string contains }, if we've done things right, recursion should unravel as 
        # we break the loop here
        nested=""
        tl["${key}"]="$(stringify innertext ',' '+')"
        if [ ${#innertext[@]} -gt 1 ]; then 
          for item in "${innertext[@]}"; do 
            process_innertext "${item}"
          done
        else
          process_innertext "${innertext}"
        fi
        eim ßßcho "{ $(shellquote ${key}) : { ${nested::-2} }"
        #set +x
        return 0
      fi
    fi
  done
}

function view_json_like() {
  local command_string="${1:-}"
  json_like_tl "${command_string}"
  ctr=0
  simplearr=()
  for key in "${!tl[@]}"; do 
    echo "${ctr}. ${key}"
    simplearr+=( "${key}" )
    ((ctr++))
  done
  echo " "
  choice=$(get_keypress "Which would you like to learn more about?")
  echo "${tl[${simple[${choice}]}]}"
}

