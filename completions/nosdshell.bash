# bash completion for nosdshell.
#
# Completes nosdshell's own --version/-V plus the quickshell CLI it forwards
# to (subcommands log/list/kill/ipc/msg and their flags). The flag lists are
# a snapshot of the quickshell-nosd 0.3.2 CLI; refresh them from
# `quickshell --help` / `quickshell <subcommand> --help` when bumping the fork.

_nosdshell() {
  local cur prev sub nested skip i w v is_value
  local -a words value_flags
  words=("${COMP_WORDS[@]}")
  cur="${words[COMP_CWORD]}"
  prev="${words[COMP_CWORD-1]}"
  value_flags=(-p --path -c --config -m --manifest --log-rules --debug
    -t --tail -r --rules -i --id --pid)

  # A flag waiting for its value: complete paths.
  for v in "${value_flags[@]}"; do
    if [[ "$prev" == "$v" ]]; then
      COMPREPLY=($(compgen -f -- "$cur"))
      return 0
    fi
  done

  # Locate the subcommand (and, under ipc, the nested subcommand),
  # skipping over flag values.
  sub="" nested="" skip=0
  for ((i = 1; i < COMP_CWORD; i++)); do
    w="${words[i]}"
    if ((skip)); then
      skip=0
      continue
    fi
    is_value=0
    for v in "${value_flags[@]}"; do
      if [[ "$w" == "$v" ]]; then
        is_value=1
        break
      fi
    done
    if ((is_value)); then
      skip=1
    elif [[ "$w" == -* ]]; then
      continue
    elif [[ -z "$sub" ]]; then
      sub="$w"
    elif [[ "$sub" == "ipc" && -z "$nested" ]]; then
      nested="$w"
    fi
  done

  local -a flags instance_flags
  instance_flags=(-i --id --pid -p --path -c --config -m --manifest
    -n --newest --any-display)

  if [[ "$cur" == -* ]]; then
    case "$sub" in
      log)
        flags=(-h --help -t --tail -f --follow -r --rules
          "${instance_flags[@]}" --no-color --log-times --log-rules
          -v --verbose)
        ;;
      list)
        flags=(-h --help -a --all -j --json --show-dead
          "${instance_flags[@]}")
        ;;
      kill)
        flags=(-h --help "${instance_flags[@]}")
        ;;
      msg)
        flags=(-h --help -s --show "${instance_flags[@]}")
        ;;
      ipc)
        if [[ -n "$nested" ]]; then
          flags=(-h --help)
        else
          flags=(-h --help "${instance_flags[@]}")
        fi
        ;;
      *)
        flags=(-h --help -V --version -n --no-duplicate -d --daemonize
          -p --path -c --config -m --manifest --no-color --log-times
          --log-rules -v --verbose --debug --waitfordebug)
        ;;
    esac
    COMPREPLY=($(compgen -W "${flags[*]}" -- "$cur"))
    return 0
  fi

  if [[ -z "$sub" ]]; then
    COMPREPLY=($(compgen -W "log list kill ipc msg" -- "$cur"))
  elif [[ "$sub" == "ipc" && -z "$nested" ]]; then
    COMPREPLY=($(compgen -W "show call wait listen prop" -- "$cur"))
  else
    COMPREPLY=($(compgen -f -- "$cur"))
  fi
}

complete -F _nosdshell nosdshell
