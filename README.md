# gmod-ree-boot
Ree-suite’s server restart script. Helps restart a gmod server after a certain point.
the `reeboot/` directory goes right into `garrysmod/addons/`.

## Required configuration
First of all, you'll want to add this `exit` concommand alias to `cfg/network.cfg`:

```cfg
alias "reboot_server" exit
alias "reboot_server" exit
```

This will allow Gmod's Lua layer to effectively run the `exit` command, which actually restarts the SRCDS instance on Windows.
On Linux, you might want to use some kind of script to restart the server after it exits out:

```sh
#!/bin/bash

while true; do
    ./srcds_run -game garrysmod # etc...
    printf "Server is restarting after 'exit' command.\n"
done
```

Next, put this in your `cfg/server.cfg` if you don't already have it in there:

```cfg
sv_hibernate_think 1
```

This will force the Think hook and timers to run even when nobody is on the server.
This allows Reeboot to function properly in terms of rebooting on time and rescheduling the next reboot after the server restarts.
