# fish completion for nosdshell.
#
# Completes nosdshell's own --version/-V plus the quickshell CLI it forwards
# to (subcommands log/list/kill/ipc/msg and their flags). The flag lists are
# a snapshot of the quickshell-nosd 0.3.2 CLI; refresh them from
# `quickshell --help` / `quickshell <subcommand> --help` when bumping the fork.

# Top-level flags (no subcommand given yet).
set -l top -n __fish_use_subcommand
complete -c nosdshell $top -s h -l help -d 'Print help message and exit'
complete -c nosdshell $top -s V -l version -d "Print nosdshell's version and exit"
complete -c nosdshell $top -s n -l no-duplicate -d 'Exit if another instance of the config is running'
complete -c nosdshell $top -s d -l daemonize -d 'Detach from the controlling terminal'
complete -c nosdshell $top -s p -l path -r -F -d 'Path to a QML file or config folder'
complete -c nosdshell $top -s c -l config -r -F -d 'Name of a quickshell configuration to run'
complete -c nosdshell $top -s m -l manifest -r -F -d 'Path to a quickshell manifest (deprecated)'
complete -c nosdshell $top -l no-color -d 'Disable colored logging'
complete -c nosdshell $top -l log-times -d 'Log timestamps with each message'
complete -c nosdshell $top -l log-rules -r -d 'Log rules, in QT_LOGGING_RULES format'
complete -c nosdshell $top -s v -l verbose -d 'Increase log verbosity'
complete -c nosdshell $top -l debug -r -d 'Open the given port for a QML debugger connection'
complete -c nosdshell $top -l waitfordebug -d 'Wait for a QML debugger before executing'

# Subcommands.
complete -c nosdshell -n __fish_use_subcommand -f -a log -d 'Print quickshell logs'
complete -c nosdshell -n __fish_use_subcommand -f -a list -d 'List running quickshell instances'
complete -c nosdshell -n __fish_use_subcommand -f -a kill -d 'Kill quickshell instances'
complete -c nosdshell -n __fish_use_subcommand -f -a ipc -d 'Communicate with other Quickshell instances'
complete -c nosdshell -n __fish_use_subcommand -f -a msg -d 'Deprecated alias of ipc call'

# Instance/config selection flags shared by the subcommands.
for sub in log list kill ipc msg
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -s h -l help -d 'Print help message and exit'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -s i -l id -r -d 'Instance id to operate on'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -l pid -r -d 'Process id of the instance to operate on'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -s p -l path -r -F -d 'Path to a QML file or config folder'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -s c -l config -r -F -d 'Name of a quickshell configuration to run'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -s m -l manifest -r -F -d 'Path to a quickshell manifest (deprecated)'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -s n -l newest -d 'Operate on the most recently launched instance'
    complete -c nosdshell -n "__fish_seen_subcommand_from $sub" -l any-display -d 'Do not filter instances by display connection'
end

# Flags specific to log / list / msg.
complete -c nosdshell -n '__fish_seen_subcommand_from log' -s t -l tail -r -d 'Maximum number of lines to print from the bottom'
complete -c nosdshell -n '__fish_seen_subcommand_from log' -s f -l follow -d 'Keep reading the log until the logging process terminates'
complete -c nosdshell -n '__fish_seen_subcommand_from log' -s r -l rules -r -d 'Rules for the log being read, in QT_LOGGING_RULES format'
complete -c nosdshell -n '__fish_seen_subcommand_from log' -l no-color -d 'Disable colored logging'
complete -c nosdshell -n '__fish_seen_subcommand_from log' -l log-times -d 'Log timestamps with each message'
complete -c nosdshell -n '__fish_seen_subcommand_from log' -l log-rules -r -d 'Log rules, in QT_LOGGING_RULES format'
complete -c nosdshell -n '__fish_seen_subcommand_from log' -s v -l verbose -d 'Increase log verbosity'
complete -c nosdshell -n '__fish_seen_subcommand_from list' -s a -l all -d 'List all instances'
complete -c nosdshell -n '__fish_seen_subcommand_from list' -s j -l json -d 'Output the list as json'
complete -c nosdshell -n '__fish_seen_subcommand_from list' -l show-dead -d 'Include dead instances in the list'
complete -c nosdshell -n '__fish_seen_subcommand_from msg' -s s -l show -d 'Print information about a function or target'

# Nested subcommands under ipc, and their flags.
complete -c nosdshell -n '__fish_seen_subcommand_from ipc; and not __fish_seen_subcommand_from show call wait listen prop' -f -a show -d 'Print information about available IPC targets'
complete -c nosdshell -n '__fish_seen_subcommand_from ipc; and not __fish_seen_subcommand_from show call wait listen prop' -f -a call -d 'Call an IpcHandler function'
complete -c nosdshell -n '__fish_seen_subcommand_from ipc; and not __fish_seen_subcommand_from show call wait listen prop' -f -a wait -d 'Wait for one IpcHandler signal'
complete -c nosdshell -n '__fish_seen_subcommand_from ipc; and not __fish_seen_subcommand_from show call wait listen prop' -f -a listen -d 'Listen for IpcHandler signals'
complete -c nosdshell -n '__fish_seen_subcommand_from ipc; and not __fish_seen_subcommand_from show call wait listen prop' -f -a prop -d 'Manipulate IpcHandler properties'
for nest in show call wait listen prop
    complete -c nosdshell -n "__fish_seen_subcommand_from $nest" -s h -l help -d 'Print help message and exit'
end
