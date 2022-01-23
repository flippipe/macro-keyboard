# Building a macro keyboard

⚠️ This configurations are all custom to my computer. Do not copy and past. ☢️

## Quick Deploy instructions

### Configure X11 to ignore Macro Keyboard

    # ln -s macro-keyboard/90-macrokeyboard.conf /usr/share/X11/xorg.conf.d/

Restart X Server

    # systemctl restart gdm3.service

### Configure udev Rules

    # ln -s macro-keyboard/90-macro-keyboard.rules /etc/udev/rules.d/

Reload udev rules

    # udevadm control --reload

### Configure SystemD

    $ ln -s macro-keyboard/actkbd.service ~/.config/systemd/user/

Reload Systemd

    $ systemctl --user daemon-reload


### Add script to bin folder

    $ ln -s macro-keyboard/keyboardScript.sh ~/bin/