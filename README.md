# Building a macro keyboard

⚠️ This configurations are all custom to my computer. Do not copy and past. ☢️

Read [Building a Macro Keyboard](https://flippipe.github.io/post/building-a-macro-keyboard/) for more details about the files.

## Quick Deploy instructions

### Configure X11 to ignore Macro Keyboard

    # ln -s macro-keyboard/90-macrokeyboard.conf /usr/share/X11/xorg.conf.d/90-macrokeyboard.conf

Restart X Server

    # systemctl restart gdm3.service

### Configure udev Rules

    # ln -s macro-keyboard/90-macro-keyboard.rules /etc/udev/rules.d/90-macro-keyboard.rules

Reload udev rules

    # udevadm control --reload

### Configure SystemD

    $ ln -s macro-keyboard/actkbd.service ~/.config/systemd/user/actkbd.service

Reload Systemd

    $ systemctl --user daemon-reload


### Add script to bin folder

    $ ln -s macro-keyboard/keyboardScript.sh /usr/bin/keyboardScript.sh

### Add actkbd config file

    # ln -s macro-keyboard/actkbd.conf /etc/actkbd.conf
